## Dockside Burn map (C3 G1): contract structure, def/variants, variable-table coverage, the D-064
## rulings (QC-42 police outside, QC-37 saw targets, industrial doors, cartel caps). Owner: ENV C.
## Design: docs/design/heists/dockside_burn.md (D-064). Contract: docs/contracts/heist_map.md v1.2.
extends TestCase

const SCENE: String = "res://world/heists/dockside_burn/dockside_burn.tscn"
const REQUIRED: Dictionary = {
	"Geometry": "Node3D", "Props": "Node3D", "Lighting": "Node3D", "Navigation": "NavigationRegion3D",
	"Zones": "Node3D", "Rooms": "Node3D", "Spawns": "Node3D", "Patrols": "Node3D", "Tactical": "Node3D",
	"Gameplay": "Node3D", "Variants": "Node3D", "Mission": "Node", "Preplan": "Node3D", "ReviewCameras": "Node3D",
}
## Design doc variable table (+ the night-shift slot group and the rare-perch carrier groups).
const GROUPS: Dictionary = {
	"guard_post": ["post_gate", "post_yard_w", "post_yard_e", "post_hall", "post_platform", "post_dock", "post_quay"],
	"cash_location": ["cash_strongroom", "cash_countroom"],
	"weapons_containers": ["k1", "k2", "k3", "k4", "k5", "k6"],
	"product_location": ["prod_chamber_a", "prod_chamber_b", "prod_packing"],
	"warehouse_entry": ["door_office", "door_quay", "door_dock"],
	"east_gangway": ["gangway_down", "gangway_up"],
	"goods_lift": ["lift_powered", "lift_dead"],
	"player_perch": ["perch_roof", "perch_stack", "perch_none"],
	"escape": ["esc_van_gate", "esc_van_lane", "esc_boat"],
	"night_shift": ["shift_1", "shift_2", "shift_3"],
	"perch_viaduct": ["viaduct_on", "viaduct_off"],
	"perch_trawler": ["trawler_on", "trawler_off"],
}
const SCALARS: Dictionary = {
	"police_delay_s": [60.0, 90.0, 120.0], "cash_bags": [4, 6, 8], "product_bags": [4, 6, 8],
	"escape_eta_s": [90.0, 120.0, 150.0],
}
const RARE: Array[StringName] = [&"informant_tip", &"extra_container", &"police_tipped", &"cartel_reinforcements",
	&"fog_lifts", &"harbor_unit"]
const ROOMS: Dictionary = {
	"O1": "reception", "O2": "security_room", "ST": "stair", "LF": "elevator", "E1": "electrical", "OC": "corridor",
	"PL": "plant", "WS": "workshop", "LK": "locker_room", "J": "janitor", "PK": "warehouse", "H": "warehouse",
	"C1": "warehouse", "SP": "warehouse", "C2": "warehouse", "SR": "vault", "AN": "warehouse", "M1": "cash_office",
	"M2": "break_room", "M3": "restroom", "MC": "corridor", "HH": "stair", "GH": "office", "QS": "storage",
	"X1": "exterior", "X2": "exterior", "X3": "exterior", "X4": "exterior", "X5": "exterior",
}
const PREPLAN: Dictionary = {
	"pp_spawn_gate": "spawn", "pp_spawn_lane": "spawn", "pp_spawn_pontoon": "spawn", "pp_drop_gatehouse": "drop_zone",
	"pp_drop_lane": "drop_zone", "pp_drop_quay": "drop_zone", "pp_drop_platform": "drop_zone", "pp_escape_gate": "escape",
	"pp_escape_lane": "escape", "pp_escape_boat": "escape", "pp_perch_roof": "drop_zone", "pp_perch_stack": "drop_zone",
	"pp_gangway": "insider",
}
## Building footprint (wall centre lines): police never spawn inside it (QC-42, D-064).
const BUILDING: Rect2 = Rect2(0.0, 0.0, 48.0, 32.0)

var _map: HeistMap = null


func before_all() -> void:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps != null:
		_map = ps.instantiate() as HeistMap


func after_all() -> void:
	if _map != null:
		_map.free()


