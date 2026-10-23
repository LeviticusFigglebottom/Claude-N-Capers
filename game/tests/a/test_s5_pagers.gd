## A1-07: pagers (S5.2 delay/window/answer, S5.3 answer cap, S5.4 release + juggling, S5.5 timeout).
extends TestCase

const GUARD_POS: Vector3 = Vector3(5, 0.05, -5)

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_pagers", 515, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "skip_casing": true})
	_listen(EventBus.pager_started, &"pager_started")
	_listen(EventBus.pager_answer_started, &"pager_answer_started")
	_listen(EventBus.pager_answered, &"pager_answered")
	_listen(EventBus.pager_failed, &"pager_failed")
	_listen(EventBus.alarm_raised, &"alarm_raised")
	_listen(EventBus.voice_line_requested, &"voice_line_requested")


func after_each() -> void:
	Engine.time_scale = 1.0
	Tweak.stealth().pager_release_resumes = false  # the default (D-114 §4 amended)
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
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


func _guard() -> NpcBase:
	return _rt.npcs(&"guard")[0] as NpcBase


## Mask crew `slot` and stand it next to the guard body.
func _ready_crew(slot: int, offset: Vector3) -> CrewController:
	var c: CrewController = _rt.crew_controller(slot) as CrewController
	c.set_masked()
	_rt.teleport_crew(slot, Transform3D(Basis.IDENTITY, GUARD_POS + offset))
	return c


## Kill the guard and wait for its pager to beep. Returns [guard, pager_id].
func _kill_and_wait_pager() -> Array:
	var g: NpcBase = _guard()
	var c: CrewController = _ready_crew(0, Vector3(0, 0, 1.5))
	await wait_physics_frames(2)
	g.die({}, c.net_id)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_started").is_empty(), 6.0)
	assert_true(ok, "pager_started")
	return [g, int(_of(&"pager_started")[0][1]) if ok else 0]


func test_s5_2_pager_starts_2_to_4_s_after_kill() -> void:
	var g: NpcBase = _guard()
	var c: CrewController = _ready_crew(0, Vector3(0, 0, 1.5))
	await wait_physics_frames(2)
	g.die({}, c.net_id)
	var frames: int = 0
	while _of(&"pager_started").is_empty() and frames < 400:
		await wait_physics_frames(1)
		frames += 1
	var t: float = float(frames) / Engine.physics_ticks_per_second
	assert_false(_of(&"pager_started").is_empty(), "pager started")
	assert_true(t >= Tweak.stealth().pager_delay_min_s - 0.05 and t <= Tweak.stealth().pager_delay_max_s + 0.05,
		"delay %.2f s in [2, 4]" % t)
	assert_eq(int(_of(&"pager_started")[0][2]), g.net_id, "guard net id")
	var comp: InteractableComponent = g.get_node_or_null(^"PagerInteractable") as InteractableComponent
	assert_true(comp != null, "PagerInteractable on the body")
	if comp != null:
		assert_eq(comp.kind, &"answer_pager")
		assert_eq(comp.priority, 10)
		assert_true(comp.allow_multiple, "juggling allowed")
		assert_false(comp.casing_allowed, "not while casing")
	var rows: Array[Dictionary] = _pagers().pager_entries()
	assert_eq(rows.size(), 1, "one HUD row")
	if rows.size() == 1:
		assert_eq(int(rows[0]["guard_net_id"]), g.net_id)
		assert_true(float(rows[0]["time_left"]) <= Tweak.stealth().pager_window_s, "window timer")
		assert_false(bool(rows[0]["answering"]))


func test_s5_2_answer_hold_10s_counts() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var g: NpcBase = r[0]
	ATestMaps.hold_interact(_rt, 0, g.net_id)
	await wait_seconds(Tweak.stealth().pager_answer_s * 0.5)
	assert_eq(_of(&"pager_answer_started").size(), 1, "answer started")
	assert_true(bool(_pagers().pager_entries()[0]["answering"]), "HUD: answering")
	assert_true(_of(&"pager_answered").is_empty(), "not done at half time")
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 10.0)
	_rt.clear_bot_intent(0)
	assert_true(ok, "answered")
	if ok:
		var e: Array = _of(&"pager_answered")[0]
		assert_eq(int(e[1]), int(r[1]), "pager id")
		assert_eq(int(e[2]), 0, "slot")
		assert_eq(int(e[3]), 1, "total = 1")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm")
	assert_true(g.get_node_or_null(^"PagerInteractable") == null or g.get_node(^"PagerInteractable").is_queued_for_deletion(),
		"pager component removed")
	assert_eq(_pagers().pager_entries().size(), 0, "HUD row gone")
	assert_eq(_rt.phase, Enums.HeistPhase.STEALTH)


