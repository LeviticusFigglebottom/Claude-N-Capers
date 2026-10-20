## Ostrander Federal map (OF-C1, G1): contract nodes, ENV B's def / variant table wired (D-137), every slot of B's
## table, the D-138 cage gates, the coordinator's spawn tags and ENV D's clip-name idles, the PO6-17 markers, and the
## measurable traversal numbers of next_heist_ostrander.md §7 read off the built scene (colliders / meshes), so a regen
## that breaks one fails here. Owner: ENV C. Design: docs/design/heists/ostrander_federal.md (D-075 / D-136; QC-g as
## amended: the 1.50 m counter base). Contract: docs/contracts/heist_map.md v1.2.
extends TestCase

const SCENE: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const DEF: String = "res://world/heists/ostrander_federal/ostrander_federal_def.tres"
const VARIANTS: String = "res://world/heists/ostrander_federal/ostrander_federal_variants.tres"
const L: GDScript = preload("res://world/heists/ostrander_federal/greybox/ostrander_federal_layout.gd")
const REQUIRED: Dictionary = {
	"Geometry": "Node3D", "Props": "Node3D", "Lighting": "Node3D", "Navigation": "NavigationRegion3D",
	"Zones": "Node3D", "Rooms": "Node3D", "Spawns": "Node3D", "Patrols": "Node3D", "Tactical": "Node3D",
	"Gameplay": "Node3D", "Variants": "Node3D", "Mission": "Node", "Preplan": "Node3D", "ReviewCameras": "Node3D",
}
const BLD: String = "Geometry/Building/"
## §7.1: the VC concourse's south (vault) wall face; the lz_static bypass is between LaserPost1 and it.
const VC_SOUTH_FACE: float = 12.7
## §7.2 / QC-g amended: the solid screen base, the customers' ledge, the work tops.
const SCREEN_BASE_MIN: float = 1.5
## OF-P1 (ENV P windowed pass) numbers: §7.4 the terrace east parapet guard (solid part) / §7.1 the sweep's centre
## window / §7.7 the rope ladder's Bottom grab point clear of the hoist car footprint.
const THROW_GUARD_M: float = 1.1
const THROW_GUARD_SOLID_M: float = 0.5
const SWEEP_WINDOW_MIN_S: float = 2.0
const LADDER_CAR_CLEAR_MIN_M: float = 1.0
## Spawn tags the roster reads (coordinator, LEAD rulings): each on at least one spawn.
const SPAWN_TAGS: Array[StringName] = [&"civ_manager_mgr_floor", &"civ_manager_mgr_gallery", &"civ_manager_mgr_vault",
	&"guard_lobby", &"guard_vault", &"guard_rover_hall", &"guard_rover_gallery", &"guard_rover_basement",
	&"guard_rover_dock", &"security_operator", &"guard_vip", &"guard_vaultline", &"civ_teller", &"civ_officer",
	&"civ_customer", &"civ_plaza", &"civ_client", &"civ_vip"]
## ENV D clip names (env/d-art b2527e4d) used as idle_activity / the cower pause anim.
const CLIPS: Array[StringName] = [&"teller_count", &"counter_customer", &"queue_idle", &"check_desk_write"]
const ASSAULT: Array[String] = ["TurretVan_1", "TurretVan_2", "HeliOrbit_1", "HeliDrop_1", "HeliDrop_2", "HeliDrop_3",
	"Breach_1", "Breach_2"]

var _map: HeistMap = null


func before_all() -> void:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps != null:
		_map = ps.instantiate() as HeistMap


func after_all() -> void:
	if _map != null:
		_map.free()


func test_map_registry_and_def() -> void:
	assert_true(_map != null, "ostrander_federal.tscn instantiates a HeistMap")
	assert_eq(HeistRegistry.map_scene_path(&"ostrander_federal"), SCENE, "HeistRegistry resolves the map")
	if _map == null:
		return
	assert_true(_map.heist_def != null and _map.heist_def.resource_path == DEF, "heist_def is the registry def")
	assert_true(_map.variant_table != null and _map.variant_table.resource_path == VARIANTS, "variant_table wired")
	assert_eq(_map.heist_def.id, &"ostrander_federal", "def id")
	assert_eq(_map.heist_def.base_payout, 80000, "D-137: base payout $80k (B's block)")
	assert_true(_map.heist_def.pager_max_by_difficulty.is_empty(), "D-140 GUARDS lever: no pager_max override")


