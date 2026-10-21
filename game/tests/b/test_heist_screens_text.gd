## LEAD r262 / r263: a headless walk of every screen the player reads, for every offered heist (HeistCatalog.ids():
## GH, ND, SL, DB, GN, OF): the Board's broker and contract cards, the briefing per difficulty, the pre-planning board on
## every point and the crew assets, the HUD objective line and the Tab sheet with every objective and the data the
## mission passes, the payday with the heist's achievements, the achievements screen. Every visible text must carry
## no raw key ("objective.x", "ui.y", "asset.z"), no {placeholder} and no dev tag. test_heist_text_audit checks the
## same strings as data; this checks what the screens actually show. A new heist in the catalogue is walked too.
extends TestCase

const BOARD: PackedScene = preload("res://content/ui/board/board_screen.tscn")
const BRIEFING: PackedScene = preload("res://content/ui/briefing/briefing_screen.tscn")
const PREPLAN: PackedScene = preload("res://content/ui/preplanning/preplanning_screen.tscn")
const HUD: PackedScene = preload("res://content/ui/hud/hud.tscn")
const PAYDAY: PackedScene = preload("res://content/ui/results/payday.tscn")
const ACHIEVEMENTS: PackedScene = preload("res://content/ui/achievements/achievements_screen.tscn")
const BANNED: Array[String] = ["[loud]", "[stealth]", "TODO", "TBD", "PLACEHOLDER", "FIXME", "XXX"]
## Sample values for the objective data the missions pass (test_heist_text_audit.ALLOWED_ARGS); a {name} the string
## uses that is not here gets 2.
const ARG_SAMPLES: Dictionary = {"count": 1, "total": 3, "found": 1, "opened": 1, "drives": 2, "drives_secured": 1,
	"answered": 1, "seconds": 60.0, "shutters_in_s": 30.0}

var _raw_key_rx: RegEx = RegEx.create_from_string(
		"\\b(objective|ui|vo|voice|heist|item|loot|asset|music|achievement|contact|unlock|perk|mask)\\.[a-z_]")
var _gate_rx: RegEx = RegEx.create_from_string("\\bG[0-9]\\b")
var _arg_rx: RegEx = RegEx.create_from_string("\\{([a-z_]+)\\}")


func _heists() -> Array[StringName]:
	var out: Array[StringName] = []
	for h: StringName in HeistCatalog.ids():
		out.append(h)
	return out


func _name(h: StringName) -> String:
	return UiText.t(StringName("heist.%s.name" % h))


func test_the_walk_covers_every_offered_heist() -> void:
	assert_true(_heists().size() >= 6, "offered heists: %s" % [_heists()])
	assert_has(_heists(), &"ostrander_federal")


func test_briefing_on_every_difficulty() -> void:
	for h: StringName in _heists():
		for d: int in range(6):
			var s: BriefingScreen = BRIEFING.instantiate() as BriefingScreen
			s.setup(h, d)
			add_child(s)
			await wait_frames(2)
			var texts: Array[String] = _texts(s)
			texts.append_array(s.security_texts())
			texts.append_array(s.objective_texts())
			assert_true(texts.size() >= 10, "%s d%d briefing has text (%d)" % [h, d, texts.size()])
			_check_all("%s briefing d%d" % [h, d], texts)
			s.queue_free()
			await wait_frames(1)


## The Board: the broker on every heist at every difficulty, and every pin's contract card.
func test_board_broker_and_contract_cards() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	p.stash = 100000000
	p.level = 100
	var s: BoardScreen = BOARD.instantiate() as BoardScreen
	s.save_on_buy = false
	s.build_gate = func(_d: int) -> bool: return true
	s.setup(p)
	add_child(s)
	await wait_frames(2)
	s.set_broker_open(true)
	for h: StringName in _heists():
		for d: int in range(6):
			s.broker_select(h, d)
			await wait_frames(1)
			var texts: Array[String] = _texts(s)
			var nm: String = _name(h)
			assert_true(texts.any(func(t: String) -> bool: return t.contains(nm)), "%s d%d: the broker shows it" % [h, d])
			_check_all("%s board broker d%d" % [h, d], texts)
	s.set_broker_open(false)
	for slot: int in range(12):
		s.select_slot(slot)
		await wait_frames(1)
		_check_all("board slot %d (%s)" % [slot, s.selected_contract().get("heist_id", "")], _texts(s))
	s.queue_free()
	await wait_frames(1)


func test_preplan_board_points_and_assets() -> void:
	for h: StringName in _heists():
		var p: PlayerProfile = PlayerProfile.new_default()
		p.cash = 10000000
		var s: PreplanningScreen = PREPLAN.instantiate() as PreplanningScreen
		s.save_on_confirm = false
		s.setup(h, Enums.Difficulty.HAZARDOUS, p)
		add_child(s)
		await wait_frames(2)
		_check_all("%s preplan board" % h, _texts(s))
		# Every point on the heist's blueprint (the older heists list none in HeistDef.preplanning).
		var points: Array[StringName] = s.board.blueprint.point_ids()
		assert_true(points.size() >= 3, "%s points found: %s" % [h, points])
		for pid: StringName in points:
			s.show_point(pid)
			await wait_frames(1)
			_check_all("%s preplan point %s" % [h, pid], _texts(s))
		s.show_crew_assets()
		await wait_frames(1)
		_check_all("%s preplan crew assets" % h, _texts(s))
		s.queue_free()
		await wait_frames(1)


