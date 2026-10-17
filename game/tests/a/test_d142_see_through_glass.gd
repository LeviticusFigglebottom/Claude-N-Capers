## D-142 (PD2: guards see through glass): stealth vision rays pass colliders in StealthDirector.GROUP_SEE_THROUGH (the
## Window prefab's GlassBody, C's clear glazing); a plain wall still blocks; glass in front of a wall does not let sight
## through the wall. Combat LOS (bullets) is unchanged.
extends TestCase

const EYE: Vector3 = Vector3(0.0, 1.6, 0.0)
const TARGET: Vector3 = Vector3(0.0, 1.6, -8.0)

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch() -> StealthDirector:
	_rt = await HeistLauncher.launch(&"unit_map", 1420, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	return _rt.stealth


func _pane(z: float, see_through: bool) -> StaticBody3D:
	var b: StaticBody3D = ATestMaps.add_wall(_rt.map, Vector3(0.0, 1.5, z), Vector3(4.0, 3.0, 0.05))
	if see_through:
		b.add_to_group(StealthDirector.GROUP_SEE_THROUGH)
	return b


func test_d142_vision_through_glass_not_walls() -> void:
	var st: StealthDirector = await _launch()
	assert_true(st.has_los(EYE, TARGET), "setup: open line")
	var glass: StaticBody3D = _pane(-3.0, true)
	await wait_physics_frames(2)
	assert_true(st.has_los(EYE, TARGET), "visible through a see_through pane")
	var glass2: StaticBody3D = _pane(-5.0, true)
	await wait_physics_frames(2)
	assert_true(st.has_los(EYE, TARGET), "visible through two panes")
	var wall: StaticBody3D = _pane(-6.5, false)
	await wait_physics_frames(2)
	assert_false(st.has_los(EYE, TARGET), "glass in front of a plain wall: blocked by the wall")
	wall.queue_free()
	glass2.queue_free()
	glass.remove_from_group(StealthDirector.GROUP_SEE_THROUGH)
	await wait_physics_frames(2)
	assert_false(st.has_los(EYE, TARGET), "a plain wall blocks")
	var space: PhysicsDirectSpaceState3D = _rt.map.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(EYE, TARGET, 1)  # world_static
	glass.add_to_group(StealthDirector.GROUP_SEE_THROUGH)
	assert_false(space.intersect_ray(q).is_empty(), "a plain (bullet) ray still hits the glass")


func test_d142_window_prefab_glass_is_see_through() -> void:
	await _launch()
	var w: Node3D = (load("res://systems/prefabs/window/window.tscn") as PackedScene).instantiate() as Node3D
	_rt.map.add_child(w)
	w.global_position = Vector3(0.0, 0.0, -3.0)
	await wait_physics_frames(3)
	var body: Node = w.get_node_or_null(^"GlassBody")
	assert_true(body != null and body.is_in_group(StealthDirector.GROUP_SEE_THROUGH), "Window GlassBody is see_through")


## Stealth LOS along -Z at height `y` (x 0), from z 0 to z -8.
func _los_at(st: StealthDirector, y: float) -> bool:
	return st.has_los(Vector3(0.0, y, 0.0), Vector3(0.0, y, -8.0))


## A ray on `mask` (world_static = bullets / movement) along -Z at height `y` hits something.
func _solid_at(y: float, mask: int = GameplayPrefab.LAYER_WORLD_STATIC) -> bool:
	var space: PhysicsDirectSpaceState3D = _rt.map.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0.0, y, 0.0), Vector3(0.0, y, -8.0), mask)
	return not space.intersect_ray(q).is_empty()