func test_s5_3_fifth_answer_raises_alarm_on_completion() -> void:
	Engine.time_scale = 4.0
	_pagers().set_answered_total(_pagers().max_answers)
	var r: Array = await _kill_and_wait_pager()
	ATestMaps.hold_interact(_rt, 0, (r[0] as NpcBase).net_id)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 14.0)
	_rt.clear_bot_intent(0)
	assert_true(ok, "5th answer completes")
	if ok:
		assert_eq(int(_of(&"pager_answered")[0][3]), 5, "total 5")
	var alarms: Array[Array] = _of(&"alarm_raised")
	assert_eq(alarms.size(), 1, "alarm once")
	if alarms.size() == 1:
		assert_eq(alarms[0][1], &"pager_limit", "reason pager_limit")
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD)


func test_s5_3_fourth_answer_mercer_line() -> void:
	Engine.time_scale = 4.0
	_pagers().set_answered_total(_pagers().max_answers - 1)
	var r: Array = await _kill_and_wait_pager()
	ATestMaps.hold_interact(_rt, 0, (r[0] as NpcBase).net_id)
	await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 14.0)
	_rt.clear_bot_intent(0)
	# D-117 §6: heister barks (BarkDirector) may come with the answer; the cap line is Mercer's, from his
	# pager_last_answer pool (vo.mercer.pager_last included, BarkTweak.patterns).
	var lines: Array[Array] = []
	for e: Array in _of(&"voice_line_requested"):
		if e[1] == &"mercer" and String(e[2]).begins_with("vo.mercer.pager_last"):
			lines.append(e)
	assert_eq(lines.size(), 1, "Mercer line")
	if lines.size() == 1:
		assert_true([&"vo.mercer.pager_last", &"vo.mercer.pager_last_answer_1", &"vo.mercer.pager_last_answer_2"]
			.has(lines[0][2]), "last-answer line (%s)" % lines[0][2])
	assert_true(_of(&"alarm_raised").is_empty(), "4th answer is fine")


## S5.4 (the default, D-114 §4 amended): an early release with no juggle alarms after the juggle grace
## (StealthTweak.pager_juggle_window_s); the juggle itself: test_po6_08_pager_freeze.gd.
func test_s5_4_release_early_raises_alarm() -> void:
	Engine.time_scale = 4.0
	Tweak.stealth().pager_release_resumes = false
	var r: Array = await _kill_and_wait_pager()
	ATestMaps.hold_interact(_rt, 0, (r[0] as NpcBase).net_id)
	await wait_seconds(2.0)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_seconds(Tweak.stealth().pager_juggle_window_s + 0.3)
	var fails: Array[Array] = _of(&"pager_failed")
	assert_eq(fails.size(), 1, "pager failed")
	if fails.size() == 1:
		assert_eq(fails[0][2], &"released")
	var alarms: Array[Array] = _of(&"alarm_raised")
	assert_eq(alarms.size(), 1, "alarm")
	if alarms.size() == 1:
		assert_eq(alarms[0][1], &"pager_failed")
	assert_true(_of(&"pager_answered").is_empty())


func test_s5_4_juggle_two_answerers_no_alarm() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var g: NpcBase = r[0]
	_ready_crew(1, Vector3(1.0, 0, 0.5))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, g.net_id)
	await wait_seconds(2.0)
	ATestMaps.hold_interact(_rt, 1, g.net_id)
	await wait_seconds(2.0)
	assert_eq(_of(&"pager_answer_started").size(), 2, "both answering")
	_rt.set_bot_intent(0, CrewIntent.new())  # first lets go: the second still holds
	await wait_seconds(1.0)
	assert_true(_of(&"pager_failed").is_empty(), "no failure while slot 1 holds")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm while slot 1 holds")
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 12.0)
	_rt.clear_bot_intent(1)
	assert_true(ok, "slot 1 completes")
	if ok:
		assert_eq(int(_of(&"pager_answered")[0][2]), 1, "answered by slot 1")
		assert_eq(int(_of(&"pager_answered")[0][3]), 1, "total 1")
	await wait_physics_frames(3)
	assert_true(_of(&"alarm_raised").is_empty(), "juggle: no alarm")


