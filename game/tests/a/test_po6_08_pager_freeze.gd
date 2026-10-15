## PO6-08 (D-114 §3/§4, S5.2/S5.4): the pager response window freezes the moment a player starts the
## answer hold, resumes from the same value when the last holder lets go early (or goes down), ends
## for good on a completed answer, and every looping pager cue has an owner that stops it.
## Holds go through the real InteractionSystem path (CrewIntent.interact on the crew's bot intent).
extends TestCase

const GUARD_POS: Vector3 = Vector3(5, 0.05, -5)
const CUE_PLAYER_PATH: String = "res://world/audio/cue_player.gd"
const LOOP_PAGER_CUES: Array[StringName] = [&"cue.pager_beep", &"cue.pager_radio"]

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _cues: Node = null


func before_each() -> void:
	Engine.time_scale = 1.0
	Tweak.stealth().pager_release_resumes = true
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_po6_08", 608, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "skip_casing": true})
	_listen(EventBus.pager_started, &"pager_started")
	_listen(EventBus.pager_answer_started, &"pager_answer_started")
	_listen(EventBus.pager_answered, &"pager_answered")
	_listen(EventBus.pager_failed, &"pager_failed")
	_listen(EventBus.alarm_raised, &"alarm_raised")
	_listen(EventBus.audio_cue_requested, &"audio_cue_requested")


func after_each() -> void:
	Engine.time_scale = 1.0
	Tweak.stealth().pager_release_resumes = false  # LEAD: PO 2026-10-15 early release = alarm (default)
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _cues != null and is_instance_valid(_cues):
		_cues.queue_free()
	_cues = null
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
		_events.append([tag, a, b, c])
	sig.connect(cb)
	_conns.append([sig, cb])


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _pagers() -> PagerSystem:
	return _rt.service(G.SVC_PAGERS) as PagerSystem


func _ready_crew(slot: int, offset: Vector3) -> CrewController:
	var c: CrewController = _rt.crew_controller(slot) as CrewController
	c.set_masked()
	_rt.teleport_crew(slot, Transform3D(Basis.IDENTITY, GUARD_POS + offset))
	return c


## Kill the guard, wait for the beep. Returns [guard, pager_id].
func _kill_and_wait_pager() -> Array:
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var c: CrewController = _ready_crew(0, Vector3(0, 0, 1.5))
	await wait_physics_frames(2)
	g.die({}, c.net_id)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_started").is_empty(), 6.0)
	assert_true(ok, "pager_started")
	return [g, int(_of(&"pager_started")[0][1]) if ok else 0]


func _row() -> Dictionary:
	var rows: Array[Dictionary] = _pagers().pager_entries()
	return rows[0] if not rows.is_empty() else {}


func _window() -> float:
	return float(_row().get("time_left", -1.0))


## A player hold: interact held on the body, through InteractionSystem.tick (crew_intent.md).
func _hold(slot: int, g: NpcBase) -> void:
	ATestMaps.hold_interact(_rt, slot, g.net_id)


func _release(slot: int) -> void:
	_rt.set_bot_intent(slot, CrewIntent.new())


func test_po6_08_window_freezes_while_answering() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var g: NpcBase = r[0]
	await wait_seconds(2.0)
	var before: float = _window()
	assert_true(before > 0.0 and before < Tweak.stealth().pager_window_s - 1.0, "window ran before the hold (%.2f)" % before)
	_hold(0, g)
	var held: bool = await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	assert_true(held, "answer started through the interaction system")
	var frozen: float = _window()
	await wait_seconds(4.0)
	var row: Dictionary = _row()
	assert_true(bool(row.get("answering", false)), "row answering")
	assert_near(float(row.get("time_left", -1.0)), frozen, 0.001, "window frozen during the hold")
	assert_true(float(row.get("progress", 0.0)) > 0.2, "answer progress advances (%.2f)" % float(row.get("progress", 0.0)))
	assert_true(float(row.get("answer_left", 0.0)) < Tweak.stealth().pager_answer_s, "answer_left counts the hold")
	assert_true(frozen - before < 0.0001 and before - frozen < 0.5, "froze at the start of the hold")
	assert_true(_of(&"pager_failed").is_empty(), "no failure while answering")
	_release(0)


