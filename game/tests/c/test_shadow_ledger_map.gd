## Shadow Ledger map (C2 G1): contract structure, def/variants, variable-table coverage, D-040/D-046 rules.
## Owner: ENV C. Design: docs/design/heists/shadow_ledger.md (D-042). Contract: docs/contracts/heist_map.md v1.2.
extends TestCase

const SCENE: String = "res://world/heists/shadow_ledger/shadow_ledger.tscn"
const REQUIRED: Dictionary = {
	"Geometry": "Node3D", "Props": "Node3D", "Lighting": "Node3D", "Navigation": "NavigationRegion3D",
	"Zones": "Node3D", "Rooms": "Node3D", "Spawns": "Node3D", "Patrols": "Node3D", "Tactical": "Node3D",
	"Gameplay": "Node3D", "Variants": "Node3D", "Mission": "Node", "Preplan": "Node3D", "ReviewCameras": "Node3D",
}
## Design doc variable table (+ the cleaners count and the kessler helper group) -> slot ids.
const GROUPS: Dictionary = {
	"late_partner": ["moor_late", "moor_gone"],
	"laptop": ["lap_kessler", "lap_moor", "lap_study", "lap_boardroom"],
	"server_room": ["srv_locked", "srv_contractor"],
	"keycard": ["kc_reception", "kc_security", "kc_it", "kc_kessler", "kc_lounge", "kc_guest", "kc_cleaner"],
	"code_note": ["code_it_board", "code_security_log", "code_moor_planner", "code_contractor"],
	"guard_post": ["rover_l41", "rover_l42"],
	"guard_extra": ["stair_watch", "roof_watch", "extra_none"],
	"security_room_staffed": ["sec_staffed", "sec_empty"],
	"camera": ["cam_a", "cam_b", "cam_c"],
	"laser_pattern": ["lz_static", "lz_sweep", "lz_timed"],
	"vent_open": ["vent_l42", "vent_l41", "vent_sealed"],
	"gondola": ["gon_west_l41", "gon_north_l42", "gon_stowed"],
	"escape": ["esc_heli", "esc_line", "esc_service"],
	"cleaners": ["cleaners_1", "cleaners_2", "cleaners_3"],
	"kessler": ["kessler_in", "kessler_out"],
}
const SCALARS: Dictionary = {"time_lock_s": [90.0, 120.0]}
const RARE: Array[StringName] = [&"ledger_printout", &"cage_left_open", &"kessler_sleepover", &"timelock_extended"]
const ROOMS: Dictionary = {
	"S1": "lobby", "S2": "storage", "S3": "corridor", "SA": "stair", "SB": "stair", "SL": "elevator",
	"LF1": "shaft", "LF2": "shaft", "J41": "storage", "J42": "storage", "WCW41": "restroom", "WCM42": "restroom",
	"K1": "office", "K2": "office", "K3": "lobby", "K4": "office", "K5": "office", "K6": "corridor", "K7": "corridor",
	"K8": "office", "K9": "corridor", "K10": "corridor", "K11": "server_room", "K12": "office", "K13": "security_room",
	"K14": "electrical", "K15": "storage", "K16": "corridor", "K17": "storage", "K18": "break_room", "K19": "office",
	"K20": "office", "K24": "office", "M1": "lounge", "M2": "lobby", "M3": "gallery", "M4": "office", "M5": "bedroom",
	"M6": "restroom", "M7": "corridor", "M8": "dining_room", "M9": "corridor", "M10": "corridor", "M11": "break_room",
	"M12": "electrical", "M13": "storage", "M14": "office", "M15": "corridor", "R1": "plant", "R2": "stair",
	"R3": "plant", "X1": "exterior", "X2": "exterior",
}
## Doc §Pre-planning; crew-spawn points use the category `spawn` (lead's final D-046 ruling).
const PREPLAN: Dictionary = {
	"pp_spawn_roof": "spawn", "pp_spawn_service": "spawn", "pp_drop_plant": "drop_zone", "pp_drop_refuse": "drop_zone",
	"pp_escape_heli": "escape", "pp_escape_line": "escape", "pp_escape_service": "escape",
	"pp_gondola_west": "insider", "pp_gondola_north": "insider", "pp_riser_l41": "insider", "pp_riser_l42": "insider",
}

