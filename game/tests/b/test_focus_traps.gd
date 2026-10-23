## r279 (a), after the RT pre-planning trap: on every B menu screen, reached through MenuFlow as a player does, the
## arrow keys (Control.find_valid_focus_neighbor) can reach every visible focusable control from the screen's default
## focus, and get back to it from every control (no trap). tests/b/focus_graph.gd does the graph; the pre-planning
## lists per point are covered by test_preplan_screen.test_arrow_keys_never_trap_focus.
extends TestCase

const FocusGraph: GDScript = preload("res://tests/b/focus_graph.gd")
const HEIST: StringName = &"glasshouse"
## 16:9 (the 1280x720 floor), 21:9 ultrawide, 16:10: canvas_items/expand lays each out differently.
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(3440, 1440), Vector2i(1920, 1200)]

var _flow: MenuFlow = null


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()
	SaveService.delete_profile(0)
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = 500000
	SaveService.save_profile(p, 0)


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(4)


func after_each() -> void:
	if _flow != null:
		_flow.queue_free()
		_flow = null
	await wait_frames(2)


func _check(where: String, root: Control = null) -> void:
	var win: Window = get_tree().root
	var size0: Vector2i = win.size
	for sz: Vector2i in SIZES:
		win.size = sz
		await wait_frames(6)
		var top: Control = root if root != null else _flow.current
		assert_true(top != null and top.is_visible_in_tree(), "%s: a screen is shown" % where)
		if top == null:
			break
		var n: int = FocusGraph.focusables(top).size()
		assert_true(n >= 1, "%s @%s: the graph sees the screen's controls (%d)" % [where, sz, n])
		var home: Control = get_viewport().gui_get_focus_owner()
		var problems: PackedStringArray = FocusGraph.problems(top, home if home != null and top.is_ancestor_of(home) else null)
		assert_eq(problems, PackedStringArray(), "%s (%s) @%s: arrow-key focus problems" % [where, top.name, sz])
	win.size = size0


func test_main_menu_and_hub() -> void:
	_flow.show_home()
	await _check("main menu")
	_flow.show_hub()
	await _check("hub")


func test_every_hub_station() -> void:
	for id: StringName in [&"board", &"planning", &"armory", &"masks", &"crew", &"notoriety", &"profile"]:
		_flow.show_hub()
		await wait_frames(2)
		if _flow.open_station(id):
			await _check("station %s" % id)


func test_heist_path_screens() -> void:
	_flow.show_hub()
	_flow.open_station(&"planning")
	await _check("heist select")
	_flow.call(&"_on_heist_chosen", HEIST, Enums.Difficulty.ROUTINE)
	await _check("briefing")
	_flow.call(&"_on_briefing_continue", HEIST, Enums.Difficulty.ROUTINE)
	await _check("pre-planning")
	_flow.preplanning_screen.confirm()
	await _check("loadout (pre-heist)")
	_flow.loadout_screen.skills_requested.emit()
	await _check("skill tree")
	_flow.close_progression()
	_flow.loadout_screen.perk_deck_requested.emit()
	await _check("perk deck")
	_flow.close_progression()
	_flow.loadout_screen.masks_requested.emit()
	await _check("masks (from loadout)")


func test_achievements_options_and_payday() -> void:
	_flow.show_hub()
	_flow.call(&"_open_achievements")
	await _check("achievements")
	_flow.show_hub()
	_flow.call(&"_show_sample_payday")
	await wait_frames(30)
	await _check("payday")


func test_the_helper_finds_a_trap() -> void:
	# A fixture: A <-> B, and C whose arrows all point at itself (focus can enter from B's right, never leave).
	var root: Control = Control.new()
	root.size = Vector2(600, 200)
	add_child(root)
	var bs: Array[Button] = []
	for i: int in range(3):
		var b: Button = Button.new()
		b.text = "b%d" % i
		b.position = Vector2(20 + 200 * i, 20)
		b.size = Vector2(120, 40)
		root.add_child(b)
		bs.append(b)
	for side: Side in FocusGraph.SIDES:
		bs[2].set_focus_neighbor(side, bs[2].get_path_to(bs[2]))
	await wait_frames(2)
	var probs: PackedStringArray = FocusGraph.problems(root, bs[0])
	assert_true(probs.size() == 1 and probs[0].begins_with("trap: ") and probs[0].contains("b2"), "trap found: %s" % probs)
	root.queue_free()


func test_options_and_lobby() -> void:
	_flow.show_home()
	await wait_frames(2)
	var opts: Control = _flow.options_menu.open()
	await _check("options (from the main menu)", opts)
	opts.queue_free()
	_flow.show_hub()
	_flow.show_lobby()
	await _check("co-op lobby")