func test_contract_nodes() -> void:
	if _map == null:
		fail("map missing")
		return
	for n: String in REQUIRED:
		var c: Node = _map.get_node_or_null(n)
		assert_true(c != null and c.is_class(REQUIRED[n]), "required child %s (%s)" % [n, REQUIRED[n]])
	assert_true(_map.get_node("Mission") is HeistMission, "Mission script extends HeistMission")
	assert_eq(_map.floor_heights, PackedFloat32Array([-4.0, 0.0, 5.0, 8.6, 12.2]), "floor_heights")
	var nav: NavigationRegion3D = _map.get_node("Navigation") as NavigationRegion3D
	assert_true(nav.navigation_mesh != null and nav.navigation_mesh.get_polygon_count() > 0, "baked navmesh")
	var kinds: Dictionary = {}
	for z: Node in _map.find_children("*", "MapZone", true, false):
		kinds[(z as MapZone).kind] = true
	for k: MapZone.Kind in [MapZone.Kind.ESCAPE, MapZone.Kind.SECURE_LOOT, MapZone.Kind.PUBLIC, MapZone.Kind.RESTRICTED,
			MapZone.Kind.OUT_OF_BOUNDS]:
		assert_true(kinds.has(k), "zone kind %d present" % k)


## Every rule group of B's table has >= 2 slots in the map; every weights / force_active key names a real slot.
func test_variant_slots_match_table() -> void:
	if _map == null:
		fail("map missing")
		return
	var slots: Dictionary = {}
	for vs: Node in _map.get_node("Variants").find_children("*", "VariantSlot", true, false):
		var s: VariantSlot = vs as VariantSlot
		if not slots.has(s.slot_group):
			slots[s.slot_group] = []
		(slots[s.slot_group] as Array).append(s.slot_id)
	for r: Dictionary in _map.variant_table.rules:
		var g: StringName = r["group"]
		assert_true(slots.has(g) and (slots[g] as Array).size() >= 2, "group %s has >= 2 slots" % g)
		for d: Variant in (r.get("weights_by_difficulty", {}) as Dictionary).values():
			for sid: Variant in (d as Dictionary).keys():
				assert_has(slots.get(g, []), StringName(sid), "%s weight key %s is a slot" % [g, sid])
	for ev: Dictionary in _map.variant_table.rare_events:
		var fa: Variant = (ev.get("effects", {}) as Dictionary).get("force_active")
		if fa is Dictionary:
			assert_has(slots.get(StringName((fa as Dictionary)["group"]), []), StringName((fa as Dictionary)["slot"]),
				"rare %s forces a real slot" % ev.get("id"))


## D-138: each cage gate is a BARRED Door opened by its keypad / padlock; the vault door; route doors >= 1.0 m (§7).
func test_doors_and_cage_gates() -> void:
	if _map == null:
		fail("map missing")
		return
	var doors: Node = _map.get_node("Gameplay/Doors")
	for gate: String in ["CashCageGate", "GoldCageGate"]:
		var d: Node = doors.get_node(gate)
		assert_eq(int(d.get(&"lock")), int(Door.Lock.BARRED), "%s is BARRED (D-138)" % gate)
		assert_true(float(d.get(&"width_m")) >= 1.0, "%s >= 1.0 m" % gate)
		assert_true(d.get_node_or_null("Padlock") != null, "%s carries its padlock" % gate)
	var kp: Node = _map.get_node("Gameplay/Devices/CashCageKeypad")
	var hit: bool = false
	for p: NodePath in kp.get(&"targets"):
		hit = hit or kp.get_node_or_null(p) == doors.get_node("CashCageGate")
	assert_true(hit, "the cash-cage keypad targets its gate")
	assert_eq(int(doors.get_node("VaultDoor").get(&"lock")), int(Door.Lock.VAULT), "vault door")
	for nm: String in L.ROUTE_DOORS:
		var r: Node = doors.get_node_or_null(nm)
		assert_true(r != null and float(r.get(&"width_m")) >= 1.0, "%s is a >= 1.0 m route door" % nm)