func test_d142_display_case_glass_see_through_cabinet_blocks() -> void:
	var st: StealthDirector = await _launch()
	var dc: DisplayCase = ATestMaps.add_prefab(_rt, "display_case", Vector3(0.0, 0.0, -3.0)) as DisplayCase
	await wait_physics_frames(3)
	# Placeholder: cabinet 0-0.9 m, glass 0.9-1.3 m.
	var cabinet: CollisionObject3D = dc.get_node(^"Collision") as CollisionObject3D
	assert_true(dc.glass_body != null and dc.glass_body.is_in_group(StealthDirector.GROUP_SEE_THROUGH),
		"the case's GlassBody is see_through")
	if dc.glass_body == null:
		return
	assert_false(cabinet.is_in_group(StealthDirector.GROUP_SEE_THROUGH), "the cabinet body is not")
	assert_eq(dc.glass_body.collision_layer, cabinet.collision_layer, "glass keeps the case's movement / bullet layer")
	assert_eq(Damage.find_target(dc.glass_body), dc, "hits on the glass reach the case")
	assert_true(_los_at(st, 1.1), "visible through the case glass")
	assert_false(_los_at(st, 0.5), "the cabinet base blocks")
	assert_true(_solid_at(1.1), "bullets / movement still stop at the glass")
	assert_true(_solid_at(0.5), "and at the cabinet")
	dc.break_glass(0)
	await wait_physics_frames(2)
	assert_true(dc.glass_broken, "broken")
	assert_true(_los_at(st, 1.1), "broken: still visible over the cabinet")
	assert_false(_los_at(st, 0.5), "broken: the cabinet still blocks")
	assert_true(_solid_at(1.1), "broken: the case still blocks movement as before")


func test_d142_window_opt_out_blocks() -> void:
	var st: StealthDirector = await _launch()
	var w: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(0.0, 1.0, -3.0), func(n: Node) -> void:
		(n as WindowPrefab).see_through = false) as WindowPrefab
	await wait_physics_frames(3)
	var body: Node = w.get_node(^"GlassBody")
	assert_false(body.is_in_group(StealthDirector.GROUP_SEE_THROUGH), "see_through=false: GlassBody not in the group")
	assert_false(st.has_los(EYE, TARGET), "a window with see_through=false blocks vision")
	body.add_to_group(StealthDirector.GROUP_SEE_THROUGH)
	await wait_physics_frames(1)
	assert_true(st.has_los(EYE, TARGET), "control: the same pane in the group is see-through")


func _door(glass: bool, opaque_glass: bool = false, double: bool = false) -> Door:
	return ATestMaps.add_prefab(_rt, "door", Vector3(0.0, 0.0, -3.0), func(n: Node) -> void:
		var d: Door = n as Door
		d.leaf_surface = &"glass" if glass else &""
		d.see_through = not opaque_glass
		if double:
			d.swing = Door.Swing.DOUBLE) as Door


func _drop(d: Door) -> void:
	d.get_parent().remove_child(d)
	d.free()
	await wait_physics_frames(2)


func test_d142_glass_leaf_door_see_through_solid_blocks() -> void:
	var st: StealthDirector = await _launch()
	var d: Door = _door(true)
	await wait_physics_frames(3)
	assert_true(d.leaf_see_through(), "a glass leaf is see-through")
	assert_true(st.has_los(EYE, TARGET), "visible through a closed glass-leaf door")
	assert_true(_solid_at(EYE.y, GameplayPrefab.LAYER_WORLD_DYNAMIC), "the glass leaf still blocks bullets / movement")
	await _drop(d)
	var dd: Door = _door(true, false, true)
	await wait_physics_frames(3)
	for x: float in [-0.4, 0.4]:
		var off: Vector3 = Vector3(x, 0.0, 0.0)
		assert_true(st.has_los(EYE + off, TARGET + off), "visible through the double door's leaf at x %.1f" % x)
	var leaves: int = 0
	for c: Node in dd.get_children():
		if c is AnimatableBody3D:
			leaves += 1
			assert_true(c.is_in_group(StealthDirector.GROUP_SEE_THROUGH), "%s is see_through" % c.name)
	assert_eq(leaves, 2, "two leaf bodies")
	await _drop(dd)
	var solid: Door = _door(false)
	await wait_physics_frames(3)
	assert_false(solid.leaf_see_through(), "a wood leaf is not see-through")
	assert_false(st.has_los(EYE, TARGET), "a closed solid door blocks")
	await _drop(solid)
	var frosted: Door = _door(true, true)
	await wait_physics_frames(3)
	assert_false(frosted.leaf_see_through(), "a glass leaf with see_through=false is not")
	assert_false(st.has_los(EYE, TARGET), "a frosted glass door blocks")
