## D-117 §6 / pd2_fidelity C8: the VO bark director (systems/vo/bark_director.gd, BarkTweak). Every wired fact plays
## one line; a repeat inside the cooldown plays nothing; one speaker at a time; the acting heister says their own
## line; nothing plays over the contact radio or a mission line (Mercer barks give way); every bark goes out on the
## [R] voice_line_requested path exactly once.
extends TestCase

var _rt: HeistRuntime = null
var _d: BarkDirector = null
## [speaker, line_id, ctx] of every bark (ctx.source == &"bark").
var _lines: Array[Array] = []
## [signal_name, args] handed to the [R] path.
var _rep: Array[Array] = []
## [key, speaker, line_id, slot, now_s] per bark_played.
var _played: Array[Array] = []
var _cb: Callable


func before_each() -> void:
	_lines.clear()
	_rep.clear()
	_played.clear()
	_cb = func(speaker: StringName, line_id: StringName, ctx: Dictionary) -> void:
		if StringName(ctx.get("source", &"")) == BarkDirector.SOURCE:
			_lines.append([speaker, line_id, ctx])
	EventBus.voice_line_requested.connect(_cb)


func after_each() -> void:
	if EventBus.voice_line_requested.is_connected(_cb):
		EventBus.voice_line_requested.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	_d = null
	await wait_frames(2)


func _loadout(heister: StringName) -> Loadout:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.heister = heister
	return l


func _launch(skip_casing: bool = true, manual: bool = true) -> void:
	_rt = await HeistLauncher.launch(&"unit_barks", 11701, Enums.Difficulty.ROUTINE, self, {
		"map_packed": ATestMaps.basic(1, 1), "ai_teammates": 3, "crew_ai": false, "skip_casing": skip_casing,
		"loadouts": {0: _loadout(&"rook"), 1: _loadout(&"sable")},
	})
	await wait_physics_frames(2)
	_d = _rt.service(BarkDirector.SERVICE) as BarkDirector
	assert_true(_d != null, "HeistRuntime creates the BarkDirector service")
	if _d == null:
		return
	_d.auto_process = not manual
	_d.replicate = func(sig: StringName, args: Array) -> void: _rep.append([sig, args])
	_d.bark_played.connect(func(key: StringName, sp: StringName, id: StringName, slot: int) -> void:
		_played.append([key, sp, id, slot, _d.now_s]))


## Advances the director until nothing waits and the channel is free (at most `max_s`).
func _drain(max_s: float = 12.0) -> void:
	var t: float = 0.0
	while t < max_s:
		_d.advance(0.05)
		t += 0.05
		if _d.queue.is_empty() and not _d.is_busy():
			return


func _count(key: StringName) -> int:
	return _played.filter(func(p: Array) -> bool: return p[0] == key).size()


