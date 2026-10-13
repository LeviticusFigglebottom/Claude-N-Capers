## B1-04: the loadout screen shows LoadoutResolver's concealment / detection risk and updates them
## when a mod changes; it saves to the profile.
extends TestCase


var _screen: LoadoutScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	_screen = (load("res://content/ui/menus/loadout.tscn") as PackedScene).instantiate() as LoadoutScreen
	_screen.setup(PlayerProfile.new_default())
	add_child(_screen)
	await wait_frames(1)


func after_each() -> void:
	_screen.queue_free()
	await wait_frames(1)


func _expected_dr() -> int:
	return LoadoutResolver.resolve(_screen.current_loadout()).detection_risk


func test_detection_risk_follows_mod_change() -> void:
	assert_eq(_screen.detection_risk, _expected_dr())
	assert_eq(_screen.detection_risk_label.text, UiText.t(&"ui.common.percent", {"value": _expected_dr()}))
	var before: int = _screen.detection_risk
	assert_true(_screen.select_mod(Enums.ModType.SUPPRESSOR, &"mod.p9_suppressor"), "owned suppressor offered")
	assert_true(_screen.current_loadout().secondary_mods.has(&"mod.p9_suppressor"))
	assert_eq(_screen.detection_risk, _expected_dr())
	assert_eq(_screen.detection_risk_label.text, UiText.t(&"ui.common.percent", {"value": _expected_dr()}))
	assert_ne(_screen.detection_risk, before, "suppressor costs concealment, so DR changes")
	assert_true(_screen.select_mod(Enums.ModType.SUPPRESSOR, &""), "back to none")
	assert_eq(_screen.detection_risk, before)


func test_armor_changes_concealment() -> void:
	assert_true(_screen.select_armor(&"armor.patrol_vest"))
	var bd: Dictionary = LoadoutResolver.concealment_breakdown(_screen.current_loadout())
	assert_eq(_screen.concealment_total, int(bd["total"]))
	assert_eq(_screen.detection_risk, int(bd["detection_risk"]))


func test_mod_slots_follow_weapon_and_ownership() -> void:
	var w: WeaponDef = ContentDB.weapon(&"weapon.kestrel_p9")
	assert_eq(_screen.mod_options.size(), w.mod_slots.size(), "one row per mod slot")
	var sights: ItemSlot = _screen.mod_options[Enums.ModType.SIGHT] as ItemSlot
	assert_eq(sights.item_count, 2, "stock + owned reflex sight (iron sights are the stock part)")


func test_save_writes_loadout() -> void:
	_screen.select_mod(Enums.ModType.MAGAZINE, &"mod.p9_extended_mag")
	assert_eq(_screen.save(), OK)
	var p: PlayerProfile = SaveService.load_profile(0)
	assert_true(p.loadout.secondary_mods.has(&"mod.p9_extended_mag"))


## PO-4 (lead note 3): slot cards open an item grid; focusing a tile previews, picking equips.
func test_slot_card_picker_grid() -> void:
	var slot: ItemSlot = _screen.armor_option as ItemSlot
	assert_true(slot != null, "armor is a slot card")
	var before: int = _screen.detection_risk
	var pk: ItemPicker = slot.open_picker()
	await wait_frames(2)
	assert_eq(pk.tiles.size(), slot.item_count, "one tile per item")
	var target: int = -1
	for i: int in range(slot.item_count):
		if not slot.is_item_disabled(i) and StringName(slot.get_item_metadata(i)) == &"armor.patrol_vest":
			target = i
	assert_true(target >= 0, "patrol vest offered")
	pk.tiles[target].focus_entered.emit()
	assert_eq(_screen.detection_risk, before, "a preview does not change the loadout")
	pk.tiles[target].pressed.emit()
	await wait_frames(2)
	assert_eq(LoadoutScreen._selected_id(slot), &"armor.patrol_vest", "the pick equips")
	assert_false(is_instance_valid(pk), "the grid closes")
	var bd: Dictionary = LoadoutResolver.concealment_breakdown(_screen.current_loadout())
	assert_eq(_screen.detection_risk, int(bd["detection_risk"]), "refreshed after the pick")
