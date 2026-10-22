## B4-03: skill tree screen. Tier gates and budget (level 100 / level 5), aced needs basic, refund
## rule (blocked when a higher tier depends on the points), free respec, skill sets, save round trip,
## focus grid, and every state/reason string.
extends TestCase

const SLOT: int = 5
const T1: StringName = &"skill.field_medic.triage"
## A skill whose every key still waits for a hook (SkillTreeDef.blocked_on_keys).
const BLOCKED: StringName = &"skill.breacher.hot_floor"
const T2: StringName = &"skill.field_medic.bedside_manner"
const T2B: StringName = &"skill.field_medic.numbing_agent"
const T3: StringName = &"skill.field_medic.field_kit"
const T4: StringName = &"skill.field_medic.rally_cry"

var _screen: SkillTreeScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_each() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		await wait_frames(1)
	_screen = null
	SaveService.delete_profile(SLOT)


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _make(level: int) -> SkillTreeScreen:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = level
	_screen = (load("res://content/ui/progression/skill_tree_screen.tscn") as PackedScene).instantiate() as SkillTreeScreen
	_screen.profile_slot = SLOT
	_screen.setup(p)
	add_child(_screen)
	await wait_frames(1)
	return _screen


func test_screen_builds_every_tree() -> void:
	var s: SkillTreeScreen = await _make(100)
	assert_eq(s.tree_tabs.size(), 5)
	for tree: StringName in SkillPoints.tree_def().trees:
		s.show_tree(tree)
		assert_eq(s.current_tree, tree)
		assert_eq(s.skill_buttons.size(), 18, "3 subtrees x 6 skills in %s" % tree)
		assert_eq(s.subtree_spent_labels.size(), 3)
		for sid: Variant in s.skill_buttons:
			var text: String = (s.skill_buttons[sid] as Button).text
			assert_false(text.contains("%s.name" % sid), "name resolved for %s" % sid)
	assert_eq(s.set_buttons.size(), ProgressionUiTweak.load_default().skill_set_count)
	assert_eq(s.points_label.text, UiText.t(&"ui.skills.points_left", {"points": 120, "total": 120}))


func test_tier_gates_at_level_100() -> void:
	var s: SkillTreeScreen = await _make(100)
	var sk: Dictionary = s.profile.loadout.skills
	assert_eq(SkillBuild.state_of(sk, T2, 100), SkillBuild.STATE_LOCKED)
	var r: Dictionary = s.buy(T2)
	assert_false(bool(r["ok"]))
	assert_eq(StringName(r["reason"]), SkillPoints.REASON_TIER)
	assert_eq(s.selected_skill, T2)
	assert_true(s.buy_button.disabled, "buy disabled while tier-locked")
	assert_eq(s.detail_reason.text, UiText.t(&"ui.skills.reason.tier_locked", r))
	assert_true(bool(s.buy(T1)["ok"]))
	assert_eq(SkillBuild.state_of(sk, T2, 100), SkillBuild.STATE_AVAILABLE, "tier 2 opens after 1 point")
	assert_eq(SkillBuild.state_of(sk, T3, 100), SkillBuild.STATE_LOCKED)
	assert_true(bool(s.buy(T2)["ok"]))
	assert_eq(SkillBuild.state_of(sk, T3, 100), SkillBuild.STATE_AVAILABLE, "tier 3 opens at 3")
	assert_eq(StringName(s.buy(T4)["reason"]), SkillPoints.REASON_TIER, "tier 4 needs 18")
	for sid: StringName in [T1, T2, T2B, T3]:
		s.buy(sid)
		s.buy(sid)
	assert_eq(SkillPoints.spent_in_subtree(sk, &"field_medic", 4), 4 + 6 + 6 + 9)
	assert_true(bool(s.buy(T4)["ok"]))
	assert_eq(s.available_points(), 120 - SkillPoints.spent_total(sk))
	assert_true(SkillPoints.is_legal(sk, 120))


