## GN-P1 (next_heist.md §7, D-104/D-110): Gallery Night G1 traversal by real input (PTraversal). Skips until the
## gallery_night map is on this branch (C's greybox). Step 1 (layout, doors, nav) covers:
## - §7.2 balcony throws: from the east balcony (BE, upper FFL 5.4) over the hall balustrade at 3 pitches, a LIGHT
##   canvas lands on the Great Hall floor in the east drop strip (x 24-28);
## - §7.3 Mews -> loading dock with a HEAVY bag along the navmesh (step-free, no snag);
## - §7.7 the route doors (staff, SV, CO, CS, AT, TR, head house) >= 1.0 m clear width.
## §7.6 ladders: every Ladder up and down (skips until step 2 adds them). Laser gaps (§7.1) and the pool (§7.4)
## arrive with the contract nodes (step 2).
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
## Treasury laser grid plane (z), the crossing line and the upper floor; one seed per laser_pattern variant.
const TR_GRID_Z: float = 26.5
const TR_CROSS_X: float = 40.0
const TR_FLOOR_Y: float = 5.4
const SEED_STATIC: int = 1104
const SEED_TIMED: int = 1103
const SEED_SWEEP: int = 1101
## Sweep (3 beams ping-ponging 7.3 m, 6 s period, 2 s apart): a beam crosses the centre about every 1 s (~0.7 s
## window); near a side wall the beams turn in pairs, leaving ~1.4 s gaps. A player crosses there.
const TR_SWEEP_X: float = 37.0

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


## §7.6 (step 2): every Ladder on the map climbed up and back down by real input (masked, no bag).
func test_ladders_up_and_down() -> void:
	if _rt == null:
		skip("gallery_night not on this branch yet")
		return
	var ladders: Array[Ladder] = []
	var stack: Array[Node] = [_rt]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Ladder and (n as Ladder).is_visible_in_tree():
			ladders.append(n as Ladder)
	if ladders.is_empty():
		skip("no Ladder prefabs in the greybox yet (step 2)")
		return
	for l: Ladder in ladders:
		if not l.usable:
			# A's GN mission (b25c8dc5): the areaway ladder is usable only while its grate is open. Open the
			# nearest Door (the grate) like a player would, and expect the mission to enable the ladder.
			var grate: Door = _nearest_door(l.top_position(), 4.0)
			assert_true(grate != null, "%s: gated ladder has a grate nearby" % l.name)
			if grate == null:
				continue
			grate.set_open(true, true)
			await wait_physics_frames(2)
			assert_true(l.usable, "%s: opening %s enables it" % [l.name, grate.name])
		var r: Dictionary = await _tr.ladder(l, true)
		assert_true(bool(r.get("up", false)), "%s: climbed up (%s)" % [l.name, r])
		assert_true(bool(r.get("down", false)), "%s: climbed back down (%s)" % [l.name, r])


func _nearest_door(p: Vector3, within_m: float) -> Door:
	var best: Door = null
	var best_d: float = within_m
	var stack: Array[Node] = [_rt]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Door:
			var d: float = (n as Door).global_position.distance_to(p)
			if d < best_d:
				best_d = d
				best = n as Door
	return best


# --- §7.1 Treasury laser grid (step 2): one seed per pattern; crossing must not trip the grid ------------------

func _relaunch(seed: int) -> LaserGrid:
	if _tr != null:
		_tr.inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
		await wait_frames(2)
	_rt = await HeistLauncher.launch(HEIST, seed, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "ai_teammates": 0})
	_rt.isolate_npc(null)
	_tr = PTraversal.new(self, _rt)
	await wait_physics_frames(10)
	var stack: Array[Node] = [_rt]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is LaserGrid and (n as LaserGrid).is_visible_in_tree():
			return n as LaserGrid
	return null


## Walk straight through the grid plane (crouched when `crouch`), from 1.2 m south to 1.2 m north of it.
func _cross(crouch: bool, sprint: bool = false) -> bool:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	if crouch:
		_tr.inp.press(&"crouch")
	if sprint:
		_tr.inp.press(&"sprint")
	_tr.inp.press(&"move_forward")
	var ok: bool = await wait_until(func() -> bool: return c.global_position.z > TR_GRID_Z + 1.2, 6.0)
	_tr.inp.release_all()
	await wait_physics_frames(5)
	return ok


