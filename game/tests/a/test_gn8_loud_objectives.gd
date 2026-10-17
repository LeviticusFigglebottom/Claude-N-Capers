## GN-8 (B's GN audit): (a) going loud skips the stealth card steps (keycard / treasury / art_store) so the current step
## is not "Get a keycard" in the lockdown; (b) re-adding an objective id keeps its place in the order; (c) a hack already
## done in stealth re-arms in loud (doc §Loud: "the same hack lifts the lockdown"); (d) the HUD's current step (the
## first ACTIVE row) is a required step, the ACTIVE optional ones below it.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch() -> HeistMission:
	_rt = await HeistLauncher.launch(&"gallery_night", 1130, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(3)
	return _rt.mission


func _ids(rows: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Variant in rows:
		out.append(StringName((r as Dictionary)["id"]))
	return out


func _hack() -> HackTerminal:
	for n: Node in _rt.mission.find_tagged(&"hack"):
		if n is HackTerminal:
			return n as HackTerminal
	return null


## (b) HeistMission.add_objective on an existing id relabels it in place.
func test_gn8_readd_keeps_order() -> void:
	var m: HeistMission = HeistMission.new()
	add_child(m)
	m.add_objective(&"a", &"obj.a")
	m.add_objective(&"b", &"obj.b")
	m.add_objective(&"c", &"obj.c")
	m.add_objective(&"a", &"obj.a_loud", Enums.ObjectiveState.ACTIVE, {"x": 1})
	m.add_objective(&"d", &"obj.d")
	assert_eq(_ids(m.objectives()), [&"a", &"b", &"c", &"d"] as Array[StringName], "a keeps its place, d goes last")
	assert_eq(StringName(m.objectives()[0]["text_key"]), &"obj.a_loud", "relabelled")
	m.queue_free()


## (d) LocalHudModel.required_first: ACTIVE optional rows go after the last ACTIVE required row.
func test_gn8_required_step_is_current() -> void:
	var a: int = Enums.ObjectiveState.ACTIVE
	var done: int = Enums.ObjectiveState.COMPLETED
	var rows: Array[Dictionary] = [
		{"id": &"casing", "state": done, "args": {"optional": true}},
		{"id": &"keycard", "state": a, "args": {"optional": true}},
		{"id": &"hack", "state": a, "args": {"optional": true}},
		{"id": &"centrepiece", "state": a, "args": {}},
		{"id": &"canvases", "state": a, "args": {}},
		{"id": &"extras", "state": a, "args": {"optional": true}},
	]
	var out: Array[StringName] = _ids(LocalHudModel.required_first(rows))
	assert_eq(out, [&"casing", &"centrepiece", &"canvases", &"keycard", &"hack", &"extras"] as Array[StringName],
		"required first, the as-needed steps right below, the rest in order")
	var only_opt: Array[Dictionary] = [rows[1], rows[2]]
	assert_eq(_ids(LocalHudModel.required_first(only_opt)), [&"keycard", &"hack"] as Array[StringName],
		"no required step active: unchanged")


## (d) end to end on Gallery Night: the HUD's first ACTIVE row at the start is a required step.
func test_gn8_gn_hud_current_step_required() -> void:
	await _launch()
	await wait_until(func() -> bool: return not _rt.hud_model.objectives.is_empty(), 3.0)
	var first: Dictionary = {}
	for o: Dictionary in _rt.hud_model.objectives:
		if int(o["state"]) == Enums.ObjectiveState.ACTIVE:
			first = o
			break
	assert_false(first.is_empty(), "an active step")
	assert_false(bool((first.get("args", {}) as Dictionary).get("optional", false)),
		"the current step is required (%s)" % first.get("id"))


## (a) + (b) + (c) going loud: card steps skipped, hack relabelled in place.
func test_gn8_loud_skips_card_steps_and_keeps_hack_in_place() -> void:
	var m: HeistMission = await _launch()
	var before: Array[StringName] = _ids(m.objectives())
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_true(_rt.went_loud, "loud")
	for id: StringName in [&"keycard", &"treasury", &"art_store"]:
		assert_eq(m.objective_state(id), Enums.ObjectiveState.COMPLETED, "%s leaves the current step" % id)
		var row: Dictionary = {}
		for o: Dictionary in m.objectives():
			if o["id"] == id:
				row = o
		assert_true(bool((row["data"] as Dictionary).get("skipped", false)), "%s marked skipped (lockdown)" % id)
	var after: Array[StringName] = _ids(m.objectives())
	assert_eq(after.find(&"hack"), before.find(&"hack"), "hack_loud keeps the hack's place")
	assert_eq(m.objective_state(&"hack"), Enums.ObjectiveState.ACTIVE, "the loud hack is a step")
	var first: Dictionary = {}
	for o: Dictionary in _rt.hud_model.objectives:
		if int(o["state"]) == Enums.ObjectiveState.ACTIVE:
			first = o
			break
	assert_ne(StringName(first.get("id", &"")), &"keycard", "not 'Get a keycard' in the lockdown")


## (c) the stealth hack done, then loud: the terminal re-arms, [hack] is active again and lifts the shutters.
func test_gn8_stealth_hack_done_then_loud_rearms() -> void:
	var m: HeistMission = await _launch()
	var ht: HackTerminal = _hack()
	assert_true(ht != null, "Argus terminal")
	ht.duration_s = 0.2
	ht.interruptions = Vector2i.ZERO
	ht.start_hack(0)
	assert_true(await wait_until(func() -> bool: return m.objective_state(&"hack") == Enums.ObjectiveState.COMPLETED,
		5.0), "stealth hack done")
	assert_eq(ht.state, HackTerminal.State.DONE, "terminal done")
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_eq(ht.state, HackTerminal.State.IDLE, "re-armed by the lockdown")
	assert_true(ht.interactable.enabled, "usable again")
	assert_eq(m.objective_state(&"hack"), Enums.ObjectiveState.ACTIVE, "[hack] is the loud step again")
	ht.reconfigure(0.2, Vector2i.ZERO)
	ht.start_hack(0)
	assert_true(await wait_until(func() -> bool: return m.objective_state(&"hack") == Enums.ObjectiveState.COMPLETED,
		5.0), "loud hack done")
	for n: Node in m.find_tagged(&"shutter"):
		if n is Door:
			assert_true((n as Door).is_open, "%s lifted" % n.name)
