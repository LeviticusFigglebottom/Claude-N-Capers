## Armor bag gating (lead, D-056 follow-up): `deployable.armor_bag` needs `deploy.armor_bag` (shared perk
## card 6). DeployableGate rules + the loadout picker shows it locked until the loadout grants the flag.
extends TestCase

const BAG: StringName = &"deployable.armor_bag"

var _screen: LoadoutScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
	await wait_frames(1)


func _open(deck: StringName, cards: int, deployable: StringName) -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.loadout.perk_deck = deck
	p.loadout.perk_deck_cards = cards
	p.loadout.deployable = deployable
	_screen = (load("res://content/ui/menus/loadout.tscn") as PackedScene).instantiate() as LoadoutScreen
	_screen.setup(p)
	add_child(_screen)
	await wait_frames(1)


func _bag_index() -> int:
	for i: int in range(_screen.deployable_option.item_count):
		if StringName(_screen.deployable_option.get_item_metadata(i)) == BAG:
			return i
	return -1


func test_gate_rules() -> void:
	var def: DeployableDef = ContentDB.deployable(BAG)
	assert_true(def != null and def.kind == &"armor_bag", "armor bag def (A's kind)")
	assert_eq(DeployableGate.required_flag(BAG), &"deploy.armor_bag")
	assert_eq(DeployableGate.required_flag(&"deployable.doctor_bag"), &"", "doctor bag is free")
	assert_false(DeployableGate.allowed(BAG, {}))
	assert_true(DeployableGate.allowed(BAG, {&"deploy.armor_bag": true}))
	var l: Loadout = Loadout.new()
	l.perk_deck = &"perk.bulk"
	l.perk_deck_cards = 5
	assert_false(DeployableGate.allowed_for(l, BAG), "5 cards: no Go Bag yet")
	l.perk_deck_cards = 6
	assert_true(DeployableGate.allowed_for(l, BAG), "card 6 grants it in any deck")
	var card: Dictionary = DeployableGate.unlock_card(BAG)
	assert_eq(int(card["card"]), 6)
	assert_eq(card["name"], &"perk.shared.card6.name")


func test_picker_locks_without_the_card() -> void:
	await _open(&"perk.bulk", 5, BAG)
	var i: int = _bag_index()
	assert_true(i >= 0, "the armor bag is listed")
	assert_true(_screen.deployable_option.is_item_disabled(i), "locked without card 6")
	assert_true(_screen.deployable_option.get_item_text(i).contains(UiText.t(&"perk.shared.card6.name")),
			"the label names the unlocking card")
	assert_eq(_screen.current_loadout().deployable, &"", "a locked pick falls back to none")


func test_picker_offers_it_with_the_card() -> void:
	await _open(&"perk.bulk", 6, BAG)
	var i: int = _bag_index()
	assert_false(_screen.deployable_option.is_item_disabled(i), "unlocked by card 6")
	assert_eq(_screen.deployable_option.get_item_text(i), UiText.t(&"item.deployable.armor_bag.name"))
	assert_eq(_screen.current_loadout().deployable, BAG, "equipped")
