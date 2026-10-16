## D-117 §6: every written mission line is said by its mission script, once at its moment. Gallery Night's 17 lines,
## Shadow Ledger's camera warning, Golden Hour's code-found line; Dockside Burn's briefing lines never play in-heist
## (briefing screen only); a heist with its own last-pager line replaces PagerSystem's generic one.
extends TestCase

var _rt: HeistRuntime = null
var _lines: Array[Array] = []
var _cb: Callable


func before_each() -> void:
	_lines.clear()
	_cb = func(speaker: StringName, line_id: StringName, ctx: Dictionary) -> void:
		_lines.append([speaker, line_id, ctx])
	EventBus.voice_line_requested.connect(_cb)


func after_each() -> void:
	if EventBus.voice_line_requested.is_connected(_cb):
		EventBus.voice_line_requested.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(heist: StringName, run_seed: int) -> void:
	_rt = await HeistLauncher.launch(heist, run_seed, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(3)


func _count(line_id: StringName) -> int:
	return _lines.filter(func(l: Array) -> bool: return l[1] == line_id).size()


func _speaker(line_id: StringName) -> StringName:
	for l: Array in _lines:
		if l[1] == line_id:
			return l[0]
	return &""


func _net_id(tag: StringName) -> int:
	for n: Node in _rt.mission.find_tagged(tag):
		var v: Variant = n.get(&"net_id")
		if v != null and int(v) != 0:
			return int(v)
	return 0


## Fire `fn` twice; `line_id` is said exactly once.
func _once(line_id: StringName, fn: Callable, what: String) -> void:
	fn.call()
	fn.call()
	assert_eq(_count(line_id), 1, "%s: %s said once (%d)" % [what, line_id, _count(line_id)])


func test_gn_stealth_lines_once_at_their_moment() -> void:
	await _launch(&"gallery_night", 1130)
	var m: HeistMission = _rt.mission
	var crew: Node = _rt.crew_controller(0)
	assert_true(crew != null and crew.is_in_group(G.CREW), "crew body")
	assert_true(m.own_last_pager_line, "GN says its own last-pager line")
	# Keycard in hand.
	_once(&"vo.mercer.gallery_night_keycard", func() -> void: EventBus.item_picked_up.emit(&"item.keycard", 0),
		"keycard picked up")
	assert_eq(_count(&"vo.mercer.gallery_night_keycard"), 1)
	EventBus.item_picked_up.emit(&"item.code_note", 0)
	assert_eq(_count(&"vo.mercer.gallery_night_keycard"), 1, "a code note is not a keycard")
	# The curator's lanyard card (approach).
	var card: KeycardPickup = null
	for k: Node in m.find_tagged(&"keycard"):
		if k is KeycardPickup and (k as KeycardPickup).carrier_tag != &"":
			card = k as KeycardPickup
	_once(&"vo.mercer.gallery_night_curator_keycard", func() -> void: m.call(&"_on_curator_area", crew, card),
		"near the curator")
	# Argus hack: started once, each reboot called.
	var hack: int = _net_id(&"hack")
	assert_true(hack != 0, "hack terminal")
	_once(&"vo.mercer.gallery_night_hack_started", func() -> void: EventBus.device_started.emit(hack, &"hack", 60.0),
		"hack started")
	EventBus.device_jammed.emit(hack)
	assert_eq(_count(&"vo.mercer.gallery_night_hack_interrupted"), 1, "hack interrupted on the reboot")
	assert_eq(_count(&"vo.mercer.gallery_night_drill_jam"), 0, "a hack reboot is not a drill jam")
	# Frame sensors: the first approach to a canvas whose sensor is live.
	var live: Node = null
	for tag: StringName in [&"canvas_lantern", &"canvas_orchard", &"canvas_widow", &"canvas_saint"]:
		for c: Node in m.find_tagged(tag):
			var ls: LootSpawn = c as LootSpawn
			if live == null and ls != null and ls.alarm_on_take and AlarmGroups.is_live(_rt, ls.alarm_group):
				live = c
	if live != null:
		_once(&"vo.mercer.gallery_night_sensors_warning",
			func() -> void: m.call(&"_on_find_area", crew, StringName(live.get(&"objective_tag")), live),
			"approaching a live frame")
	else:
		m.call(&"_warn_sensors", null)
		assert_eq(_count(&"vo.mercer.gallery_night_sensors_warning"), 0, "no live frame rolled: no warning")
	# Treasury lasers (and the sweep hint only when bound for lz_sweep).
	_once(&"vo.mercer.gallery_night_lasers", func() -> void: m.call(&"_on_laser_hint_area", crew, false),
		"approaching the TR grid")
	assert_eq(_count(&"vo.mercer.gallery_night_lasers_sweep"), 0, "no sweep hint off lz_sweep")
	# Treasury / art store opened by their readers.
	var tr: int = _net_id(&"treasury_door")
	var rd: int = _net_id(&"vault_reader")
	assert_true(tr != 0 and rd != 0, "TR / AS readers")
	_once(&"vo.mercer.gallery_night_treasury_open",
		func() -> void: EventBus.interaction_completed.emit(tr, 0, &"keycard_reader"), "Treasury opened")
	_once(&"vo.mercer.gallery_night_art_store_open",
		func() -> void: EventBus.interaction_completed.emit(rd, 0, &"keycard_reader"), "art store opened")
	# Last pager at the run's cap only.
	m.call(&"_on_pager_answered", m.pager_cap() - 1)
	assert_eq(_count(&"vo.mercer.gallery_night_last_pager"), 0, "not before the cap")
	m.call(&"_on_pager_answered", m.pager_cap())
	assert_eq(_count(&"vo.mercer.gallery_night_last_pager"), 1, "at the cap")
	for l: Array in _lines:
		if l[1] == &"vo.mercer.gallery_night_last_pager":
			assert_eq(int((l[2] as Dictionary).get("answered", 0)), m.pager_cap(), "{answered}")
	# Rare timed spawns walk in.
	_once(&"vo.mercer.gallery_night_inspectors",
		func() -> void: m.call(&"_on_timed_spawn", &"rare_insurance_inspection", &"guard_inspection"), "inspectors")
	_once(&"vo.mercer.gallery_night_vaultline",
		func() -> void: m.call(&"_on_timed_spawn", &"rare_vaultline_early", &"guard_vaultline"), "Vaultline")
	# Vance: the Lantern Bearer in a crew member's hands.
	var mgr: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var study: LootBag = mgr.spawn_bag(&"loot.painting_study", Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)), true)
	EventBus.loot_picked.emit(study.net_id, 0)
	assert_eq(_count(&"vo.vance.gallery_night_centrepiece"), 0, "a study is not the centrepiece")
	var lantern: LootBag = mgr.spawn_bag(&"loot.painting_lantern_bearer", Transform3D(Basis.IDENTITY, Vector3(1, 1, 0)), true)
	_once(&"vo.vance.gallery_night_centrepiece", func() -> void: EventBus.loot_picked.emit(lantern.net_id, 0),
		"Lantern Bearer carried")
	assert_eq(_speaker(&"vo.vance.gallery_night_centrepiece"), &"vance", "Vance says it")


