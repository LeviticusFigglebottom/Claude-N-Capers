## B's Options parity pass (options.md): ENV P's camera / look code reads
## - GameSettings.ads_sensitivity() (0.1..2): aimed / scoped look delta x it, hip fire unchanged;
## - GameSettings.screen_shake() (0..1): every camera shaker (tase jitter, hit / kick / melee punch) x it.
## The settings are stubbed here (FakeSettings) so the hooks are testable before and after B's build lands.
extends TestCase


class FakeSettings:
	extends GameSettings
	var ads: float = 1.0
	var shake: float = 1.0

	func ads_sensitivity() -> float:
		return ads

	func screen_shake() -> float:
		return shake


var _rt: HeistRuntime = null
var _inp: PInputDriver = null
var _gs: FakeSettings = null


func before_each() -> void:
	_gs = FakeSettings.new()
	GameSettings.set_current(_gs)
	_rt = await HeistLauncher.launch(&"unit_map", 4403, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	await wait_physics_frames(10)


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	GameSettings.set_current(null)
	await wait_frames(1)


## Yaw turned by a 200 px mouse move.
func _turn(c: CrewController) -> float:
	var y0: float = c.look_yaw
	_inp.look(200.0, 0.0)
	await wait_physics_frames(4)
	return absf(angle_difference(y0, c.look_yaw))


func test_ads_sensitivity_scales_aimed_look_only() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_seconds(1.0)
	_gs.ads = 0.5
	var hip: float = await _turn(c)
	assert_true(hip > 0.01, "the mouse turns the crew")
	_gs.ads = 1.0
	var hip1: float = await _turn(c)
	assert_near(hip, hip1, hip1 * 0.02, "hip fire ignores aiming sensitivity")
	_inp.press(&"aim")
	await wait_seconds(1.0)
	_gs.ads = 1.0
	var aimed1: float = await _turn(c)
	_gs.ads = 0.5
	var aimed05: float = await _turn(c)
	assert_true(aimed1 > 0.001, "aimed look turns")
	assert_near(aimed05 / aimed1, 0.5, 0.03, "aiming sensitivity 0.5 halves the aimed look delta")
	_inp.release(&"aim")


func test_screen_shake_zero_removes_punches_and_jitter() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	await wait_seconds(0.3)
	_gs.shake = 0.0
	EventBus.damage_applied.emit(c.net_id, 0, {"amount": 20.0, "health_damage": 20.0, "armor_damage": 0.0,
		"direction": c.global_transform.basis.x})
	var peak: float = 0.0
	for _i: int in 18:
		await wait_physics_frames(1)
		peak = maxf(peak, c.fp_states.cam_rot.length())
	assert_near(peak, 0.0, 1e-6, "screen shake 0: no hit punch")
	c.health.incapacitate(Enums.CrewState.TASED)
	await wait_seconds(0.4)
	var jit: float = 0.0
	for _i: int in 12:
		await wait_physics_frames(1)
		jit = maxf(jit, c.fp_states.cam_rot.length())
	assert_near(jit, 0.0, 1e-6, "screen shake 0: no tase jitter")
	assert_near(c.fp_states.cam_dy, -Tweak.crew().fp_tase_buckle_m, 0.01, "the knee buckle is not shake: kept")
	_gs.shake = 1.0
	var full: float = await _peak_rot(c, 30)
	_gs.shake = 0.5
	var half: float = await _peak_rot(c, 30)
	assert_true(full > 0.0 and half / full > 0.3 and half / full < 0.7,
		"screen shake 0.5 about halves the tase jitter (%.3f vs %.3f deg)" % [rad_to_deg(half), rad_to_deg(full)])
	c.health.revive(1)


func _peak_rot(c: CrewController, frames: int) -> float:
	var m: float = 0.0
	for _i: int in frames:
		await wait_physics_frames(1)
		m = maxf(m, c.fp_states.cam_rot.length())
	return m