var _map: HeistMap = null


func before_all() -> void:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps != null:
		_map = ps.instantiate() as HeistMap


func after_all() -> void:
	if _map != null:
		_map.free()


func test_map_loads_as_heist_map() -> void:
	assert_true(_map != null, "shadow_ledger.tscn instantiates a HeistMap")
	assert_eq(HeistRegistry.map_scene_path(&"shadow_ledger"), SCENE, "HeistRegistry resolves the map")


func test_contract_nodes() -> void:
	if _map == null:
		fail("map missing")
		return
	for n: String in REQUIRED:
		var c: Node = _map.get_node_or_null(n)
		assert_true(c != null, "required child %s" % n)
		if c != null:
			assert_true(c.is_class(REQUIRED[n]), "%s is a %s" % [n, REQUIRED[n]])
	assert_true(_map.get_node("Mission") is HeistMission, "Mission script extends HeistMission")
	assert_eq(_map.floor_heights, PackedFloat32Array([0.0, 3.6, 8.0, 11.6]), "floor_heights L40 / L41 / L42 / roof")
	var nav: NavigationRegion3D = _map.get_node("Navigation") as NavigationRegion3D
	assert_true(nav.navigation_mesh != null and nav.navigation_mesh.get_polygon_count() > 0, "baked navmesh committed")
	if nav.navigation_mesh != null:
		assert_near(nav.navigation_mesh.agent_radius, 0.3, 0.001, "NPC agent radius 0.3 (D-025)")
		assert_near(nav.navigation_mesh.cell_size, 0.1, 0.001, "cell size 0.1 (D-025)")


func test_def() -> void:
	if _map == null or _map.heist_def == null:
		fail("heist_def missing")
		return
	var d: HeistDef = _map.heist_def
	assert_eq(d.id, &"shadow_ledger")
	assert_eq(d.map_scene, SCENE)
	assert_eq(d.base_payout, 110000, "doc base payout")
	assert_eq(d.contact, &"contact.accountant")
	assert_eq(d.music_track, &"shadow_ledger")
	assert_eq(d.mode, Enums.HeistMode.STEALTH_ONLY, "stealth only (S11.3)")
	for e: StringName in [&"heli", &"zipline", &"lift"]:
		assert_has(d.escape_options, e)
	for l: StringName in [&"loot.ledger_laptop", &"loot.ledger_drives", &"loot.ledger_books"]:
		assert_has(d.loot, l)
	var pp: Dictionary = d.preplanning
	assert_eq(int(pp.get("favors", 0)), 6, "pre-planning favors 6")
	assert_has(pp.get("disable", []), &"asset.ammo_bag_drop", "no loud drops")
	assert_has(pp.get("disable", []), &"asset.doctor_bag_drop", "no loud drops")
	assert_true(pp.get("assets", null) is Dictionary, "nested `assets` overrides (D-046 final)")
	var assets: Dictionary = pp.get("assets", {})
	for a: StringName in [&"asset.alternate_entry", &"asset.gondola_left_hung", &"asset.riser_panel", &"asset.intel_laptop"]:
		assert_true(assets.has(a), "asset override %s" % a)
	assert_has((assets.get(&"asset.alternate_entry", {}) as Dictionary).get("point_categories", []), &"spawn")
	for tag: StringName in [&"laptop", &"keycard", &"server_door", &"cage", &"hack", &"drives", &"secure",
			&"study_safe", &"escape"]:
		assert_has(d.objectives, tag, "objective id %s (doc [tag])" % tag)


