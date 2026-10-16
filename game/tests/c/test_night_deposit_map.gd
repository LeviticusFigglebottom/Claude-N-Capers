## Night Deposit map (C2 G1): contract structure, def/variants, variable-table coverage, D-040 rules.
## Owner: ENV C. Design: docs/design/heists/night_deposit.md. Contract: docs/contracts/heist_map.md v1.2.
extends TestCase

const SCENE: String = "res://world/heists/night_deposit/night_deposit.tscn"
const REQUIRED: Dictionary = {
	"Geometry": "Node3D", "Props": "Node3D", "Lighting": "Node3D", "Navigation": "NavigationRegion3D",
	"Zones": "Node3D", "Rooms": "Node3D", "Spawns": "Node3D", "Patrols": "Node3D", "Tactical": "Node3D",
	"Gameplay": "Node3D", "Variants": "Node3D", "Mission": "Node", "Preplan": "Node3D", "ReviewCameras": "Node3D",
}
## Design doc variable table (+ the `rover_none` helper slot for the weighted rover count) -> slot ids.
const GROUPS: Dictionary = {
	"keycard": ["kc_manager_desk", "kc_teller_drawer", "kc_break_locker", "kc_security", "kc_records"],
	"code_note": ["code_manager_planner", "code_break_board", "code_records_ledger", "code_on_manager"],
	"server_room": ["srv_basement", "srv_ground"],
	"guard_post": ["rover_ground", "rover_basement", "rover_exterior", "rover_none"],
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
	"pp_drop_lot": "drop_zone", "pp_drop_quay": "drop_zone", "pp_spawn_lot": "spawn",
	"pp_spawn_quay": "spawn", "pp_escape_van": "escape", "pp_escape_boat": "escape",
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
	assert_eq(d.base_payout, 26000, "D-120 base payout")
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
		var sr: Dictionary = rule.get("slot_requires", {})
		for sid0: Variant in sr:
			for og2: Variant in (sr[sid0] as Dictionary):
				assert_has(ruled, String(og2), "rule `%s` slot_requires references earlier group `%s`" % [g, og2])
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
		# G2: the steps are one merged mesh per flight (Visual_<flight>); count its distinct tread levels
		var mi: MeshInstance3D = f.get_node_or_null("Visual_" + String(f.name)) as MeshInstance3D
		assert_true(mi != null and mi.mesh != null, "%s has its step mesh" % f.name)
		if mi != null and mi.mesh != null:
			assert_true(_tread_levels(mi.mesh) >= 10, "%s has 10 treads" % f.name)
		assert_true(f.get_node_or_null("Ramp") is StaticBody3D, "%s has a ramp collider" % f.name)


## Distinct heights (1 cm) of the horizontal triangles of a mesh: the tread levels of a flight.
static func _tread_levels(mesh: Mesh) -> int:
	var levels: Dictionary = {}
	for s: int in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx = PackedInt32Array(range(v.size()))
		for t: int in range(0, idx.size(), 3):
			var a: Vector3 = v[idx[t]]
			if absf(a.y - v[idx[t + 1]].y) < 0.001 and absf(a.y - v[idx[t + 2]].y) < 0.001:
				levels[roundi(a.y * 100.0)] = true
	return levels.size()


## Doc constraints that the rule order must guarantee, over many seeds.
func test_rule_constraints_hold() -> void:
	if _map == null or _map.variant_table == null:
		fail("map missing")
		return
	var slots: Dictionary = VariantResolver.collect_slots(_map)
	for s: int in range(200):
		GameRng.begin_run(7000 + s)
		var v: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.ROUTINE)
		var code: Array = v.get(&"code_note", [])
		assert_eq(code.size(), 1, "one code source (a note or the manager)")
		if code.has(&"code_on_manager"):
			assert_true((v.get(&"night_manager", []) as Array).has(&"mgr_in"), "code_on_manager needs the manager")
		assert_eq((v.get(&"keycard", []) as Array).size(), 1, "exactly one keycard")
		assert_eq((v.get(&"escape", []) as Array).size(), 1, "exactly one escape")
		assert_eq((v.get(&"laser_pattern", []) as Array).size(), 1, "one laser pattern")
		assert_eq((v.get(&"guard_post", []) as Array).size(), 1, "Routine: one guard_post pick")
		assert_true(_rovers(v) <= 1, "Routine: 0-1 rover")
		assert_false((v.get(&"rare", []) as Array).has(&"armored_car_early"), "armored_car_early is Brutal+ only")
		assert_has([60.0, 90.0, 120.0], float(v.get(&"time_lock_s", 0.0)), "time_lock_s rolled")
	GameRng.begin_run(9001)
	var vb: Dictionary = VariantResolver.resolve(_map.variant_table, slots, Enums.Difficulty.BRUTAL)
	var n_b: int = _rovers(vb)
	assert_true(n_b >= 1 and n_b <= 2, "Brutal: 1-2 rovers")


func _rovers(v: Dictionary) -> int:
	var n: int = 0
	for sid: Variant in (v.get(&"guard_post", []) as Array):
		if StringName(sid) != &"rover_none":
			n += 1
	return n


