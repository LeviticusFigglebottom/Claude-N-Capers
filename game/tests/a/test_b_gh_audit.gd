## B-GH audit (LEAD RULING): at the Glasshouse lockdown a known code still opens the safe (as a keycard on a loud door),
## so the [code] step stays (only the dead reader's [keycard] is skipped); the lockdown line is not said about a safe
## that is already open.
extends TestCase

var _rt: HeistRuntime = null
var _lines: Array[StringName] = []


func before_each() -> void:
	_lines.clear()
	EventBus.voice_line_requested.connect(_on_line)


func after_each() -> void:
	if EventBus.voice_line_requested.is_connected(_on_line):
		EventBus.voice_line_requested.disconnect(_on_line)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_line(_speaker: StringName, line_id: StringName, _ctx: Dictionary) -> void:
	_lines.append(line_id)


func _launch() -> HeistMission:
	_rt = await HeistLauncher.launch(&"glasshouse", 4711, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	await wait_physics_frames(2)
	return _rt.mission


func test_code_still_works_at_lockdown() -> void:
	var m: HeistMission = await _launch()
	var code_before: int = m.objective_state(&"code")
	m.call(&"_go_loud")
	var safe: Dictionary = {}
	for o: Dictionary in m.objectives():
		if o["id"] == &"safe":
			safe = o["data"] as Dictionary
	assert_has(safe.get("methods", []), &"code", "the lockdown safe still lists the code")
	assert_has(safe.get("methods", []), &"drill", "and the drill")
	assert_eq(m.objective_state(&"code"), code_before, "[code] is not skipped at lockdown")
	assert_true(_lines.has(&"vo.mercer.glasshouse_lockdown"), "lockdown line for a shut safe")


func test_no_lockdown_line_for_an_open_safe() -> void:
	var m: HeistMission = await _launch()
	m.set(&"_safe_open", true)
	_lines.clear()
	m.call(&"_go_loud")
	assert_false(_lines.has(&"vo.mercer.glasshouse_lockdown"), "no lockdown line about an already-open safe")