func test_variable_table_coverage() -> void:
	if _map == null or _map.variant_table == null:
		fail("variant table missing")
		return
	var t: HeistVariantTable = _map.variant_table
	var slots: Dictionary = {}
	for n: Node in _map.find_children("*", "VariantSlot", true, false):
		var vs: VariantSlot = n
		if not slots.has(String(vs.slot_group)):
			slots[String(vs.slot_group)] = []
		(slots[String(vs.slot_group)] as Array).append(String(vs.slot_id))
	var ruled: Array[String] = []
	for rule: Dictionary in t.rules:
		ruled.append(String(rule.get("group", "")))
	for g2: String in GROUPS:
		var have: Array = slots.get(g2, [])
		assert_true(have.size() >= 2, "group `%s` has >= 2 slots" % g2)
		for sid: String in GROUPS[g2]:
			assert_has(have, sid, "group `%s` slot `%s`" % [g2, sid])
		assert_has(ruled, g2, "group `%s` has a rule" % g2)
	for g3: String in slots:
		assert_has(ruled, g3, "every slot group has a rule (`%s`)" % g3)
	var scalars: Dictionary = {}
	for sc: Dictionary in t.scalars:
		scalars[String(sc.get("id", ""))] = sc.get("values", [])
	for s: String in SCALARS:
		assert_eq(scalars.get(s, []), SCALARS[s], "scalar %s values" % s)
	var rare_ids: Array[StringName] = []
	for ev: Dictionary in t.rare_events:
		rare_ids.append(StringName(ev.get("id", &"")))
	for r: StringName in RARE:
		assert_has(rare_ids, r, "rare event %s" % r)


func test_rooms_spawns_cameras_preplan() -> void:
	if _map == null:
		fail("map missing")
		return
	var rooms: Dictionary = {}
	for n: Node in _map.find_children("*", "RoomVolume", true, false):
		var rv: RoomVolume = n
		rooms[String(rv.room_id)] = String(rv.purpose)
	for id: String in ROOMS:
		assert_eq(rooms.get(id, ""), ROOMS[id], "room %s purpose" % id)
	var kinds: Dictionary = {}
	var oob: int = 0
	for n2: Node in _map.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n2
		kinds[sp.kind] = int(kinds.get(sp.kind, 0)) + 1
		if sp.kind == SpawnPoint.Kind.PLAYER and sp.tags.has(&"oob_respawn"):
			oob += 1
	assert_true(int(kinds.get(SpawnPoint.Kind.PLAYER, 0)) >= 8, "roof + service-level PLAYER spawns")
	assert_true(oob >= 2, "oob_respawn PLAYER spawns on the roof (D-040)")
	assert_true(int(kinds.get(SpawnPoint.Kind.POLICE, 0)) >= 4, "4 police directions P1-P4 (contract only)")
	assert_true(int(kinds.get(SpawnPoint.Kind.GUARD, 0)) >= 5, "reception post + 2 rover + 2 extra slots")
	assert_eq(int(kinds.get(SpawnPoint.Kind.CAMERA_OPERATOR, 0)), 1, "camera operator seat")
	assert_true(_map.review_cameras.size() >= 12, ">= 12 review cameras")
	var top: bool = false
	for p: NodePath in _map.review_cameras:
		assert_true(_map.get_node_or_null(p) is Marker3D, "review camera %s resolves" % p)
		top = top or String(p).get_file().begins_with("TopDown")
	assert_true(top, "has a TopDown review camera")
	for pid: String in PREPLAN:
		var m: Node = _map.get_node_or_null("Preplan/" + pid)
		assert_true(m is Marker3D, "preplan point %s" % pid)
		if m != null:
			assert_eq(String(m.get_meta(&"category", "")), PREPLAN[pid], "preplan %s category" % pid)
			assert_true(m.is_in_group(G.PREPLAN_POINT), "preplan %s in group" % pid)
	var svc: Node = _map.get_node_or_null("Preplan/pp_spawn_service")
	if svc != null:
		assert_eq((svc.get_meta(&"params", {}) as Dictionary).get("spawn_tag", &""), &"preplan_spawn_service")


