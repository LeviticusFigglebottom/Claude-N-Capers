## PQ-B-2 (D-076): every B screen reachable from the hub keeps its focusable controls on screen at the
## 1080-unit canvas (= 1280x720 under canvas_items stretch). Controls inside a ScrollContainer only need
## that scroll to be on screen (follow_focus brings them in).
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
## Stations that are screens (range loads a level, so it is excluded).
const STATIONS: Array[StringName] = [&"board", &"planning", &"armory", &"masks", &"crew", &"jukebox",
		&"notoriety", &"profile"]


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


static func _scroll_parent(c: Control) -> ScrollContainer:
	var n: Node = c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null


## Offending controls ("name rect"); empty = all fit.
static func offscreen(screen: Control, chain: Array[Control]) -> Array[String]:
	var out: Array[String] = []
	var vis: Rect2 = screen.get_viewport().get_visible_rect().grow(1.0)
	for c: Control in chain:
		if c == null or not c.is_visible_in_tree():
			continue
		var sc: ScrollContainer = _scroll_parent(c)
		if sc != null:
			if not vis.encloses(sc.get_global_rect()):
				out.append("%s(scroll) %s" % [sc.name, sc.get_global_rect()])
			continue
		if not vis.encloses(c.get_global_rect()):
			out.append("%s %s" % [c.name, c.get_global_rect()])
	return out


## PQ-B-17: visible, non-empty labels rendering below MIN_PX real pixels at 1280x720.
const MIN_PX: float = 14.0


static func small_text(screen: Control) -> Array[String]:
	var out: Array[String] = []
	for n: Node in screen.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if not l.is_visible_in_tree() or l.text.strip_edges() == "":
			continue
		var px: float = l.get_theme_font_size(&"font_size") * l.get_global_transform().get_scale().y * 720.0 / 1080.0
		if px < MIN_PX - 0.01:
			out.append("%s/%s %.1fpx '%s'" % [l.get_parent().name, l.name, px, l.text.left(20)])
	for n: Node in screen.find_children("*", "Button", true, false):
		var b: Button = n as Button
		if not b.is_visible_in_tree() or b.text.strip_edges() == "":
			continue
		var bpx: float = b.get_theme_font_size(&"font_size") * b.get_global_transform().get_scale().y * 720.0 / 1080.0
		if bpx < MIN_PX - 0.01:
			out.append("button %.1fpx '%s'" % [bpx, b.text.left(20)])
	return out


func _check(open: Callable, label: String) -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.show_hub()
	await wait_frames(1)
	open.call(f)
	await wait_frames(3)
	var screen: UiScreen = f.current as UiScreen
	assert_true(screen != null, label + " opened a UiScreen")
	if screen != null:
		var bad: Array[String] = offscreen(screen, screen.focus_chain)
		assert_eq(bad.size(), 0, "%s off-screen at 720p: %s" % [label, ", ".join(bad)])
		var tiny: Array[String] = small_text(screen)
		assert_eq(tiny.size(), 0, "%s text below %.0f px at 720p: %s" % [label, MIN_PX, "; ".join(tiny)])
	f.queue_free()
	await wait_frames(2)


func test_station_screens_fit_720p() -> void:
	for id: StringName in STATIONS:
		await _check(func(f: MenuFlow) -> void: f.open_station(id), String(id))


func test_achievements_fits_720p() -> void:
	await _check(func(f: MenuFlow) -> void: f.hub.achievements_requested.emit(), "achievements")


## PQ-B-11: every Options tab (the in-heist pause uses the same OptionsScreen) fits at 720p.
func test_options_tabs_fit_720p() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.show_hub()
	await wait_frames(1)
	var s: OptionsScreen = f.options_menu.open()
	await wait_frames(2)
	for t: StringName in OptionsScreen.TABS:
		s.show_tab(t)
		await wait_frames(2)
		var bad: Array[String] = offscreen(s, s.focus_chain)
		assert_eq(bad.size(), 0, "options/%s off-screen at 720p: %s" % [t, ", ".join(bad)])
	f.queue_free()
	await wait_frames(2)


## PQ-B-11: the safehouse pause menu fits at 720p.
func test_safehouse_pause_fits_720p() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.show_hub()
	await wait_frames(1)
	var p: SafehousePauseMenu = f.safehouse.pause_menu
	p.visible = true
	await wait_frames(2)
	assert_true(p.focus_chain.size() > 0)
	var bad: Array[String] = offscreen(p, p.focus_chain)
	assert_eq(bad.size(), 0, "safehouse pause off-screen at 720p: %s" % ", ".join(bad))
	f.queue_free()
	await wait_frames(2)