func test_po6_08_early_release_resumes_from_frozen_value() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var g: NpcBase = r[0]
	await wait_seconds(1.0)
	_hold(0, g)
	await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	var frozen: float = _window()
	await wait_seconds(3.0)
	_release(0)
	await wait_physics_frames(3)
	var resumed: float = _window()
	assert_true(resumed > 0.0, "pager still alive after an early release")
	assert_true(absf(frozen - resumed) < 0.1, "resumes from the frozen value (%.2f vs %.2f)" % [frozen, resumed])
	assert_false(bool(_row().get("answering", true)), "no longer answering")
	assert_true(_of(&"pager_failed").is_empty(), "early release is not a failure (D-114 §4)")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm on early release")
	await wait_seconds(1.0)
	assert_true(_window() < resumed - 0.5, "window counts down again after release")
	# Pick it up again and finish: the answer completes cleanly.
	_hold(0, g)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 14.0)
	_release(0)
	assert_true(ok, "re-held answer completes")
	assert_eq(_of(&"pager_answer_started").size(), 2, "two holds")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm")


func test_po6_08_resumed_window_still_times_out() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	_hold(0, r[0] as NpcBase)
	await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	await wait_seconds(2.0)
	_release(0)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_failed").is_empty(),
		Tweak.stealth().pager_window_s + 2.0)
	assert_true(ok, "the resumed window expires")
	if ok:
		assert_eq(_of(&"pager_failed")[0][2], &"timeout", "reason timeout")
	assert_eq(_of(&"alarm_raised").size(), 1, "alarm on expiry")


func test_po6_08_completed_answer_ends_the_pager() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	_hold(0, r[0] as NpcBase)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 14.0)
	_release(0)
	assert_true(ok, "answered")
	assert_eq(_pagers().pager_entries().size(), 0, "no HUD row after the answer")
	assert_eq(_pagers().pager_state(int(r[1])), -1, "pager resolved")
	await wait_seconds(Tweak.stealth().pager_window_s + 1.0)
	assert_true(_of(&"pager_failed").is_empty(), "no later timeout")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm")


func test_po6_08_answerer_going_down_resumes() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	_hold(0, r[0] as NpcBase)
	await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	await wait_seconds(1.0)
	var frozen: float = _window()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_crew_state(Enums.CrewState.DOWNED)
	await wait_physics_frames(2)
	assert_false(bool(_row().get("answering", true)), "downed answerer no longer holds")
	assert_true(absf(_window() - frozen) < 0.1, "window resumes from the frozen value")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm")
	await wait_seconds(1.0)
	assert_true(_window() < frozen - 0.5, "window counts down again")
	_release(0)
	c.set_crew_state(Enums.CrewState.NORMAL)


func test_po6_08_stale_session_does_not_keep_it_frozen() -> void:
	# The answerer drops out without the normal cancel path (peer left / crew state flipped by
	# replication): its InteractionSystem session is still open and nobody ticks it. The pager must
	# not stay frozen forever.
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	_hold(0, r[0] as NpcBase)
	await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	var frozen: float = _window()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.clear_bot_intent(0)
	c.process_mode = Node.PROCESS_MODE_DISABLED  # no more ticks: the session would linger
	c.crew_state = Enums.CrewState.DOWNED  # raw write: skips set_crew_state()'s cancel
	await wait_physics_frames(3)
	assert_eq(_rt.interaction.holders_of(_pagers()._pagers[int(r[1])]["comp"] as InteractableComponent).size(), 0,
		"stale session cancelled")
	await wait_seconds(1.0)
	assert_true(_window() < frozen - 0.5, "window resumes after the answerer left")
	c.crew_state = Enums.CrewState.NORMAL
	c.process_mode = Node.PROCESS_MODE_INHERIT


func test_po6_08_legacy_release_rule_still_alarms() -> void:
	Engine.time_scale = 4.0
	Tweak.stealth().pager_release_resumes = false
	var r: Array = await _kill_and_wait_pager()
	_hold(0, r[0] as NpcBase)
	await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	_release(0)
	await wait_physics_frames(3)
	assert_eq(_of(&"pager_failed").size(), 1, "S5.4 legacy: failed")
	assert_eq(_of(&"alarm_raised").size(), 1, "S5.4 legacy: alarm")


func test_po6_08_no_unowned_looping_pager_cue() -> void:
	# D-114 §3: PagerSystem never requests a looping pager cue through audio_cue_requested (that
	# player would have no owner to stop it); CuePlayer owns the keyed loops on the pager_* facts.
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	_hold(0, r[0] as NpcBase)
	await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 14.0)
	_release(0)
	for e: Array in _of(&"audio_cue_requested"):
		assert_false(LOOP_PAGER_CUES.has(e[1] as StringName), "no loose %s request" % e[1])


