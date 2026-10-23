## A4-01 / S8.3: camera loop (stealth.camera_loop) blinds one camera for 25 s, one loop per crew member.
extends TestCase

const OperatorTest = preload("res://tests/a/test_s8_2_camera_operator.gd")

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func test_s8_3_loop_one_camera_25s() -> void:
	assert_near(Tweak.interaction().camera_loop_active_s, 25.0, 0.001, "spec 25 s")
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": OperatorTest._map(), "ai_teammates": 0, "crew_ai": false})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var station: CameraStation = _rt.map.get_node("Gameplay/Station") as CameraStation
	assert_eq(station._loop_check(c),
		CameraStation.BLOCK_NEED_SKILL, "no flag: needs the skill")
	Modifiers.set_source(0, &"test", {&"stealth.camera_loop": true})
	assert_eq(station._loop_check(c), InteractableComponent.BLOCK_NONE)
	station._on_loop_completed(c)
	var blind: Array = station.cameras().filter(func(x: SecurityCamera) -> bool: return x.is_suppressed())
	assert_eq(blind.size(), 1, "exactly one camera looped")
	station._on_loop_completed(c)
	blind = station.cameras().filter(func(x: SecurityCamera) -> bool: return x.is_suppressed())
	assert_eq(blind.size(), 1, "a second loop by the same crew replaces the first")
	station._tick_loops(24.9)
	assert_eq(station.loops.size(), 1, "still looped before 25 s")
	station._tick_loops(0.2)
	assert_eq(station.loops.size(), 0, "loop ended")
	blind = station.cameras().filter(func(x: SecurityCamera) -> bool: return x.is_suppressed())
	assert_eq(blind.size(), 0, "camera sees again")