func test_budget_at_level_5() -> void:
	var s: SkillTreeScreen = await _make(5)
	assert_eq(s.available_points(), 5)
	assert_true(bool(s.buy(T1)["ok"]))
	assert_true(bool(s.buy(T1)["ok"]), "ace: 3 more points")
	assert_eq(s.available_points(), 1)
	var r: Dictionary = s.buy(T2)
	assert_false(bool(r["ok"]))
	assert_eq(StringName(r["reason"]), SkillPoints.REASON_POINTS)
	assert_false(s.profile.loadout.skills.has(T2))
	assert_eq(s.points_label.text, UiText.t(&"ui.skills.points_left", {"points": 1, "total": 5}))
	assert_eq(s.detail_reason.text, UiText.t(&"ui.skills.reason.not_enough_points", r))


func test_aced_requires_basic() -> void:
	var s: SkillTreeScreen = await _make(100)
	var sk: Dictionary = s.profile.loadout.skills
	s.select_skill(T1)
	assert_eq(s.buy_button.text, UiText.t(&"ui.skills.buy_basic", {"cost": 1}), "first step is basic")
	s.buy(T1)
	assert_eq(int(sk[T1]), SkillPoints.BASIC, "one press buys basic, never aced directly")
	assert_eq(SkillBuild.state_of(sk, T1, 100), SkillBuild.STATE_BASIC)
	assert_eq(s.buy_button.text, UiText.t(&"ui.skills.buy_aced", {"cost": 3}))
	s.buy(T1)
	assert_eq(int(sk[T1]), SkillPoints.ACED)
	assert_eq(StringName(s.buy(T1)["reason"]), SkillPoints.REASON_ACED)
	assert_true(s.buy_button.disabled)


func test_refund_blocked_when_higher_tier_depends() -> void:
	var s: SkillTreeScreen = await _make(100)
	var sk: Dictionary = s.profile.loadout.skills
	s.buy(T1)
	s.buy(T2)
	var r: Dictionary = s.refund(T1)
	assert_false(bool(r["ok"]))
	assert_eq(StringName(r["reason"]), SkillBuild.REASON_REFUND_TIER)
	assert_true(sk.has(T1), "nothing removed")
	assert_true(s.refund_button.disabled)
	assert_eq(s.detail_reason.text, UiText.t(&"ui.skills.reason.refund_breaks_tier"))
	assert_true(bool(s.refund(T2)["ok"]), "the dependent skill goes first")
	assert_true(bool(s.refund(T1)["ok"]))
	assert_eq(sk.size(), 0)
	assert_eq(StringName(s.refund(T1)["reason"]), SkillBuild.REASON_NOT_OWNED)


func test_refund_aced_steps_down_to_basic() -> void:
	var s: SkillTreeScreen = await _make(100)
	var sk: Dictionary = s.profile.loadout.skills
	s.buy(T1)
	s.buy(T1)
	s.buy(T2)
	var r: Dictionary = s.refund(T1)
	assert_true(bool(r["ok"]), "basic still holds tier 2's 1-point gate")
	assert_eq(int(r["refund"]), 3)
	assert_eq(int(sk[T1]), SkillPoints.BASIC)
	assert_eq(s.available_points(), 120 - 1 - 2)
	assert_true(SkillPoints.is_legal(sk, 120))


func test_respec_returns_all_points_and_saves() -> void:
	var s: SkillTreeScreen = await _make(100)
	for sid: StringName in [T1, T1, T2, T2B]:
		s.buy(sid)
	assert_true(s.available_points() < 120)
	s.respec_button.pressed.emit()
	assert_eq(s.profile.loadout.skills.size(), 4 - 1, "first press only arms the reset")
	s.respec_button.pressed.emit()
	assert_eq(s.profile.loadout.skills.size(), 0)
	assert_eq(s.available_points(), 120)
	assert_eq(SaveService.load_profile(SLOT).loadout.skills.size(), 0, "saved")


func test_save_round_trip() -> void:
	var s: SkillTreeScreen = await _make(100)
	s.buy(T1)
	s.buy(T1)
	s.buy(T2)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(int(q.loadout.skills[T1]), 2)
	assert_eq(int(q.loadout.skills[T2]), 1)
	assert_eq(q.level, 100)


