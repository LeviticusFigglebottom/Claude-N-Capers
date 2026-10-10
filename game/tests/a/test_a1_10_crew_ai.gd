## A1-10 CrewAiBrain plumbing: bot intents override the brain, the "crew_ai" launch option, the
## tweak resource and the order hook.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(options: Dictionary = {}) -> void:
	var o: Dictionary = {"map_packed": ATestMaps.basic(0, 0)}
	o.merge(options, true)
	_rt = await HeistLauncher.launch(&"unit_map", 7, Enums.Difficulty.ROUTINE, self, o)
	await wait_physics_frames(2)


func test_a1_10_tweak_loads() -> void:
	var tw: CrewAiTweak = load(CrewAiBrain.TWEAK_PATH) as CrewAiTweak
	assert_true(tw != null, "crew_ai_tweak.tres loads")
	assert_true(tw.follow_min_m < tw.follow_stop_m and tw.follow_stop_m < tw.follow_max_m, "follow band ordered")


func test_a1_10_bot_intent_overrides_brain() -> void:
	await _launch()
	var c: CrewController = _rt.crew_controller(1) as CrewController
	var b: CrewAiBrain = CrewAiBrain.of(c)
	assert_true(b.is_active() and c.stealth_hidden, "brain drives slot 1 in stealth")
	var walk: CrewIntent = CrewIntent.new()
	walk.move = Vector2(0.0, 1.0)
	_rt.set_bot_intent(1, walk)
	var p0: Vector3 = c.global_position
	await wait_seconds(0.5)
	assert_false(b.is_active(), "inactive under a bot intent")
	assert_false(c.stealth_hidden, "a bot-driven AI slot is observable like a player")
	assert_true(c.global_position.distance_to(p0) > 0.5, "the bot intent moves it")
	_rt.clear_bot_intent(1)
	await wait_physics_frames(2)
	assert_true(b.is_active() and c.stealth_hidden, "brain resumes")


func test_a1_10_option_disables_brain() -> void:
	await _launch({"crew_ai": false})
	var c: CrewController = _rt.crew_controller(1) as CrewController
	assert_false(CrewAiBrain.of(c).is_active(), "crew_ai=false: brain idle")
	assert_false(c.stealth_hidden)


func test_a1_10_order_hook_stores() -> void:
	await _launch()
	var b: CrewAiBrain = CrewAiBrain.of(_rt.crew_controller(2))
	b.receive_order(&"hold", 0, Vector3(1, 0, 2))
	assert_eq(b.order, &"hold")
	assert_eq(b.order_position, Vector3(1, 0, 2))