func test_out_of_bounds_and_cameras() -> void:
	if _map == null:
		fail("map missing")
		return
	var oob: int = 0
	for n: Node in _map.find_children("*", "MapZone", true, false):
		if (n as MapZone).kind == MapZone.Kind.OUT_OF_BOUNDS:
			oob += 1
	assert_eq(oob, 4, "OUT_OF_BOUNDS curtains beyond the 4 parapet / balustrade edges (D-040)")
	var cams: Dictionary = {}
	for n2: Node in _map.get_node("Variants/Group_camera").find_children("Camera*", "", true, false):
		cams[String(n2.get_meta(&"camera_id", ""))] = true
	assert_eq(cams.size(), 12, "C1-C12 placed across the three layouts")


## Stairs (doc vertical data): Stair A L40 -> roof (6 flights), Stair B L40 -> L42 (4), feature stair (2).
func test_stair_flights() -> void:
	if _map == null:
		fail("map missing")
		return
	var flights: Array[Node] = []
	for n: Node in _map.find_children("*", "Node3D", true, false):
		if String(n.get_meta(&"kind", "")) == "stairs":
			flights.append(n)
	assert_eq(flights.size(), 12, "12 flights")
	for f: Node in flights:
		assert_true(f.find_children("Step*", "MeshInstance3D", false, false).size() >= 9, "%s has >= 9 treads" % f.name)
		assert_true(f.get_node_or_null("Ramp") is StaticBody3D, "%s has a ramp collider" % f.name)


## Doc constraints the rules must guarantee, over many seeds.
func test_rule_constraints_hold() -> void:
	if _map == null or _map.variant_table == null:
		fail("map missing")
		return
	var slots: Dictionary = VariantResolver.collect_slots(_map)
	for s: int in range(200):
		GameRng.begin_run(7000 + s)
		var v: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.ROUTINE)
		assert_eq((v.get(&"keycard", []) as Array).size(), 2, "two keycards")
		assert_eq((v.get(&"laptop", []) as Array).size(), 1, "one laptop")
		if (v.get(&"late_partner", []) as Array).has(&"moor_late"):
			assert_eq(v.get(&"laptop", []), [&"lap_moor"], "Moor in -> the laptop is on her desk")
		if (v.get(&"code_note", []) as Array).has(&"code_contractor"):
			assert_true((v.get(&"server_room", []) as Array).has(&"srv_contractor"), "code_contractor needs srv_contractor")
		assert_eq((v.get(&"code_note", []) as Array).size(), 1, "one code note")
		assert_eq((v.get(&"guard_post", []) as Array).size(), 1, "Routine: one rover")
		assert_eq((v.get(&"guard_extra", []) as Array).size(), 0, "Routine: no extra guard")
		assert_eq((v.get(&"escape", []) as Array).size(), 1, "exactly one escape")
		assert_false((v.get(&"cleaners", []) as Array).has(&"cleaners_3"), "Routine: never 3 cleaners")
		assert_false((v.get(&"rare", []) as Array).has(&"timelock_extended"), "timelock_extended is Brutal+ only")
		var kes: bool = (v.get(&"kessler", []) as Array).has(&"kessler_in")
		assert_eq(kes, (v.get(&"rare", []) as Array).has(&"kessler_sleepover"), "Kessler only with kessler_sleepover")
		assert_has([90.0, 120.0], float(v.get(&"time_lock_s", 0.0)), "time_lock_s rolled")
	for s2: int in range(50):
		GameRng.begin_run(9000 + s2)
		var vh: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.HAZARDOUS)
		assert_eq((vh.get(&"guard_post", []) as Array).size(), 2, "Hazardous+: both rovers")
		GameRng.begin_run(9500 + s2)
		var vb: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.BRUTAL)
		assert_false((vb.get(&"guard_extra", []) as Array).has(&"extra_none"), "Brutal: a walked extra (fire or roof watch)")
		GameRng.begin_run(9800 + s2)
		var vl: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.LETHAL)
		assert_eq((vl.get(&"guard_extra", []) as Array).size(), 2, "Lethal: both extras (5 guards)")


