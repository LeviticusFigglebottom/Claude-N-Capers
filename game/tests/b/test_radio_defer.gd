## D-117 §6 (DB/SL strings audit): a heist's own objective radio line waits out a mission line instead of being
## dropped (RadioTweak.defer_events); generic lines are still dropped. Clock stepped by hand as test_contact_radio.
extends TestCase


var _saved_seed: int = 0


func before_each() -> void:
	_saved_seed = GameRng.run_seed
	GameRng.begin_run(1234)


func after_each() -> void:
	for c: Node in get_children():
		if c is ContactRadio:
			c.queue_free()
	GameRng.begin_run(_saved_seed)  # r230: the seed leaked into test_range's crew shot (spread) and made it miss
	await wait_frames(1)


func _radio(heist: StringName) -> ContactRadio:
	var r: ContactRadio = ContactRadio.new()
	r.auto_process = false
	r.setup(heist)
	add_child(r)
	return r


func _run(r: ContactRadio, seconds: float, step: float = 0.25) -> Array[StringName]:
	var out: Array[StringName] = []
	var cb: Callable = func(_sp: StringName, id: StringName, _ev: StringName) -> void: out.append(id)
	r.line_spoken.connect(cb)
	var t: float = 0.0
	while t < seconds:
		r.advance(step)
		t += step
	r.line_spoken.disconnect(cb)
	return out


func test_heist_objective_line_waits_out_the_mission_line() -> void:
	# D-117 §6 (DB/SL audit): the mission says its line in the same frame as the objective change. A line written
	# for this heist's objective is spoken after the quiet, not dropped; a generic one is still dropped.
	var r: ContactRadio = _radio(&"shadow_ledger")
	EventBus.objective_updated.emit(&"cage", Enums.ObjectiveState.ACTIVE, {})
	EventBus.objective_updated.emit(&"cage", Enums.ObjectiveState.COMPLETED, {})
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.shadow_ledger_cage_open", {})
	assert_true(r.is_suppressed())
	var quiet: float = r._suppressed_until - r.now_s
	assert_eq(_run(r, quiet - 0.25).size(), 0, "quiet while the mission line plays")
	assert_eq(_run(r, 2.0), [&"vo.accountant.shadow_ledger_radio_cage"] as Array[StringName],
			"the heist's own cage line is heard after it")
	# Mission line first, then the objective (same frame, other order): also deferred.
	_run(r, 10.0)
	EventBus.objective_updated.emit(&"hack", Enums.ObjectiveState.HIDDEN, {})
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.shadow_ledger_hack_done", {})
	EventBus.objective_updated.emit(&"hack", Enums.ObjectiveState.ACTIVE, {})
	assert_eq(_run(r, 12.0).size(), 1, "objective_new with a heist line waits too")
	# An objective with no heist line (generic pool only) is dropped by the mission line, as before.
	_run(r, 10.0)
	EventBus.objective_updated.emit(&"no_such_step", Enums.ObjectiveState.ACTIVE, {})
	EventBus.objective_updated.emit(&"no_such_step", Enums.ObjectiveState.COMPLETED, {})
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.shadow_ledger_cage_open", {})
	assert_eq(_run(r, 12.0).size(), 0, "generic objective line dropped")
