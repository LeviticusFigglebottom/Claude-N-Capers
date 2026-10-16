## Lead perf finding (A's gh_stealth harness: process frames of 7-20 s after masking up on llvmpipe): the
## HUD's per-frame work stays inside a budget. A masked HUD (objectives + world markers in front of a
## camera, three crew rows, the onboarding card up, a toast) is stepped FRAMES times: every processing
## node of the HUD subtree runs its _process, timed directly (engine frame times on a shared CPU are noise).
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")
const FRAMES: int = 120
const BUDGET_MS: float = 1.0
const CHURN_BUDGET_MS: float = 2.0

var _hud: Hud
var _model: MockHudModel
var _cam: Camera3D


func before_each() -> void:
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.make_current()
	_model = MockHudModel.new()
	add_child(_model)


func after_each() -> void:
	if _hud != null:
		_hud.queue_free()
	_hud = null
	_model.queue_free()
	_cam.queue_free()
	await wait_frames(2)


func _fill_model() -> void:
	_model.player_mode = &"masked"
	_model.masked = true
	_model.casing = false
	var objs: Array[Dictionary] = []
	var markers: Array[Dictionary] = []
	for i: int in range(4):
		var id: StringName = StringName("obj_%d" % i)
		# Half without args: "{count}/{total}" stays unfilled and takes ObjectivesPanel's cleanup path.
		objs.append({"id": id, "text_key": &"objective.glasshouse.secure", "args": {"bags": 4, "secured": i} if i % 2 == 0 else {},
			"state": Enums.ObjectiveState.ACTIVE})
		markers.append({"id": id, "text_key": &"objective.glasshouse.secure", "position": Vector3(i * 2.0 - 3.0, 0, -8.0 - i),
			"state": Enums.ObjectiveState.ACTIVE})
	_model.objectives = objs
	_model.objective_markers = markers
	var crew: Array[Dictionary] = []
	for slot: int in [1, 2, 3]:
		crew.append({"slot": slot, "name": "Mate %d" % slot, "is_ai": slot > 1, "health_frac": 0.6, "armor_frac": 0.3,
			"state": Enums.CrewState.NORMAL, "downs_left": 3, "carried_loot_id": &"", "mode": &"masked"})
	_model.crew = crew
	_model.health = 100.0
	_model.max_health = 230.0


## Average milliseconds of one HUD step: _process(1/60) of every processing node under `root`.
func _step_ms(root: Node) -> float:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	var procs: Array[Node] = []
	for n: Node in nodes:
		if n.has_method(&"_process"):
			procs.append(n)
	var t0: int = Time.get_ticks_usec()
	for _i: int in range(FRAMES):
		for n: Node in procs:
			if n.is_processing():
				n.call(&"_process", 1.0 / 60.0)
	return float(Time.get_ticks_usec() - t0) / FRAMES / 1000.0


func test_masked_hud_per_frame_cost_is_within_budget() -> void:
	_fill_model()
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)
	_hud.onboarding.call(&"_show", &"loud")
	_hud.toast(&"ui.hud.player_left", {"name": "Cole", "heister": "Sable"}, 999.0)
	await wait_frames(5)
	assert_true(_hud.objective_markers.drawn.size() > 0, "markers on screen")
	var cost: float = _step_ms(_hud)
	print("HUD per-frame cost %.3f ms" % cost)
	assert_true(cost < BUDGET_MS, "HUD per-frame cost %.3f ms < %.1f ms" % [cost, BUDGET_MS])


## Worst case: every model group changes every frame (moving targets, detection, crew health while masked),
## so every widget refresh runs each frame. Prints the cost per signal (the profile) and holds the total
## under CHURN_BUDGET_MS.
func test_refresh_churn_per_frame_is_within_budget() -> void:
	_fill_model()
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)
	_hud.onboarding.call(&"_show", &"loud")
	await wait_frames(5)
	var total: float = 0.0
	var rows: Array[String] = []
	for sig: Dictionary in _model.get_signal_list():
		var sname: StringName = StringName(sig["name"])
		if not String(sname).ends_with("_changed") or sname == &"changed":
			continue
		var args: Array = [_model.objective_markers] if sname == &"objective_markers_changed" else []
		var t0: int = Time.get_ticks_usec()
		for _i: int in range(FRAMES):
			_model.callv(&"emit_signal", [sname] + args)
		var ms: float = float(Time.get_ticks_usec() - t0) / FRAMES / 1000.0
		total += ms
		rows.append("%s %.3f" % [sname, ms])
	rows.sort_custom(func(a: String, b: String) -> bool: return float(a.get_slice(" ", 1)) > float(b.get_slice(" ", 1)))
	print("HUD refresh profile (ms / frame): total %.3f | %s" % [total, " | ".join(rows.slice(0, 8))])
	assert_true(total < CHURN_BUDGET_MS, "all refreshes in one frame %.3f ms < %.1f ms" % [total, CHURN_BUDGET_MS])