## §7.1: the lz_static bypass gap >= 1.0 m between the grid's last post and the vault wall; levelcheck's laser metas.
func test_laser_gap() -> void:
	if _map == null:
		fail("map missing")
		return
	assert_eq(float(_map.get_meta(&"laser_min_gap_m", 0.0)), 1.0, "laser_min_gap_m")
	assert_eq(float(_map.get_meta(&"laser_crouch_face_m", 0.0)), 1.215, "laser_crouch_face_m")
	var post: StaticBody3D = _map.get_node("Variants/Group_laser_pattern/Slot_lz_static/LaserPost1") as StaticBody3D
	var gap: float = VC_SOUTH_FACE - _box(post).end.z
	assert_true(gap >= 1.0, "lz_static bypass gap %.2f m >= 1.0" % gap)
	for sid: String in ["lz_static", "lz_sweep", "lz_timed"]:
		assert_true(_map.get_node_or_null("Variants/Group_laser_pattern/Slot_%s/LaserPost0/VaultLasers" % sid) != null,
			"%s grid hangs off its emitter post" % sid)
	# OF-P1 §7.1: the sweep's centre lane (capsule 0.35 + 0.05 each side) is clear >= 2.0 s (MEDIUM 4 m: 1.52 s).
	var sweep: LaserGrid = _map.get_node("Variants/Group_laser_pattern/Slot_lz_sweep/LaserPost0/VaultLasers") as LaserGrid
	assert_eq(sweep.sweep_beams, 2, "lz_sweep: 2 beams")
	assert_near(sweep.period_s, 7.0, 0.001, "lz_sweep: 7 s")
	var win: float = _sweep_window(sweep, 0.0)
	assert_true(win >= SWEEP_WINDOW_MIN_S, "lz_sweep centre lane clear %.2f s >= %.1f" % [win, SWEEP_WINDOW_MIN_S])
	var timed: LaserGrid = _map.get_node("Variants/Group_laser_pattern/Slot_lz_timed/LaserPost0/VaultLasers") as LaserGrid
	assert_true(timed.beam_count == 4 and is_equal_approx(timed.period_s, 20.0) and is_equal_approx(timed.off_s, 6.0),
		"lz_timed unchanged (4 beams, off 6 s of 20 s)")


## §7.2 / QC-g amended: the solid screen base >= 1.50 m, the ledge 1.05, 12 work tops at 1.00, glass see_through.
func test_counter() -> void:
	if _map == null:
		fail("map missing")
		return
	for side: String in ["W", "E"]:
		var base: AABB = _box(_map.get_node(BLD + "Counter/ScreenBase" + side) as StaticBody3D)
		assert_true(base.end.y >= SCREEN_BASE_MIN - 0.001, "screen base %s top %.2f >= 1.50" % [side, base.end.y])
		assert_near(_box(_map.get_node(BLD + "Counter/CustomerLedge" + side) as StaticBody3D).end.y, 1.05, 0.001, "ledge")
		var glass: Node = _map.get_node(BLD + "Counter/BanditGlass" + side)
		assert_true(glass.is_in_group(&"see_through"), "bandit glass %s is see_through (D-142)" % side)
		assert_true(_box(glass as StaticBody3D).position.y <= base.end.y + 0.001, "glass starts on the base")
	var tops: int = 0
	for n: Node in _map.get_node("Props/MapBuilt").get_children():
		if String(n.get_meta(&"kind", "")) == "teller_worktop":
			tops += 1
			assert_near(_box(n as StaticBody3D).end.y, 1.0, 0.001, "%s top 1.00" % n.name)
	assert_eq(tops, 12, "12 teller work tops")


