## D-118: a masked crew member's switched-on flashlight / laser feeds the S2.1 detection meter of a guard or
## camera that sees the light even when it cannot see the body (StealthDirector._gadget_rate,
## StealthTweak.gadget_*). Off, unmasked or pointed away: no fill. D-118 correction (pd2_fidelity S4.2): PD2
## observers ignore gadgets, so the multipliers default to 0 (test_d118_defaults_ignore_gadgets); the mechanism
## tests force them on (0.6 / 0.4) and restore the defaults after.
extends TestCase

const FORCED_LIGHT: float = 0.6
const FORCED_LASER: float = 0.4


## Minimal camera observer (same protocol as test_s3_8_cameras.gd).
class FakeCamera extends Node3D:
	var net_id: int = 0
	var detection_preset: StringName = &"camera"

	func _ready() -> void:
		add_to_group(G.OBSERVER)

	func observer_kind() -> int:
		return Enums.ObserverKind.CAMERA

	func can_observe() -> bool:
		return true

	func eye_position() -> Vector3:
		return global_position

	func look_forward() -> Vector3:
		return -global_transform.basis.z


var _rt: HeistRuntime = null
var _st: StealthDirector = null
var _defaults: Array[float] = []


func before_each() -> void:
	var tw: StealthTweak = Tweak.stealth()
	_defaults = [tw.gadget_light_detect_mult, tw.gadget_laser_detect_mult] as Array[float]
	tw.gadget_light_detect_mult = FORCED_LIGHT
	tw.gadget_laser_detect_mult = FORCED_LASER
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0})
	_st = _rt.stealth


func after_each() -> void:
	var tw: StealthTweak = Tweak.stealth()
	tw.gadget_light_detect_mult = _defaults[0]
	tw.gadget_laser_detect_mult = _defaults[1]
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


## Crew at `pos` aiming horizontally at `look_at` (teleport sets look_yaw, pitch 0).
func _place(pos: Vector3, look_at: Vector3) -> void:
	var f: Vector3 = look_at - pos
	f.y = 0.0
	_rt.teleport_crew(0, Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), pos))
	await wait_physics_frames(2)


func _guard(pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> NpcBase:
	return ATestMaps.add_npc_observer(_rt, &"guard", pos, facing)


## Give the equipped weapon `gadgets` and switch it on (authority).
func _gadget(c: CrewController, gadgets: Array[StringName]) -> void:
	var ws: int = c.weapons.equipped_slot
	c.weapons.stats(ws).gadgets = gadgets
	if not c.weapons.gadget_on(ws):
		c.weapons.toggle_gadget()
	assert_true(c.weapons.gadget_on(ws), "gadget switched on")


func _gadget_off(c: CrewController) -> void:
	if c.weapons.gadget_on(c.weapons.equipped_slot):
		c.weapons.toggle_gadget()
	assert_false(c.weapons.gadget_on(c.weapons.equipped_slot), "gadget switched off")


func test_d118_flashlight_on_guard_back_fills_meter() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _guard(Vector3.ZERO)  # faces -Z
	await _place(Vector3(0, 0.05, 8), Vector3.ZERO)  # behind him, shining at his head
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "body behind the guard: no fill")
	await wait_seconds(0.5)
	assert_near(_st.detection_value(g, 0), 0.0, 0.0001, "gadget off: meter does not rise")
	_gadget(c, [&"flashlight"] as Array[StringName])
	await wait_physics_frames(2)
	var r: float = _st.fill_rate(g, c)
	var tw: StealthTweak = Tweak.stealth()
	var d: float = c.eye_position().distance_to(g.eye_position())
	var expect: float = 1.0 * tw.gadget_light_detect_mult * clampf(1.0 - d / tw.gadget_light_range_m, tw.dist_factor_min, 1.0)
	assert_near(r, expect * Modifiers.mult(0, &"stealth.detection_rate_mult"), 0.02, "lit guard fills at the gadget rate")
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.0, 1.0)
	assert_true(ok, "flashlight on the guard: meter rises")
	var v0: float = _st.detection_value(g, 0)
	await wait_seconds(0.5)
	assert_true(_st.detection_value(g, 0) > v0, "keeps rising while lit (%f -> %f)" % [v0, _st.detection_value(g, 0)])
	await _place(Vector3(0, 0.05, 8), Vector3(0, 0, 20))  # light pointed away
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "pointed away: no fill")
	await _place(Vector3(0, 0.05, 8), Vector3.ZERO)
	assert_true(_st.fill_rate(g, c) > 0.0, "back on him")
	ATestMaps.add_wall(_rt.map, Vector3(0, 2, 4), Vector3(6, 4, 0.4))
	await wait_physics_frames(2)
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "wall blocks the light")