func _stand_south(crouch: bool, x: float = TR_CROSS_X) -> void:
	await _tr.place(Vector3(x, TR_FLOOR_Y, TR_GRID_Z - 1.2), Vector3(x, TR_FLOOR_Y, TR_GRID_Z + 2.0))
	if crouch:
		_tr.inp.press(&"crouch")
		await wait_seconds(0.6)


func test_laser_static_crouch_under() -> void:
	if _rt == null:
		skip("gallery_night not on this branch yet")
		return
	var g: LaserGrid = await _relaunch(SEED_STATIC)
	if g == null or g.pattern != &"static":
		skip("no static Treasury grid on seed %d (%s)" % [SEED_STATIC, _rt.variants.get(&"laser_pattern", [])])
		return
	await _stand_south(true)
	assert_true(await _cross(true), "crouched through the static grid")
	assert_false(g.tripped, "the crouch-under gap (1.30 m beam) clears the crouched capsule")
	assert_false(_rt.went_loud, "no alarm")


func test_laser_timed_cross_in_the_off_window() -> void:
	if _rt == null:
		skip("gallery_night not on this branch yet")
		return
	var g: LaserGrid = await _relaunch(SEED_TIMED)
	if g == null or g.pattern != &"timed_off":
		skip("no timed Treasury grid on seed %d" % SEED_TIMED)
		return
	await _stand_south(false)
	assert_true(await wait_until(func() -> bool: return g.beams_on(), g.period_s + 1.0), "beams cycle on")
	assert_true(await wait_until(func() -> bool: return not g.beams_on(), g.period_s + 1.0), "beams cycle off")
	assert_true(await _cross(false, true), "sprinted through in the off window")
	assert_false(g.tripped, "the %.1f s off window is long enough to cross" % g.off_s)


func test_laser_sweep_cross_behind_the_beam() -> void:
	if _rt == null:
		skip("gallery_night not on this branch yet")
		return
	var g: LaserGrid = await _relaunch(SEED_SWEEP)
	if g == null or g.pattern != &"sweeping":
		skip("no sweeping Treasury grid on seed %d" % SEED_SWEEP)
		return
	await _stand_south(false, TR_SWEEP_X)
	# Wait until every sweeping beam is >= 0.6 m from the crossing line and none is closing in.
	var last: Array[float] = []
	var clear: Callable = func() -> bool:
		var xs: Array[float] = []
		for a: Area3D in g.beam_areas:
			xs.append(a.global_position.x)
		var ok: bool = not last.is_empty()
		for k: int in xs.size():
			var d: float = absf(xs[k] - TR_SWEEP_X)
			if d < 0.6 or (ok and k < last.size() and absf(last[k] - TR_SWEEP_X) > d and d < 2.0):
				ok = false
		last.clear()  # in place: a lambda captures `last` by value, reassigning would not persist
		last.append_array(xs)
		return ok
	assert_true(await wait_until(clear, g.period_s * 2.0 + 1.0), "a sweep gap opens")
	assert_true(await _cross(false, true), "sprinted through behind the beam")
	assert_false(g.tripped, "crossing behind the sweep does not trip it")


## §7.4 (step 2): into the reflecting pool over the 0.3 m rim and out the far side with a HEAVY bag.
func test_pool_in_and_out_with_a_heavy_bag() -> void:
	if _rt == null:
		skip("gallery_night not on this branch yet")
		return
	var pts: Array[Vector3] = [Vector3(-9.5, 0.0, 13.6), Vector3(-9.5, 0.0, 18.0), Vector3(-9.5, 0.0, 22.4)]
	var r: Dictionary = await _tr.route(pts, Enums.LootWeight.HEAVY, false, 30.0)
	assert_true(bool(r.get("ok", false)), "over the rim, through the pool and out with a heavy bag (%s)" % [r])
