## PO6-07 evidence (lead r205): a real Golden Hour run through HeistLauncher with bots: kill a guard, answer the
## pager, go loud, run the first assault wave to FADE. Logs every keyed loop start/stop and the number of pooled
## players playing a looping stream, then asserts the pager beep/radio and the siren are gone when their state ends.
## Slow (one assault wave at time_scale 4), so it only runs with CAPER_AUDIO_REVIEW=1:
##   CAPER_AUDIO_REVIEW=1 GODOT=/opt/godot/godot bash tools/ci/run_tests.sh c/_review gh_audio
## Log: user://po6_07_gh_audio_log.txt (path printed). Owner: ENV C.
extends TestCase

const HEIST: StringName = &"glasshouse"
const SEED: int = 1001
const LOG_PATH: String = "user://po6_07_gh_audio_log.txt"

var _launcher: Script = null
var _lines: PackedStringArray = PackedStringArray()
var _t0: int = 0
var _cue: CuePlayer = null
var _last_keys: Array[StringName] = []
var _last_looping: int = -1


func before_all() -> void:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == &"HeistLauncher":
			_launcher = load(c["path"]) as Script


func after_each() -> void:
	Engine.time_scale = 1.0


func test_gh_pager_and_siren_stop() -> void:
	if OS.get_environment("CAPER_AUDIO_REVIEW") != "1":
		skip("evidence run: set CAPER_AUDIO_REVIEW=1")
		return
	if _launcher == null:
		skip("no HeistLauncher")
		return
	_t0 = Time.get_ticks_msec()
	var rt: Object = await _launcher.call(&"launch", HEIST, SEED, Enums.Difficulty.ROUTINE, self, {"ai_teammates": 3})
	var crew: Node3D = rt.call(&"crew_controller", 0) as Node3D
	await wait_until(func() -> bool: return crew == null or BotUtil.nav_ready(crew), 10.0)
	await wait_physics_frames(2)
	var map: Node = rt.get(&"map")
	_cue = map.find_child("CuePlayer", true, false) as CuePlayer if map != null else null
	assert_true(_cue != null, "GH map has a CuePlayer")
	if _cue == null:
		await _teardown(rt)
		return
	_connect_facts()
	_log("launched %s seed %d" % [HEIST, SEED])
	await _pager_phase(rt, crew)
	await _loud_phase(rt, crew)
	_save()
	await _teardown(rt)


func _pager_phase(rt: Object, crew: Node3D) -> void:
	var started: Array[int] = []
	var answered: Array[int] = []
	var on_start: Callable = func(pid: int, _g: int) -> void: started.append(pid)
	var on_ans: Callable = func(pid: int, _s: int, _t: int) -> void: answered.append(pid)
	EventBus.pager_started.connect(on_start)
	EventBus.pager_answered.connect(on_ans)
	var guards: Array = rt.call(&"npcs", &"guard")
	if guards.is_empty():
		fail("no guards")
		return
	var guard: Node3D = guards[0]
	if rt.has_method(&"isolate_npc"):
		rt.call(&"isolate_npc", guard)
		await wait_physics_frames(2)
	var shot_v: Variant = BotUtil.find_clear_point(guard, 3.0, true)
	if shot_v == null:
		fail("no firing point behind the guard")
		return
	rt.call(&"teleport_crew", 0, shot_v)
	var m: CrewIntent = CrewIntent.new()
	m.mask_up = true
	rt.call(&"set_bot_intent", 0, m)
	await _watch_seconds(1.2)
	var aim: CrewIntent = BotUtil.look_at_intent(crew.global_position + Vector3(0, 1.65, 0),
		guard.global_position + Vector3(0, 1.65, 0))
	aim.fire = true
	rt.call(&"set_bot_intent", 0, aim)
	await wait_physics_frames(3)
	rt.call(&"clear_bot_intent", 0)
	assert_true(await _watch_until(func() -> bool: return not started.is_empty(), 6.0), "pager started")
	if started.is_empty():
		return
	var pid: int = started[0]
	await _watch_seconds(1.0)
	assert_true(_cue.is_loop_active(StringName("pager_beep_%d" % pid)), "beep loop while the pager rings")
	var ans: CrewIntent = CrewIntent.new()
	ans.interact = true
	ans.interact_target_net_id = int(guard.get(&"net_id")) if guard.get(&"net_id") != null else 0
	var ans_v: Variant = BotUtil.find_clear_point(guard, 1.0, true)
	if ans_v != null:
		rt.call(&"teleport_crew", 0, ans_v)
	rt.call(&"set_bot_intent", 0, ans)
	assert_true(await _watch_until(func() -> bool: return not answered.is_empty(), 16.0), "pager answered")
	rt.call(&"clear_bot_intent", 0)
	await _watch_seconds(2.0)
	assert_false(_cue.is_loop_active(StringName("pager_beep_%d" % pid)), "beep stopped after the answer")
	assert_false(_cue.is_loop_active(StringName("pager_radio_%d" % pid)), "radio stopped after the answer")
	assert_eq(_looping_players(), 0, "no looping player 2 s after the answer")
	_log("CHECK after answer: loops=%s looping_players=%d" % [_cue.active_loop_keys(), _looping_players()])
	EventBus.pager_started.disconnect(on_start)
	EventBus.pager_answered.disconnect(on_ans)


