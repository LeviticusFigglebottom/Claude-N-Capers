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
