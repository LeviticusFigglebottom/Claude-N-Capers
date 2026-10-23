## B2-01: the menu path in pd2_fidelity C2/C3 order (heist select -> briefing -> pre-planning ->
## loadout -> launch) with back navigation at every step, the launch options MenuFlow hands to
## HeistLauncher (options["preplan"], QB-PP2), the loadout mask picker (custom masks survive a save)
## and the Masks button round trip. Never launches a heist (MenuFlow.build_launch_options is pure).
extends TestCase

const START_CASH: int = 200000
const CREW_ASSET: StringName = &"asset.spare_body_bags"


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = START_CASH
	SaveService.save_profile(p, 0)


func _flow() -> MenuFlow:
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	return f


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


## main menu -> safehouse -> planning table (heist select) -> briefing -> pre-planning.
func _to_preplanning(f: MenuFlow) -> void:
	f.main_menu.safehouse_button.pressed.emit()
	f.hub.station_button(&"planning").pressed.emit()
	assert_true(f.heist_select.select_heist_id(&"glasshouse"), "glasshouse offered")
	f.heist_select.next_button.pressed.emit()
	await wait_frames(1)
	f.briefing_screen.continue_button.pressed.emit()
	await wait_frames(2)


## ... -> pre-planning (one crew asset bought, confirmed) -> loadout.
func _to_loadout(f: MenuFlow) -> void:
	await _to_preplanning(f)
	f.preplanning_screen.show_crew_assets()
	assert_eq(f.preplanning_screen.buy(CREW_ASSET), PreplanPlan.OK)
	f.preplanning_screen.confirm_button.pressed.emit()
	await wait_frames(2)