func _ids_of(key: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Array in _played:
		if p[0] == key:
			out.append(p[2])
	return out


## Fires `fn` twice back to back and drains: each key in `keys` played exactly once, by `speaker` (&"" = any).
func _fact(what: String, fn: Callable, keys: Array[StringName], speaker: StringName = &"") -> void:
	var before: int = _played.size()
	fn.call()
	fn.call()
	_drain()
	for key: StringName in keys:
		assert_eq(_count(key), 1, "%s: %s played once (%d)" % [what, key, _count(key)])
		for p: Array in _played:
			if p[0] == key and speaker != &"" and String(key).begins_with("crew."):
				assert_eq(p[1], speaker, "%s: %s said by %s" % [what, key, speaker])
				assert_true(String(p[2]).begins_with("vo.%s." % speaker), "%s: %s's own line (%s)" % [what, speaker, p[2]])
	assert_eq(_played.size() - before, keys.size(), "%s: nothing else played" % what)


func test_d117_barks_every_fact_once() -> void:
	await _launch()
	if _d == null:
		return
	var crew1: CrewController = _rt.crew_controller(1) as CrewController
	var guard: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var cap: int = (_rt.service(G.SVC_PAGERS) as PagerSystem).max_answers
	_fact("crew_masked", func() -> void: EventBus.crew_masked.emit(0), [&"mercer.crew_masked"] as Array[StringName])
	_fact("pager_started", func() -> void: EventBus.pager_started.emit(901, guard.net_id),
		[&"mercer.pager_started"] as Array[StringName])
	_fact("answer_pager", func() -> void: EventBus.interaction_started.emit(guard.net_id, 1, &"answer_pager"),
		[&"crew.pager_started"] as Array[StringName], &"sable")
	_fact("pager_answered", func() -> void: EventBus.pager_answered.emit(901, 1, 1),
		[&"mercer.pager_answered"] as Array[StringName])
	_fact("pager_limit", func() -> void: EventBus.pager_answered.emit(902, 1, cap + 1),
		[&"mercer.pager_limit"] as Array[StringName])
	_fact("pager_failed", func() -> void: EventBus.pager_failed.emit(903, &"timeout"),
		[&"mercer.pager_failed"] as Array[StringName])
	EventBus.pager_failed.emit(904, &"cancelled")
	_drain()
	assert_eq(_count(&"mercer.pager_failed"), 1, "a cancelled pager is not a failure")
	_fact("body_discovered", func() -> void: EventBus.body_discovered.emit(guard.net_id, 0),
		[&"mercer.body_discovered"] as Array[StringName])
	_fact("camera", func() -> void: _rt.stealth.camera_countdown_started.emit(777, 3.0),
		[&"mercer.camera_spotted"] as Array[StringName])
	_fact("device_started", func() -> void: EventBus.device_started.emit(555, &"drill", 60.0),
		[&"mercer.device_started"] as Array[StringName])
	_fact("device_jammed", func() -> void: EventBus.device_jammed.emit(555),
		[&"crew.device_jammed", &"mercer.device_jammed"] as Array[StringName])
	_fact("device_finished", func() -> void: EventBus.device_finished.emit(555),
		[&"mercer.device_finished"] as Array[StringName])
	EventBus.device_started.emit(556, &"hack", 60.0)
	EventBus.device_finished.emit(556)
	_drain()
	assert_eq(_count(&"mercer.device_finished"), 1, "Mercer's drill lines skip a hack")
	_fact("bag_body", func() -> void: EventBus.interaction_started.emit(guard.net_id, 0, &"bag_body"),
		[&"crew.bagging_body"] as Array[StringName], &"rook")
	_fact("civilian_killed", func() -> void: EventBus.civilian_killed.emit(4242, 1),
		[&"crew.civilian_killed"] as Array[StringName], &"sable")
	_fact("guard_down", func() -> void: EventBus.npc_killed.emit(guard.net_id, crew1.net_id, {}),
		[&"crew.guard_down"] as Array[StringName], &"sable")
	_fact("crew_downed", func() -> void: EventBus.crew_downed.emit(1, 1),
		[&"crew.crew_downed", &"mercer.crew_downed"] as Array[StringName], &"sable")
	_fact("revive", func() -> void: EventBus.interaction_started.emit(crew1.net_id, 0, &"revive"),
		[&"crew.reviving"] as Array[StringName], &"rook")
	_fact("crew_custody", func() -> void: EventBus.crew_custody.emit(1),
		[&"mercer.crew_custody"] as Array[StringName])
	EventBus.loot_picked.emit(808, 1)
	_fact("loot_secured", func() -> void: EventBus.loot_secured.emit(808, &"loot.money", 1000),
		[&"crew.loot_secured"] as Array[StringName], &"sable")
	EventBus.loot_secured.emit(809, &"loot.body_bag", 0)
	_drain()
	assert_eq(_count(&"crew.loot_secured"), 1, "a body bag gets no bark")
	# Stealth: no reload barks (BarkTweak.reload_loud_only).
	crew1.weapons.reload_started.emit(0, 2.0)
	_drain()
	assert_eq(_count(&"crew.reloading"), 0, "no reload bark in stealth")
	_fact("going_loud", func() -> void: EventBus.alarm_raised.emit(&"test", 0),
		[&"crew.going_loud"] as Array[StringName])
	_fact("reload", func() -> void: crew1.weapons.reload_started.emit(0, 2.0),
		[&"crew.reloading"] as Array[StringName], &"sable")
	_fact("cops_incoming", func() -> void: EventBus.assault_phase_changed.emit(Enums.AssaultPhase.ANTICIPATION, 0),
		[&"crew.cops_incoming"] as Array[StringName])
	# The [R] path: every bark exactly once, with the same arguments the local fact carried.
	assert_eq(_rep.size(), _lines.size(), "one replicated fact per bark (%d / %d)" % [_rep.size(), _lines.size()])
	for i: int in mini(_rep.size(), _lines.size()):
		assert_eq(_rep[i][0], &"voice_line_requested", "replicated as voice_line_requested")
		assert_eq((_rep[i][1] as Array)[1], _lines[i][1], "same line replicated")
		assert_eq((_rep[i][1] as Array)[0], _lines[i][0], "same speaker replicated")


func test_d117_barks_repeat_inside_cooldown_plays_nothing() -> void:
	await _launch()
	if _d == null:
		return
	EventBus.alarm_raised.emit(&"test", 0)
	_drain()
	var crew1: CrewController = _rt.crew_controller(1) as CrewController
	crew1.weapons.reload_started.emit(0, 2.0)
	_drain()
	assert_eq(_count(&"crew.reloading"), 1, "first reload barks")
	_d.advance(1.0)
	crew1.weapons.reload_started.emit(0, 2.0)
	(_rt.crew_controller(2) as CrewController).weapons.reload_started.emit(0, 2.0)  # AI seat: no viewmodel
	_drain()
	assert_eq(_count(&"crew.reloading"), 1, "inside the shared cooldown: nothing (any heister)")
	_d.advance(_d.tweak.cooldown_of(&"crew.reloading"))
	crew1.weapons.reload_started.emit(0, 2.0)
	_drain()
	assert_eq(_count(&"crew.reloading"), 2, "after the cooldown it barks again")
	var ids: Array[StringName] = _ids_of(&"crew.reloading")
	assert_ne(ids[0], ids[1], "the next variant, not the same line twice")
	# Once per heist.
	EventBus.alarm_raised.emit(&"again", 0)
	_d.advance(100.0)
	EventBus.alarm_raised.emit(&"again", 0)
	_drain()
	assert_eq(_count(&"crew.going_loud"), 1, "going loud is said once per heist")


func test_d117_barks_one_speaker_at_a_time() -> void:
	await _launch()
	if _d == null:
		return
	EventBus.crew_downed.emit(1, 1)  # the downed heister + Mercer
	EventBus.civilian_killed.emit(4243, 0)
	_d.advance(0.05)
	assert_eq(_played.size(), 1, "one line at a time")
	_drain()
	assert_eq(_played.size(), 3, "the others queue and follow")
	for i: int in range(1, _played.size()):
		var prev: Array = _played[i - 1]
		var line: Dictionary = _d.table.line(prev[2])
		var talk: float = _d.tweak.talk_s(StringTable.text(StringName(line.get("text_key", &""))))
		assert_true(float(_played[i][4]) >= float(prev[4]) + talk + _d.tweak.global_gap_s - 0.001,
			"%s starts after %s ended (+gap)" % [_played[i][2], prev[2]])


func test_d117_barks_acting_heister_speaks() -> void:
	await _launch()
	if _d == null:
		return
	EventBus.civilian_killed.emit(4244, 0)
	_drain()
	EventBus.interaction_started.emit(0, 2, &"bag_body")  # slot 2: generic crew -> fallback heister
	_drain()
	assert_eq(_played.size(), 2, "two barks")
	if _played.size() == 2:
		assert_eq(_played[0][1], &"rook", "slot 0 is Rook (Loadout.heister)")
		assert_true(String(_played[0][2]).begins_with("vo.rook.civilian_killed_"), "Rook's own line")
		var fb: StringName = _d.tweak.fallback_heisters[2 % _d.tweak.fallback_heisters.size()]
		assert_eq(_played[1][1], fb, "generic crew: BarkTweak.fallback_heisters by slot")
		assert_eq(int(_played[1][3]), 2, "ctx slot = the actor")


func test_d117_barks_silent_over_radio_and_mission() -> void:
	await _launch()
	if _d == null:
		return
	# Contact radio on air: the bark waits until it ends.
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.radio_loot_secured_1", {"source": &"radio"})
	EventBus.civilian_killed.emit(4245, 1)
	_d.advance(0.5)
	assert_eq(_played.size(), 0, "nothing over the radio")
	_drain()
	assert_eq(_played.size(), 1, "the heister speaks once the radio is done")
	# Mercer barks give way to a mission line of the same moment (before or after the fact): no doubling.
	_d.advance(10.0)
	EventBus.body_discovered.emit(1, 2)
	_d.advance(0.1)
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.abort", {})
	_drain()
	assert_eq(_count(&"mercer.body_discovered"), 0, "a mission line after the fact replaces Mercer's bark")
	_d.advance(30.0)
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.pager_last", {})
	EventBus.body_discovered.emit(1, 2)
	_drain()
	assert_eq(_count(&"mercer.body_discovered"), 0, "a mission line just before the fact covers it too")
	_d.advance(30.0)
	EventBus.voice_line_requested.emit(&"mercer", &"vo.mercer.pager_last", {})
	_d.advance(1.0)
	EventBus.device_started.emit(600, &"drill", 30.0)
	_d.advance(0.5)
	assert_eq(_count(&"mercer.device_started"), 0, "busy while the mission line plays")
	_drain()
	assert_eq(_count(&"mercer.device_started"), 1, "a fact after the mission line still plays, after it")


func test_d117_barks_casing_start_and_heist_end() -> void:
	await _launch(false, false)
	if _d == null:
		return
	assert_eq(_rt.phase, Enums.HeistPhase.CASING, "casing")
	await wait_until(func() -> bool: return _count(&"mercer.heist_start_casing") > 0, 5.0)
	assert_eq(_count(&"mercer.heist_start_casing"), 1, "Mercer's casing line once at the start")
	_rt.end_heist(true)
	assert_eq(_count(&"mercer.stealth_success"), 1, "stealth win: stealth_success")
	assert_eq(_count(&"mercer.heist_success") + _count(&"mercer.heist_failed"), 0, "one result line")
	EventBus.civilian_killed.emit(4246, 0)
	_d.advance(10.0)
	assert_eq(_count(&"crew.civilian_killed"), 0, "silent after the end")


func test_d117_barks_pager_last_answer_pool() -> void:
	await _launch()
	if _d == null:
		return
	var id: StringName = _d.say_now(&"pager_last_answer")
	assert_true([&"vo.mercer.pager_last_answer_1", &"vo.mercer.pager_last_answer_2", &"vo.mercer.pager_last"].has(id),
		"the cap line comes from Mercer's pager_last_answer pool (%s)" % id)
	assert_eq(_rep.size(), 1, "replicated")
