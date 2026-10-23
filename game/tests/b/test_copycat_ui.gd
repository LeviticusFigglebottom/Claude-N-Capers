## D-164 Copycat push 2: the perk deck screen shows each Understudy choice card's picked bonus and the mimic card's
## copied deck; pressing a card (accept / click) cycles the pick, which lands in the saved Loadout and the resolver.
extends TestCase

const SLOT: int = 6
const DECK: StringName = &"perk.understudy"

var _screen: PerkDeckScreen


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


func _make() -> PerkDeckScreen:
	var p: PlayerProfile = PlayerProfile.new_default()
	_screen = (load("res://content/ui/progression/perk_deck_screen.tscn") as PackedScene).instantiate() as PerkDeckScreen
	_screen.profile_slot = SLOT
	_screen.setup(p)
	add_child(_screen)
	await wait_frames(1)
	_screen.preview(DECK)
	return _screen


func test_choice_cards_show_and_cycle_their_bonus() -> void:
	var s: PerkDeckScreen = await _make()
	for i: int in [0, 2, 4, 6]:
		assert_true(s.card_choosable(i) and s.card_choice_labels[i].visible, "card %d has a pick" % (i + 1))
	for i: int in [1, 3, 5, 7]:
		assert_false(s.card_choosable(i) or s.card_choice_labels[i].visible, "shared card %d has none" % (i + 1))
	assert_true(s.card_choice_labels[0].text.contains(UiText.t(&"perk.understudy.choice.health.name")), "default: health")
	s.cycle_choice(0)
	assert_eq(int(s.profile.loadout.perk_choices[0]), 1)
	assert_true(s.card_choice_labels[0].text.contains(UiText.t(&"perk.understudy.choice.armor.name")))
	for _k: int in range(3):
		s.cycle_choice(0)
	assert_eq(int(s.profile.loadout.perk_choices[0]), 0, "wraps after the 4th option")
	# The pad's accept on a focused card cycles it too.
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	s.card_panels[2].gui_input.emit(ev)
	assert_eq(int(s.profile.loadout.perk_choices[2]), 1, "accept on card 3")
	var saved: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(int(saved.loadout.perk_choices.get(2, -1)), 1, "saved")


func test_mimic_card_cycles_mimicable_decks_only() -> void:
	var s: PerkDeckScreen = await _make()
	assert_true(s.card_choosable(8))
	assert_eq(s.card_choice_labels[8].text, UiText.t(&"ui.perks.mimic_none"), "nothing copied yet")
	var opts: Array[StringName] = s.mimic_options(DECK)
	assert_eq(opts.size(), 15, "the 15 mimicable decks")
	for bad: StringName in [&"perk.hacker", &"perk.overlord", DECK]:
		assert_false(opts.has(bad), "%s is not offered" % bad)
	s.cycle_choice(8)
	assert_eq(s.profile.loadout.perk_mimic_deck, opts[0])
	assert_true(s.card_choice_labels[8].text.contains(UiText.t(StringName("%s.mimic.desc" % opts[0]))))
	s.cycle_choice(8)
	assert_eq(s.profile.loadout.perk_mimic_deck, opts[1])
	# Equipped with 9 cards, the copied card reaches the modifiers.
	s.profile.loadout.perk_deck = DECK
	s.profile.loadout.perk_deck_cards = 9
	s.profile.loadout.perk_mimic_deck = &"perk.hustler"
	var m: Dictionary = LoadoutResolver.resolve_modifiers(s.profile.loadout)
	assert_near(float(m.get(&"defense.armor_regen_delay_mult", 1.0)), 0.9, 0.0001, "Hustler's card 9 copied")


func test_plain_decks_have_no_picks() -> void:
	var s: PerkDeckScreen = await _make()
	s.preview(&"perk.bulk")
	for i: int in range(9):
		assert_false(s.card_choosable(i) or s.card_choice_labels[i].visible)
	s.cycle_choice(0)
	assert_true(s.profile.loadout.perk_choices.is_empty(), "no pick on a plain deck")


## LEAD r292 queue (2): the loadout screen's perk line names the deck and, for Understudy, the picks and the copy.
func test_loadout_summary_line() -> void:
	var l: Loadout = Loadout.new()
	assert_eq(PerkProgress.summary_text(l), UiText.t(&"ui.loadout.perk_none"))
	l.perk_deck = &"perk.bulk"
	l.perk_deck_cards = 9
	var plain: String = PerkProgress.summary_text(l)
	assert_true(plain.contains(UiText.t(&"perk.bulk.name")) and not plain.contains("·"), plain)
	l.perk_deck = DECK
	l.perk_choices = {0: 1, 6: 3}
	var none: String = PerkProgress.summary_text(l)
	assert_true(none.contains(UiText.t(&"ui.loadout.perk_copies_none")), none)
	l.perk_mimic_deck = &"perk.frenzy"
	var text: String = PerkProgress.summary_text(l)
	for want: String in [UiText.t(&"perk.understudy.choice.armor.name"), UiText.t(&"perk.understudy.choice.health.name"),
			UiText.t(&"perk.understudy.choice.speed.name"), UiText.t(&"perk.frenzy.name")]:
		assert_true(text.contains(want), "%s in %s" % [want, text])
	# On the real loadout screen (armory station).
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.loadout = l
	SaveService.save_profile(p, 0)
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(flow)
	await wait_frames(4)
	flow.show_hub()
	flow.open_station(&"armory")
	await wait_frames(4)
	var label: Label = flow.loadout_screen.perk_summary_label
	assert_true(label != null and label.visible and label.text.contains(UiText.t(&"perk.frenzy.name")),
			"loadout screen: %s" % (label.text if label != null else "<none>"))
	flow.queue_free()
	await wait_frames(2)
	SaveService.delete_profile(0)
