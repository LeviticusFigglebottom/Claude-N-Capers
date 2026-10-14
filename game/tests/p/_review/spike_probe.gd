## PO pass: CPU frame spikes without rendering contention (headless). Launches a heist with FrameProf on, masks
## the local crew, raises the alarm at --alarm_at heist seconds (the first-loud frame), runs --seconds, and prints
## every frame whose wall time exceeds --ms (default 50) with FrameProf's top systems.
##   /opt/godot/godot --headless --path game res://tests/p/_review/spike_probe.tscn -- --heist=glasshouse \
##     [--seconds=40] [--alarm_at=20] [--ms=50]
## Owner: ENV P.
extends Node

var _heist: StringName = &"glasshouse"
var _seconds: float = 40.0
var _alarm_at: float = 20.0
var _ms: float = 50.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"heist": _heist = StringName(v)
			"seconds": _seconds = v.to_float()
			"alarm_at": _alarm_at = v.to_float()
			"ms": _ms = v.to_float()
	_run.call_deferred()


func _run() -> void:
	FrameProf.enabled = true
	var t_launch: int = Time.get_ticks_msec()
	var rt: HeistRuntime = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self, {})
	print("[SPIKE] launch %s took %d ms" % [_heist, Time.get_ticks_msec() - t_launch])
	var c: CrewController = rt.crew_controller(0) as CrewController
	FrameProf.reset_frame()
	var alarmed: bool = false
	var worst: float = 0.0
	var last: int = Time.get_ticks_usec()
	var frames: int = 0
	while rt.heist_time_s < _seconds:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - last) / 1000.0
		last = now
		frames += 1
		worst = maxf(worst, ms)
		if ms > _ms:
			print("[SPIKE] t=%.2f frame %.0f ms%s top: %s" % [rt.heist_time_s, ms, " (first loud)" if alarmed and
				rt.heist_time_s < _alarm_at + 0.5 else "", FrameProf.top(6)])
		FrameProf.reset_frame()
		if frames == 30 and c != null:
			c.set_masked(true)
			_report_unresolved_markers(rt)
		if not alarmed and rt.heist_time_s >= _alarm_at and rt.stealth != null:
			alarmed = true
			print("[SPIKE] raising the alarm at t=%.2f" % rt.heist_time_s)
			rt.stealth.raise_alarm(&"spike_probe")
	print("[SPIKE] RESULT %s frames=%d worst=%.0f ms" % [_heist, frames, worst])
	rt.teardown()
	get_tree().quit(0)


## Active objectives whose HUD marker tags find no node (LocalHudModel re-resolves every tag ~1/s while any is unresolved).
func _report_unresolved_markers(rt: HeistRuntime) -> void:
	if rt.hud_model == null:
		return
	for o: Dictionary in rt.hud_model.objectives:
		var tags: Variant = (o.get("args", {}) as Dictionary).get("marker_tags", [])
		if not (tags is Array):
			continue
		for t: Variant in tags:
			var n: int = rt.find_by_tag(StringName(t)).size()
			print("[SPIKE] marker %s tag %s -> %d node(s)%s" % [o.get("id", &""), t, n, "  UNRESOLVED" if n == 0 else ""])
