## P-FP-STATES (CrewFpStates; PD2 L2.5 / L4.3 / L4.4): first-person presentation of DOWNED / TASED /
## CLOAKER_DOWNED and of taking a hit, on the local human only. DOWNED lowers the eye itself (the shot origin
## follows the camera); the rest is camera / viewmodel only. Reduce Motion drops the rolls and hit punches.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	GameSettings.set_current(GameSettings.new())
	_rt = await HeistLauncher.launch(&"unit_map", 4401, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(10)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	GameSettings.set_current(null)
	await wait_frames(1)


func _crew() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _head(c: CrewController) -> Node3D:
	return c.get_node(^"Head") as Node3D


func _hit(c: CrewController, health: float, armor: float, travel: Vector3) -> void:
	EventBus.damage_applied.emit(c.net_id, 0, {"amount": health + armor, "health_damage": health,
		"armor_damage": armor, "direction": travel})


func test_downed_lowers_eye_and_shot_origin_then_revive_raises() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	await wait_seconds(0.3)
	var stand: float = _head(c).position.y
	assert_near(stand, tw.eye_standing, 0.03, "standing camera")
	c.health.go_down()
	assert_near(c.eye_height(), tw.eye_downed, 1e-4, "the eye (shot origin) is down at once")
	await wait_physics_frames(2)
	assert_true(_head(c).position.y > tw.eye_downed + 0.3, "the camera eases down, not a snap")
	await wait_seconds(0.8)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "still downed")
	assert_near(_head(c).position.y, tw.eye_downed, 0.03, "camera settled at the downed eye")
	assert_near(c.eye_position().y - c.global_position.y, tw.eye_downed, 1e-4, "shots leave from the camera")
	assert_near(rad_to_deg(_head(c).rotation.z), tw.fp_down_roll_deg, 0.5, "small downed roll")
	assert_near(c.fp_states.w_down, 1.0, 1e-4)
	assert_true(c.fp_states.vm_offset.is_equal_approx(tw.fp_down_vm_offset), "viewmodel held lower")
	c.health.revive(1)
	await wait_seconds(1.0)
	assert_near(_head(c).position.y, tw.eye_standing, 0.03, "revived: back up")
	assert_near(_head(c).rotation.z, 0.0, 1e-3, "no roll after revive")


func test_tased_convulses_and_buckles() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	await wait_seconds(0.2)
	c.health.incapacitate(Enums.CrewState.TASED)
	assert_near(c.eye_height(), tw.eye_standing, 1e-4, "a tase does not move the shot origin")
	await wait_seconds(0.4)
	var rots: Array[Vector3] = []
	for _i: int in 12:
		await wait_physics_frames(1)
		rots.append(c.fp_states.cam_rot)
	var spread: float = 0.0
	for r: Vector3 in rots:
		spread = maxf(spread, r.distance_to(rots[0]))
		assert_true(absf(rad_to_deg(r.x)) < tw.fp_tase_shake_deg * 1.2, "jitter bounded")
	assert_true(rad_to_deg(spread) > 0.4, "the camera convulses frame to frame")
	assert_near(c.fp_states.cam_dy, -tw.fp_tase_buckle_m, 0.01, "knees buckle")
	assert_true(c.fp_states.vm_rot_deg.length() > 0.0, "the viewmodel shakes too")
	c.health.revive(1)
	await wait_seconds(0.4)
	assert_near(c.fp_states.cam_rot.length(), 0.0, 1e-4, "still again after the tase")
	assert_near(c.fp_states.cam_dy, 0.0, 1e-4)


func test_kick_drops_camera_to_the_floor_on_its_side() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	await wait_seconds(0.2)
	c.health.incapacitate(Enums.CrewState.CLOAKER_DOWNED)
	await wait_seconds(1.2)
	assert_near(_head(c).position.y, tw.fp_kick_eye_m, 0.03, "camera on the floor")
	assert_near(rad_to_deg(_head(c).rotation.z), tw.fp_kick_roll_deg, 1.0, "rolled onto its side")
	assert_near(c.fp_states.vm_offset.y, -tw.fp_kick_vm_drop_m, 1e-3, "the viewmodel drops out of view")
	c.health.revive(1)
	await wait_seconds(1.2)
	assert_near(_head(c).position.y, tw.eye_standing, 0.03, "back up once revived")


