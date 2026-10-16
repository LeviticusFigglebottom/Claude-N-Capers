## D-115 achievements in play: the payday's unlock toast (AchievementToast, queued, never over the pause
## menu / a blocker) and the payday's "Achievements unlocked" section (name, description, reward; hidden when
## the run unlocked nothing). Only the local profile shown by the payday is evaluated.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const FIRST: StringName = &"achievement.first_score"
const CATACLYSM: StringName = &"achievement.cataclysm_clear"

var _screen: PaydayScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	MouseCapture.pop_release(&"pause")
	_screen = _new_screen()
	add_child(_screen)
	await wait_frames(1)


func after_each() -> void:
	MouseCapture.pop_release(&"pause")
	_screen.queue_free()
	await wait_frames(1)


func _new_screen() -> PaydayScreen:
	var pd: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	pd.cards_enabled = false
	return pd


## A profile with every achievement already unlocked except `open`.
func _profile_except(open: Array[StringName]) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	for a: AchievementDef in Achievements.all():
		if not open.has(a.id):
			p.achievements[a.id] = {"progress": Achievements.target_of(a), "unlocked": true}
	return p


## A successful Cataclysm run: unlocks First Score and Cataclysm Clear on a profile that has neither.
func _cataclysm_win() -> Dictionary:
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	r["difficulty"] = 5
	return r


func _labels_text(root: Node) -> String:
	var parts: PackedStringArray = []
	for l: Node in root.find_children("*", "Label", true, false):
		if (l as Label).visible:
			parts.append((l as Label).text)
	return " | ".join(parts)


func test_two_unlocks_two_queued_toasts_and_two_entries() -> void:
	_screen.setup(_profile_except([FIRST, CATACLYSM]))
	_screen.show_result(_cataclysm_win())
	var got: Array[StringName] = _screen.achievements_unlocked
	assert_eq(got.size(), 2, "exactly the two open achievements unlock: %s" % [got])
	assert_has(got, FIRST)
	assert_has(got, CATACLYSM)
	# Section: two entries with name, description and (for Cataclysm Clear) the reward.
	assert_true(_screen.achievements_panel.visible, "section shown")
	assert_eq(_screen.achievement_rows.size(), 2)
	for id: StringName in got:
		var a: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, id) as AchievementDef
		var text: String = _labels_text(_screen.achievement_rows[id] as Node)
		assert_true(text.contains(UiText.t(a.name_key)), "name in the entry: " + text)
		assert_true(text.contains(UiText.t(a.desc_key)), "description in the entry: " + text)
	var cat: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, CATACLYSM) as AchievementDef
	var reward: String = AchievementsScreen.reward_name(cat)
	assert_ne(reward, "", "Cataclysm Clear grants a mask")
	assert_true(_labels_text(_screen.achievement_rows[CATACLYSM] as Node).contains(reward), "reward listed")
	assert_false(_labels_text(_screen.achievement_rows[FIRST] as Node).contains(UiText.t(&"ui.achievements.reward_caption")),
			"no reward line for an achievement that grants nothing")
	# Toasts: the first shows at once, the second waits, then follows; then the banner is gone.
	var t: AchievementToast = _screen.toast
	assert_true(t != null)
	assert_eq(t.current, got[0])
	assert_eq(t.queue, [got[1]] as Array[StringName], "second toast queued")
	assert_true(t.panel.visible)
	assert_eq(t.name_label.text, UiText.t((ContentDB.by_id(ContentDB.ACHIEVEMENTS, got[0]) as AchievementDef).name_key))
	t.tick(AchievementToast.SHOW_S + 0.01)
	assert_eq(t.current, got[1], "second toast after the first")
	assert_true(t.panel.visible)
	assert_eq(t.reward_label.visible, got[1] == CATACLYSM)
	if got[1] == CATACLYSM:
		assert_true(t.reward_label.text.contains(reward))
	t.tick(AchievementToast.SHOW_S + 0.01)
	assert_eq(t.current, &"")
	assert_false(t.panel.visible)
	assert_eq(t.shown_ids, got, "two toasts, in unlock order")


func test_no_unlocks_hides_section_and_shows_no_toast() -> void:
	_screen.setup(_profile_except([]))
	_screen.show_result(_cataclysm_win())
	assert_eq(_screen.achievements_unlocked.size(), 0)
	assert_true(_screen.achievements_panel != null)
	assert_false(_screen.achievements_panel.visible, "empty section hidden")
	assert_eq(_screen.achievement_rows.size(), 0)
	assert_eq(_screen.toast.current, &"")
	assert_eq(_screen.toast.shown_ids.size(), 0, "no toast")
	assert_false(_screen.toast.panel.visible)


