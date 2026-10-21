## LEAD r262 OF done check: a headless walk of every Ostrander Federal screen the player reads (the Board's broker
## and contract cards, the briefing per
## difficulty, the pre-planning board on every point and the crew assets, the HUD objective line and the Tab sheet
## with every OF objective and the data the mission passes, the payday with every OF achievement, the achievements
## screen). Every visible text must carry no raw key ("objective.x", "ui.y", "asset.z"), no {placeholder}, no dev tag,
## and no blank where a string is expected. test_heist_text_audit checks the same strings as data; this checks
## what the screens actually show.
extends TestCase

const OF: StringName = &"ostrander_federal"
const BOARD: PackedScene = preload("res://content/ui/board/board_screen.tscn")
const BRIEFING: PackedScene = preload("res://content/ui/briefing/briefing_screen.tscn")
const PREPLAN: PackedScene = preload("res://content/ui/preplanning/preplanning_screen.tscn")
const HUD: PackedScene = preload("res://content/ui/hud/hud.tscn")
const PAYDAY: PackedScene = preload("res://content/ui/results/payday.tscn")
const ACHIEVEMENTS: PackedScene = preload("res://content/ui/achievements/achievements_screen.tscn")
const BANNED: Array[String] = ["[loud]", "[stealth]", "TODO", "TBD", "PLACEHOLDER", "FIXME", "XXX"]
## The data each OF objective carries on the HUD (ostrander_federal_mission.gd _add / update_objective_data).
const OBJECTIVE_DATA: Dictionary = {
	&"drill_delivery": {"count": 1, "total": 3},
	&"secure": {"count": 2, "total": 4},
	&"time_lock_wait": {"seconds": 95.0, "method": &"code"},
	&"escape_wait": {"seconds": 60.0},
}

var _raw_key_rx: RegEx = RegEx.create_from_string(
		"\\b(objective|ui|vo|voice|heist|item|loot|asset|music|achievement|contact|unlock|perk|mask)\\.[a-z_]")
var _gate_rx: RegEx = RegEx.create_from_string("\\bG[0-9]\\b")


func test_briefing_on_every_difficulty() -> void:
	for d: int in range(6):
		var s: BriefingScreen = BRIEFING.instantiate() as BriefingScreen
		s.setup(OF, d)
		add_child(s)
		await wait_frames(2)
		var texts: Array[String] = _texts(s)
		texts.append_array(s.security_texts())
		texts.append_array(s.objective_texts())
		assert_true(texts.size() >= 10, "d%d briefing has text (%d)" % [d, texts.size()])
		_check_all("briefing d%d" % d, texts)
		s.queue_free()
		await wait_frames(1)


## The Board: the broker on OF at every difficulty, and every pin's contract card while OF is on the board.
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
	for d: int in range(6):
		s.broker_select(OF, d)
		await wait_frames(1)
		var texts: Array[String] = _texts(s)
		assert_true(texts.any(func(t: String) -> bool: return t.contains(UiText.t(&"heist.ostrander_federal.name"))),
				"d%d: the broker shows OF" % d)
		_check_all("board broker d%d" % d, texts)
	s.set_broker_open(false)
	for slot: int in range(12):
		s.select_slot(slot)
		await wait_frames(1)
		_check_all("board slot %d (%s)" % [slot, s.selected_contract().get("heist_id", "")], _texts(s))
	s.queue_free()
	await wait_frames(1)


func test_preplan_board_points_and_assets() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = 10000000
	var s: PreplanningScreen = PREPLAN.instantiate() as PreplanningScreen
	s.save_on_confirm = false
	s.setup(OF, Enums.Difficulty.HAZARDOUS, p)
	add_child(s)
	await wait_frames(2)
	_check_all("preplan board", _texts(s))
	var points: Dictionary = {}
	var assets: Dictionary = (HeistRegistry.get_def(OF).preplanning.get("assets", {}) as Dictionary)
	for a: Variant in assets:
		for pid: Variant in (assets[a] as Dictionary).get("point_ids", []):
			points[StringName(pid)] = true
	assert_true(points.size() >= 8, "OF points found: %s" % [points.keys()])
	for pid: StringName in points:
		s.show_point(pid)
		await wait_frames(1)
		_check_all("preplan point %s" % pid, _texts(s))
	s.show_crew_assets()
	await wait_frames(1)
	_check_all("preplan crew assets", _texts(s))
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
	var ids: Array[StringName] = []
	for id: Variant in HeistRegistry.get_def(OF).objectives:
		ids.append(StringName(id))
	assert_true(ids.size() >= 15, "OF objectives: %s" % [ids])
	# Each objective alone as the HUD's current step, then all of them on the Tab sheet.
	for id: StringName in ids:
		var one: Array[Dictionary] = [_objective(id)]
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
				"hud %s shows '%s' (got %s)" % [id, want, shown])
		_check_all("hud %s" % id, _texts(hud))
	var all: Array[Dictionary] = []
	for id: StringName in ids:
		all.append(_objective(id))
	model.objectives = all
	hud.scoreboard.set_process(false)
	hud.scoreboard.set_shown(true)
	await wait_frames(2)
	var sheet: Array[String] = _texts(hud.scoreboard)
	assert_true(sheet.size() >= 8, "Tab sheet has text (%d)" % sheet.size())
	_check_all("tab sheet", sheet)
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)


func test_payday_with_every_of_achievement() -> void:
	var ids: Array[StringName] = []
	for a: AchievementDef in Achievements.all():
		if a.category == OF:
			ids.append(a.id)
	assert_true(ids.size() >= 6, "OF achievements: %s" % [ids])
	var pd: PaydayScreen = PAYDAY.instantiate() as PaydayScreen
	pd.cards_enabled = false
	pd.apply_to_profile = false
	add_child(pd)
	await wait_frames(1)
	pd.setup(PlayerProfile.new_default())
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	r["heist_id"] = OF
	pd.show_result(r)
	pd.achievements_unlocked = ids
	pd.call(&"_render")
	await wait_frames(3)
	var texts: Array[String] = _texts(pd)
	assert_true(texts.has(UiText.t(&"heist.ostrander_federal.name")) or texts.any(
			func(t: String) -> bool: return t.contains(UiText.t(&"heist.ostrander_federal.name"))), "payday names OF")
	_check_all("payday", texts)
	pd.queue_free()
	await wait_frames(1)


func test_achievements_screen() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for a: AchievementDef in Achievements.all():
		if a.category == OF:
			p.achievements[a.id] = {"progress": Achievements.target_of(a), "unlocked": true}
	var s: AchievementsScreen = ACHIEVEMENTS.instantiate() as AchievementsScreen
	s.setup(p)
	add_child(s)
	await wait_frames(2)
	var texts: Array[String] = _texts(s)
	for a: AchievementDef in Achievements.all():
		if a.category == OF:
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


func _objective(id: StringName) -> Dictionary:
	return {"id": id, "text_key": StringName("objective.ostrander_federal.%s" % id),
		"args": (OBJECTIVE_DATA.get(id, {}) as Dictionary).duplicate(), "state": Enums.ObjectiveState.ACTIVE}


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