## ENV A prefabs in their doc roles.
func test_gameplay_prefabs() -> void:
	if _map == null:
		fail("map missing")
		return
	var hack: HackTerminal = _map.get_node_or_null("Gameplay/Server/HackTerminal") as HackTerminal
	assert_true(hack != null, "the ledger rack is a HackTerminal")
	if hack != null:
		assert_eq(hack.objective_tag, &"hack")
		assert_near(hack.duration_s, 45.0, 0.001, "doc: 45 s")
		assert_eq(hack.interruptions, Vector2i(1, 2), "doc: 1-2 interruptions")
	var cage: Safe = _map.get_node_or_null("Gameplay/Server/CageLock") as Safe
	assert_true(cage != null, "cage lock is a Safe")
	if cage != null:
		assert_eq(cage.size, Safe.Size.LARGE)
		assert_eq(cage.methods, [&"code", &"saw"] as Array[StringName], "code or saw")
		assert_eq(cage.code_group, &"cage")
	var study: Safe = _map.get_node_or_null("Gameplay/Study/StudySafe") as Safe
	assert_true(study != null, "study safe")
	if study != null:
		assert_has(study.methods, &"keycard", "keycard via its reader")
		assert_false(study.reader.is_empty(), "study safe bound to its reader")
	var reader: KeycardReader = _map.get_node_or_null("Gameplay/Server/ServerReader") as KeycardReader
	assert_true(reader != null and reader.targets.size() == 1, "server-door keycard reader")
	var zl: Zipline = _map.get_node_or_null("Variants/Group_escape/Slot_esc_line/BagLineE2") as Zipline
	assert_true(zl != null and not zl.end.is_empty(), "E2 bag line with its far end")
	var heli: EscapeZone = _map.get_node_or_null("Variants/Group_escape/Slot_esc_heli/HeliEscapeE1") as EscapeZone
	assert_true(heli != null, "heli escape zone")
	if heli != null:
		assert_eq(heli.escape_type, &"heli")
		assert_near(heli.arrival_delay_s, 45.0, 0.001, "heli lands 45 s after the call")
	var grids: Array[Node] = _map.get_node("Variants/Group_laser_pattern").find_children("ArtHallLasers", "", true, false)
	assert_eq(grids.size(), 3, "one art-hall grid per laser_pattern slot")


## ENV B's board merges the nested D-046 `assets` data without errors and offers the heist assets on
## this map's points (category `spawn` for the service entry).
func test_preplan_board_merges() -> void:
	var b: PreplanBoard = PreplanBoard.build(&"shadow_ledger", Enums.Difficulty.ROUTINE)
	assert_eq(b.errors, [] as Array[String], "no pre-planning data errors")
	assert_eq(b.favors_budget, 6, "favors 6")
	assert_true(b.asset(&"asset.ammo_bag_drop") == null, "ammo drop disabled (no loud)")
	for pa: Array in [[&"pp_spawn_service", &"asset.alternate_entry"], [&"pp_gondola_west", &"asset.gondola_left_hung"],
			[&"pp_gondola_north", &"asset.gondola_left_hung"], [&"pp_riser_l41", &"asset.riser_panel"],
			[&"pp_escape_line", &"asset.escape_position"], [&"pp_drop_plant", &"asset.body_bag_case_drop"]]:
		assert_has(b.assets_for_point(pa[0]), pa[1], "%s offers %s" % [pa[0], pa[1]])
	assert_false(b.assets_for_point(&"pp_riser_l41").has(&"asset.gondola_left_hung"), "gondola asset only on its points")
