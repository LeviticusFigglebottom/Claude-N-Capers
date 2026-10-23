## B4-03: perk deck screen. 14 decks x 9 cards, perk points from XP (PerkProgress), unlock in order,
## equip writes Loadout.perk_deck + perk_deck_cards, dev unlock flag, save round trip.
extends TestCase

const SLOT: int = 6
const BULK: StringName = &"perk.bulk"
const IRONCLAD: StringName = &"perk.ironclad"

var _screen: PerkDeckScreen
var _tw: ProgressionUiTweak


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	_tw = ProgressionUiTweak.load_default()


func after_each() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		await wait_frames(1)
	_screen = null
	SaveService.delete_profile(SLOT)


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _make(xp: int) -> PerkDeckScreen:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.xp = xp
	_screen = (load("res://content/ui/progression/perk_deck_screen.tscn") as PackedScene).instantiate() as PerkDeckScreen
	_screen.profile_slot = SLOT
	_screen.setup(p)
	add_child(_screen)
	await wait_frames(1)
	return _screen


func _points_for(cards: int, deck_id: StringName) -> int:
	var d: PerkDeckDef = PerkProgress.deck(deck_id)
	var total: int = 0
	for i: int in range(cards):
		total += int(d.cards[i]["cost"])
	return total


func test_lists_14_decks_and_9_cards() -> void:
	var s: PerkDeckScreen = await _make(0)
	assert_eq(s.deck_buttons.size(), 21)
	assert_eq(PerkProgress.decks(_tw)[0].id, _tw.deck_order[0], "data order")
	s.preview(BULK)
	var visible: int = 0
	for p: PanelContainer in s.card_panels:
		visible += 1 if p.visible else 0
	assert_eq(visible, 9)
	assert_eq(s.card_name_labels[0].text, UiText.t(&"perk.bulk.card1.name"))
	assert_eq(s.card_name_labels[3].text, UiText.t(&"perk.shared.card4.name"), "shared card 4 (Low Profile)")
	assert_true(s.card_desc_labels[8].text.contains(UiText.t(&"perk.shared.completion.desc")))
	assert_eq(s.card_state_labels[0].text, UiText.t(&"ui.perks.state.next"))
	assert_eq(s.card_state_labels[1].text, UiText.t(&"ui.perks.state.locked"))


func test_equip_writes_loadout_and_saves() -> void:
	var s: PerkDeckScreen = await _make(0)
	(s.deck_buttons[IRONCLAD] as Button).pressed.emit()
	assert_eq(s.profile.loadout.perk_deck, IRONCLAD)
	assert_eq(s.profile.loadout.perk_deck_cards, 0)
	assert_true(s.equip_button.disabled, "already equipped")
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.loadout.perk_deck, IRONCLAD)


func test_perk_points_and_unlock_order() -> void:
	var cost3: int = _points_for(3, BULK)
	var s: PerkDeckScreen = await _make(cost3 * _tw.xp_per_perk_point)
	assert_eq(PerkProgress.earned(s.profile, _tw), cost3)
	s.preview(BULK)
	for i: int in range(3):
		assert_true(bool(s.unlock_next(BULK)["ok"]), "card %d" % (i + 1))
	assert_eq(PerkProgress.available(s.profile, _tw), 0)
	var r: Dictionary = s.unlock_next(BULK)
	assert_false(bool(r["ok"]))
	assert_eq(StringName(r["reason"]), PerkProgress.REASON_POINTS)
	assert_eq(int(r["index"]), 4, "cards unlock in order")
	assert_true(s.unlock_button.disabled)
	assert_ne(s.reason_label.text, "")
	assert_eq(s.profile.loadout.perk_deck_cards, 0, "not equipped yet")
	s.equip(BULK)
	assert_eq(s.profile.loadout.perk_deck_cards, 3, "equip carries the deck's progress")
	assert_eq(s.card_state_labels[2].text, UiText.t(&"ui.perks.state.unlocked"))
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(int(q.perk_cards[BULK]), 3)
	assert_eq(q.loadout.perk_deck_cards, 3)
	# Another deck keeps its own (empty) progress; switching back restores 3.
	s.equip(IRONCLAD)
	assert_eq(s.profile.loadout.perk_deck_cards, 0)
	s.equip(BULK)
	assert_eq(s.profile.loadout.perk_deck_cards, 3)


func test_unlocking_the_equipped_deck_updates_loadout() -> void:
	var s: PerkDeckScreen = await _make(_points_for(9, BULK) * _tw.xp_per_perk_point)
	s.equip(BULK)
	for i: int in range(9):
		assert_true(bool(s.unlock_next(BULK)["ok"]))
		assert_eq(s.profile.loadout.perk_deck_cards, i + 1)
	assert_eq(StringName(s.unlock_next(BULK)["reason"]), PerkProgress.REASON_ALL)
	assert_eq(s.unlock_button.text, UiText.t(&"ui.perks.all_unlocked"))
	assert_near(float(LoadoutResolver.resolve_modifiers(s.profile.loadout).get(&"defense.health_mult", 1.0)), 2.0, 0.0001,
			"full Bulk deck resolves")


func test_dev_flag_unlocks_everything() -> void:
	var tw: ProgressionUiTweak = ProgressionUiTweak.new()
	tw.dev_unlock_all_perks = true
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(PerkProgress.cards_unlocked(p, BULK, tw), 9)
	assert_true(PerkProgress.equip(p, BULK, tw))
	assert_eq(p.loadout.perk_deck_cards, 9)
	assert_eq(StringName(PerkProgress.can_unlock_next(p, BULK, tw)["reason"]), PerkProgress.REASON_ALL)


func test_keys_exist() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for st: String in ["unlocked", "next", "locked"]:
		assert_has(table, "ui.perks.state.%s" % st)
	assert_has(table, "ui.perks.reason.%s" % PerkProgress.REASON_POINTS)
	for d: PerkDeckDef in PerkProgress.decks(_tw):
		assert_has(table, "%s.name" % d.id)
		assert_has(table, d.description)
		for c: Dictionary in d.cards:
			assert_has(table, String(c["name"]))
			assert_has(table, String(c["desc"]))
