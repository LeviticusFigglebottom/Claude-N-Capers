## Glasshouse map (C1-03 G1): contract structure, def/variants, variable-table coverage.
## Owner: ENV C. Design: docs/design/heists/glasshouse.md. Contract: docs/contracts/heist_map.md v1.1.
extends TestCase

const SCENE: String = "res://world/heists/glasshouse/glasshouse.tscn"
const REQUIRED: Dictionary = {
	"Geometry": "Node3D", "Props": "Node3D", "Lighting": "Node3D", "Navigation": "NavigationRegion3D",
	"Zones": "Node3D", "Rooms": "Node3D", "Spawns": "Node3D", "Patrols": "Node3D", "Tactical": "Node3D",
	"Gameplay": "Node3D", "Variants": "Node3D", "Mission": "Node", "ReviewCameras": "Node3D",
}
## Design doc variable table (+ rare-event carrier groups) -> slot ids.
const GROUPS: Dictionary = {
	"keycard": ["kc_counter", "kc_manager", "kc_security", "kc_breakroom", "kc_jeweler"],
	"guard_post": ["rover_boh", "rover_upper", "alley_smoker"],
	"back_door": ["back_propped", "back_locked"],
	"open_window": ["ow_breakroom_open", "ow_breakroom_latched"],
	"jeweler": ["jw_working", "jw_gone"],
	"admin_clerk": ["clerk_in", "clerk_out"],
	"salon": ["salon_open", "salon_locked"],
	"extra_loot": ["xl_delivery", "xl_manager_cash", "xl_none"],
	"escape": ["esc_alley_west", "esc_pell"],
	"customers": ["cust_1", "cust_2", "cust_3", "cust_4", "cust_5"],
	"camera": ["cam_c1", "cam_c2", "cam_c3", "cam_c4", "cam_c5", "cam_c6"],
	"security_room_staffed": ["sec_staffed", "sec_empty"],
	"code_note": ["code_admin", "code_breakroom", "code_jeweler_notebook"],
	"manager_present": ["mgr_out", "mgr_in"],
	"safe_state": ["safe_closed", "safe_open"],
	"estate": ["estate_none", "estate_bag"],
}
const RARE: Array[StringName] = [&"safe_left_open", &"estate_consignment", &"drill_relock", &"nervous_manager"]
const ROOMS: Dictionary = {
	"G1": "storage", "G7": "electrical", "G2": "workshop", "G3": "restroom", "G4": "corridor", "G8": "stair",
	"G9": "storage", "G10": "corridor", "G5": "sales_floor", "G6": "sales_floor", "U1": "break_room",
	"U2": "security_room", "U3": "restroom", "U4": "corridor", "U8": "corridor", "U5": "office",
	"U6": "office", "U7": "storage", "X1": "exterior", "X2": "exterior",
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
	assert_true(_map != null, "glasshouse.tscn instantiates a HeistMap")
	assert_eq(HeistRegistry.map_scene_path(&"glasshouse"), SCENE, "HeistRegistry resolves the map")


func test_contract_nodes() -> void:
	if _map == null:
		fail("map missing")
		return
	for n: String in REQUIRED:
		var c: Node = _map.get_node_or_null(n)
		assert_true(c != null, "required child %s" % n)
		if c != null:
			assert_true(c.is_class(REQUIRED[n]), "%s is a %s" % [n, REQUIRED[n]])
	var mission: Node = _map.get_node("Mission")
	assert_true(mission is HeistMission, "Mission script extends HeistMission")
	assert_eq(_map.floor_heights, PackedFloat32Array([0.0, 4.2]), "floor_heights")
	var nav: NavigationRegion3D = _map.get_node("Navigation") as NavigationRegion3D
	assert_true(nav.navigation_mesh != null and nav.navigation_mesh.get_polygon_count() > 0, "baked navmesh committed")
	if nav.navigation_mesh != null:
		assert_near(nav.navigation_mesh.agent_radius, 0.3, 0.001, "NPC agent radius 0.3 (D-025)")
		assert_near(nav.navigation_mesh.cell_size, 0.1, 0.001, "cell size 0.1 (D-025)")


func test_def() -> void:
	if _map == null:
		fail("map missing")
		return
	var d: HeistDef = _map.heist_def
	assert_true(d != null, "heist_def assigned")
	if d == null:
		return
	assert_eq(d.id, &"glasshouse")
	assert_eq(d.map_scene, SCENE)
	assert_eq(d.base_payout, 40000, "QC-5 base payout")
	assert_eq(d.contact, &"contact.vance")
	assert_eq(d.music_track, &"glasshouse")
	assert_eq(d.mode, Enums.HeistMode.STEALTH_OR_LOUD)
	assert_has(d.escape_options, &"van")
	assert_has(d.loot, &"loot.jewelry")
	assert_has(d.loot, &"loot.cash")


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
		# Rules may only reference groups resolved earlier (heist_map.md §5).
		for key: String in ["requires", "excludes"]:
			for og: Variant in (rule.get(key, {}) as Dictionary):
				assert_has(ruled, String(og), "rule `%s` %s references earlier group `%s`" % [g, key, og])
		ruled.append(g)
	for g2: String in GROUPS:
		assert_true(slots.has(g2), "slot group `%s` exists" % g2)
		var have: Array = slots.get(g2, [])
		assert_true(have.size() >= 2, "group `%s` has >= 2 slots" % g2)
		for sid: String in GROUPS[g2]:
			assert_has(have, sid, "group `%s` slot `%s`" % [g2, sid])
		assert_has(ruled, g2, "group `%s` has a rule" % g2)
	for g3: String in slots:
		assert_has(ruled, g3, "every slot group has a rule (`%s`)" % g3)
	var rare_ids: Array[StringName] = []
	for ev: Dictionary in t.rare_events:
		rare_ids.append(StringName(ev.get("id", &"")))
	for r: StringName in RARE:
		assert_has(rare_ids, r, "rare event %s" % r)


func test_rooms_spawns_cameras() -> void:
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
	for n2: Node in _map.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n2
		kinds[sp.kind] = int(kinds.get(sp.kind, 0)) + 1
	assert_true(int(kinds.get(SpawnPoint.Kind.PLAYER, 0)) >= 4, ">= 4 PLAYER spawns")
	assert_true(int(kinds.get(SpawnPoint.Kind.POLICE, 0)) >= 3, ">= 3 POLICE spawns")
	assert_true(int(kinds.get(SpawnPoint.Kind.GUARD, 0)) >= 4, "floor post + 3 guard_post slots")
	assert_eq(int(kinds.get(SpawnPoint.Kind.CAMERA_OPERATOR, 0)), 1, "camera operator seat")
	assert_true(_map.review_cameras.size() >= 12, ">= 12 review cameras")
	var top: bool = false
	for p: NodePath in _map.review_cameras:
		assert_true(_map.get_node_or_null(p) is Marker3D, "review camera %s resolves" % p)
		top = top or String(p).get_file().begins_with("TopDown")
	assert_true(top, "has a TopDown review camera")


## Doc constraints that the rule order must guarantee, over many seeds.
func test_rule_constraints_hold() -> void:
	if _map == null or _map.variant_table == null:
		fail("map missing")
		return
	var slots: Dictionary = VariantResolver.collect_slots(_map)
	for s: int in range(200):
		GameRng.begin_run(5000 + s)
		var v: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.ROUTINE)
		if (v.get(&"guard_post", []) as Array).has(&"alley_smoker"):
			assert_true((v.get(&"back_door", []) as Array).is_empty(), "smoker => back door not rolled (propped)")
		if (v.get(&"keycard", []) as Array).has(&"kc_jeweler"):
			assert_true((v.get(&"jeweler", []) as Array).is_empty(), "kc_jeweler carries its own jeweler")
		var n: int = (v.get(&"customers", []) as Array).size()
		assert_true(n >= 2 and n <= 4, "Routine customers 2-4 (got %d)" % n)
		assert_eq((v.get(&"guard_post", []) as Array).size(), 1, "Routine: one rover")
		var cams: int = (v.get(&"camera", []) as Array).size()
		assert_true(cams >= 1 and cams <= 3, "Routine: 1-3 live cameras (D-059, got %d)" % cams)
		assert_eq((v.get(&"keycard", []) as Array).size(), 1, "exactly one keycard")
		assert_eq((v.get(&"security_room_staffed", []) as Array).size(), 1, "operator row rolled (D-061)")
		assert_eq((v.get(&"code_note", []) as Array).size(), 1, "exactly one code note (D-061)")
		assert_eq((v.get(&"escape", []) as Array).size(), 1, "exactly one van slot")
	GameRng.begin_run(9001)
	var vb: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.BRUTAL)
	assert_eq((vb.get(&"guard_post", []) as Array).size(), 2, "Brutal: two rovers")
	assert_true((vb.get(&"camera", []) as Array).size() >= 2, "Brutal: >= 2 live cameras")


