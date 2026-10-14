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