## §7.3 the gallery guard (1.0 m solid + glass cap to 1.1 m); §7.5 copings and the lantern >= 50 deg; §7.4 OOB.
func test_guard_slopes_and_oob() -> void:
	if _map == null:
		fail("map missing")
		return
	var m: float = 5.0
	assert_near(_box(_map.get_node(BLD + "GalleryGuard/GuardBase") as StaticBody3D).end.y - m, 1.0, 0.001, "GA base")
	var cap: Node = _map.get_node(BLD + "GalleryGuard/GuardCap")
	assert_near(_box(cap as StaticBody3D).end.y - m, 1.1, 0.001, "GA guard 1.1 m")
	assert_true(cap.is_in_group(&"see_through"), "GA cap glass see_through")
	var copings: Array[Node] = _map.get_node(BLD + "Coping").get_children()
	assert_true(copings.size() >= 10, "parapet copings built (%d)" % copings.size())
	for c: Node in copings:
		assert_true(_min_up_slope(c) >= 50.0, "%s faces >= 50 deg (%.1f)" % [c.name, _min_up_slope(c)])
	# OF-P1 §7.4: the terrace east parapet (the E2 throw spot) is a 1.1 m guard: solid to 0.5 m, a mono-pitch coping
	# from the terrace face's 1.1 m top edge falling outward; nothing past the face above 1.1 m (test_of_bag_throws.gd).
	var e: float = 8.6
	var tw: AABB = _box(_map.get_node(BLD + "Walls/FloorE/EZ0480_1_00") as StaticBody3D)
	assert_near(tw.end.y - e, THROW_GUARD_SOLID_M, 0.001, "terrace east parapet solid to %.2f m" % THROW_GUARD_SOLID_M)
	var tc: Node3D = _map.get_node(BLD + "Coping/CopingEZ0480_0170") as Node3D
	var tca: AABB = _xform(tc) * (tc.get_node("Mesh") as MeshInstance3D).get_aabb()
	assert_near(tca.end.y - e, THROW_GUARD_M, 0.001, "terrace east parapet guard %.2f m (coping top)" % THROW_GUARD_M)
	assert_true(_coping_top_beyond(tc, tca.position.x + 0.05) <= tca.end.y - 0.07 and _min_up_slope(tc) >= 50.0,
		"the throw-spot coping falls outward from its inner edge (%.1f deg)" % _min_up_slope(tc))
	var lantern: Node = _map.get_node(BLD + "Lantern/Glazing")
	assert_true(_min_up_slope(lantern) >= 50.0, "lantern glazing >= 50 deg (%.1f)" % _min_up_slope(lantern))
	assert_true(lantern.is_in_group(&"see_through"), "lantern glazing see_through")
	for o: Array in L.OOB:
		var z: MapZone = _map.get_node_or_null("Zones/" + String(o[0])) as MapZone
		assert_true(z != null and z.kind == MapZone.Kind.OUT_OF_BOUNDS, "%s OUT_OF_BOUNDS" % o[0])


## §7.6 the Corvino fire escape: flights as ramps <= 35 deg in >= 1.0 m lanes, landings >= 1.0 m, crossing steps 0.3.
func test_fire_escape() -> void:
	if _map == null:
		fail("map missing")
		return
	var fe: Node = _map.get_node(BLD + "FireEscape")
	for i: int in range(4):
		var f: Node = fe.get_node("Flight%d" % i)
		var top: float = _max_up_slope(f)
		assert_true(top > 0.0 and top <= 35.0, "Flight%d is a ramp (%.1f deg)" % [i, top])
		var mesh: MeshInstance3D = f.get_node("Mesh") as MeshInstance3D
		assert_true(mesh.mesh.get_aabb().size.z >= 1.0, "Flight%d lane >= 1.0 m" % i)
	for j: int in range(5):
		var b: AABB = _box(fe.get_node("Landing%d" % j) as StaticBody3D)
		assert_true(minf(b.size.x, b.size.z) >= 1.0, "Landing%d >= 1.0 m" % j)
	for s: String in ["CrossingStepOut", "CrossingStepIn"]:
		assert_true(_box(fe.get_node(s) as StaticBody3D).size.y <= 0.35, "%s riser <= 0.35" % s)


