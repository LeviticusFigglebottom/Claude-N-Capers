## Nav perf probe (LEAD 2026-10-16, after round 226 / ENV A's sync navigation, D-121): with navigation iterating on the
## physics frame, a door's NavLink toggle and a breach's link rebuild the nav map inside physics. Loud Golden Hour
## (glasshouse) with the AI crew and the police assault running: baseline physics frame times, then every Door with
## a NavLink toggled (open / closed), then a director breach event (link enabled when BLOWN). Per change: the
## synchronous call time, the worst physics frame (Performance.TIME_PHYSICS_PROCESS) over the next frames, and the
## NavigationServer3D.map_changed count. Budget: 1 / physics_ticks_per_second. Headless is fine (CPU numbers).
##   /opt/godot/godot --headless --path game res://tests/p/_review/nav_perf_probe.tscn -- [--seed=1792002290]
##     [--doors=12] [--settle=10]
## Prints "[NAVPERF] ..." lines and a RESULT summary. Owner: ENV P.
extends Node

var _seed: int = 1792002290
var _max_doors: int = 12
var _settle_s: float = 10.0
var _rebuilds: int = 0
var _rt: HeistRuntime = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"seed": _seed = v.to_int()
			"doors": _max_doors = v.to_int()
			"settle": _settle_s = v.to_float()
	_run.call_deferred()


func _phys_ms() -> float:
	return Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0


func _frames(n: int) -> Array[float]:
	var out: Array[float] = []
	for _i: int in n:
		await get_tree().physics_frame
		out.append(_phys_ms())
	return out


static func _stats(v: Array[float]) -> Dictionary:
	var s: Array[float] = v.duplicate()
	s.sort()
	if s.is_empty():
		return {"median": 0.0, "p95": 0.0, "max": 0.0}
	return {"median": s[s.size() / 2], "p95": s[mini(s.size() - 1, int(s.size() * 0.95))], "max": s[-1]}


func _run() -> void:
	NavigationServer3D.map_changed.connect(func(_m: RID) -> void: _rebuilds += 1)
	_rt = await HeistLauncher.launch(&"glasshouse", _seed, Enums.Difficulty.ROUTINE, self,
		{"skip_casing": true, "crew_ai": true})
	var budget: float = 1000.0 / float(Engine.physics_ticks_per_second)
	var nav_map: RID = (_rt.crew_members()[0] as Node3D).get_world_3d().navigation_map
	print("[NAVPERF] async_iterations=%s budget=%.2f ms" % [NavigationServer3D.map_get_use_async_iterations(nav_map),
		budget])
	for c: CrewController in _rt.crew_members():
		Modifiers.set_source(c.slot, &"test.navperf", {&"defense.damage_taken_mult": 0.0})
	_rt.stealth.raise_alarm(&"test", 0)
	for _i: int in int(_settle_s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	var base: Dictionary = _stats(await _frames(600))
	print("[NAVPERF] baseline median %.2f p95 %.2f max %.2f ms (600 frames, enemies %d)" % [base["median"],
		base["p95"], base["max"], _rt.npcs(&"police").size()])
	# Doors.
	var door_worst: float = 0.0
	var door_call_worst: float = 0.0
	var toggles: int = 0
	var doors: Array[Door] = []
	for n: Node in _rt.find_children("*", "Door", true, false):
		var d: Door = n as Door
		if d != null and d.get(&"_nav_link") != null:
			doors.append(d)
	for d: Door in doors.slice(0, _max_doors):
		for open: bool in [not d.is_open, d.is_open]:
			var r0: int = _rebuilds
			var t0: int = Time.get_ticks_usec()
			d.set_open(open, true)
			var call_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			var after: Dictionary = _stats(await _frames(4))
			toggles += 1
			door_worst = maxf(door_worst, after["max"])
			door_call_worst = maxf(door_call_worst, call_ms)
			print("[NAVPERF] door %s open=%s call %.2f ms, next 4 frames max %.2f ms, rebuilds %d" % [d.name, open,
				call_ms, after["max"], _rebuilds - r0])
	# Breach.
	var breach_worst: float = 0.0
	var dir: AssaultDirector = _rt.find_child("AssaultDirector", true, false) as AssaultDirector
	var b: Node = dir.events.run(&"breach") if dir != null and dir.events != null else null
	if b == null:
		print("[NAVPERF] breach: no breach event ran")
	else:
		var blown: Array[bool] = [false]
		if b.has_signal(&"blown"):
			b.connect(&"blown", func(_x: Node) -> void: blown[0] = true)
		var r0: int = _rebuilds
		var frames: Array[float] = []
		var at_blow: float = 0.0
		for _i: int in 60 * 30:
			await get_tree().physics_frame
			frames.append(_phys_ms())
			if blown[0] and at_blow == 0.0:
				var post: Array[float] = await _frames(6)
				at_blow = (_stats(post)["max"] as float)
				frames.append_array(post)
				break
		breach_worst = maxf(at_blow, 0.0)
		print("[NAVPERF] breach blown=%s, worst of the 6 frames after BLOWN %.2f ms (whole wait max %.2f), rebuilds %d"
			% [blown[0], at_blow, _stats(frames)["max"], _rebuilds - r0])
	var fmt: String = "[NAVPERF] RESULT budget %.2f ms | baseline median %.2f p95 %.2f max %.2f | doors %d toggles:" \
		+ " worst frame %.2f ms, worst call %.2f ms | breach worst %.2f ms | map rebuilds %d"
	print(fmt % [budget, base["median"], base["p95"], base["max"], toggles, door_worst, door_call_worst, breach_worst,
		_rebuilds])
	get_tree().quit(0)