func test_po6_08_beep_stops_on_answer_start_and_end() -> void:
	if not ResourceLoader.exists(CUE_PLAYER_PATH):
		skip("CuePlayer not in this build")
		return
	_cues = (load(CUE_PLAYER_PATH) as GDScript).new() as Node
	add_child(_cues)
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var pid: int = int(r[1])
	var beep: StringName = StringName("pager_beep_%d" % pid)
	var radio: StringName = StringName("pager_radio_%d" % pid)
	assert_true(bool(_cues.call(&"is_loop_active", beep)), "beep loops while the pager waits")
	_hold(0, r[0] as NpcBase)
	await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	assert_false(bool(_cues.call(&"is_loop_active", beep)), "beep stops when answering starts")
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 14.0)
	_release(0)
	assert_true(ok, "answered")
	assert_false(bool(_cues.call(&"is_loop_active", beep)), "beep stopped after the answer")
	assert_false(bool(_cues.call(&"is_loop_active", radio)), "radio stopped after the answer")


func test_po6_08_beep_stops_on_expiry() -> void:
	if not ResourceLoader.exists(CUE_PLAYER_PATH):
		skip("CuePlayer not in this build")
		return
	_cues = (load(CUE_PLAYER_PATH) as GDScript).new() as Node
	add_child(_cues)
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var beep: StringName = StringName("pager_beep_%d" % int(r[1]))
	assert_true(bool(_cues.call(&"is_loop_active", beep)), "beep loops")
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_failed").is_empty(),
		Tweak.stealth().pager_window_s + 2.0)
	assert_true(ok, "expired")
	assert_false(bool(_cues.call(&"is_loop_active", beep)), "beep stops on expiry")


func test_po6_08_frozen_state_replicates_to_clients() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	_hold(0, r[0] as NpcBase)
	await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	await wait_seconds(1.0)
	var server: Dictionary = _pagers().net_state()
	var client: PagerSystem = PagerSystem.new()
	client._apply_remote(server)  # what HeistNetSync.apply_services delivers on a client
	var rows: Array[Dictionary] = client._remote_entries()
	assert_eq(rows.size(), 1, "client row")
	if rows.size() == 1:
		assert_eq(int(rows[0]["pager_id"]), int(r[1]))
		assert_true(bool(rows[0]["answering"]), "client sees answering")
		assert_near(float(rows[0]["time_left"]), _window(), 0.06, "client sees the frozen window")
		assert_true(float(rows[0]["progress"]) > 0.0, "client sees answer progress")
	var svc: Dictionary = _rt.net_sync.services_state()
	assert_true(svc.has(HeistNetSync.SVC_PAGERS), "pager rows in the services diff")
	client.free()
	_release(0)


func test_po6_08_answer_fires_pager_answered() -> void:
	# C's CuePlayer stops the loops on this fact (PO6-07).
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	_hold(0, r[0] as NpcBase)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 14.0)
	_release(0)
	assert_true(ok, "pager_answered fires on answer")
	if ok:
		assert_eq(int(_of(&"pager_answered")[0][1]), int(r[1]), "pager id")
	assert_eq(_of(&"pager_answered").size(), 1, "once")


func test_po6_08_expiry_fires_pager_failed() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_failed").is_empty(),
		Tweak.stealth().pager_window_s + 2.0)
	assert_true(ok, "pager_failed fires on expiry")
	if ok:
		assert_eq(int(_of(&"pager_failed")[0][1]), int(r[1]), "pager id")
		assert_eq(_of(&"pager_failed")[0][2], &"timeout")


func test_po6_08_guard_removed_mid_pager_fires_pager_failed() -> void:
	if ResourceLoader.exists(CUE_PLAYER_PATH):
		_cues = (load(CUE_PLAYER_PATH) as GDScript).new() as Node
		add_child(_cues)
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var g: NpcBase = r[0]
	_hold(0, g)
	await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	_release(0)
	g.queue_free()  # despawned / freed mid-pager
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_failed").is_empty(), 2.0)
	assert_true(ok, "pager_failed fires when the guard is removed")
	if ok:
		assert_eq(int(_of(&"pager_failed")[0][1]), int(r[1]), "pager id")
		assert_eq(_of(&"pager_failed")[0][2], &"cancelled", "reason cancelled (no alarm)")
	assert_true(_of(&"alarm_raised").is_empty(), "removal is not an alarm")
	assert_eq(_pagers().pager_entries().size(), 0, "row gone")
	if _cues != null:
		assert_false(bool(_cues.call(&"is_loop_active", StringName("pager_beep_%d" % int(r[1])))), "beep stopped")
		assert_false(bool(_cues.call(&"is_loop_active", StringName("pager_radio_%d" % int(r[1])))), "radio stopped")


func test_po6_08_teardown_mid_pager_fires_pager_failed() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	var fails: Array[Array] = _of(&"pager_failed")
	assert_eq(fails.size(), 1, "pager_failed fires on heist teardown")
	if fails.size() == 1:
		assert_eq(int(fails[0][1]), int(r[1]), "pager id")
		assert_eq(fails[0][2], &"cancelled")
	assert_true(_of(&"alarm_raised").is_empty(), "teardown is not an alarm")