## §7.7 the hole: the lid plug >= 1.2 x 2.2, the hoist car in it with >= 1.0 m landing, the rope ladder B -> G 4.0 m.
func test_hole_hoist_ladder() -> void:
	if _map == null:
		fail("map missing")
		return
	var lid: AABB = _box(_map.get_node("Gameplay/Devices/Lid/Plug") as StaticBody3D)
	assert_true(lid.size.x >= 1.2 - 0.001 and lid.size.z >= 2.2 - 0.001, "hole %.2f x %.2f" % [lid.size.x, lid.size.z])
	var car: Vector3 = _map.get_node("Gameplay/Lifts/Hoist").get(&"car_size_m")
	assert_true(car.x <= lid.size.x and lid.size.z - car.z >= 1.0, "hoist car fits with a >= 1.0 m landing")
	var lad: Node = _map.get_node("Gameplay/Ladders/RopeLadder")
	assert_eq(float(lad.get_meta(&"burn_height_m", 0.0)), 4.0, "rope ladder 4.0 m after the burn")
	assert_true(float(lad.get(&"height_m")) <= 3.2 + 0.001, "stowed under the lid until the burn")
	assert_false(bool(lad.get(&"usable")), "the rope ladder is not usable at start (QC-61)")
	# OF-P1 §7.7 (c): the ladder's Bottom grab point (ladder_placeholder.tscn's Bottom marker) >= 1.0 m clear of the car's
	# footprint, inside the hole; the car against the hole's south edge.
	var ph: Node3D = (load("res://systems/prefabs/ladder/ladder_placeholder.tscn") as PackedScene).instantiate() as Node3D
	var bottom: Vector3 = _xform(lad as Node3D) * (ph.get_node("Bottom") as Node3D).position
	ph.free()
	var hx: Transform3D = _xform(_map.get_node("Gameplay/Lifts/Hoist") as Node3D)
	var car_lo: Vector2 = Vector2(hx.origin.x - car.x * 0.5, hx.origin.z - car.z * 0.5)
	var car_hi: Vector2 = Vector2(hx.origin.x + car.x * 0.5, hx.origin.z + car.z * 0.5)
	var clear: float = Vector2(maxf(maxf(car_lo.x - bottom.x, bottom.x - car_hi.x), 0.0),
		maxf(maxf(car_lo.y - bottom.z, bottom.z - car_hi.y), 0.0)).length()
	assert_true(clear >= LADDER_CAR_CLEAR_MIN_M - 0.001, "rope ladder Bottom %s is %.2f m clear of the car" % [bottom, clear])
	var lo: Vector3 = lid.position
	var hi: Vector3 = lid.end
	assert_true(bottom.x > lo.x and bottom.x < hi.x and bottom.z - 0.35 >= lo.z - 0.001 and bottom.z < hi.z,
		"the climber's column is inside the hole")
	assert_true(car_hi.y <= hi.z + 0.001 and car_lo.x >= lo.x - 0.001 and car_hi.x <= hi.x + 0.001, "the car fits the hole")
	# §7.7 (a) / (b): the hoist rig (the vault shaft with its backstop and sill, the TW guard screens) rides with the hoist
	# (disabled until the burn) on world_dynamic; the throws themselves: test_of_bag_throws.gd.
	var rig: Node = _map.get_node_or_null("Gameplay/Lifts/Hoist/Rig")
	assert_true(rig != null, "the hoist rig under the hoist")
	if rig != null:
		for nm: String in ["ShaftBackstop", "ShaftW", "ShaftE", "ShaftSill", "HoleGuardW", "HoleGuardE", "HoleGuardS"]:
			var b: StaticBody3D = rig.get_node_or_null(nm) as StaticBody3D
			assert_true(b != null and b.collision_layer == 2, "rig %s on world_dynamic" % nm)
		var gs: AABB = _box(rig.get_node("HoleGuardS") as StaticBody3D)
		assert_true(gs.end.y >= 1.5 - 0.001, "TW guard screens 1.5 m")
	# D-136 §3b.5 (LEAD): the SD attendant at her desk, on lane B's chair Seat, never a civ_officer (officer_coffee).
	var att: SpawnPoint = _map.find_child("SDAttendant", true, false) as SpawnPoint
	assert_true(att != null and att.idle_activity == &"desk_work" and att.tags.has(&"civ_sd_attendant")
		and not att.tags.has(&"civ_officer"), "the SD attendant (desk_work, civ_sd_attendant)")
	if att != null:
		assert_true(_xform(att).origin.distance_to(Vector3(37.0, -4.0, 9.67)) < 0.01, "on ChairSDAttendant's Seat")
	var caged: Node = _map.get_node("Gameplay/Ladders/CagedLadder")
	assert_eq(caged.get(&"objective_tag"), &"caged_ladder", "caged ladder tag")
	for e: Array in [["Dock", "E1"], ["Tannery", "E2"], ["Terrace", "E3"]]:
		var slot: String = "Variants/Group_escape/Slot_%s/" % {"Dock": "esc_van_dock", "Tannery": "esc_van_tannery",
			"Terrace": "esc_heli_terrace"}[e[0]]
		var sz: Node = _map.get_node(slot + "Secure" + String(e[0]))
		var ez: Node = _map.get_node(slot + "Escape" + String(e[0]))
		assert_true(sz.get(&"objective_tag") == &"secure" and ez.get(&"objective_tag") == &"escape",
			"%s: mission tags secure / escape" % e[0])
		assert_true(String(sz.get_meta(&"escape_label", "")) == e[1] and String(ez.get_meta(&"escape_label", "")) == e[1],
			"%s: escape_label %s" % [e[0], e[1]])