func test_full_path_and_back_navigation() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(2)
	assert_eq(_focused(), f.main_menu.safehouse_button as Control, "main menu: Safehouse focused")
	f.main_menu.safehouse_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.hub as Control, "main menu -> safehouse hub")
	assert_eq(_focused(), f.hub.station_button(&"board") as Control, "hub: first station focused")
	f.hub.station_button(&"planning").pressed.emit()
	await wait_frames(2)
	assert_eq(_focused(), f.heist_select.heist_buttons[0] as Control, "heist select: first heist focused")
	assert_eq(f.current, f.heist_select as Control)
	assert_eq(f.heist_select.next_button.text, UiText.t(&"ui.heist_select.next"))
	f.heist_select.select_difficulty(Enums.Difficulty.BRUTAL)
	assert_true(f.heist_select.select_heist_id(&"glasshouse"), "glasshouse offered")
	f.heist_select.next_button.pressed.emit()
	await wait_frames(2)
	# heist select -> briefing
	assert_eq(f.current, f.briefing_screen as Control)
	assert_eq(f.briefing_screen.heist_id, &"glasshouse")
	assert_eq(f.briefing_screen.difficulty, Enums.Difficulty.BRUTAL)
	assert_eq(_focused(), f.briefing_screen.continue_button as Control, "briefing: Continue focused")
	f.briefing_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.heist_select as Control, "briefing Back -> heist select")
	assert_eq(_focused(), f.heist_select.heist_buttons[0] as Control, "heist select: first heist focused")
	assert_true(f.heist_select.select_heist_id(&"glasshouse"), "glasshouse offered")
	f.heist_select.next_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.briefing_screen as Control)
	# briefing -> pre-planning
	f.briefing_screen.continue_button.pressed.emit()
	await wait_frames(2)
	var pp: PreplanningScreen = f.preplanning_screen
	assert_eq(f.current, pp as Control)
	assert_eq(pp.heist_id, &"glasshouse")
	assert_eq(pp.difficulty, Enums.Difficulty.BRUTAL)
	assert_eq(pp.profile, f.profile, "pre-planning edits the flow's profile")
	var first_marker: Control = pp.blueprint_view.markers[pp.blueprint_view.marker_ids()[0]] as Control
	assert_eq(_focused(), first_marker, "pre-planning: first marker focused")
	f.preplanning_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.briefing_screen as Control, "pre-planning Back -> briefing")
	assert_eq(_focused(), f.briefing_screen.continue_button as Control)
	f.briefing_screen.continue_button.pressed.emit()
	await wait_frames(2)
	pp = f.preplanning_screen
	first_marker = pp.blueprint_view.markers[pp.blueprint_view.marker_ids()[0]] as Control
	# pre-planning (one asset) -> loadout
	pp.show_crew_assets()
	assert_eq(pp.buy(CREW_ASSET), PreplanPlan.OK)
	var cost: int = pp.board.cost_of(CREW_ASSET)
	assert_true(cost > 0, "asset costs spending cash")
	pp.confirm_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.loadout_screen as Control)
	assert_eq(_focused(), f.loadout_screen.weapon_option as Control, "loadout: first control focused")
	assert_eq(f.loadout_screen.profile, f.profile, "loadout edits the same profile")
	assert_has(f.preplan["modifier_sources"], CREW_ASSET)
	assert_eq(int(f.preplan["version"]), PreplanPlan.HANDOFF_VERSION)
	assert_eq(StringName((f.preplan["plan"] as Dictionary)["heist_id"]), &"glasshouse")
	assert_eq(int((f.preplan["cash_spent"] as Dictionary)[0]), pp.board.cost_of(CREW_ASSET))
	assert_eq(SaveService.load_profile(0).cash, START_CASH - cost, "charged once on confirm")
	# loadout Back -> pre-planning refunds; confirming again charges once
	f.loadout_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, pp as Control, "loadout Back -> the same pre-planning board")
	assert_true(f.preplan.is_empty(), "plan dropped")
	assert_eq(SaveService.load_profile(0).cash, START_CASH, "refunded")
	assert_true(pp.is_selected(CREW_ASSET), "selections kept")
	assert_eq(pp.cash_left(), START_CASH - cost)
	assert_eq(_focused(), first_marker)
	pp.confirm_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.loadout_screen as Control)
	assert_eq(SaveService.load_profile(0).cash, START_CASH - cost, "re-confirm charges once")
	# what Launch would pass to HeistLauncher.launch
	var loadout: Loadout = f.loadout_screen.current_loadout()
	var resolved: Loadout = LoadoutResolver.resolve(loadout)
	var ai: int = HeistCatalog.heist_list().solo_ai_for(&"glasshouse")
	var opts: Dictionary = MenuFlow.build_launch_options(ai, 0, resolved, f.preplan)
	assert_eq(int(opts["ai_teammates"]), ai)
	assert_eq((opts["loadouts"] as Dictionary)[0], resolved)
	assert_eq(opts["preplan"], f.preplan)
	var result: Dictionary = opts["preplan"] as Dictionary
	assert_eq(int((result["plan"] as Dictionary)["difficulty"]), Enums.Difficulty.BRUTAL)
	for k: String in PreplanPlan.RESULT_KEYS:
		assert_has(result, k, "PreplanResult v1 key")
	f.queue_free()
	await wait_frames(1)


func test_launch_options_without_plan() -> void:
	var l: Loadout = Loadout.new()
	var opts: Dictionary = MenuFlow.build_launch_options(2, 1, l)
	assert_eq(int(opts["ai_teammates"]), 2)
	assert_eq((opts["loadouts"] as Dictionary)[1], l)
	assert_false(opts.has("preplan"), "direct launch / no plan: no preplan key")
	assert_false(MenuFlow.build_launch_options(2, 1, l, {}).has("preplan"))
	assert_eq(PreplanPlan.resolve_ids(&"glasshouse", [] as Array), {}, "no accepted id: no plan")
	assert_eq(PreplanPlan.resolve_ids(&"glasshouse", [&"asset.not_in_catalog"]), {}, "unknown ids only: no plan")
	var plan: Dictionary = PreplanPlan.resolve_ids(&"glasshouse", [&"asset.extra_cable_ties"])
	assert_eq(MenuFlow.build_launch_options(0, 0, l, plan)["preplan"], plan)


