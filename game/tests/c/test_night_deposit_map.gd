## Night Deposit map (C2 G1): contract structure, def/variants, variable-table coverage, D-040 rules.
## Owner: ENV C. Design: docs/design/heists/night_deposit.md. Contract: docs/contracts/heist_map.md v1.2.
extends TestCase

const SCENE: String = "res://world/heists/night_deposit/night_deposit.tscn"
const REQUIRED: Dictionary = {
	"Geometry": "Node3D", "Props": "Node3D", "Lighting": "Node3D", "Navigation": "NavigationRegion3D",
	"Zones": "Node3D", "Rooms": "Node3D", "Spawns": "Node3D", "Patrols": "Node3D", "Tactical": "Node3D",
	"Gameplay": "Node3D", "Variants": "Node3D", "Mission": "Node", "Preplan": "Node3D", "ReviewCameras": "Node3D",
}
## Design doc variable table (+ the code_carrier helper group) -> slot ids.
const GROUPS: Dictionary = {
	"keycard": ["kc_manager_desk", "kc_teller_drawer", "kc_break_locker", "kc_security", "kc_records"],
	"code_note": ["code_manager_planner", "code_break_board", "code_records_ledger"],
	"code_carrier": ["code_on_manager", "code_in_note"],
	"server_room": ["srv_basement", "srv_ground"],
	"guard_post": ["rover_ground", "rover_basement", "rover_exterior"],
	"camera": ["cam_a", "cam_b", "cam_c"],
	"security_room_staffed": ["sec_staffed", "sec_empty"],
	"vent_open": ["vent_open", "vent_locked"],
	"laser_pattern": ["laser_static", "laser_sweep", "laser_timed"],
	"night_manager": ["mgr_in", "mgr_out"],
	"cleaner": ["cleaner_ground", "cleaner_basement", "cleaner_none"],
	"escape": ["esc_van_lot", "esc_boat_quay"],
	"extra_loot": ["mgr_safe_full", "mgr_safe_empty"],
}
const SCALARS: Dictionary = {"time_lock_s": [60.0, 90.0, 120.0], "depository_bags": [3, 4, 5], "deposit_boxes": [4, 6, 8]}
const RARE: Array[StringName] = [&"time_lock_glitch", &"armored_car_early", &"fog_lifts", &"co_op_courier"]
const ROOMS: Dictionary = {
	"G1": "storage", "G2": "stair", "G3": "security_room", "G4": "break_room", "G5": "electrical",
	"G6": "storage", "G7": "corridor", "G8": "office", "G9": "banking_hall", "G10": "corridor",
	"G11": "office", "G12": "office", "G13": "lobby", "B1": "storage", "B2": "locker_room", "B3": "plant",
	"B4": "server_room", "B5": "corridor", "B6": "storage", "B7": "corridor", "B8": "vault", "B9": "vault",
	"B10": "corridor", "B11": "office", "B12": "vault", "B13": "restroom", "B14": "storage",
	"X1": "exterior", "X2": "exterior",
}
const PREPLAN: Dictionary = {
	"pp_drop_lot": "drop_zone", "pp_drop_quay": "drop_zone", "pp_spawn_lot": "player_spawn",
	"pp_spawn_quay": "player_spawn", "pp_escape_van": "escape", "pp_escape_boat": "escape",
	"pp_insider_code": "insider", "pp_insider_keycard": "insider", "pp_vent": "insider", "pp_blueprint_cams": "insider",
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
	assert_true(_map != null, "night_deposit.tscn instantiates a HeistMap")
	assert_eq(HeistRegistry.map_scene_path(&"night_deposit"), SCENE, "HeistRegistry resolves the map")


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
	assert_eq(_map.floor_heights, PackedFloat32Array([-4.0, 0.0]), "floor_heights: basement + ground (D-040)")
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
	assert_eq(d.id, &"night_deposit")
	assert_eq(d.map_scene, SCENE)
	assert_eq(d.base_payout, 90000, "doc base payout")
	assert_eq(d.contact, &"contact.accountant")
	assert_eq(d.music_track, &"night_deposit")
	assert_eq(d.mode, Enums.HeistMode.STEALTH_OR_LOUD)
	assert_has(d.escape_options, &"van")
	assert_has(d.escape_options, &"boat")
	assert_eq(int(d.preplanning.get("favors", 0)), 4, "pre-planning favors 4")
	for tag: StringName in [&"keycard", &"code", &"server", &"vault_gate", &"time_lock", &"time_lock_wait",
			&"vault_loot", &"depository", &"vault_drill", &"secure", &"escape"]:
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
		var g: String = String(rule.get("group", ""))
		for key: String in ["requires", "excludes"]:
			for og: Variant in (rule.get(key, {}) as Dictionary):
				assert_has(ruled, String(og), "rule `%s` %s references earlier group `%s`" % [g, key, og])
		ruled.append(g)
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
	assert_true(int(kinds.get(SpawnPoint.Kind.PLAYER, 0)) >= 4, ">= 4 PLAYER spawns")
	assert_true(oob >= 2, "oob_respawn PLAYER spawns at the quay steps (D-040)")
	assert_true(int(kinds.get(SpawnPoint.Kind.POLICE, 0)) >= 4, "4 police directions P1-P4")
	assert_true(int(kinds.get(SpawnPoint.Kind.GUARD, 0)) >= 5, "hall + basement posts + 3 rover slots")
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


func test_out_of_bounds_water() -> void:
	if _map == null:
		fail("map missing")
		return
	var found: bool = false
	for n: Node in _map.find_children("*", "MapZone", true, false):
		var z: MapZone = n
		if z.kind == MapZone.Kind.OUT_OF_BOUNDS:
			found = true
	assert_true(found, "OUT_OF_BOUNDS harbor water zone (D-040)")


## Stair data (doc vertical data): 2 flights x 11 risers @ 4.0/22, landing at -2.0.
func test_stair_flights() -> void:
	if _map == null:
		fail("map missing")
		return
	var flights: Array[Node] = []
	for n: Node in _map.find_children("*", "Node3D", true, false):
		if String(n.get_meta(&"kind", "")) == "stairs":
			flights.append(n)
	assert_eq(flights.size(), 2, "two flights")
	for f: Node in flights:
		assert_eq(f.find_children("Step*", "MeshInstance3D", false, false).size() >= 10, true, "%s has 10 treads" % f.name)
		assert_true(f.get_node_or_null("Ramp") is StaticBody3D, "%s has a ramp collider" % f.name)


## Doc constraints that the rule order must guarantee, over many seeds.
func test_rule_constraints_hold() -> void:
	if _map == null or _map.variant_table == null:
		fail("map missing")
		return
	var slots: Dictionary = VariantResolver.collect_slots(_map)
	for s: int in range(200):
		GameRng.begin_run(7000 + s)
		var v: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.ROUTINE)
		var carrier: Array = v.get(&"code_carrier", [])
		if carrier.has(&"code_on_manager"):
			assert_true((v.get(&"night_manager", []) as Array).has(&"mgr_in"), "code_on_manager needs the manager")
			assert_true((v.get(&"code_note", []) as Array).is_empty(), "a carried code excludes the notes")
		else:
			assert_eq((v.get(&"code_note", []) as Array).size(), 1, "one written code note")
		assert_eq((v.get(&"keycard", []) as Array).size(), 1, "exactly one keycard")
		assert_eq((v.get(&"escape", []) as Array).size(), 1, "exactly one escape")
		assert_eq((v.get(&"laser_pattern", []) as Array).size(), 1, "one laser pattern")
		assert_true((v.get(&"guard_post", []) as Array).size() <= 1, "Routine: 0-1 rover")
		assert_has([60.0, 90.0, 120.0], float(v.get(&"time_lock_s", 0.0)), "time_lock_s rolled")
	GameRng.begin_run(9001)
	var vb: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.BRUTAL)
	var n_b: int = (vb.get(&"guard_post", []) as Array).size()
	assert_true(n_b >= 1 and n_b <= 2, "Brutal: 1-2 rovers")