func test_map_loads_as_heist_map() -> void:
	assert_true(_map != null, "dockside_burn.tscn instantiates a HeistMap")
	assert_eq(HeistRegistry.map_scene_path(&"dockside_burn"), SCENE, "HeistRegistry resolves the map")


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
	assert_eq(_map.floor_heights, PackedFloat32Array([-1.8, 0.0, 3.6, 7.2]), "floor_heights (D-064 Q4 keeps -1.8)")
	assert_eq(_map.floor_names, PackedStringArray(["Landing", "Ground", "Mezzanine", "Roof"]), "floor_names (D-054)")
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
	assert_eq(d.id, &"dockside_burn")
	assert_eq(d.map_scene, SCENE)
	assert_eq(d.base_payout, 24000, "D-120 base payout")
	assert_eq(d.contact, &"contact.reyes")
	assert_eq(d.music_track, &"dockside_burn")
	assert_eq(d.mode, Enums.HeistMode.LOUD_ONLY, "loud only (S11.3)")
	for e: StringName in [&"van", &"boat"]:
		assert_has(d.escape_options, e)
	for l: StringName in [&"loot.cash_bricks", &"loot.weapon_crate", &"loot.contraband"]:
		assert_has(d.loot, l)
	assert_false(d.loot.has(&"loot.thermite"), "the thermite bag is a tool, not payout loot")
	for tag: StringName in [&"cartel", &"breach", &"product", &"burn", &"strongroom", &"count_cage", &"containers",
			&"secure", &"escape_wait", &"escape"]:
		assert_has(d.objectives, tag, "objective id %s (doc [tag])" % tag)
	var pp: Dictionary = d.preplanning
	assert_eq(int(pp.get("favors", 0)), 5, "pre-planning favors 5")
	for a: StringName in [&"asset.body_bag_case_drop", &"asset.spare_body_bags"]:
		assert_has(pp.get("disable", []), a, "%s disabled (no bodies in a loud-only map)" % a)
	assert_true(pp.get("assets", null) is Dictionary, "nested `assets` overrides (D-046 final)")
	var assets: Dictionary = pp.get("assets", {})
	assert_has((assets.get(&"asset.ammo_bag_drop", {}) as Dictionary).get("point_ids", []), &"pp_drop_platform")
	assert_has((assets.get(&"asset.alternate_entry", {}) as Dictionary).get("point_ids", []), &"pp_spawn_pontoon")


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
	for g: String in GROUPS:
		var have: Array = slots.get(g, [])
		assert_true(have.size() >= 2, "group `%s` has >= 2 slots" % g)
		for sid: String in GROUPS[g]:
			assert_has(have, sid, "group `%s` slot `%s`" % [g, sid])
		assert_has(ruled, g, "group `%s` has a rule" % g)
	for g2: String in slots:
		assert_has(ruled, g2, "every slot group has a rule (`%s`)" % g2)
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


func test_rooms_and_overrides() -> void:
	if _map == null:
		fail("map missing")
		return
	var rooms: Dictionary = {}
	for n: Node in _map.find_children("*", "RoomVolume", true, false):
		var rv: RoomVolume = n
		rooms[String(rv.room_id)] = rv
	for id: String in ROOMS:
		assert_true(rooms.has(id), "room %s" % id)
		if rooms.has(id):
			assert_eq(String((rooms[id] as RoomVolume).purpose), ROOMS[id], "room %s purpose" % id)
	for hb: String in ["C1", "SP", "C2"]:
		if rooms.has(hb):
			assert_eq((rooms[hb] as RoomVolume).get_meta(&"ceiling_range", Vector2.ZERO), Vector2(6.0, 9.0),
				"%s high-bay ceiling override 6.0-9.0 (D-064 Q3)" % hb)


func test_spawns_police_outside_the_building() -> void:
	if _map == null:
		fail("map missing")
		return
	var players: int = 0
	var oob: int = 0
	var police: Array[SpawnPoint] = []
	for n: Node in _map.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n
		if sp.kind == SpawnPoint.Kind.PLAYER:
			players += 1
			oob += 1 if sp.tags.has(&"oob_respawn") else 0
		elif sp.kind == SpawnPoint.Kind.POLICE:
			police.append(sp)
	assert_true(players >= 12, "gate + lane + pontoon PLAYER spawns (got %d)" % players)
	assert_true(oob >= 3, "oob_respawn spawns on the quay (D-040)")
	assert_eq(police.size(), 6, "P1e, P1w, P2, P3 (gangway_down), P4, P5")
	for sp2: SpawnPoint in police:
		var p: Vector3 = sp2.global_position if sp2.is_inside_tree() else _world(sp2)
		var inside: bool = BUILDING.has_point(Vector2(p.x, p.z)) and p.y < 8.0
		assert_false(inside, "QC-42: police spawn %s is outside the building" % sp2.name)
	var roof: SpawnPoint = _map.get_node_or_null("Spawns/PoliceRoof") as SpawnPoint
	assert_true(roof != null and bool(roof.get_meta(&"police_only", false)), "P5 roof spawn is a police-only island")


