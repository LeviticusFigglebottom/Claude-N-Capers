## D-099: WeaponStats.recoil_horizontal_bias_deg is the signed per-shot mean of the horizontal kick
## (+ = right). A right bias turns the view right (look yaw decreases) on average.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_d099_horizontal_bias_drifts_right() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var w: CrewWeapons = c.weapons
	var s: Variant = w.get(&"_states").get(w.equipped_slot)
	var stats: WeaponStats = (s.get(&"stats") as WeaponStats).duplicate() as WeaponStats
	stats.recoil_kick_deg = 0.0
	stats.recoil_horizontal_deg = 0.5
	stats.recoil_horizontal_bias_deg = 0.4
	s.set(&"stats", stats)
	var pin: PlayerInput = c.get_node(^"PlayerInput") as PlayerInput
	var acc0: Vector2 = pin.get(&"_recoil_acc")
	for _i: int in 20:
		w.call(&"_apply_recoil", s)
	var dx: float = (pin.get(&"_recoil_acc") as Vector2).x - acc0.x
	assert_true(dx < 0.0, "net yaw kick to the right (yaw delta %.4f rad)" % dx)
	assert_near(dx, -deg_to_rad(0.4) * 20.0, deg_to_rad(0.5) * 20.0 * 0.5, "mean is the bias per shot")