func test_hit_punch_health_over_armor_and_side() -> void:
	var c: CrewController = _crew()
	await wait_seconds(0.3)
	var right: Vector3 = c.global_transform.basis.x
	_hit(c, 0.0, 10.0, right)
	var armor_peak: Vector3 = await _peak(c)
	_hit(c, 10.0, 0.0, right)
	var health_peak: Vector3 = await _peak(c)
	assert_true(absf(armor_peak.x) > 0.0, "an armor hit punches")
	assert_true(absf(health_peak.x) > absf(armor_peak.x) * 1.5, "a health hit punches harder")
	assert_true(health_peak.z < 0.0, "a round travelling right rolls the camera right")
	_hit(c, 10.0, 0.0, -right)
	var left: Vector3 = await _peak(c)
	assert_true(left.z > 0.0, "and from the other side, the other way")
	await wait_seconds(0.6)
	assert_near(c.fp_states.cam_rot.length(), 0.0, 1e-4, "settled")
	# not our crew: nothing
	EventBus.damage_applied.emit(c.net_id + 999, 0, {"amount": 10.0, "health_damage": 10.0})
	await wait_physics_frames(4)
	assert_near(c.fp_states.cam_rot.length(), 0.0, 1e-4, "other victims are not ours")


func test_reduce_motion_keeps_heights_drops_rolls_and_punches() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	GameSettings.current().set_value(GameSettings.ACCESSIBILITY, &"reduce_motion", true)
	await wait_seconds(0.3)
	_hit(c, 10.0, 0.0, c.global_transform.basis.x)
	var p: Vector3 = await _peak(c)
	assert_near(p.length(), 0.0, 1e-5, "no hit punch")
	c.health.incapacitate(Enums.CrewState.CLOAKER_DOWNED)
	await wait_seconds(1.2)
	assert_near(_head(c).position.y, tw.fp_kick_eye_m, 0.03, "still on the floor (information)")
	assert_true(absf(rad_to_deg(_head(c).rotation.z)) < 1.0, "but not rolled")
	c.health.revive(1)
	await wait_seconds(0.3)
	c.health.incapacitate(Enums.CrewState.TASED)
	await wait_seconds(0.5)
	var m: float = 0.0
	for _i: int in 12:
		await wait_physics_frames(1)
		m = maxf(m, absf(rad_to_deg(c.fp_states.cam_rot.x)))
	assert_true(m < tw.fp_tase_shake_deg * tw.fp_reduce_motion_mult * 1.2, "tase jitter scaled down")


func test_remote_and_ai_crew_get_none() -> void:
	_rt.teardown()
	_rt = await HeistLauncher.launch(&"unit_map", 4402, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": true, "ai_teammates": 1})
	await wait_physics_frames(10)
	var ai: CrewController = null
	for m: CrewController in _rt.crew_members():
		if m.is_ai:
			ai = m
	assert_true(ai != null, "an AI teammate")
	if ai == null:
		return
	ai.health.go_down()
	await wait_physics_frames(10)
	assert_true(ai.fp_states == null, "no first-person state presentation on an AI crew")


## Largest hit-punch rotation over the next 0.3 s.
func _peak(c: CrewController) -> Vector3:
	var best: Vector3 = Vector3.ZERO
	for _i: int in 18:
		await wait_physics_frames(1)
		if c.fp_states != null and c.fp_states.cam_rot.length() > best.length():
			best = c.fp_states.cam_rot
	await wait_seconds(0.5)
	return best


## PD2: the downed player still holds the secondary on screen; in custody (spectating) no viewmodel is drawn.
func test_custody_hides_the_viewmodel_downed_keeps_it() -> void:
	var c: CrewController = _crew()
	await wait_seconds(1.0)
	var view: CrewView = CrewView.of(c)
	assert_true(view.viewmodel_visible(), "masked: the weapon is on screen")
	c.health.go_down()
	await wait_seconds(0.5)
	assert_true(view.viewmodel_visible(), "downed: the secondary stays on screen")
	c.health.go_to_custody()
	await wait_frames(3)
	assert_eq(c.crew_state, Enums.CrewState.CUSTODY)
	assert_false(view.viewmodel_visible(), "custody: no first-person weapon")
	c.health.release_from_custody()
	await wait_seconds(0.5)
	assert_true(view.viewmodel_visible(), "released: the weapon is back")
