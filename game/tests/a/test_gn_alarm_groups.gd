## D-103 §6 / QC-54 (Gallery Night frame sensors): a LootSpawn with alarm_on_take raises alarm_raised(&"sensor")
## when a bag is taken while its alarm_group is live; AlarmGroups.disable(group) (the Argus hack) makes that group's
## loot safe; loot without alarm_on_take never alarms.
extends TestCase

var _rt: HeistRuntime = null
var _alarms: Array[StringName] = []
var _cb: Callable = Callable()


func after_each() -> void:
	if _cb.is_valid() and EventBus.alarm_raised.is_connected(_cb):
		EventBus.alarm_raised.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	_alarms.clear()
	_rt = await HeistLauncher.launch(&"unit_map", 1105, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	await wait_physics_frames(2)
	_cb = func(reason: StringName, _src: int) -> void: _alarms.append(reason)
	EventBus.alarm_raised.connect(_cb)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _spawn(pos: Vector3, alarmed: bool, group: StringName) -> LootSpawn:
	return ATestMaps.add_prefab(_rt, "loot_spawn", pos, func(p: GameplayPrefab) -> void:
		(p as LootSpawn).loot_id = &"loot.cash"
		(p as LootSpawn).count = 3
		(p as LootSpawn).alarm_on_take = alarmed
		(p as LootSpawn).alarm_group = group) as LootSpawn


func _take(sp: LootSpawn, c: CrewController) -> void:
	sp._on_completed(c)
	var mgr: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	if c.is_carrying_bag():
		mgr.drop_bag(c, false)
	await wait_physics_frames(2)


func test_gn_unalarmed_loot_never_alarms() -> void:
	var c: CrewController = await _launch()
	var plain: LootSpawn = _spawn(Vector3(2, 0, -4), false, &"")
	await wait_physics_frames(2)
	await _take(plain, c)
	assert_eq(_alarms, [] as Array[StringName], "no sensor on plain loot")
	assert_false(_rt.went_loud)


func test_gn_alarmed_take_in_a_live_group_raises_sensor() -> void:
	var c: CrewController = await _launch()
	var framed: LootSpawn = _spawn(Vector3(2, 0, -4), true, &"argus")
	await wait_physics_frames(2)
	await _take(framed, c)
	assert_has(_alarms, AlarmGroups.REASON_SENSOR, "alarm_raised(&\"sensor\")")
	assert_true(_rt.went_loud, "the sensor alarm sends the heist loud")


func test_gn_disabled_group_makes_its_loot_safe() -> void:
	var c: CrewController = await _launch()
	var framed: LootSpawn = _spawn(Vector3(2, 0, -4), true, &"argus")
	var other: LootSpawn = _spawn(Vector3(-2, 0, -4), true, &"vault")
	await wait_physics_frames(2)
	AlarmGroups.disable(_rt, &"argus")
	assert_false(AlarmGroups.is_live(_rt, &"argus"), "argus offline")
	assert_true(AlarmGroups.is_live(_rt, &"vault"), "other groups stay live")
	await _take(framed, c)
	assert_eq(_alarms, [] as Array[StringName], "a disabled group's frame is safe")
	await _take(other, c)
	assert_has(_alarms, AlarmGroups.REASON_SENSOR, "a live group still alarms")


## GN: a canvas loot_spawn reads "Hold F to cut the painting" (ui.prompt.cut_painting, ENV B), any other loot keeps
## its own prompt; an explicit prompt_key wins.
func test_gn_canvas_spawns_prompt_cut_the_painting() -> void:
	await _launch()
	var canvas: LootSpawn = ATestMaps.add_prefab(_rt, "loot_spawn", Vector3(2, 0, -4), func(p: GameplayPrefab) -> void:
		(p as LootSpawn).loot_id = &"loot.painting_widow_in_blue") as LootSpawn
	var cash: LootSpawn = _spawn(Vector3(-2, 0, -4), false, &"")
	var custom: LootSpawn = ATestMaps.add_prefab(_rt, "loot_spawn", Vector3(0, 0, -8), func(p: GameplayPrefab) -> void:
		(p as LootSpawn).loot_id = &"loot.painting_study"
		(p as LootSpawn).prompt_key = &"ui.prompt.take_loot") as LootSpawn
	await wait_physics_frames(2)
	assert_eq(canvas.interactable.prompt_key, LootSpawn.PROMPT_CUT, "a painting is cut")
	assert_eq(canvas.interactable.kind, &"bag_loot", "still a bag_loot interaction (bots, pilot, LootManager)")
	assert_ne(cash.interactable.prompt_key, LootSpawn.PROMPT_CUT, "cash is not cut")
	assert_eq(custom.interactable.prompt_key, &"ui.prompt.take_loot", "explicit prompt_key wins")
