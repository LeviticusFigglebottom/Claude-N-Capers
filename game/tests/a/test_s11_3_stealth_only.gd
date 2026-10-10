## A2-07 S11.3: HeistDef.mode. STEALTH_ONLY: alarm -> Mercer abort line, heist_ended(failed) after
## StealthTweak.stealth_only_abort_s, no assault. LOUD_ONLY: starts loud, masked, director running.
extends TestCase

var _rt: HeistRuntime = null
var _ended: Array[Dictionary] = []
var _lines: Array[Array] = []


func before_each() -> void:
	_ended.clear()
	_lines.clear()
	EventBus.heist_ended.connect(_on_ended)
	EventBus.voice_line_requested.connect(_on_line)


func after_each() -> void:
	EventBus.heist_ended.disconnect(_on_ended)
	EventBus.voice_line_requested.disconnect(_on_line)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_ended(result: Dictionary) -> void:
	_ended.append(result)


func _on_line(speaker: StringName, line_id: StringName, _ctx: Dictionary) -> void:
	_lines.append([speaker, line_id])


func _launch(mode: Enums.HeistMode) -> void:
	var def: HeistDef = HeistDef.new()
	def.id = &"unit_mode"
	def.mode = mode
	_rt = await HeistLauncher.launch(&"unit_mode", 7, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_heist_def(def), "ai_teammates": 0, "skip_casing": true})


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func test_s11_3_stealth_only_alarm_fails_after_abort_line() -> void:
	await _launch(Enums.HeistMode.STEALTH_ONLY)
	assert_eq(_rt.heist_mode, Enums.HeistMode.STEALTH_ONLY)
	assert_eq(_rt.phase, Enums.HeistPhase.STEALTH, "stealth-only starts in stealth")
	var delay: float = Tweak.stealth().stealth_only_abort_s
	assert_near(delay, 5.0, 0.001, "S11.3 5 s abort delay (tweak)")
	_rt.stealth.raise_alarm(&"test", 0)
	assert_has(_lines, [&"mercer", &"vo.mercer.abort"], "Mercer abort line on the alarm")
	await wait_seconds(delay * 0.5)
	assert_eq(_ended.size(), 0, "not ended before the abort delay")
	assert_false(_director().running, "no assault in a stealth-only heist")
	assert_eq(_director().assault_phase, Enums.AssaultPhase.NONE)
	var ok: bool = await wait_until(func() -> bool: return not _ended.is_empty(), delay)
	assert_true(ok, "heist_ended after the delay")
	if ok:
		assert_false(bool(_ended[0]["success"]), "failed")
		assert_false(bool(_ended[0]["stealth"]), "the alarm sounded")
	assert_eq(_rt.phase, Enums.HeistPhase.ENDED)
	assert_eq(_ended.size(), 1, "heist_ended once")
	assert_false(_director().running, "director never started")


func test_s11_3_stealth_or_loud_alarm_does_not_abort() -> void:
	await _launch(Enums.HeistMode.STEALTH_OR_LOUD)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_near(_rt.stealth_abort_left, -1.0, 0.001, "no abort countdown")
	assert_false(_lines.has([&"mercer", &"vo.mercer.abort"]), "no abort line")
	assert_true(_director().running, "assault director starts")
	assert_eq(_ended.size(), 0)


func test_s11_3_loud_only_starts_loud() -> void:
	await _launch(Enums.HeistMode.LOUD_ONLY)
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD, "loud-only starts LOUD (no casing/stealth)")
	assert_true(_rt.went_loud)
	assert_false(_rt.stealth.is_stealth(), "no stealth")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(c.masked, "crew starts masked")
	assert_false(c.is_casing(), "no casing mode")
	await wait_physics_frames(2)
	assert_true(_director().running, "assault director running")
	assert_ne(_director().assault_phase, Enums.AssaultPhase.NONE)