## OF-A6 map hooks: the lid is a replicated GameplayPrefab tagged `lid` holding the plug and the panel, the hole is a
## permanent navmesh hole, the burn prefabs start disabled, the console / rack open no door, the planner is a CodeNote,
## the bond bag / bond_delivery marker, and every expected CivilianRoute (stops >= 1.0 m from door centres).
func test_of_a6_hooks() -> void:
	if _map == null:
		fail("map missing")
		return
	var lid: GameplayPrefab = _map.get_node_or_null("Gameplay/Devices/Lid") as GameplayPrefab
	assert_true(lid != null and lid.objective_tag == &"lid", "the lid prefab (tag lid)")
	if lid != null:
		assert_true(lid.get_node_or_null("Visual/LidPanel") is MeshInstance3D, "the panel is part of the lid")
		assert_true(lid.get_node_or_null("Plug") is StaticBody3D, "the plug is part of the lid")
	assert_true(_map.get_node_or_null(BLD + "Lid") == null and _map.get_node_or_null(BLD + "Visual/LidPanel") == null,
		"no lid left in Geometry")
	var nm: NavigationMesh = (_map.get_node("Navigation") as NavigationRegion3D).navigation_mesh
	var over: int = 0
	for i: int in range(nm.get_polygon_count()):
		for vi: int in nm.get_polygon(i):
			var v: Vector3 = nm.vertices[vi]
			if absf(v.y) < 0.5 and v.x > 23.4 and v.x < 24.6 and v.z > 13.5 and v.z < 15.7:
				over += 1
	assert_eq(over, 0, "no navmesh vertex over the hole (permanent nav hole)")
	for nm2: String in ["Gameplay/Lifts/Hoist", "Gameplay/Ladders/RopeLadder"]:
		assert_false(bool(_map.get_node(nm2).get(&"enabled_at_start")), "%s placed disabled" % nm2)
	assert_eq(_map.get_node("Gameplay/Ladders/RopeLadder").get(&"objective_tag"), &"rope_ladder", "rope ladder tag")
	var drill: DrillPoint = _map.get_node("Gameplay/Devices/LidDrill") as DrillPoint
	assert_true(drill.requires_loot == &"loot.thermal_drill_part" and drill.requires_count == 2, "drill parts x2")
	assert_true((_map.get_node("Gameplay/Devices/TimeLockConsole").get(&"targets") as Array).is_empty(),
		"the time-lock console opens no door")
	for rack: Node in _map.find_children("VaultControlRack", "", true, false):
		assert_true((rack.get(&"targets") as Array).is_empty(), "the rack opens no door")
	for pc: Node in _map.find_children("CodePC", "", true, false):
		assert_eq(pc.get(&"reveals_code_group"), &"vault", "%s reveals vault" % pc.get_parent().name)
	var note: CodeNote = _map.get_node("Gameplay/Markers/CodeHintPlanner") as CodeNote
	assert_true(note != null and note.reveals_variant_group == &"code_pc" and note.code_group == &"", "the planner")
	var bonds: LootSpawn = _map.get_node_or_null("Gameplay/Loot/BondSafe/VaultBonds") as LootSpawn
	assert_true(bonds != null and bonds.loot_id == &"loot.bearer_bonds", "a bond bag in the bond safe")
	assert_true(_map.get_node_or_null("Gameplay/Markers/BondDelivery") != null, "bond_delivery marker")
	var doors: Array[Node] = _map.find_children("*", "Door", true, false)
	var ids: Dictionary = {}
	for r: Node in _map.find_children("*", "CivilianRoute", true, false):
		var route: CivilianRoute = r as CivilianRoute
		ids[route.id()] = true
		assert_true(route.stop_count() >= 2, "route %s has stops" % route.id())
		for st: PatrolPoint in route.stop_list():
			var p: Vector3 = _xform(st).origin
			for d: Node in doors:
				var dp: Vector3 = _xform(d as Node3D).origin
				if absf(dp.y - p.y) < 1.5:
					assert_true(Vector2(dp.x - p.x, dp.z - p.z).length() >= 1.0, "%s/%s >= 1 m from %s" % [r.name,
						st.name, d.name])
	for id: StringName in [&"mgr_floor", &"mgr_gallery", &"mgr_vault", &"teller_rotation", &"officer_coffee"]:
		assert_true(ids.has(id), "civilian route %s" % id)