func test_s5_4_first_completion_cancels_other_holder_without_alarm() -> void:
	Engine.time_scale = 4.0
	var r: Array = await _kill_and_wait_pager()
	var g: NpcBase = r[0]
	_ready_crew(1, Vector3(1.0, 0, 0.5))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, g.net_id)
	await wait_seconds(1.0)
	ATestMaps.hold_interact(_rt, 1, g.net_id)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_answered").is_empty(), 14.0)
	await wait_physics_frames(3)
	_rt.clear_bot_intent(0)
	_rt.clear_bot_intent(1)
	assert_true(ok, "answered")
	if ok:
		assert_eq(int(_of(&"pager_answered")[0][2]), 0, "first holder's completion counts")
	assert_eq(_of(&"pager_answered").size(), 1, "counted once")
	assert_true(_of(&"pager_failed").is_empty(), "other holder cancelled silently")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm")


func test_s5_5_timeout_raises_alarm() -> void:
	Engine.time_scale = 4.0
	await _kill_and_wait_pager()
	await wait_seconds(Tweak.stealth().pager_window_s - 1.0)
	assert_true(_of(&"pager_failed").is_empty(), "still inside the window")
	await wait_seconds(1.5)
	var fails: Array[Array] = _of(&"pager_failed")
	assert_eq(fails.size(), 1, "failed")
	if fails.size() == 1:
		assert_eq(fails[0][2], &"timeout")
	assert_eq(_of(&"alarm_raised").size(), 1, "alarm")
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD)


func test_s5_2_no_pager_when_loud_and_pending_cancelled() -> void:
	var g: NpcBase = _guard()
	var c: CrewController = _ready_crew(0, Vector3(0, 0, 1.5))
	await wait_physics_frames(2)
	g.die({}, c.net_id)
	await wait_physics_frames(10)
	(_rt.service(G.SVC_STEALTH) as StealthDirector).raise_alarm(&"test", 0)
	await wait_seconds(Tweak.stealth().pager_delay_max_s + 0.3)
	assert_true(_of(&"pager_started").is_empty(), "pending pager cancelled on LOUD")
	assert_eq(_pagers().pager_entries().size(), 0)
	var g2: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(-3, 0.05, -3)))
	await wait_physics_frames(2)
	g2.die({}, c.net_id)
	await wait_seconds(Tweak.stealth().pager_delay_max_s + 0.3)
	assert_true(_of(&"pager_started").is_empty(), "no pagers once loud")


func test_s5_2_only_guards_have_pagers() -> void:
	var c: CrewController = _ready_crew(0, Vector3(0, 0, 1.5))
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(-3, 0.05, -3)))
	await wait_physics_frames(2)
	civ.die({}, c.net_id)
	await wait_seconds(Tweak.stealth().pager_delay_max_s + 0.3)
	assert_true(_of(&"pager_started").is_empty(), "civilians have no pager")


func test_s5_2_dominated_guard_gets_a_pager() -> void:
	var g: NpcBase = _guard()
	_ready_crew(0, Vector3(0, 0, 1.5))
	await wait_physics_frames(2)
	g.set_alert_state(Enums.AlertState.DOMINATED)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"pager_started").is_empty(), 6.0)
	assert_true(ok, "domination starts the pager")
	assert_true(g.get_node_or_null(^"PagerInteractable") != null, "answer on the living guard")
	g.die({}, 0)
	await wait_seconds(Tweak.stealth().pager_delay_max_s + 0.3)
	assert_eq(_of(&"pager_started").size(), 1, "one pager per guard")


## GH sweep (r299): a body folded over a desk (the camera operator) had its hips inside the desk's collision; the pager
## prompt there had no line of sight from anywhere. It is kept on the root's side of any static geometry in between.
func test_pager_prompt_kept_out_of_geometry() -> void:
	var host: Node3D = Node3D.new()
	add_child(host)
	var guard: Node3D = Node3D.new()
	host.add_child(guard)
	guard.global_position = Vector3(50, 0, 50)
	var skel: Skeleton3D = Skeleton3D.new()
	skel.name = "Skeleton3D"
	guard.add_child(skel)
	var hips: int = skel.add_bone("hips")
	skel.set_bone_pose_position(hips, Vector3(-1.0, 0.9, 0))  # folded 1 m forward, over the "desk"
	var desk: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.8, 2.0, 1.6)
	shape.shape = box
	desk.add_child(shape)
	host.add_child(desk)
	desk.global_position = Vector3(49.0, 0.5, 50)  # x 48.6..49.4: the hips (x 49.0) are inside, the root is not
	await wait_physics_frames(2)
	var ps: PagerSystem = PagerSystem.new()
	ps._tw = Tweak.stealth()
	var comp: InteractableComponent = InteractableComponent.new()
	guard.add_child(comp)
	ps._follow_body({"guard": guard}, comp)
	assert_true(comp.global_position.x > 49.4, "the prompt stays outside the desk (x %.2f)" % comp.global_position.x)
	assert_true(comp.global_position.x <= 50.0, "between the root and the desk")
	ps.free()
	host.queue_free()