func test_toast_draws_over_the_payday() -> void:
	_screen.setup(_profile_except([FIRST]))
	_screen.show_result(_cataclysm_win())
	var t: AchievementToast = _screen.toast
	assert_eq(t.get_parent(), _screen, "the payday owns the toast (the HUD is hidden at payday)")
	assert_true(t.z_index > 0, "drawn over the summary and the card stage")
	assert_eq(t.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never eats a click")
	assert_true(t.panel.visible)


func test_toast_never_over_pause_or_blocker_and_holds_its_time() -> void:
	_screen.setup(_profile_except([FIRST, CATACLYSM]))
	_screen.show_result(_cataclysm_win())
	var t: AchievementToast = _screen.toast
	var first: StringName = t.current
	MouseCapture.push_release(&"pause")
	t.tick(AchievementToast.SHOW_S * 3.0)
	assert_false(t.panel.visible, "hidden while the pause menu is up")
	assert_eq(t.current, first, "its time holds while hidden")
	MouseCapture.pop_release(&"pause")
	t.tick(0.01)
	assert_true(t.panel.visible, "back after the pause")
	var sheet: Control = Control.new()  # stands in for the HUD's Tab sheet
	add_child(sheet)
	t.blockers.append(sheet)
	t.tick(AchievementToast.SHOW_S * 3.0)
	assert_false(t.panel.visible, "hidden while a blocker (Tab sheet) shows")
	assert_eq(t.current, first)
	sheet.visible = false
	t.tick(AchievementToast.SHOW_S + 0.01)
	assert_eq(t.shown_ids.size(), 2, "queue resumes after the blocker")
	sheet.queue_free()


func test_new_result_clears_the_old_toasts() -> void:
	_screen.setup(_profile_except([FIRST, CATACLYSM]))
	_screen.show_result(_cataclysm_win())
	assert_ne(_screen.toast.current, &"")
	_screen.show_result(_cataclysm_win())  # same profile: nothing left to unlock
	assert_eq(_screen.toast.current, &"")
	assert_eq(_screen.toast.queue.size(), 0)
	assert_false(_screen.achievements_panel.visible)


func test_coop_only_the_local_profile_unlocks() -> void:
	# Two crew members see the same HeistResult; each payday evaluates only its own profile.
	var r: Dictionary = _cataclysm_win()
	assert_true((r.get("crew", []) as Array).size() > 1, "sample result has a crew")
	var veteran: PlayerProfile = _profile_except([CATACLYSM])  # already has First Score
	_screen.apply_to_profile = true
	_screen.setup(veteran)
	_screen.show_result(r)
	assert_eq(_screen.achievements_unlocked, [CATACLYSM] as Array[StringName], "only what this profile lacked")
	assert_eq(_screen.toast.shown_ids, [CATACLYSM] as Array[StringName])
	var other: PaydayScreen = _new_screen()  # the other player's machine: its own local profile (slot 1 here)
	other.profile_slot = 1
	add_child(other)
	await wait_frames(1)
	var rookie: PlayerProfile = _profile_except([FIRST, CATACLYSM])
	other.setup(rookie)
	other.show_result(r)
	assert_eq(other.achievements_unlocked.size(), 2, "the rookie unlocks both")
	assert_eq(other.toast.shown_ids.size(), 1, "its own first toast, the second queued")
	assert_eq(_screen.toast.shown_ids, [CATACLYSM] as Array[StringName], "the veteran's toasts are unchanged")
	assert_eq(_screen.achievement_rows.size(), 1)
	assert_true(Achievements.is_unlocked(SaveService.load_profile(1), FIRST), "saved to its own slot")
	other.queue_free()
	SaveService.delete_profile(1)
	await wait_frames(1)


func test_section_takes_gamepad_focus_only_past_one_line() -> void:
	_screen.setup(_profile_except([FIRST, CATACLYSM]))
	_screen.show_result(_cataclysm_win())
	assert_eq(_screen.achievements_panel.focus_mode, Control.FOCUS_NONE, "one line fits at 720p: not focusable")
	var many: Array[StringName] = []
	for a: AchievementDef in Achievements.all().slice(0, PaydayScreen.ACHIEVEMENT_COLUMNS + 1):
		many.append(a.id)
	_screen.achievements_unlocked = many
	_screen._render()
	assert_eq(_screen.achievement_rows.size(), many.size())
	var p: PanelContainer = _screen.achievements_panel
	assert_eq(p.focus_mode, Control.FOCUS_ALL, "two lines: d-pad can reach the section")
	assert_eq(_screen.continue_button.get_node(_screen.continue_button.focus_neighbor_top), p, "up from Continue")
	assert_eq(p.get_node(p.focus_neighbor_bottom), _screen.continue_button, "and back")


## r227: payday has no Back, so its hint strip offers only Select (the capture showed "Escape BACK").
func test_payday_hint_strip_has_no_back() -> void:
	var pairs: Array = PaydayScreen.new().control_hint_pairs()
	assert_eq(pairs.size(), 1)
	assert_eq(StringName(pairs[0][0]), &"ui_accept")
