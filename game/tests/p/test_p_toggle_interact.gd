## Toggle interact (B's Options interact_mode = toggle, GameSettings.is_toggle(&"interact")), real input (PInputDriver):
## a tap of F at a timed interactable runs it to the end without holding; a second tap cancels it (and is no shout);
## moving away cancels it; the latch drops after the end (no second use). Hold mode: a tap still cancels at once.
extends TestCase

const TAKE_S: float = 2.0

var _rt: HeistRuntime = null
var _inp: PInputDriver = null
var _mode_before: Variant = null


func before_each() -> void:
	_mode_before = GameSettings.current().get_value(GameSettings.CONTROLS, &"interact_mode")
	_rt = await HeistLauncher.launch(&"unit_map", 2990, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "skip_casing": true})
	_inp = PInputDriver.new(self)
	_crew().set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0)))
	await wait_physics_frames(5)


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	GameSettings.current().set_value(GameSettings.CONTROLS, &"interact_mode", _mode_before)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _set_mode(mode: String) -> void:
	GameSettings.current().set_value(GameSettings.CONTROLS, &"interact_mode", mode)


## A cash bundle at eye height 1.2 m ahead; true once the crew aims at it.
func _loot() -> SmallLoot:
	var eye: float = _crew().get_node(^"Head").global_position.y
	var l: SmallLoot = ATestMaps.add_prefab(_rt, "small_loot", Vector3(0.0, eye - 0.1, -1.2), func(p: GameplayPrefab) -> void:
		(p as SmallLoot).interaction_time_s = TAKE_S) as SmallLoot
	await wait_physics_frames(3)
	assert_true(_rt.interaction.aimed_component(_crew()) != null, "the loot is aimed at")
	return l


## The loot frees itself when taken: wait on a weak reference (a captured freed object logs an error).
func _until_taken(l: SmallLoot) -> bool:
	var w: WeakRef = weakref(l)
	return await wait_until(func() -> bool: return w.get_ref() == null or (w.get_ref() as SmallLoot).taken, TAKE_S + 2.0)


func _in_session() -> bool:
	return not _rt.interaction.session(0).is_empty()


func test_tap_runs_to_the_end() -> void:
	_set_mode("toggle")
	var l: SmallLoot = await _loot()
	await _inp.tap(&"interact")
	await wait_physics_frames(10)
	assert_true(_in_session(), "a tap starts the take and it keeps going with F released")
	var done: bool = await _until_taken(l)
	assert_true(done, "the take completes without holding F")
	await wait_physics_frames(10)
	assert_false(_crew().intent != null and _crew().intent.interact, "the latch drops after the end")
	assert_false(_in_session(), "no second use")


func test_second_tap_cancels_without_shout() -> void:
	_set_mode("toggle")
	var l: SmallLoot = await _loot()
	var shouts: Array[int] = [0]
	var probe: Callable = func() -> void:
		if _crew().intent != null and _crew().intent.shout:
			shouts[0] += 1
	await _inp.tap(&"interact")
	await wait_physics_frames(15)
	assert_true(_in_session(), "started")
	_inp.press(&"interact")
	for _k: int in 6:
		await wait_physics_frames(1)
		probe.call()
	_inp.release(&"interact")
	await wait_physics_frames(3)
	probe.call()
	assert_false(_in_session(), "the second tap cancels")
	assert_false(l.taken, "not taken")
	assert_eq(shouts[0], 0, "the cancelling tap is not a shout")
	await _inp.tap(&"interact")
	await wait_physics_frames(10)
	assert_true(_in_session(), "a third tap starts it again")


func test_moving_away_cancels() -> void:
	_set_mode("toggle")
	var l: SmallLoot = await _loot()
	await _inp.tap(&"interact")
	await wait_physics_frames(10)
	assert_true(_in_session(), "started")
	_inp.press(&"move_back")
	await wait_seconds(0.8)
	_inp.release(&"move_back")
	await wait_physics_frames(5)
	assert_false(_in_session(), "moving away cancels it")
	assert_false(l.taken, "not taken")
	assert_false(_crew().intent.interact, "and the latch drops")


func test_hold_mode_tap_cancels() -> void:
	_set_mode("hold")
	var l: SmallLoot = await _loot()
	await _inp.tap(&"interact")
	await wait_physics_frames(10)
	assert_false(_in_session(), "hold mode: releasing F cancels")
	_inp.press(&"interact")
	var done: bool = await _until_taken(l)
	_inp.release(&"interact")
	assert_true(done, "hold mode: holding F takes it")