## Stairs A / B are ramp-collision flights; RC aisles >= 1.0; the queue rails are one collider each.
func test_stairs_aisles_rails() -> void:
	if _map == null:
		fail("map missing")
		return
	var flights: int = 0
	for f: Node in _map.get_node(BLD + "StairFlights").get_children():
		if String(f.get_meta(&"kind", "")) != "stairs":
			continue   # the flights' handrails
		flights += 1
		assert_true(f.get_node_or_null("Ramp") != null, "%s has its ramp collider" % f.name)
	assert_eq(flights, 14, "Stair A (B -> R, 4 x 2 flights) + Stair B (B -> E, 3 x 2)")
	var mb: Node = _map.get_node("Props/MapBuilt")
	for i: int in range(1, 6):
		var a: AABB = _box(mb.get_node("RecordsShelf%d" % i) as StaticBody3D)
		var b: AABB = _box(mb.get_node("RecordsShelf%d" % (i + 1)) as StaticBody3D)
		assert_true(b.position.x - a.end.x >= 1.0, "RC aisle %d >= 1.0 m" % i)
	for q: String in ["QueueRail1", "QueueRail2"]:
		assert_eq(mb.get_node(q).find_children("*", "CollisionShape3D", false, false).size(), 1, "%s one collider" % q)


## Spawn tags exactly as the roster reads them; ENV D clip names; queue marks >= 0.91 m apart; NPC idle points >= 1.0 m
## off every door centre.
func test_spawn_tags_and_idles() -> void:
	if _map == null:
		fail("map missing")
		return
	var tags: Dictionary = {}
	var idles: Dictionary = {}
	var queue: Array[Vector3] = []
	var doors: Array[Vector3] = []
	for d: Node in _map.get_node("Gameplay/Doors").get_children():
		doors.append(_xform(d as Node3D).origin)
	for n: Node in _map.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n as SpawnPoint
		for t: StringName in sp.tags:
			tags[t] = true
		idles[sp.idle_activity] = true
		var p: Vector3 = _xform(sp).origin
		if sp.idle_activity == &"queue_idle" and not queue.any(func(q: Vector3) -> bool: return q.distance_to(p) < 0.01):
			queue.append(p)   # the customers slots repeat the same marks
		if sp.kind in [SpawnPoint.Kind.CIVILIAN, SpawnPoint.Kind.GUARD] and not sp.tags.has(&"scripted"):
			for dp: Vector3 in doors:
				assert_true(absf(dp.y - p.y) > 1.5 or Vector2(dp.x - p.x, dp.z - p.z).length() >= 1.0,
					"%s is >= 1.0 m off a door centre" % sp.name)
	for t2: StringName in SPAWN_TAGS:
		assert_true(tags.has(t2), "a spawn carries %s" % t2)
	assert_false(tags.has(&"guard_operator"), "the operator tag is security_operator")
	for c: StringName in CLIPS:
		assert_true(idles.has(c), "an idle uses ENV D's clip %s" % c)
	for i: int in range(queue.size()):
		for j: int in range(i + 1, queue.size()):
			assert_true(queue[i].distance_to(queue[j]) >= 0.91, "queue marks >= 0.91 m apart")
	var cower: int = 0
	for pp: Node in _map.get_node("Patrols/Civilians").get_children():
		cower += 1 if StringName(pp.get(&"pause_anim")) == &"cower_stand" else 0
	assert_eq(cower, 5, "5 cower_stand points")