## Doc per-difficulty weights (Routine vs Brutal) take effect: frequencies over 1000 seeds.
func test_difficulty_weights() -> void:
	if _map == null or _map.variant_table == null:
		fail("map missing")
		return
	var slots: Dictionary = VariantResolver.collect_slots(_map)
	var runs: int = 1000
	var stats: Dictionary = {}
	for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.BRUTAL]:
		var c: Dictionary = {"tl120": 0, "tl60": 0, "staffed": 0, "static": 0, "no_rover": 0, "two_rovers": 0,
			"armored": 0, "on_manager": 0}
		for s: int in range(runs):
			GameRng.begin_run(20000 + s)
			var v: Dictionary = VariantResolver.resolve(_map.variant_table, slots, d)
			var tl: float = float(v.get(&"time_lock_s", 0.0))
			c["tl120"] += 1 if is_equal_approx(tl, 120.0) else 0
			c["tl60"] += 1 if is_equal_approx(tl, 60.0) else 0
			c["staffed"] += 1 if (v.get(&"security_room_staffed", []) as Array).has(&"sec_staffed") else 0
			c["static"] += 1 if (v.get(&"laser_pattern", []) as Array).has(&"laser_static") else 0
			var r: int = _rovers(v)
			c["no_rover"] += 1 if r == 0 else 0
			c["two_rovers"] += 1 if r == 2 else 0
			c["armored"] += 1 if (v.get(&"rare", []) as Array).has(&"armored_car_early") else 0
			c["on_manager"] += 1 if (v.get(&"code_note", []) as Array).has(&"code_on_manager") else 0
		stats[d] = c
	var ro: Dictionary = stats[Enums.Difficulty.ROUTINE]
	var br: Dictionary = stats[Enums.Difficulty.BRUTAL]
	Log.info(&"test", "night_deposit weights over %d seeds: Routine %s | Brutal %s" % [runs, ro, br])
	var f: Callable = func(n: int) -> float: return float(n) / float(runs)
	# time_lock_s: 120 s at 0.2 (Routine) vs 0.5 (Brutal); 60 s at 0.4 vs 0.1.
	assert_near(f.call(ro["tl120"]), 0.2, 0.05, "Routine time_lock_s 120 ~ 0.2")
	assert_near(f.call(br["tl120"]), 0.5, 0.05, "Brutal time_lock_s 120 ~ 0.5")
	assert_near(f.call(ro["tl60"]), 0.4, 0.05, "Routine time_lock_s 60 ~ 0.4")
	assert_near(f.call(br["tl60"]), 0.1, 0.04, "Brutal time_lock_s 60 ~ 0.1")
	assert_near(f.call(ro["staffed"]), 0.6, 0.05, "Routine security room staffed ~ 0.6")
	assert_near(f.call(br["staffed"]), 0.75, 0.05, "Brutal security room staffed ~ 0.75")
	assert_near(f.call(ro["static"]), 0.5, 0.05, "Routine static lasers ~ 0.5")
	assert_near(f.call(br["static"]), 0.2, 0.05, "Brutal static lasers ~ 0.2")
	assert_near(f.call(ro["no_rover"]), 0.3, 0.05, "Routine: no rover ~ 0.3 (doc 0.3 / 0.7)")
	assert_eq(int(ro["two_rovers"]), 0, "Routine never has 2 rovers")
	assert_eq(int(br["no_rover"]), 0, "Brutal always has a rover")
	assert_near(f.call(br["two_rovers"]), 0.5, 0.06, "Brutal: 2 rovers ~ 0.5")
	assert_eq(int(ro["armored"]), 0, "armored_car_early gated to Brutal+ (min_difficulty)")
	assert_near(f.call(br["armored"]), 0.08, 0.03, "Brutal armored_car_early ~ 8%")
	# code_on_manager: 0.5 (mgr_in) x 1.5 / 4.5 = 1/6.
	assert_near(f.call(ro["on_manager"]), 1.0 / 6.0, 0.04, "code_on_manager ~ 1/6 (needs mgr_in)")


## Real ENV A prefabs replace the G1 placeholders (QC-11 bag_lift, QC-12 hack_terminal).
func test_lift_and_hack_prefabs() -> void:
	if _map == null:
		fail("map missing")
		return
	var lift: BagLift = _map.get_node_or_null("Gameplay/Misc/CashLift") as BagLift
	assert_true(lift != null, "Gameplay/Misc/CashLift is a BagLift")
	if lift != null:
		assert_eq(lift.objective_tag, &"cash_lift")
		assert_near(lift.travel_s, 8.0, 0.001, "doc: 8 s per trip")
		assert_eq(lift.capacity, 2, "doc: 2 bags per cycle")
		assert_eq(lift.targets.size(), 1, "one other landing (B1)")
		assert_near(lift.position.y, 0.05, 0.001, "landing 0 = G1 car floor (0.05 m sill)")
		var b: Node3D = lift.get_node_or_null(lift.targets[0]) as Node3D
		assert_true(b != null, "LandingBasement resolves")
		if b != null:
			assert_near((lift.transform * b.position).y, -3.95, 0.001, "landing 1 = B1 car floor")
	var hacks: Array[Node] = _map.get_node("Variants/Group_server_room").find_children("HackTerminal", "", true, false)
	assert_eq(hacks.size(), 2, "one hack terminal per server_room slot")
	for h: Node in hacks:
		var ht: HackTerminal = h as HackTerminal
		assert_true(ht != null, "%s/HackTerminal is a HackTerminal" % h.get_parent().name)
		if ht != null:
			assert_eq(ht.objective_tag, &"server_hack")
			assert_near(ht.duration_s, 60.0, 0.001, "doc: 60 s (3 x 20 s)")
			assert_eq(ht.interruptions, Vector2i(2, 2), "doc: 2 reboot interruptions")
			assert_true(ht.stealth_only, "stealth only")