## Building ENTRY points are breach targets only (QC-42); every padlock / container lock is a saw
## target (QC-37, D-057).
func test_entry_points_and_saw_targets() -> void:
	if _map == null:
		fail("map missing")
		return
	var building_entries: int = 0
	for n: Node in _map.get_node("Tactical").get_children():
		var tp: TacticalPoint = n as TacticalPoint
		if tp == null or tp.kind != TacticalPoint.Kind.ENTRY:
			continue
		var on_shell: bool = tp.tags.has(&"roller") or tp.tags.has(&"door") or tp.tags.has(&"skylight")
		if on_shell:
			building_entries += 1
			assert_has(tp.tags, &"breach_only", "%s is breach-only" % tp.name)
	assert_true(building_entries >= 14, "building ENTRY points (got %d)" % building_entries)
	var saws: int = 0
	for n2: Node in _map.find_children("Padlock", "", true, false):
		assert_true(n2 is Padlock, "%s is ENV A's padlock prefab (QC-37; joins G.SAW_TARGET when ready)" % _map.get_path_to(n2))
		assert_eq((n2 as Padlock).targets.size(), 1, "%s opens one target" % _map.get_path_to(n2))
		saws += 1
	assert_eq(saws, 13, "7 roller-door padlocks + 6 container padlocks")


## Doc vertical data: ST 4 flights, the platform stair 2, the fire stair 2, the quay steps 1.
func test_stair_flights() -> void:
	if _map == null:
		fail("map missing")
		return
	var flights: Array[Node] = []
	for n: Node in _map.find_children("*", "Node3D", true, false):
		if String(n.get_meta(&"kind", "")) == "stairs":
			flights.append(n)
	assert_eq(flights.size(), 9, "9 flights")
	for f: Node in flights:
		assert_true(f.find_children("Step*", "MeshInstance3D", false, false).size() >= 9, "%s has >= 9 treads" % f.name)
		assert_true(f.get_node_or_null("Ramp") is StaticBody3D, "%s has a ramp collider" % f.name)


## Wide doors are `industrial_door` (D-064 Q3 scale rule); the fire shutters are tagged per product room.
func test_doors() -> void:
	if _map == null:
		fail("map missing")
		return
	var industrial: int = 0
	for n: Node in _map.get_node("Gameplay/Doors").get_children():
		if String(n.get_meta(&"kind", "")) == "industrial_door":
			industrial += 1
			assert_true(float(n.get(&"width_m")) >= 2.4, "%s is >= 2.4 m wide" % n.name)
	assert_eq(industrial, 13, "6 cold-store sliding doors + 7 roller doors")
	var vault: Door = _map.get_node_or_null("Gameplay/Doors/StrongroomDoor") as Door
	assert_true(vault != null and vault.lock == Door.Lock.VAULT, "strongroom vault door")
	var drill: DrillPoint = _map.get_node_or_null("Gameplay/Doors/StrongroomDoor/StrongroomDrill") as DrillPoint
	assert_true(drill != null and drill.device == DrillPoint.Device.THERMAL, "thermal drill on the vault door")
	if drill != null:
		assert_near(drill.duration_s, 240.0, 0.001, "doc: 240 s")
	for sid: String in ["prod_chamber_a", "prod_chamber_b", "prod_packing"]:
		var bp: BurnPoint = _map.get_node_or_null("Variants/Group_product_location/Slot_%s/BurnPoint" % sid) as BurnPoint
		assert_true(bp != null and bp.objective_tag == &"burn", "%s burn point (ENV A burn_point, QC-38)" % sid)
		if bp != null:
			assert_near(bp.duration_s, 30.0, 0.001, "burn 30 s")
			assert_eq(bp.requires_loot, &"loot.thermite", "the burn takes the thermite bag")
			assert_true(bp.fire_volume_size.x >= 10.0, "%s fire volume spans the room" % sid)
	var lift: BagLift = _map.get_node_or_null("Gameplay/Misc/GoodsLift") as BagLift
	assert_true(lift != null and lift.targets.size() == 1 and lift.capacity == 2, "goods lift: 2 landings, 2 bags")