func test_d118_gadget_off_or_unmasked_no_fill() -> void:
	var c: CrewController = _crew()
	var g: NpcBase = _guard(Vector3.ZERO)
	await _place(Vector3(0, 0.05, 8), Vector3.ZERO)
	_gadget(c, [&"flashlight"] as Array[StringName])
	await wait_physics_frames(2)
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "unmasked (casing, weapon holstered): no gadget fill")
	c.set_masked()
	await wait_physics_frames(2)
	assert_true(_st.fill_rate(g, c) > 0.0, "masked: the light gives him away")
	_gadget_off(c)
	await wait_physics_frames(2)
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "gadget off: no fill")
	await wait_seconds(0.6)
	var v: float = _st.detection_value(g, 0)
	await wait_seconds(0.4)
	assert_true(_st.detection_value(g, 0) <= v, "gadget off: meter does not rise")


func test_d118_laser_dot_in_view_and_beam_near_head() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _guard(Vector3.ZERO)  # faces -Z
	ATestMaps.add_wall(_rt.map, Vector3(0, 2, -6), Vector3(12, 4, 0.4))
	# Behind and to the side of the guard, the dot on the wall in front of him (beam ~2 m from his head).
	await _place(Vector3(5, 0.05, 8), Vector3(0, 0, -5.8))
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "body out of view, gadget off: no fill")
	_gadget(c, [&"laser"] as Array[StringName])
	await wait_physics_frames(2)
	assert_true(_st.fill_rate(g, c) > 0.0, "laser dot in the guard's view fills")
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.0, 1.0)
	assert_true(ok, "laser dot: meter rises")
	await _place(Vector3(5, 0.05, 8), Vector3(5, 0, 20))  # beam away from him
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "laser pointed away: no fill")
	await _place(Vector3(0.6, 0.05, 8), Vector3(0.6, 0, -5.8))  # beam 0.6 m past his head
	assert_true(_st.fill_rate(g, c) > 0.0, "beam passing his head into his view fills")
	await _place(Vector3(3, 0.05, 8), Vector3(3, 0, 20))  # beam behind him, 3 m away
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "beam out of view: no fill")


func test_d118_camera_sees_flashlight_and_laser() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var cam: FakeCamera = FakeCamera.new()
	cam.name = "Cam"
	_rt.dynamic_root.add_child(cam)
	var cam_pos: Vector3 = Vector3(0, 3, 0)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, 1, -22) - cam_pos, Vector3.UP), cam_pos)
	NetIds.claim(cam)
	await _place(Vector3(0, 0.05, -22), Vector3.ZERO)  # 22 m: beyond the camera preset's far (20)
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "body beyond camera range: no fill")
	_gadget(c, [&"flashlight"] as Array[StringName])
	await wait_physics_frames(2)
	assert_true(_st.fill_rate(cam, c) > 0.0, "camera sees the flashlight shining at it")
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(cam, 0) > 0.0, 1.0)
	assert_true(ok, "camera meter rises")
	await _place(Vector3(0, 0.05, -22), Vector3(0, 0, -40))
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "light pointed away from the camera: no fill")
	_gadget_off(c)
	var ws: int = c.weapons.equipped_slot
	c.weapons.stats(ws).gadgets = [&"laser"] as Array[StringName]
	c.weapons.toggle_gadget()
	ATestMaps.add_wall(_rt.map, Vector3(0, 2, -30), Vector3(12, 4, 0.4))
	await wait_physics_frames(2)
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "dot 30 m out, beyond the camera's far range: no fill")
	# Camera 18 m in front of the crew member, looking away from him at the far wall where the dot lands.
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 3, -12))
	cam.look_at(Vector3(0, 1.6, -29.8), Vector3.UP)
	await _place(Vector3(0, 0.05, 6), Vector3(0, 0, -29.8))
	assert_true(_st.fill_rate(cam, c) > 0.0, "camera sees the laser dot (body behind it)")
	cam.look_at(Vector3(20, 3, -12), Vector3.UP)  # turned sideways: neither dot nor body in its cone
	await wait_physics_frames(2)
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "dot outside the camera cone: no fill")


## D-118 correction: at the shipped defaults a flashlight on a guard's back and a laser dot in his view do nothing.
func test_d118_defaults_ignore_gadgets() -> void:
	var tw: StealthTweak = Tweak.stealth()
	tw.gadget_light_detect_mult = _defaults[0]
	tw.gadget_laser_detect_mult = _defaults[1]
	assert_eq(_defaults, [0.0, 0.0] as Array[float], "PD2: gadget multipliers default to 0 (S4.2)")
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _guard(Vector3.ZERO)  # faces -Z
	await _place(Vector3(0, 0.05, 8), Vector3.ZERO)
	_gadget(c, [&"flashlight", &"laser"] as Array[StringName])
	await wait_physics_frames(2)
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "flashlight + laser on the guard's back: no fill")
	await wait_seconds(0.6)
	assert_near(_st.detection_value(g, 0), 0.0, 0.0001, "meter stays empty")
	ATestMaps.add_wall(_rt.map, Vector3(0, 1, -6), Vector3(6, 3, 0.4))
	await _place(Vector3(3, 0.05, 4), Vector3(0, 1, -6))  # dot on the wall in front of him
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "laser dot in his view: no fill")