func test_gn_loud_lines_once_at_their_moment() -> void:
	await _launch(&"gallery_night", 1130)
	var m: HeistMission = _rt.mission
	var crew: Node = _rt.crew_controller(0)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_eq(_count(&"vo.mercer.gallery_night_lockdown"), 1, "lockdown")
	# Loud: the stealth approach hints stay quiet.
	m.call(&"_on_laser_hint_area", crew, true)
	m.call(&"_on_curator_area", crew, null)
	m.call(&"_warn_sensors", null)
	for id: StringName in [&"vo.mercer.gallery_night_lasers", &"vo.mercer.gallery_night_curator_keycard",
			&"vo.mercer.gallery_night_sensors_warning"]:
		assert_eq(_count(id), 0, "%s silent once loud" % id)
	# Vault drill on, jammed, through.
	var drill: int = _net_id(&"vault_drill")
	assert_true(drill != 0, "vault drill")
	_once(&"vo.mercer.gallery_night_vault_drill", func() -> void: EventBus.device_started.emit(drill, &"drill", 240.0),
		"vault drill placed")
	EventBus.device_jammed.emit(drill)
	assert_eq(_count(&"vo.mercer.gallery_night_drill_jam"), 1, "drill jam")
	assert_eq(_count(&"vo.mercer.gallery_night_hack_interrupted"), 0, "a drill jam is not a hack reboot")
	# Loud hack done: shutters up.
	_once(&"vo.mercer.gallery_night_shutters_up", func() -> void: m.call(&"_lift_lockdown"), "loud hack done")
	# Sniper on the hotel roof (S1), not the conservatory (S2).
	var hotel: Node3D = _rt.map.get_node_or_null(^"Tactical/SniperHotel") as Node3D
	var cons: Node3D = _rt.map.get_node_or_null(^"Tactical/SniperConservatory") as Node3D
	var guards: Array[Node] = _rt.npcs(&"guard")
	assert_true(hotel != null and cons != null and not guards.is_empty(), "perches and a stand-in unit")
	if hotel != null and cons != null and not guards.is_empty():
		var g: NpcBase = guards[0] as NpcBase
		g.global_position = cons.global_position
		m.call(&"_on_special_spawned", g.net_id, &"enemy.longshot")
		assert_eq(_count(&"vo.mercer.gallery_night_sniper_hotel"), 0, "conservatory perch: no hotel line")
		g.global_position = hotel.global_position
		m.call(&"_on_special_spawned", g.net_id, &"enemy.bulwark")
		assert_eq(_count(&"vo.mercer.gallery_night_sniper_hotel"), 0, "not a Longshot")
		_once(&"vo.mercer.gallery_night_sniper_hotel",
			func() -> void: m.call(&"_on_special_spawned", g.net_id, &"enemy.longshot"), "Longshot on the hotel")
	# The ride: Mercer's escape line, then Vance's payday (once).
	_once(&"vo.vance.gallery_night_payday", func() -> void:
		m.set(&"_escape_open", false)
		m.call(&"_open_escape"), "escape open")
	assert_eq(_speaker(&"vo.vance.gallery_night_payday"), &"vance", "Vance says it")