## Doc constraints the rules must guarantee, over many seeds.
func test_rule_constraints_hold() -> void:
	if _map == null or _map.variant_table == null:
		fail("map missing")
		return
	var slots: Dictionary = VariantResolver.collect_slots(_map)
	var posts: Array[int] = [3, 3, 4, 4, 5, 6]
	for d: int in range(6):
		for s: int in range(40):
			GameRng.begin_run(8000 + 100 * d + s)
			var v: Dictionary = VariantResolver.resolve(_map.variant_table, slots, d)
			var rare: Array = v.get(&"rare", [])
			assert_eq((v.get(&"guard_post", []) as Array).size(), posts[d], "cartel posts at difficulty %d" % d)
			assert_eq((v.get(&"weapons_containers", []) as Array).size(), 2, "two weapons containers")
			for g: StringName in [&"cash_location", &"product_location", &"warehouse_entry", &"east_gangway",
					&"goods_lift", &"player_perch", &"escape", &"night_shift"]:
				assert_eq((v.get(g, []) as Array).size(), 1, "one %s" % g)
			if (v.get(&"cash_location", []) as Array).has(&"cash_strongroom"):
				assert_eq(v.get(&"goods_lift", []), [&"lift_powered"], "strongroom cash -> the lift is powered")
			assert_eq((v.get(&"perch_viaduct", []) as Array).has(&"viaduct_on"), rare.has(&"fog_lifts"), "S3 only with fog_lifts")
			assert_eq((v.get(&"perch_trawler", []) as Array).has(&"trawler_on"), rare.has(&"harbor_unit"),
				"S4 only with harbor_unit")
			if d < Enums.Difficulty.HAZARDOUS:
				assert_false(rare.has(&"cartel_reinforcements"), "reinforcements Hazardous+")
			if d < Enums.Difficulty.BRUTAL:
				assert_false(rare.has(&"harbor_unit"), "harbor_unit Brutal+")
			if d == Enums.Difficulty.CATACLYSM:
				assert_near(float(v.get(&"police_delay_s", 0.0)), 60.0, 0.001, "Cataclysm: police at 60 s")


## ENV B's board merges the nested D-046 `assets` data without errors and offers the drops on this map.
func test_preplan_board_merges() -> void:
	var b: PreplanBoard = PreplanBoard.build(&"dockside_burn", Enums.Difficulty.ROUTINE)
	assert_eq(b.errors, [] as Array[String], "no pre-planning data errors")
	assert_eq(b.favors_budget, 5, "favors 5")
	for pa: Array in [[&"pp_drop_gatehouse", &"asset.ammo_bag_drop"], [&"pp_drop_platform", &"asset.doctor_bag_drop"],
			[&"pp_spawn_lane", &"asset.alternate_entry"], [&"pp_escape_boat", &"asset.escape_position"]]:
		assert_has(b.assets_for_point(pa[0]), pa[1], "%s offers %s" % [pa[0], pa[1]])
	for pid: String in PREPLAN:
		var m: Node = _map.get_node_or_null("Preplan/" + pid) if _map != null else null
		assert_true(m is Marker3D, "preplan point %s" % pid)
		if m != null:
			assert_eq(String(m.get_meta(&"category", "")), PREPLAN[pid], "preplan %s category" % pid)


static func _world(n: Node3D) -> Vector3:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin


## Lead G2 review: the loading hall keeps an open floor >= 12 m (no props) between crate-cover banks.
func test_hall_open_floor_and_crate_cover() -> void:
	if _map == null:
		fail("map missing")
		return
	var r: Array = [28.6, 0.4, 42.4, 9.6]
	assert_true(float(r[2]) - float(r[0]) >= 12.0, "open floor >= 12 m")
	var crates: int = 0
	for n: Node in _map.get_node("Props").find_children("*", "StaticBody3D", true, false):
		var b: Node3D = n as Node3D
		var p: Vector3 = b.position
		if String(b.get_meta(&"kind", "")) == "crate":
			crates += 1
		if p.y < 1.0 and p.x > float(r[0]) and p.x < float(r[2]) and p.z > float(r[1]) and p.z < float(r[3]):
			fail("prop %s stands in the hall's open floor" % b.name)
	assert_true(crates >= 6, "crate cover in the hall (%d)" % crates)