func _loud_phase(rt: Object, crew: Node3D) -> void:
	var phases: Array[int] = []
	var on_phase: Callable = func(p: int, _w: int) -> void: phases.append(p)
	EventBus.assault_phase_changed.connect(on_phase)
	var f: CrewIntent = CrewIntent.new()
	f.mask_up = true
	f.fire = true
	f.look_pitch = deg_to_rad(30.0)
	f.look_yaw = crew.rotation.y
	rt.call(&"set_bot_intent", 0, f)
	var loud: bool = await _watch_until(func() -> bool: return rt.get(&"phase") == Enums.HeistPhase.LOUD, 20.0)
	rt.call(&"clear_bot_intent", 0)
	assert_true(loud, "heist went LOUD")
	Engine.time_scale = 4.0
	var built: bool = await _watch_until(func() -> bool: return Enums.AssaultPhase.SUSTAIN in phases, 400.0)
	assert_true(built, "assault reached SUSTAIN")
	assert_true(_cue.is_loop_active(CuePlayer.SIREN_KEY), "siren during the assault")
	var faded: bool = await _watch_until(func() -> bool: return Enums.AssaultPhase.FADE in phases, 900.0)
	assert_true(faded, "assault reached FADE")
	await _watch_seconds(2.0)
	assert_false(_cue.is_loop_active(CuePlayer.SIREN_KEY), "siren stopped after the assault")
	_log("CHECK after FADE: loops=%s looping_players=%d" % [_cue.active_loop_keys(), _looping_players()])
	Engine.time_scale = 1.0
	EventBus.assault_phase_changed.disconnect(on_phase)


func _connect_facts() -> void:
	EventBus.pager_started.connect(func(p: int, g: int) -> void: _log("fact pager_started %d guard %d" % [p, g]))
	EventBus.pager_answer_started.connect(func(p: int, s: int) -> void: _log("fact pager_answer_started %d slot %d" % [p, s]))
	EventBus.pager_answered.connect(func(p: int, s: int, _t: int) -> void: _log("fact pager_answered %d slot %d" % [p, s]))
	EventBus.pager_failed.connect(func(p: int, r: StringName) -> void: _log("fact pager_failed %d %s" % [p, r]))
	EventBus.alarm_raised.connect(func(r: StringName, _n: int) -> void: _log("fact alarm_raised %s" % r))
	EventBus.assault_phase_changed.connect(func(p: int, w: int) -> void:
		_log("fact assault_phase_changed %s wave %d" % [Enums.AssaultPhase.keys()[p], w]))
	EventBus.audio_cue_requested.connect(func(c: StringName, _p: Vector3, _n: int) -> void:
		if String(c).begins_with("cue.pager") or String(c).contains("siren"):
			_log("fact audio_cue_requested %s" % c))


## Poll loop state every physics frame while waiting; logs each change.
func _watch_until(cond: Callable, timeout_s: float) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout_s * 1000.0 / maxf(Engine.time_scale, 1.0))
	while Time.get_ticks_msec() < end:
		_poll()
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _watch_seconds(s: float) -> void:
	await _watch_until(func() -> bool: return false, s)


func _poll() -> void:
	var keys: Array[StringName] = _cue.active_loop_keys()
	var looping: int = _looping_players()
	if keys != _last_keys or looping != _last_looping:
		for k: StringName in keys:
			if not k in _last_keys:
				_log("loop START %s" % k)
		for k: StringName in _last_keys:
			if not k in keys:
				_log("loop STOP  %s" % k)
		_log("state loops=%s looping_players=%d" % [keys, looping])
		_last_keys = keys
		_last_looping = looping


func _looping_players() -> int:
	var n: int = 0
	for c: Node in _cue.get_children():
		var s3: AudioStreamPlayer3D = c as AudioStreamPlayer3D
		var s2: AudioStreamPlayer = c as AudioStreamPlayer
		if s3 != null and s3.playing and AudioCueLib.stream_loops(s3.stream):
			n += 1
		elif s2 != null and s2.playing and AudioCueLib.stream_loops(s2.stream):
			n += 1
	return n


func _log(msg: String) -> void:
	var line: String = "[%7.2f s] %s" % [float(Time.get_ticks_msec() - _t0) / 1000.0, msg]
	_lines.append(line)
	print("[PO6-07] " + line)


func _save() -> void:
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	print("[PO6-07] log -> %s" % ProjectSettings.globalize_path(LOG_PATH))


func _teardown(rt: Object) -> void:
	if rt != null and is_instance_valid(rt):
		rt.call(&"teardown")
	await wait_frames(2)