func test_choosing_a_heist_again_resets_the_path() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	await _to_loadout(f)
	assert_false(f.preplan.is_empty())
	f.loadout_screen.back_button.pressed.emit()
	await wait_frames(1)
	f.preplanning_screen.back_button.pressed.emit()
	f.briefing_screen.back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.heist_select as Control)
	assert_true(f.heist_select.select_heist_id(&"glasshouse"), "glasshouse offered")
	f.heist_select.next_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.briefing_screen as Control)
	assert_true(f.preplanning_screen == null, "old board dropped")
	assert_true(f.loadout_screen == null, "old loadout dropped")
	assert_true(f.preplan.is_empty())
	assert_eq(SaveService.load_profile(0).cash, START_CASH, "nothing left charged")
	f.queue_free()
	await wait_frames(1)


func test_loadout_mask_picker_keeps_custom_mask() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var comp: Dictionary = MaskComposer.normalized(MaskCatalog.tweak().default_composition)
	assert_eq(MaskLocker.save_custom(p, 1, comp), &"mask.custom.1")
	assert_true(MaskLocker.equip(p, &"mask.custom.1"))
	SaveService.save_profile(p, 0)
	var s: LoadoutScreen = (load("res://content/ui/menus/loadout.tscn") as PackedScene).instantiate() as LoadoutScreen
	add_child(s)
	await wait_frames(1)
	var ids: Array[StringName] = s.mask_ids()
	assert_eq(ids[0], &"", "none first")
	for id: StringName in MaskLocker.available_ids(s.profile):
		assert_has(ids, id)
	assert_eq(ids.size(), MaskLocker.available_ids(s.profile).size() + 1)
	var i: int = ids.find(&"mask.custom.1")
	assert_eq(s.mask_option.get_item_text(i), MaskCatalog.display_name(&"mask.custom.1"))
	assert_eq(s.current_loadout().mask, &"mask.custom.1", "custom mask selected")
	assert_eq(s.save(), OK)
	assert_eq(SaveService.load_profile(0).loadout.mask, &"mask.custom.1", "kept across save")
	s.queue_free()
	await wait_frames(1)


func test_masks_button_round_trip() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	await _to_loadout(f)
	var ls: LoadoutScreen = f.loadout_screen
	assert_true(ls.mask_option.is_visible_in_tree(), "D-111: the mask tile opens the bench")
	assert_false(ls.mask_ids().has(&"mask.custom.0"))
	ls.select_armor(&"armor.patrol_vest")
	ls.mask_option.pressed.emit()
	await wait_frames(2)
	var ms: MaskScreen = f.mask_screen
	assert_true(ms != null)
	assert_eq(f.current, ms as Control)
	assert_eq(ms.profile, ls.profile, "mask screen edits the loadout's profile")
	assert_eq(ms.profile.loadout.armor, &"armor.patrol_vest", "loadout committed before opening")
	assert_true(_focused() != null and ms.is_ancestor_of(_focused()), "mask screen has focus")
	var changed: Array[StringName] = []
	ms.mask_changed.connect(func(id: StringName) -> void: changed.append(id))
	assert_eq(ms.save_to_slot(0), &"mask.custom.0")
	assert_true(ms.equip_selected())
	assert_eq(changed, [&"mask.custom.0"] as Array[StringName])
	ms.back_button.pressed.emit()
	await wait_frames(2)
	assert_true(f.mask_screen == null, "mask screen closed")
	assert_eq(f.current, ls as Control, "back on the loadout screen")
	assert_true(ls.mask_ids().has(&"mask.custom.0"), "picker re-read")
	assert_eq(ls.current_loadout().mask, &"mask.custom.0", "equipped mask selected")
	assert_eq(ls.current_loadout().armor, &"armor.patrol_vest", "other choices kept")
	assert_eq(_focused(), ls.weapon_option as Control, "loadout: first control focused")
	assert_eq(ls.save(), OK)
	assert_eq(SaveService.load_profile(0).loadout.mask, &"mask.custom.0")
	f.queue_free()
	await wait_frames(1)
