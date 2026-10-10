## B4-03: Skills / Perk Deck are reachable from the loadout screen and return to it; their changes
## persist and reach LoadoutResolver, so the loadout screen's concealment / DR follows Deep Pockets
## aced and the Low Profile card.
extends TestCase

const TEST_ROOT: String = "user://test_profiles"
const LIGHT_STEP: StringName = &"skill.slipstream.light_step"
const DEEP_POCKETS: StringName = &"skill.slipstream.deep_pockets"
const BULK: StringName = &"perk.bulk"

var _flow: MenuFlow


func before_all() -> void:
	SaveService.root_dir = TEST_ROOT


func before_each() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 100
	p.xp = 20000 * ProgressionUiTweak.load_default().xp_per_perk_point
	SaveService.save_profile(p, 0)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(1)
	_flow.main_menu.play_button.pressed.emit()
	_flow.heist_select.next_button.pressed.emit()
	await wait_frames(1)


func after_each() -> void:
	_flow.queue_free()
	await wait_frames(1)


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_skills_round_trip_changes_concealment() -> void:
	var ls: LoadoutScreen = _flow.loadout_screen
	assert_eq(_flow.current, ls as Control)
	var before: int = ls.concealment_total
	ls.skills_button.pressed.emit()
	await wait_frames(1)
	var sk: SkillTreeScreen = _flow.progression_screen as SkillTreeScreen
	assert_true(sk != null, "skill screen open")
	assert_eq(_flow.current, sk as Control)
	sk.show_tree(&"shade")
	for sid: StringName in [LIGHT_STEP, DEEP_POCKETS, DEEP_POCKETS]:
		assert_true(bool(sk.buy(sid)["ok"]), "buy %s" % sid)
	sk.back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(_flow.current, ls as Control, "back returns to the loadout")
	assert_true(_flow.progression_screen == null)
	assert_eq(ls.concealment_total, before + 2 + 4, "Deep Pockets: +2 melee, +4 armor (aced)")
	assert_eq(ls.detection_risk, LoadoutResolver.resolve(ls.current_loadout()).detection_risk)
	assert_eq(ls.detection_risk_label.text, UiText.t(&"ui.common.percent", {"value": ls.detection_risk}))
	assert_eq(int(SaveService.load_profile(0).loadout.skills[DEEP_POCKETS]), 2, "persisted")


func test_perk_deck_low_profile_changes_concealment() -> void:
	var ls: LoadoutScreen = _flow.loadout_screen
	var before: int = ls.concealment_total
	ls.perks_button.pressed.emit()
	await wait_frames(1)
	var pk: PerkDeckScreen = _flow.progression_screen as PerkDeckScreen
	assert_true(pk != null, "perk screen open")
	pk.equip(BULK)
	for i: int in range(4):
		assert_true(bool(pk.unlock_next(BULK)["ok"]))
	pk.back_requested.emit()
	await wait_frames(1)
	assert_eq(_flow.current, ls as Control)
	assert_eq(ls.current_loadout().perk_deck, BULK)
	assert_eq(ls.current_loadout().perk_deck_cards, 4)
	assert_eq(ls.concealment_total, before + 1, "Low Profile (card 4): +1 concealment")
	assert_eq(ls.detection_risk, LoadoutResolver.resolve(ls.current_loadout()).detection_risk)
	ls.save()
	var q: PlayerProfile = SaveService.load_profile(0)
	assert_eq(q.loadout.perk_deck, BULK)
	assert_eq(q.loadout.perk_deck_cards, 4)


func test_widget_choices_survive_the_detour() -> void:
	var ls: LoadoutScreen = _flow.loadout_screen
	assert_true(ls.select_armor(&"armor.patrol_vest"))
	ls.skills_button.pressed.emit()
	await wait_frames(1)
	_flow.progression_screen.back_requested.emit()
	await wait_frames(1)
	assert_eq(ls.current_loadout().armor, &"armor.patrol_vest")
	assert_eq(SaveService.load_profile(0).loadout.armor, &"armor.patrol_vest")