func test_skill_sets_are_independent() -> void:
	var s: SkillTreeScreen = await _make(100)
	s.buy(T1)
	s.set_buttons[1].pressed.emit()
	assert_eq(s.profile.active_skill_set, 1)
	assert_eq(s.profile.loadout.skills.size(), 0, "set 2 starts empty")
	assert_eq(s.available_points(), 120)
	s.show_tree(&"shade")
	s.buy(&"skill.slipstream.light_step")
	s.select_skill_set(0)
	assert_true(s.profile.loadout.skills.has(T1))
	assert_false(s.profile.loadout.skills.has(&"skill.slipstream.light_step"))
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.active_skill_set, 0)
	assert_true(q.skill_set(1).has(&"skill.slipstream.light_step"))


func test_blocked_note_and_team_tag() -> void:
	var s: SkillTreeScreen = await _make(100)
	# Hot Floor's keys wait for ENV A's hooks (unhooked_skill_keys.md batch 5); Triage's landed (batch 3, LEAD r285).
	s.show_tree(&"wrench")
	s.select_skill(BLOCKED)
	assert_true(s.detail_basic_note.visible and s.detail_aced_note.visible, "Hot Floor's parts say they are not active yet")
	assert_eq(SkillBuild.activity(ContentDB.by_id(ContentDB.SKILLS, BLOCKED) as SkillDef), &"inactive")
	assert_true((s.skill_buttons[BLOCKED] as Button).text.ends_with(UiText.t(&"ui.skills.button_inactive")),
			"the tree button says so too")
	s.show_tree(&"ringleader")
	s.select_skill(T1)
	assert_eq(SkillBuild.activity(ContentDB.by_id(ContentDB.SKILLS, T1) as SkillDef), &"active", "Triage is hooked now")
	assert_false(s.detail_basic_note.visible, "Triage shows no waiting note")
	s.show_tree(&"shade")
	s.select_skill(&"skill.slipstream.deep_pockets")
	assert_false(s.detail_basic_note.visible, "Deep Pockets is fully active")
	assert_false(s.detail_team.visible)
	s.show_tree(&"ringleader")
	s.select_skill(&"skill.persuader.zip_and_tie")
	assert_true(s.detail_team.visible, "Zip & Tie aced is crew-wide")


func test_focus_grid_neighbours() -> void:
	var s: SkillTreeScreen = await _make(100)
	await wait_frames(1)
	var tier4: Button = s.skill_buttons[T4] as Button
	assert_eq(tier4.get_node(tier4.focus_neighbor_top), s.tree_tabs[&"ringleader"] as Node, "top row -> tabs")
	var t1: Button = s.skill_buttons[T1] as Button
	assert_eq(t1.get_node(t1.focus_neighbor_bottom), s.back_button as Node, "bottom row -> Back")
	assert_eq(t1.get_node(t1.focus_neighbor_top), s.skill_buttons[T2] as Node, "tier 1 -> tier 2 above")
	var right_t4: Button = s.skill_buttons[&"skill.marksman.grazing_fire"] as Button
	assert_eq(right_t4.get_node(right_t4.focus_neighbor_right), s.buy_button as Node, "right edge -> details")
	var t2b: Button = s.skill_buttons[T2B] as Button
	assert_eq(t2b.get_node(t2b.focus_neighbor_left), s.skill_buttons[T2] as Node)
	assert_eq(t2b.get_node(t2b.focus_neighbor_right), s.skill_buttons[&"skill.persuader.silver_tongue"] as Node)
	assert_true(s.skill_buttons[T1].has_focus() or s.get_viewport().gui_get_focus_owner() != null, "something focused")


func test_state_and_reason_keys_exist() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for st: StringName in [SkillBuild.STATE_LOCKED, SkillBuild.STATE_AVAILABLE, SkillBuild.STATE_BASIC, SkillBuild.STATE_ACED]:
		assert_has(table, "ui.skills.state.%s" % st)
	for r: StringName in [SkillPoints.REASON_UNKNOWN, SkillPoints.REASON_ACED, SkillPoints.REASON_TIER,
			SkillPoints.REASON_POINTS, SkillBuild.REASON_NOT_OWNED, SkillBuild.REASON_REFUND_TIER]:
		assert_has(table, "ui.skills.reason.%s" % r)
	for tree: StringName in SkillPoints.tree_def().trees:
		assert_has(table, "ui.skills.tree.%s" % tree)
		for sub: StringName in SkillPoints.tree_def().subtree_ids(tree):
			assert_has(table, "ui.skills.subtree.%s" % sub)
