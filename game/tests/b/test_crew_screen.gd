## D-145.4 / PO-19: the Bot Crew screen (CrewScreen). Rows offer what CrewLoadouts allows, a pick saves at once, the
## chosen gun's owned mods get rows, the tabs switch bots, Reset clears a bot, the pad / keyboard chain reaches every
## control, and the hub's Bot Crew button opens it (Back returns).
extends TestCase

const SCENE: PackedScene = preload("res://content/ui/crew/crew_screen.tscn")
const SLOT: int = 0
const AR: StringName = &"weapon.corsair_ar"
const CAN: StringName = &"mod.corsair_suppressor"


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C\'s 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func before_each() -> void:
	SaveService.delete_profile(SLOT)


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _profile() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.owned_weapons = [AR, &"weapon.kestrel_p9"] as Array[StringName]
	p.owned_mods = [CAN] as Array[StringName]
	p.level = 12
	SaveService.save_profile(p, SLOT)
	return p


func _screen(p: PlayerProfile) -> CrewScreen:
	var s: CrewScreen = SCENE.instantiate() as CrewScreen
	s.setup(p, SLOT)
	add_child(s)
	await wait_frames(2)
	return s


func test_rows_follow_the_armory_and_picks_save() -> void:
	var s: CrewScreen = await _screen(_profile())
	assert_eq(s.bot_tabs.size(), CrewLoadouts.SLOTS)
	var w: ItemSlot = s.rows["weapon"] as ItemSlot
	assert_eq(w.item_count, 2, "Standard issue + the one owned primary")
	assert_false(s.rows.has("mod.%d" % Enums.ModType.SUPPRESSOR), "no mod rows on the default gun")
	assert_true(s.pick("weapon", AR))
	assert_true(s.rows.has("mod.%d" % Enums.ModType.SUPPRESSOR), "the owned suppressor gets a row")
	assert_true(s.pick("mod.%d" % Enums.ModType.SUPPRESSOR, CAN))
	assert_true(s.pick("armor", &"armor.heavy_vest"))
	assert_false(s.pick("armor", &"armor.tactical_plate"), "a locked armor is not on offer")
	var saved: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(saved.crew_loadouts[0]["weapon"], AR, "saved at once")
	assert_eq(saved.crew_loadouts[0]["mods"], [CAN] as Array[StringName])
	assert_eq(saved.crew_loadouts[0]["armor"], &"armor.heavy_vest")
	assert_true(s.summary_labels[0].text.contains(UiText.t(UiText.item_key(AR))), s.summary_labels[0].text)
	assert_true(s.pick("weapon", &""), "back to Standard issue")
	assert_eq(SaveService.load_profile(SLOT).crew_loadouts[0]["mods"], [] as Array[StringName], "another gun drops the mods")
	s.queue_free()
	await wait_frames(1)


func test_tabs_reset_and_focus_chain() -> void:
	var s: CrewScreen = await _screen(_profile())
	s.select_bot(2)
	assert_eq(s.bot, 2)
	assert_true(s.bot_tabs[2].button_pressed and not s.bot_tabs[0].button_pressed)
	s.pick("outfit", Heisters.ids()[0])
	assert_eq(SaveService.load_profile(SLOT).crew_loadouts[2]["outfit"], Heisters.ids()[0], "bot 3 edited")
	assert_eq(SaveService.load_profile(SLOT).crew_loadouts[0]["outfit"], &"", "bot 1 untouched")
	s.reset_bot()
	assert_eq(SaveService.load_profile(SLOT).crew_loadouts[2]["outfit"], &"", "reset")
	for c: Control in [s.bot_tabs[0], s.rows["weapon"], s.rows["armor"], s.rows["mask"], s.rows["outfit"], s.reset_button,
			s.back_button]:
		assert_has(s.focus_chain, c)
	var tab: Button = s.bot_tabs[1]
	assert_eq(tab.get_node(tab.focus_neighbor_bottom), s.rows["weapon"], "down from a tab into the editor")
	assert_eq(tab.get_node(tab.focus_neighbor_right), s.bot_tabs[2], "tabs left / right")
	var backs: Array = []
	s.back_requested.connect(func() -> void: backs.append(1))
	s.back_button.pressed.emit()
	assert_eq(backs.size(), 1)
	s.queue_free()
	await wait_frames(1)


func test_hub_opens_bot_crew_and_back_returns() -> void:
	_profile()
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.show_hub()
	await wait_frames(1)
	f.hub.crew_button.pressed.emit()
	await wait_frames(1)
	assert_true(f.current is CrewScreen)
	(f.current as CrewScreen).back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control)
	f.queue_free()
	await wait_frames(1)