## PO6-17 markers (QC-i: Breach_1/2 are window breaches, no door kind); every greybox glass body is see_through.
func test_assault_markers_and_glass() -> void:
	if _map == null:
		fail("map missing")
		return
	for nm: String in ASSAULT:
		assert_true(_map.get_node_or_null("AssaultEvents/" + nm) != null, "AssaultEvents/%s" % nm)
	for b: String in ["Breach_1", "Breach_2"]:
		assert_eq(String(_map.get_node("AssaultEvents/" + b).get_meta(&"kind", "")), "window", "%s is a window" % b)
	var glass: int = 0
	for n: Node in _map.get_node("Geometry").find_children("*", "StaticBody3D", true, false):
		if bool(n.get_meta(&"see_through", false)):
			glass += 1
			assert_true(n.is_in_group(&"see_through"), "%s in group see_through (D-142)" % n.name)
	assert_true(glass >= 10, "glazing bodies tagged (%d)" % glass)


# --- helpers --------------------------------------------------------------------------------------------

## Map-space transform (the map is not in the tree).
func _xform(n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != _map:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Map-space AABB of a body's box collider.
func _box(body: StaticBody3D) -> AABB:
	var cs: CollisionShape3D = body.get_node("Collision") as CollisionShape3D
	var sz: Vector3 = (cs.shape as BoxShape3D).size
	return _xform(cs) * AABB(-sz * 0.5, sz)


## Highest mesh vertex (map y) of a hull body at map x >= `x`.
func _coping_top_beyond(body: Node3D, x: float) -> float:
	var mi: MeshInstance3D = body.get_node("Mesh") as MeshInstance3D
	var xf: Transform3D = _xform(mi)
	var top: float = -INF
	for s: int in range(mi.mesh.get_surface_count()):
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var w: Vector3 = xf * v
			if w.x >= x:
				top = maxf(top, w.y)
	return top


## Longest clear window (s) over two cycles for the 0.8 m lane at local x `lx` (ENV P's read-out: lane half capsule
## + 0.05, the beams' thickness), from the grid's own beam_offset.
func _sweep_window(grid: LaserGrid, lx: float) -> float:
	var r: float = Tweak.crew().capsule_radius + 0.05
	var th: float = Tweak.interaction().laser_beam_thickness_m * 0.5
	var t0: float = grid.time_s
	var best: float = 0.0
	var run: float = 0.0
	var dt: float = 0.01
	var t: float = 0.0
	while t < grid.period_s * 2.0:
		grid.time_s = t
		var clear: bool = true
		for i: int in grid.beam_total():
			var x: float = grid.beam_offset(i)
			if x + th >= lx - r and x - th <= lx + r:
				clear = false
		run = run + dt if clear else 0.0
		best = maxf(best, run)
		t += dt
	grid.time_s = t0
	return best


## Up-facing, non-flat mesh triangle slopes (deg from horizontal) of a hull body's Mesh: [min, max] (a coping's 2 mm
## ridge flat and a flight's flat tongues are left out).
func _slopes(body: Node) -> Vector2:
	var mi: MeshInstance3D = body.get_node("Mesh") as MeshInstance3D
	var out: Vector2 = Vector2(INF, -1.0)
	var basis: Basis = _xform(mi).basis
	for s: int in range(mi.mesh.get_surface_count()):
		var nrm: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_NORMAL]
		for v: Vector3 in nrm:
			var w: Vector3 = (basis * v).normalized()
			if w.y > 0.01 and w.y < 0.9998:
				var a: float = rad_to_deg(acos(clampf(w.y, -1.0, 1.0)))
				out = Vector2(minf(out.x, a), maxf(out.y, a))
	return out


func _min_up_slope(body: Node) -> float:
	return _slopes(body).x


func _max_up_slope(body: Node) -> float:
	return _slopes(body).y