## P1 gate finding: the consignment is only takeable once the safe opens (Safe enables loot
## parented under it), and every camera slot carries a real SecurityCamera.
func test_safe_loot_locked_in_safe() -> void:
	if _map == null:
		fail("map missing")
		return
	var safe: Node = _map.get_node_or_null("Gameplay/Workshop/WorkshopSafe")
	assert_true(safe is Safe, "WorkshopSafe is a Safe")
	if safe is Safe:
		# Design: keycard (bound reader), code (code note) or drill. A reader only opens a Safe
		# whose methods include &"keycard".
		for m: StringName in [&"keycard", &"code", &"drill"]:
			assert_has((safe as Safe).methods, m, "safe method %s" % m)
		assert_eq((safe as Safe).code_group, &"glasshouse_safe", "safe code_group matches the code notes")
	var loot: Node = _map.get_node_or_null("Gameplay/Workshop/WorkshopSafe/SafeLoot")
	assert_true(loot is GameplayPrefab, "SafeLoot is parented under WorkshopSafe")
	assert_true(_map.get_node_or_null("Gameplay/Workshop/SafeLoot") == null, "no SafeLoot sibling outside the safe")
	if loot is Node3D and safe is Node3D:
		# PO6-05: the loot sits at the large safe's LootAnchor (inside the body); its UsePoint stays on the
		# floor 1.54 m in front of the safe (Workshop-local (6.5, 0, 2.1)).
		assert_true((loot as Node3D).position.is_equal_approx(Vector3(0.0, 0.142, 0.0)), "SafeLoot at the LootAnchor")
		var up: Node3D = (loot as Node3D).get_node_or_null("UsePoint") as Node3D
		if up != null:
			var p: Vector3 = (safe as Node3D).transform * (loot as Node3D).transform * up.position
			var d: float = (p - Vector3(6.5, 0.0, 2.1)).length()
			assert_true(d < 0.01, "SafeLoot UsePoint keeps its Workshop-local spot (off by %.3f m)" % d)
	var slots: Array[Node] = _map.find_children("Slot_cam_*", "VariantSlot", true, false)
	assert_eq(slots.size(), 6, "six camera slots")
	for n: Node in slots:
		var cams: int = 0
		for c: Node in n.get_children():
			cams += 1 if c is SecurityCamera else 0
		assert_eq(cams, 1, "%s has one SecurityCamera" % n.name)
	var pre: Dictionary = (_map.heist_def.preplanning if _map.heist_def != null else {})
	assert_false((pre.get("disable", []) as Array).has(&"asset.intel_cameras"), "intel_cameras offered again")
