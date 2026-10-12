## PQ-B-2 (D-076): every B screen reachable from the hub keeps its focusable controls on screen at the
## 1080-unit canvas (= 1280x720 under canvas_items stretch). Controls inside a ScrollContainer only need
## that scroll to be on screen (follow_focus brings them in).
extends TestCase

const SLOT: int = 0
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


func _check(open: Callable, label: String) -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
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
	f.queue_free()
	await wait_frames(2)


func test_station_screens_fit_720p() -> void:
	for id: StringName in STATIONS:
		await _check(func(f: MenuFlow) -> void: f.open_station(id), String(id))


func test_achievements_fits_720p() -> void:
	await _check(func(f: MenuFlow) -> void: f.hub.achievements_requested.emit(), "achievements")
