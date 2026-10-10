## A1-04: cameras through the observer protocol: illegal-action rules (S3.8, S1.1), no crouch
## effect (S2.5), the unstoppable S3.5 alarm countdown and camera stimulus kinds (S4.4).
extends TestCase


## Minimal camera observer (the real SecurityCamera prefab is ENV A prefab work).
class FakeCamera extends Node3D:
	var net_id: int = 0
	var detection_preset: StringName = &"camera"
	var spotted: Array[Node] = []
	var stimuli_seen: Array[StringName] = []
	var noises: int = 0

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

	func notify_crew_spotted(crew: Node) -> void:
		spotted.append(crew)

	func notify_stimulus(_id: int, kind: StringName, _pos: Vector3) -> void:
		stimuli_seen.append(kind)

	func notify_noise(_pos: Vector3, _kind: StringName, _source: int) -> void:
		noises += 1


var _rt: HeistRuntime = null
var _st: StealthDirector = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0})
	_st = _rt.stealth


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _place(pos: Vector3) -> void:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(2)


## Camera at (0, 3, 0) looking at `target`.
func _camera(target: Vector3) -> FakeCamera:
	var cam: FakeCamera = FakeCamera.new()
	cam.name = "Cam"
	_rt.dynamic_root.add_child(cam)
	var pos: Vector3 = Vector3(0, 3, 0)
	cam.global_transform = Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)
	NetIds.claim(cam)
	return cam


func test_s3_8_camera_unmasked_only_in_restricted() -> void:
	var c: CrewController = _crew()
	var cam: FakeCamera = _camera(Vector3(0, 1, -2))
	await _place(Vector3(0, 0.05, -2))
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "unmasked in the open: camera does not fill (not a guard)")
	ATestMaps.add_zone(_rt.map, MapZone.Kind.RESTRICTED, Vector3(0, 1, -2), Vector3(4, 3, 4))
	await wait_physics_frames(2)
	var unmasked: float = _st.fill_rate(cam, c)
	assert_true(unmasked > 0.0, "S3.8 unmasked in RESTRICTED: camera fills")
	c.set_masked()
	assert_near(unmasked / _st.fill_rate(cam, c), Tweak.stealth().casing_rate_mult, 0.001, "casing x0.35")


func test_s2_5_camera_ignores_crouch() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var cam: FakeCamera = _camera(Vector3(0, 1, -5))
	await _place(Vector3(0, 0.05, -5))
	var stand: float = _st.fill_rate(cam, c)
	assert_true(stand > 0.0, "camera sees masked crew in its cone")
	var i: CrewIntent = CrewIntent.new()
	i.crouch = true
	_rt.set_bot_intent(0, i)
	var ok: bool = await wait_until(func() -> bool: return c.crouched, 1.0)
	assert_true(ok)
	assert_near(_st.fill_rate(cam, c), stand, 0.01 * stand, "S2.5 crouch does not affect cameras")


func test_s3_5_camera_detection_starts_unstoppable_countdown() -> void:
	var tw: StealthTweak = Tweak.stealth()
	var old_delay: float = tw.camera_alarm_delay_s
	tw.camera_alarm_delay_s = 1.5
	var c: CrewController = _crew()
	c.set_masked()
	var cam: FakeCamera = _camera(Vector3(0, 1, -4))
	assert_near(_st.camera_countdown(), -1.0, 0.0001, "no countdown yet")
	await _place(Vector3(0, 0.05, -4))
	var ok: bool = await wait_until(func() -> bool: return _st.camera_countdown() > 0.0, 5.0)
	assert_true(ok, "S3.5 camera at 1.0 starts the countdown")
	assert_eq(cam.spotted, [c] as Array[Node], "camera notified")
	assert_true(_st.camera_countdown() <= 1.5)
	cam.queue_free()  # destroying the camera does not stop it
	ok = await wait_until(func() -> bool: return _st.alarm_raised, 3.0)
	tw.camera_alarm_delay_s = old_delay
	assert_true(ok, "alarm after the countdown even with the camera destroyed")
	assert_eq(_st.alarm_reason, &"camera")
	assert_near(_st.camera_countdown(), -1.0, 0.0001, "countdown cleared")


func test_s4_4_camera_stimulus_kinds_and_deaf() -> void:
	var cam: FakeCamera = _camera(Vector3(0, 0, -5))
	await _place(Vector3(20, 0.05, 20))
	var door: Node3D = Node3D.new()
	_rt.dynamic_root.add_child(door)
	door.global_position = Vector3(0.5, 0, -5)
	_st.register_stimulus(door, &"open_door")
	var body: Node3D = Node3D.new()
	_rt.dynamic_root.add_child(body)
	body.global_position = Vector3(-0.5, 0, -5)
	_st.register_stimulus(body, &"corpse")
	var ok: bool = await wait_until(func() -> bool: return cam.stimuli_seen.has(&"corpse"), 3.0)
	assert_true(ok, "S4.4 cameras see corpses")
	await wait_seconds(Tweak.stealth().stimuli[&"open_door"]["fill_time"] + 0.5)
	assert_false(cam.stimuli_seen.has(&"open_door"), "kinds with camera: false are ignored")
	_rt.make_noise(Vector3(0, 2, -1), 20.0, &"gunshot")
	assert_eq(cam.noises, 0, "S4.4 cameras do not hear")
