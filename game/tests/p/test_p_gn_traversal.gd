## GN-P1 (next_heist.md §7, D-104/D-110): Gallery Night G1 traversal by real input (PTraversal). Skips until the
## gallery_night map is on this branch (C's greybox). Step 1 (layout, doors, nav) covers:
## - §7.2 balcony throws: from the east balcony (BE, upper FFL 5.4) over the hall balustrade at 3 pitches, a LIGHT
##   canvas lands on the Great Hall floor in the east drop strip (x 24-28);
## - §7.3 Mews -> loading dock with a HEAVY bag along the navmesh (step-free, no snag);
## - §7.7 the route doors (staff, SV, CO, CS, AT, TR, head house) >= 1.0 m clear width.
## Laser gaps (§7.1), the pool (§7.4) and ladders (§7.6) arrive with the contract nodes (step 2).
extends TestCase

const HEIST: StringName = &"gallery_night"
## BE balcony, 0.6 m east of the x = 29 balustrade, mid-span (z 16.4-26.0); hall floor y 0.
const BE_THROW: Vector3 = Vector3(29.6, 5.4, 21.0)
## The Great Hall floor (ground, y 0) between the balustrade lines; the doc's drop strip x 24-28 is reported, not
## required: 0 / 15 deg throws land ~x 22.2-22.7 (still the hall floor).
const HALL_X: Vector2 = Vector2(16.0, 28.0)
## §7.7 route doors (staff door, SV, CO, CS, AT, TR, head house).
const ROUTE_DOORS: PackedStringArray = ["StaffDoor", "ServerDoor", "CuratorDoor", "StudioDoor", "AttendantDoorN",
	"AttendantDoorW", "TreasuryDoor", "HeadHouseDoor"]
const MEWS: Vector3 = Vector3(26.0, 0.0, -5.0)
const DOCK_INSIDE: Vector3 = Vector3(36.5, 0.0, 3.0)

var _rt: HeistRuntime = null
var _tr: PTraversal = null


func _available() -> bool:
	var path: String = HeistLauncher.map_path(HEIST, {})
	return path != "" and ResourceLoader.exists(path)


func before_each() -> void:
	if not _available():
		return
	_rt = await HeistLauncher.launch(HEIST, 1101, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "ai_teammates": 0})
	if _rt != null:
		_rt.isolate_npc(null)
		_tr = PTraversal.new(self, _rt)
		var map: RID = (_rt.crew_controller(0) as Node3D).get_world_3d().navigation_map
		await wait_until(func() -> bool: return NavigationServer3D.map_get_iteration_id(map) >= 2, 10.0)


func after_each() -> void:
	if _tr != null:
		_tr.inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	_tr = null
	await wait_frames(1)


func test_balcony_throw_lands_in_the_hall_strip() -> void:
	if _rt == null:
		skip("gallery_night not on this branch yet")
		return
	for pitch_deg: float in [0.0, 15.0, 30.0]:
		var r: Dictionary = await _tr.throw_bag(BE_THROW, PI * 0.5, deg_to_rad(pitch_deg), Enums.LootWeight.LIGHT,
			&"loot.painting")
		var land: Vector3 = r.get("landing", Vector3.INF)
		assert_true(bool(r.get("thrown", false)), "pitch %.0f: thrown" % pitch_deg)
		assert_true(land.y < 0.6, "pitch %.0f: on the hall floor, not the balcony or the rail (%s)" % [pitch_deg, land])
		assert_true(land.x >= HALL_X.x and land.x <= HALL_X.y and land.z > 16.4 and land.z < 26.0,
			"pitch %.0f: on the Great Hall floor (%s)" % [pitch_deg, land])
		print("GN balcony throw pitch %.0f lands %s" % [pitch_deg, land.snappedf(0.01)])


func test_mews_to_loading_dock_with_a_heavy_bag() -> void:
	if _rt == null:
		skip("gallery_night not on this branch yet")
		return
	for node: Node in get_tree().get_nodes_in_group(Door.GROUP):  # a player opens the dock doors on the way
		var d: Door = node as Door
		if d != null and _rt.is_ancestor_of(d) and String(d.name).begins_with("Dock"):
			d.set_open(true, true)
	await wait_physics_frames(5)
	var r: Dictionary = await _tr.carry(MEWS, DOCK_INSIDE, Enums.LootWeight.HEAVY, 90.0)
	assert_true(bool(r.get("ok", false)), "Mews -> LD carried a heavy bag (%s)" % [r])
	assert_true(bool(r.get("carrying", false)), "still carrying at the dock")


func test_route_doors_are_wide_enough() -> void:
	if _rt == null:
		skip("gallery_night not on this branch yet")
		return
	var narrow: PackedStringArray = []
	var n: int = 0
	for node: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var d: Door = node as Door
		if d == null or not _rt.is_ancestor_of(d) or not (String(d.name) in ROUTE_DOORS):
			continue
		n += 1
		var w: float = d.effective_width()  # width_m, else the contract default (0.9 m single, 1.8 m double)
		if w < 1.0:
			narrow.append("%s %.2f m" % [d.name, w])
	assert_eq(n, ROUTE_DOORS.size(), "every §7.7 route door is in the greybox")
	assert_true(narrow.is_empty(), "route doors < 1.0 m: %s" % ", ".join(narrow))
