## LEAD r287 RT lever A/B (headless pilot, as data): on a Rolling Thunder run, env CAPER_RT_LEVERS=escort switches only
## the escort knobs on (engage delay ESCORT_DELAY_S, accuracy x ESCORT_ACCURACY); CAPER_RT_LEVERS=on switches the
## three D-158 knobs on (RtTweak truck_window_from escort_down + wave1_exclude [stinger], CrewAiTweak
## cover_prefer_behind_leader_m 4.0; in memory only, never saved). The log then times, from the convoy's stop: the
## escort down, the first BUILD, each crew down / cuff / custody (before or after that BUILD), the first crew member
## within TRUCK_REACH_M of a truck. Lines start "RTAB". Harness only. Owner: ENV A (test support).
class_name Po5RtAb
extends RefCounted

const TRUCK_REACH_M: float = 3.0
const COVER_PREFER_M: float = 4.0
const ESCORT_DELAY_S: float = 1.5
const ESCORT_ACCURACY: float = 0.7

var _rt: HeistRuntime = null
var _note: Callable
var _t0: float = -1.0
var _build_t: float = -1.0
var _escort_t: float = -1.0
var _reached: Dictionary = {}  # slot -> true


## Before the stop: apply the levers when asked (env CAPER_RT_LEVERS=on) and log which set is live.
static func apply_levers() -> String:
	var mode: String = OS.get_environment("CAPER_RT_LEVERS")
	var t: RtTweak = RtTweak.data()
	var ct: CrewAiTweak = load(CrewAiBrain.TWEAK_PATH) as CrewAiTweak
	if mode == "on":
		t.truck_window_from = RtTweak.FROM_ESCORT_DOWN
		t.wave1_exclude = [&"stinger"] as Array[StringName]
		ct.cover_prefer_behind_leader_m = COVER_PREFER_M
	elif mode == "escort":  # LEAD r287: only the escort knobs
		t.escort_engage_delay_s = ESCORT_DELAY_S
		t.escort_accuracy_mult = ESCORT_ACCURACY
	elif mode == "nocuff":  # LEAD r288 A/B baseline: the bots' cuffer priority off (cuffer_score_mult 1.0)
		ct.cuffer_score_mult = 1.0
	return "levers %s: window_from %s, wave1_exclude %s (>= diff %d), cover_prefer %.1f, escort delay %.1f s acc x%.2f, cuffer x%.2f" % [
		mode if mode != "" else "defaults", t.truck_window_from, t.wave1_exclude, t.wave1_exclude_min_difficulty,
		ct.cover_prefer_behind_leader_m, t.escort_engage_delay_s, t.escort_accuracy_mult, ct.cuffer_score_mult]


func start(host: Node, rt: HeistRuntime, note: Callable) -> void:
	_rt = rt
	_note = note
	var m: RollingThunderMission = rt.mission as RollingThunderMission
	if m == null:
		return
	note.call("RTAB " + apply_levers())
	EventBus.assault_phase_changed.connect(_on_phase)
	EventBus.crew_downed.connect(func(slot: int, _d: int) -> void: _crew_line(slot, "down"))
	EventBus.crew_custody.connect(func(slot: int) -> void: _crew_line(slot, "custody"))
	while _live():
		await host.get_tree().create_timer(0.5, true, true).timeout
		if not _live():
			return
		if _t0 < 0.0 and m._stop_done:
			_t0 = rt.heist_time_s
			_line("stop (%s)" % m.layout_id)
		if _t0 < 0.0:
			continue
		if _escort_t < 0.0 and m.objective_state(&"escort") == Enums.ObjectiveState.COMPLETED:
			_escort_t = rt.heist_time_s - _t0
			_line("escort_down")
		for c: CrewController in rt.crew_members():
			if c.crew_state == Enums.CrewState.CUFFED and not _reached.has(-1 - c.slot):
				_reached[-1 - c.slot] = true
				_crew_line(c.slot, "cuffed")
			if _reached.has(c.slot):
				continue
			for t: ArmoredTruck in m._trucks:
				if is_instance_valid(t) and c.global_position.distance_to(t.global_position) <= TRUCK_REACH_M:
					_reached[c.slot] = true
					_line("truck_reached slot %d%s" % [c.slot, " (ai)" if c.is_ai else ""])
					break


func _on_phase(phase: int, wave: int) -> void:
	if _t0 >= 0.0 and _build_t < 0.0 and phase == Enums.AssaultPhase.BUILD and _live():
		_build_t = _rt.heist_time_s - _t0
		_line("build wave %d" % wave)


func _crew_line(slot: int, what: String) -> void:
	if _t0 < 0.0 or not _live():
		return
	var c: CrewController = _rt.crew_controller(slot) as CrewController
	_line("%s slot %d%s %s" % [what, slot, " (ai)" if c != null and c.is_ai else "",
		"before build" if _build_t < 0.0 else "after build"])


func _live() -> bool:
	return _rt != null and is_instance_valid(_rt) and _rt.is_inside_tree()


func _line(s: String) -> void:
	_note.call("RTAB t+%.1f %s" % [_rt.heist_time_s - _t0, s])
