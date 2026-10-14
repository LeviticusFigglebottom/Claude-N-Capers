## Glasshouse fire-escape door-window (PO-5, freeze gate 3 / gh_stealth): the U1 break-room window
## is walked through once it is open (ow_breakroom_open) or its glass is broken (ow_breakroom_latched).
## Per variant: the committed map's Geometry + Navigation + that slot's BreakRoomWindow go live; shut,
## a crew capsule is blocked and there is no layer-1 path landing -> break room; open / broken, the
## capsule (r 0.35, h 1.8) and a thrown bag pass the opening and a layer-1 nav path exists, through
## the opening (the landing's only other way out is the climbers-only ladder link, layer 8).
## Owner: ENV C.
extends TestCase

const SCENE: String = "res://world/heists/glasshouse/glasshouse.tscn"
const SLOT_ROOT: String = "Variants/Group_open_window/"
const OPENING_X: Vector2 = Vector2(1.65, 2.85)
const FLOOR_Y: float = 4.2
const LANDING_PT: Vector3 = Vector3(2.25, 4.2, -0.9)
const ROOM_PT: Vector3 = Vector3(2.25, 4.2, 1.6)

var _holder: Node3D = null


func after_each() -> void:
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
	_holder = null
	await wait_physics_frames(2)


func test_open_variant_walkable_once_opened() -> void:
	var w: WindowPrefab = await _setup(&"ow_breakroom_open")
	if w == null:
		return
	assert_true(w.openable and w.walkable, "open slot: openable + walkable")
	_assert_shut(w, "open slot, sash closed")
	w.set_open(true)
	await wait_physics_frames(3)
	_assert_passable(w, "open slot, sash up")
	w.set_open(false)
	await wait_physics_frames(3)
	_assert_shut(w, "open slot, sash closed again")


func test_latched_variant_walkable_once_broken() -> void:
	var w: WindowPrefab = await _setup(&"ow_breakroom_latched")
	if w == null:
		return
	assert_true(not w.openable and w.breakable and w.walkable, "latched slot: breakable + walkable, not openable")
	_assert_shut(w, "latched slot, intact")
	w.break_glass(0)
	await wait_physics_frames(3)
	_assert_passable(w, "latched slot, glass broken")


## Geometry + Navigation + the slot's window, at their map transforms, in the test's world.
func _setup(slot: StringName) -> WindowPrefab:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps == null:
		fail("glasshouse.tscn missing")
		return null
	var map: Node3D = ps.instantiate() as Node3D
	var win: Node3D = map.get_node_or_null(SLOT_ROOT + "Slot_" + String(slot) + "/BreakRoomWindow") as Node3D
	if win == null:
		map.free()
		fail("%s/BreakRoomWindow missing" % slot)
		return null
	var wx: Transform3D = _map_xform(map, win)
	_holder = Node3D.new()
	_holder.name = "FireEscapeWindowTest"
	for n: String in ["Geometry", "Navigation"]:
		var c: Node = map.get_node(n)
		_disown(c, map)
		map.remove_child(c)
		_holder.add_child(c)
	_disown(win, map)
	win.get_parent().remove_child(win)
	win.transform = wx
	_holder.add_child(win)
	map.free()
	add_child(_holder)
	await wait_physics_frames(2)
	var rid: RID = _holder.get_world_3d().navigation_map
	var synced: bool = await wait_until(func() -> bool:
		return NavigationServer3D.map_get_iteration_id(rid) > 0 \
			and NavigationServer3D.map_get_closest_point(rid, ROOM_PT).distance_to(ROOM_PT) < 0.3, 10.0)
	assert_true(synced, "navmesh live in the test world")
	return win as WindowPrefab


static func _disown(n: Node, map: Node) -> void:
	if n.owner == map:
		n.owner = null
	for c: Node in n.get_children():
		_disown(c, map)


static func _map_xform(map: Node, n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != map:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Fraction of the move landing -> room a shape gets before it hits world_static (1.0 = clear).
func _cast(shape: Shape3D, centre_y: float) -> float:
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	q.transform = Transform3D(Basis.IDENTITY, Vector3(2.25, centre_y, -0.85))
	q.motion = Vector3(0.0, 0.0, 1.75)
	var space: PhysicsDirectSpaceState3D = _holder.get_world_3d().direct_space_state
	var r: PackedFloat32Array = space.cast_motion(q)
	return r[0] if r.size() > 0 else 0.0


func _crew_capsule() -> CapsuleShape3D:
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	return cap


func _bag() -> SphereShape3D:
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = 0.25
	return s


func _path() -> PackedVector3Array:
	var rid: RID = _holder.get_world_3d().navigation_map
	var a: Vector3 = NavigationServer3D.map_get_closest_point(rid, LANDING_PT)
	var b: Vector3 = NavigationServer3D.map_get_closest_point(rid, ROOM_PT)
	return NavigationServer3D.map_get_path(rid, a, b, true, 1)


func _reaches_room(path: PackedVector3Array) -> bool:
	return path.size() >= 2 and path[path.size() - 1].distance_to(ROOM_PT) < 0.5


func _assert_shut(w: WindowPrefab, ctx: String) -> void:
	assert_true(w.nav_link() != null and not w.nav_link().enabled, "%s: window NavLink off" % ctx)
	assert_true(_cast(_crew_capsule(), FLOOR_Y + 0.92) < 0.99, "%s: crew capsule blocked by the glass" % ctx)
	assert_true(_cast(_bag(), FLOOR_Y + 1.2) < 0.99, "%s: thrown bag blocked by the glass" % ctx)
	var path: PackedVector3Array = _path()
	assert_false(_reaches_room(path), "%s: no layer-1 path landing -> break room (%s)" % [ctx, path])


func _assert_passable(w: WindowPrefab, ctx: String) -> void:
	assert_true(w.nav_link() != null and w.nav_link().enabled, "%s: window NavLink on" % ctx)
	assert_near(_cast(_crew_capsule(), FLOOR_Y + 0.92), 1.0, 0.001, "%s: crew capsule (r 0.35, h 1.8) passes" % ctx)
	var crouch: CapsuleShape3D = _crew_capsule()
	crouch.height = 1.2
	assert_near(_cast(crouch, FLOOR_Y + 0.62), 1.0, 0.001, "%s: crouched capsule passes" % ctx)
	assert_near(_cast(_bag(), FLOOR_Y + 1.2), 1.0, 0.001, "%s: thrown bag passes" % ctx)
	var path: PackedVector3Array = _path()
	assert_true(_reaches_room(path), "%s: layer-1 path landing -> break room (%s)" % [ctx, path])
	var through: bool = false
	for i: int in range(1, path.size()):
		var p0: Vector3 = path[i - 1]
		var p1: Vector3 = path[i]
		if (p0.z <= 0.0) == (p1.z <= 0.0):
			continue
		var x: float = lerpf(p0.x, p1.x, -p0.z / (p1.z - p0.z))
		through = through or (x > OPENING_X.x and x < OPENING_X.y and absf(p0.y - FLOOR_Y) < 0.4 and absf(p1.y - FLOOR_Y) < 0.4)
	assert_true(through, "%s: the path crosses the wall line inside the opening at floor height (%s)" % [ctx, path])
	var length: float = 0.0
	for j: int in range(1, path.size()):
		length += path[j - 1].distance_to(path[j])
	assert_true(length < 4.0, "%s: direct route (%.1f m)" % [ctx, length])
