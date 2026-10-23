## A4-02 / LEAD r309 AH perf (D measured ~1708 draws at the DJ booth): windowed render counters for Afterhours at the
## densest views (D-146 budgets: main pass <= 2,500 draws, total incl. shadow passes <= 4,000; architecture.md §10).
## Views: the DJ booth looking over the dance floor, the floor looking back at the booth, and the hall floor (4 yaws)
## before and during the loud stampede. Per view over SAMPLE_FRAMES: draws (main / shadow / total), objects, primitives,
## CPU process / physics ms (llvmpipe: the GPU time is not meaningful here), NPCs alive, FrameProf's top systems.
## PNG per view to --cap-out. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --path game --resolution 1920x1080 \
##     res://tests/a/e2e/ah_perf_capture.tscn -- --cap-out=/abs/dir [--seed=1] [--diff=2]
extends Node3D

const SAMPLE_FRAMES: int = 60
const BUDGET_MAIN_DRAWS: int = 2500
const BUDGET_TOTAL_DRAWS: int = 4000
const BOOTH_EYE: Vector3 = Vector3(15.5, 2.0, 7.7)
const FLOOR_CENTRE: Vector3 = Vector3(15.5, 1.7, 14.0)

var _out: String = ""
var _seed: int = 1
var _diff: int = Enums.Difficulty.HAZARDOUS
var _cam: Camera3D = null
var _over: Array[String] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cap-out="):
			_out = a.trim_prefix("--cap-out=")
		elif a.begins_with("--seed="):
			_seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--diff="):
			_diff = int(a.trim_prefix("--diff="))
	if _out == "":
		_out = OS.get_user_data_dir() + "/ah_perf"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"afterhours", _seed, _diff, self, {"crew_ai": false})
	if rt == null:
		push_error("[AHPERF] launch failed")
		get_tree().quit(1)
		return
	for c: CrewController in rt.crew_members():
		rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, Vector3(-30, 0.05, -30) + Vector3(2.0 * c.slot, 0, 0)))
	FrameProf.enabled = true
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 75.0
	_cam.current = true
	for i: int in 120:
		await get_tree().physics_frame
	print("[AHPERF] afterhours seed %d diff %d: %d civilians, %d guards, variants dance_clusters %s crowd %s" % [_seed,
		_diff, rt.npcs(&"civilian").size(), rt.npcs(&"guard").size(), rt.mission.variant(&"dance_clusters"),
		rt.mission.variant(&"crowd")])
	await _view(rt, "booth_over_floor", BOOTH_EYE, FLOOR_CENTRE + Vector3(0, -0.6, 2.0))
	await _view(rt, "floor_to_booth", FLOOR_CENTRE + Vector3(0, 0, 4.0), BOOTH_EYE)
	for yaw: int in [0, 90, 180, 270]:
		await _view(rt, "hall_calm_%d" % yaw, FLOOR_CENTRE, FLOOR_CENTRE + Vector3(0, 0, -6).rotated(Vector3.UP, deg_to_rad(yaw)))
	rt.stealth.raise_alarm(&"perf", 0)
	for i: int in 120:  # the stampede: civilians_flee, the crowd running for the exits
		await get_tree().physics_frame
	# a software-rendered view takes minutes of wall time: slow the game so the crowd is still on the floor when sampled
	Engine.time_scale = 0.02
	for yaw: int in [0, 90, 180, 270]:
		await _view(rt, "hall_stampede_%d" % yaw, FLOOR_CENTRE, FLOOR_CENTRE + Vector3(0, 0, -6).rotated(Vector3.UP,
			deg_to_rad(yaw)))
	await _view(rt, "booth_stampede", BOOTH_EYE, FLOOR_CENTRE + Vector3(0, -0.6, 2.0))
	Engine.time_scale = 1.0
	print("[AHPERF] over budget: %s" % [_over])
	print("[AHPERF] done: %s" % _out)
	get_tree().quit(0)


func _view(rt: HeistRuntime, label: String, eye: Vector3, at: Vector3) -> void:
	_cam.global_position = eye
	_cam.look_at(at)
	for i: int in 10:
		await get_tree().process_frame
	var vp: Viewport = get_viewport()
	var main_d: Array[int] = []
	var shadow_d: Array[int] = []
	var objs: Array[int] = []
	var prims: Array[int] = []
	var proc_ms: Array[float] = []
	var phys_ms: Array[float] = []
	for i: int in SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		main_d.append(vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		shadow_d.append(vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		objs.append(vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
		prims.append(vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var m: int = _max(main_d)
	var s: int = _max(shadow_d)
	if m > BUDGET_MAIN_DRAWS or m + s > BUDGET_TOTAL_DRAWS:
		_over.append("%s main %d total %d" % [label, m, m + s])
	print(("[AHPERF] %s: draws main max %d avg %d | shadow max %d | total max %d | objects %d | prims %.0fk | "
		+ "process %.1f ms physics %.1f ms | NPCs %d civ %d | top %s") % [label, m, _avg_i(main_d), s,
		_max_sum(main_d, shadow_d), _max(objs), float(_max(prims)) / 1000.0, _avg_f(proc_ms), _avg_f(phys_ms),
		rt.npcs().size(), rt.npcs(&"civilian").size(), FrameProf.top(5)])
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, label])


static func _max(a: Array) -> int:
	var v: int = 0
	for x: Variant in a:
		v = maxi(v, int(x))
	return v


static func _max_sum(a: Array[int], b: Array[int]) -> int:
	var v: int = 0
	for i: int in a.size():
		v = maxi(v, a[i] + b[i])
	return v


static func _avg_i(a: Array[int]) -> int:
	var t: int = 0
	for x: int in a:
		t += x
	return t / maxi(a.size(), 1)


static func _avg_f(a: Array[float]) -> float:
	var t: float = 0.0
	for x: float in a:
		t += x
	return t / maxf(float(a.size()), 1.0)