func test_gh_code_found_once() -> void:
	await _launch(&"glasshouse", 4242)
	var m: HeistMission = _rt.mission
	assert_true(m.own_last_pager_line, "GH says its own last-pager line")
	if bool(m.get(&"_safe_open")):
		EventBus.item_picked_up.emit(&"item.code_note", 0)
		assert_eq(_count(&"vo.mercer.glasshouse_code_found"), 0, "safe left open: no code line")
		return
	EventBus.item_picked_up.emit(&"item.keycard", 0)
	assert_eq(_count(&"vo.mercer.glasshouse_code_found"), 0, "a keycard is not the code")
	_once(&"vo.mercer.glasshouse_code_found", func() -> void: EventBus.item_picked_up.emit(&"item.code_note", 0),
		"safe code read")


func test_sl_camera_warning_once() -> void:
	await _launch(&"shadow_ledger", 777)
	var m: HeistMission = _rt.mission
	assert_true(m.own_last_pager_line, "SL says its own last-pager line")
	m.call(&"_on_camera_meter", 0.3)
	assert_eq(_count(&"vo.mercer.shadow_ledger_camera_warning"), 0, "a low meter: no warning")
	_once(&"vo.mercer.shadow_ledger_camera_warning", func() -> void: m.call(&"_on_camera_meter", 0.7),
		"a camera getting curious")
	m.call(&"_on_camera_meter", 0.95)
	assert_eq(_count(&"vo.mercer.shadow_ledger_camera_warning"), 1, "still once")


func test_db_briefing_lines_not_in_heist() -> void:
	await _launch(&"dockside_burn", 9001)
	assert_eq(_count(&"vo.mercer.dockside_burn_intro"), 1, "the in-heist intro plays")
	for l: Array in _lines:
		assert_false(String(l[1]).contains("briefing_"), "no briefing line in-heist (%s)" % l[1])


func test_nd_owns_last_pager_line() -> void:
	await _launch(&"night_deposit", 31)
	var m: HeistMission = _rt.mission
	assert_true(m.own_last_pager_line, "ND says its own last-pager line")
	var ps: PagerSystem = _rt.service(G.SVC_PAGERS) as PagerSystem
	assert_eq(m.pager_cap(), ps.max_answers, "pager_cap() is the PagerSystem cap")