func test_hud_objective_line_and_tab_sheet() -> void:
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = HUD.instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
	await wait_frames(1)
	hud.bind(model)
	for h: StringName in _heists():
		var ids: Array[StringName] = []
		for id: Variant in HeistRegistry.get_def(h).objectives:
			ids.append(StringName(id))
		assert_true(ids.size() >= 6, "%s objectives: %s" % [h, ids])
		# Each objective alone as the HUD's current step, then all of them on the Tab sheet.
		for id: StringName in ids:
			var one: Array[Dictionary] = [_objective(h, id)]
			model.objectives = one
			# The line shows the new step after the previous one's "Objective complete" beat.
			var want: String = UiText.t(StringName(one[0]["text_key"]), one[0]["args"] as Dictionary)
			var shown: Array[String] = []
			for i: int in 600:
				await wait_frames(1)
				shown = _texts(hud.objectives)
				if shown.any(func(t: String) -> bool: return t.contains(want.left(24))):
					break
			assert_true(shown.any(func(t: String) -> bool: return t.contains(want.left(24))),
					"%s hud %s shows '%s' (got %s)" % [h, id, want, shown])
			_check_all("%s hud %s" % [h, id], _texts(hud))
		var all: Array[Dictionary] = []
		for id: StringName in ids:
			all.append(_objective(h, id))
		model.objectives = all
		hud.scoreboard.set_process(false)
		hud.scoreboard.set_shown(true)
		await wait_frames(2)
		var sheet: Array[String] = _texts(hud.scoreboard)
		assert_true(sheet.size() >= 8, "%s Tab sheet has text (%d)" % [h, sheet.size()])
		_check_all("%s tab sheet" % h, sheet)
		hud.scoreboard.set_shown(false)
		await wait_frames(1)
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)


func test_payday_with_every_heist_achievement() -> void:
	for h: StringName in _heists():
		var ids: Array[StringName] = []
		for a: AchievementDef in Achievements.all():
			if a.category == h:
				ids.append(a.id)
		assert_true(ids.size() >= 5, "%s achievements: %s" % [h, ids])
		var pd: PaydayScreen = PAYDAY.instantiate() as PaydayScreen
		pd.cards_enabled = false
		pd.apply_to_profile = false
		add_child(pd)
		await wait_frames(1)
		pd.setup(PlayerProfile.new_default())
		var r: Dictionary = HeistCatalog.sample_result()
		r["success"] = true
		r["heist_id"] = h
		pd.show_result(r)
		pd.achievements_unlocked = ids
		pd.call(&"_render")
		await wait_frames(3)
		var texts: Array[String] = _texts(pd)
		var nm: String = _name(h)
		assert_true(texts.any(func(t: String) -> bool: return t.contains(nm)), "%s: the payday names the job" % h)
		_check_all("%s payday" % h, texts)
		pd.queue_free()
		await wait_frames(1)


func test_achievements_screen() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var heists: Array[StringName] = _heists()
	for a: AchievementDef in Achievements.all():
		if heists.has(a.category):
			p.achievements[a.id] = {"progress": Achievements.target_of(a), "unlocked": true}
	var s: AchievementsScreen = ACHIEVEMENTS.instantiate() as AchievementsScreen
	s.setup(p)
	add_child(s)
	await wait_frames(2)
	var texts: Array[String] = _texts(s)
	for a: AchievementDef in Achievements.all():
		if heists.has(a.category):
			assert_true(texts.has(UiText.t(a.name_key)), "%s listed by name" % a.id)
	_check_all("achievements", texts)
	s.queue_free()
	await wait_frames(1)


## The checker itself flags what the walk is for.
func test_checker_flags_raw_text() -> void:
	assert_ne(_problem("Find objective.ostrander_federal.keycard"), "", "raw objective key")
	assert_ne(_problem("asset.intel_code_pc"), "", "raw asset id")
	assert_ne(_problem("Secure {count}/{total}"), "", "unfilled placeholder")
	assert_ne(_problem("[loud] Drill"), "", "dev tag")
	assert_eq(_problem("Secure four bags (2/4)"), "", "plain text passes")


## An ACTIVE objective as the missions add it (text key objective.<heist>.<id>), its {args} filled with samples.
func _objective(h: StringName, id: StringName) -> Dictionary:
	var key: StringName = StringName("objective.%s.%s" % [h, id])
	var args: Dictionary = {}
	for m: RegExMatch in _arg_rx.search_all(UiText.t(key)):
		args[m.get_string(1)] = ARG_SAMPLES.get(m.get_string(1), 2)
	return {"id": id, "text_key": key, "args": args, "state": Enums.ObjectiveState.ACTIVE}


## Every visible Label / Button / RichTextLabel text under `root`.
func _texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if not c.is_visible_in_tree():
			continue
		var t: String = ""
		if c is Label:
			t = (c as Label).text
		elif c is Button:
			t = (c as Button).text
		elif c is RichTextLabel:
			t = (c as RichTextLabel).get_parsed_text()
		if t.strip_edges() != "":
			out.append(t)
	return out


func _check_all(where: String, texts: Array[String]) -> void:
	for t: String in texts:
		var why: String = _problem(t)
		assert_eq(why, "", "%s: '%s' %s" % [where, t.replace("\n", " / "), why])


func _problem(t: String) -> String:
	var m: RegExMatch = _raw_key_rx.search(t)
	if m != null:
		return "raw key %s" % m.get_string()
	if t.contains("{") or t.contains("}"):
		return "unfilled placeholder"
	if _gate_rx.search(t) != null:
		return "gate tag"
	for b: String in BANNED:
		if t.contains(b):
			return "dev tag %s" % b
	return ""