## Lead perf item (A's FrameProf: one hud_model frame at 44 ms in an ND loud wave): in one frame all crew
## change state (downed / back up, a carried bag) and the objective list swaps (the loud branch adds and
## completes steps). Real data changes, so every widget's refresh does its full work. Alternates two states
## so no frame is a no-op.
func test_loud_wave_frame_is_within_budget() -> void:
	_fill_model()
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)
	await wait_frames(5)
	var states: Array = [_wave(false), _wave(true)]
	# Lead r217: load-robust. The work is still timed around the model writes only (the HUD's own refresh cost), but
	# judged on the MEDIAN of 40 frames, best of 3 rounds: preemption on a shared CPU lands in the tail (the old p90
	# read 9 ms under a parallel windowed capture, 3/3 green alone), a real regression moves the median every round.
	var first: float = _wave_frame(states[0], true)
	var best_median: float = INF
	var best_p90: float = INF
	for _round: int in range(3):
		var times: Array[float] = []
		for i: int in range(40):
			times.append(_wave_frame(states[(i + 1) % 2], false))
		times.sort()
		best_median = minf(best_median, times[times.size() / 2])
		best_p90 = minf(best_p90, times[int(times.size() * 0.9)])
		if best_median < CHURN_BUDGET_MS:
			break
	print("HUD loud-wave frame: first %.3f ms, median %.3f ms, p90 %.3f ms (best of rounds)" % [first, best_median, best_p90])
	# The first loud frame (first flash, first downed screen) was the 44 ms spike: 80+ ms here when the cue
	# table loaded on it. Warm tables keep it near the others; 5 ms leaves room for a shared CPU.
	assert_true(first < 5.0, "first loud-wave frame %.3f ms < 5 ms" % first)
	assert_true(best_median < CHURN_BUDGET_MS, "loud-wave frame median %.3f ms < %.1f ms" % [best_median, CHURN_BUDGET_MS])


## One loud-wave frame: every group the wave touches changes at once; returns the ms the HUD spent on it.
func _wave_frame(st: Dictionary, log_parts: bool) -> float:
	var t0: int = Time.get_ticks_usec()
	var parts: Array[String] = []
	var tp: int = t0
	for k: String in ["crew", "crew_state", "objectives", "objective_markers", "assault_phase"]:
		_model.set(k, st[{"crew": "crew", "crew_state": "local_state", "objectives": "objectives",
				"objective_markers": "markers", "assault_phase": "assault"}[k]])
		parts.append("%s %.1f" % [k, float(Time.get_ticks_usec() - tp) / 1000.0])
		tp = Time.get_ticks_usec()
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	if log_parts:
		print("HUD loud-wave first frame %.3f ms: %s" % [ms, ", ".join(parts)])
	return ms


func _wave(down: bool) -> Dictionary:
	var crew: Array[Dictionary] = []
	for slot: int in [1, 2, 3]:
		crew.append({"slot": slot, "name": "Mate %d" % slot, "is_ai": slot > 1, "health_frac": 0.0 if down else 0.8,
			"armor_frac": 0.0 if down else 0.5, "state": Enums.CrewState.DOWNED if down else Enums.CrewState.NORMAL,
			"downs_left": 2 if down else 3, "bleedout_s": 25.0 if down else -1.0,
			"carried_loot_id": &"" if down else &"loot.gold", "mode": &"masked"})
	var objs: Array[Dictionary] = []
	var markers: Array[Dictionary] = []
	var ids: Array[StringName] = [&"keycard", &"hack", &"secure", &"escape"]
	if down:
		ids = [&"lockdown", &"hack", &"vault_drill", &"secure", &"escape_wait"] as Array[StringName]
	for i: int in range(ids.size()):
		objs.append({"id": ids[i], "text_key": &"objective.glasshouse.secure", "args": {"bags": 4, "secured": i},
			"state": Enums.ObjectiveState.COMPLETED if i == 0 and not down else Enums.ObjectiveState.ACTIVE})
		markers.append({"id": ids[i], "text_key": &"objective.glasshouse.secure", "position": Vector3(i * 2.0 - 3.0, 0, -9.0),
			"state": Enums.ObjectiveState.ACTIVE})
	return {"crew": crew, "local_state": Enums.CrewState.DOWNED if down else Enums.CrewState.NORMAL, "objectives": objs,
		"markers": markers, "assault": Enums.AssaultPhase.SUSTAIN if down else Enums.AssaultPhase.BUILD}
