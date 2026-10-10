## B1-04: every UI scene instantiates headless and builds its widgets; the menu flow reaches the
## loadout screen and the launcher stub / sample payday.
extends TestCase

const SCENES: Array[String] = [
	"res://content/ui/menus/main_menu.tscn",
	"res://content/ui/menus/heist_select.tscn",
	"res://content/ui/menus/loadout.tscn",
	"res://content/ui/menus/stub_screen.tscn",
	"res://content/ui/menus/menu_flow.tscn",
	"res://content/ui/results/payday.tscn",
	"res://content/ui/hud/hud.tscn",
	"res://content/ui/hud/mock/hud_demo.tscn",
	"res://content/ui/progression/skill_tree_screen.tscn",
	"res://content/ui/progression/perk_deck_screen.tscn",
]


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	SaveService.delete_profile(0)


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_every_scene_instantiates() -> void:
	for path: String in SCENES:
		var ps: PackedScene = load(path) as PackedScene
		assert_true(ps != null, "loads %s" % path)
		if ps == null:
			continue
		var n: Node = ps.instantiate()
		add_child(n)
		await wait_frames(2)
		assert_true(n.get_child_count() > 0, "%s built children" % path)
		n.queue_free()
		await wait_frames(1)


func test_main_menu_focus_and_range_enabled() -> void:
	var m: MainMenu = (load("res://content/ui/menus/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(m)
	await wait_frames(2)
	assert_false(m.range_button.disabled, "firing range is available (B1-05)")
	assert_true(m.play_button.has_focus(), "first button has focus for gamepad/keyboard")
	assert_false(m.play_button.focus_neighbor_bottom.is_empty(), "focus chain set")
	m.queue_free()


func test_heist_select_locks_and_preview() -> void:
	var s: HeistSelect = (load("res://content/ui/menus/heist_select.tscn") as PackedScene).instantiate() as HeistSelect
	add_child(s)
	await wait_frames(1)
	assert_true(s.heist_buttons.size() >= 1, "at least the Glasshouse entry")
	assert_eq(s.selected_heist_id(), &"glasshouse")
	assert_false(s.difficulty_buttons[Enums.Difficulty.ROUTINE].disabled)
	assert_false(s.difficulty_buttons[Enums.Difficulty.BRUTAL].disabled)
	assert_true(s.difficulty_buttons[Enums.Difficulty.TENSE].disabled, "tense locked in P1")
	assert_true(s.difficulty_buttons[Enums.Difficulty.CATACLYSM].disabled)
	var base: int = int(HeistCatalog.entries()[0]["base_payout"])
	s.select_difficulty(Enums.Difficulty.BRUTAL)
	var probe: Dictionary = {"success": true, "difficulty": Enums.Difficulty.BRUTAL, "contract_pay": base,
			"loot": [], "small_loot": 0, "crew": []}
	assert_eq(s.preview_amount(), int(PayoutCalculator.compute(probe)["contract"]))
	assert_true(s.payout_label.text.contains(UiText.group_digits(s.preview_amount())), s.payout_label.text)
	s.select_difficulty(Enums.Difficulty.LETHAL)
	assert_eq(s.selected_difficulty, Enums.Difficulty.BRUTAL, "locked difficulty cannot be picked")
	s.queue_free()


func test_flow_reaches_stub_and_sample_payday() -> void:
	if UiNav.global_class(&"HeistLauncher") != null:
		skip("HeistLauncher exists; launching is covered by the integration tests")
		return
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	assert_eq(f.current, f.main_menu as Control)
	f.main_menu.play_button.pressed.emit()
	assert_eq(f.current, f.heist_select as Control)
	f.heist_select.next_button.pressed.emit()
	assert_eq(f.current, f.loadout_screen as Control)
	await wait_frames(1)
	f.loadout_screen.launch_button.pressed.emit()
	assert_eq(f.current, f.stub_screen as Control)
	assert_true(f.stub_screen.sample_button.visible, "stub offers the sample payday")
	f.stub_screen.sample_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.payday as Control)
	assert_false(f.payday.apply_to_profile, "sample payday never pays into the profile")
	assert_true(f.payday.value_labels.has(&"total"))
	f.payday.continue_button.pressed.emit()
	assert_eq(f.current, f.main_menu as Control)
	f.queue_free()
	await wait_frames(1)
