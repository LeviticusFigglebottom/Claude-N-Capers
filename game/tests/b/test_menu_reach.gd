## Lead queue (after gate82: a hidden explicit focus neighbour trapped the payday): every menu screen,
## at 1280x720 and 1920x1080, with only a gamepad and with only mouse + keyboard. For each screen's
## focus chain (visible, enabled, focusable controls):
##   * d-pad: every control is reachable from the default focus through the four focus neighbours
##     (Control.find_valid_focus_neighbor, the engine's own d-pad resolution), and no explicit neighbour
##     points at a hidden / unfocusable control (the gate82 trap);
##   * mouse: every control (or the scroll view holding it) lies on screen, so it can be clicked.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SIDES: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]

var _flow: MenuFlow = null
var _saved_size: Vector2i


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	_saved_size = get_window().size


func after_all() -> void:
	get_window().size = _saved_size
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	if _flow != null and is_instance_valid(_flow):
		_flow.queue_free()
	_flow = null
	await wait_frames(2)


func _usable(c: Control) -> bool:
	return c != null and is_instance_valid(c) and c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE \
			and not (c is BaseButton and (c as BaseButton).disabled)


## Problems of `screen` ([] when fine): unreachable controls, off-screen controls, explicit neighbours to
## controls that cannot take focus.
func _problems(screen: Control, label: String) -> Array[String]:
	var out: Array[String] = []
	var chain: Array[Control] = []
	for c: Control in screen.get(&"focus_chain") as Array[Control]:
		if _usable(c):
			chain.append(c)
	if chain.is_empty():
		return out
	var seen: Dictionary = {chain[0]: true}
	var queue: Array[Control] = [chain[0]]
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		for side: Side in SIDES:
			var path: NodePath = c.get_focus_neighbor(side)
			if path != NodePath():
				var t: Control = c.get_node_or_null(path) as Control
				# A disabled button still takes focus (the d-pad lands on it and moves on); a hidden or
				# unfocusable one does not, which is the gate82 trap. A path to nothing is a stale link.
				if t == null:
					out.append("%s: %s's %s neighbour path %s is stale" % [label, _name(c), side, path])
				elif t != c and (not t.is_visible_in_tree() or t.focus_mode == Control.FOCUS_NONE):
					out.append("%s: %s's %s neighbour %s cannot take focus" % [label, _name(c), side, _name(t)])
			var n: Control = c.find_valid_focus_neighbor(side)
			if n != null and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var vis: Rect2 = get_viewport().get_visible_rect().grow(1.0)
	for c: Control in chain:
		if not seen.has(c):
			out.append("%s: %s not reachable by d-pad" % [label, _name(c)])
		var box: Control = _scroll_of(c)
		if not vis.encloses((box if box != null else c).get_global_rect()):
			out.append("%s: %s off screen %s" % [label, _name(box if box != null else c), (box if box != null else c).get_global_rect()])
	return out


static func _scroll_of(c: Control) -> Control:
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p as Control
		p = p.get_parent()
	return null


static func _name(c: Control) -> String:
	if c is Button and (c as Button).text != "":
		return "'%s'" % (c as Button).text
	return String(c.name)


func _open_all(size: Vector2i) -> Array[String]:
	get_window().size = size
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 30
	SaveService.save_profile(p, SLOT)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(3)
	var tag: String = "%dx%d" % [size.x, size.y]
	var out: Array[String] = []
	out.append_array(await _at(_flow.main_menu, tag + " main menu"))
	_flow.show_hub()
	out.append_array(await _at(_flow.hub, tag + " hub"))
	var opts: OptionsScreen = _flow.options_menu.open()
	await wait_frames(2)
	for t: StringName in OptionsScreen.TABS:
		opts.show_tab(t)
		out.append_array(await _at(opts, "%s options/%s" % [tag, t]))
	opts.back_requested.emit()
	await wait_frames(2)
	for st: StringName in [&"board", &"planning", &"armory", &"masks", &"crew", &"jukebox", &"notoriety", &"profile"]:
		_flow.show_hub()
		await wait_frames(1)
		if not _flow.open_station(st):
			continue
		out.append_array(await _at(_flow.current, "%s station/%s" % [tag, st]))
		if st == &"armory" and _flow.current is LoadoutScreen:
			var ls: LoadoutScreen = _flow.current as LoadoutScreen
			ls.open_workshop()
			await wait_frames(2)
			if ls.workshop != null:
				out.append_array(await _at(ls.workshop, tag + " workshop"))
				ls.close_workshop(false)
				await wait_frames(1)
			for scene: PackedScene in [MenuFlow.SKILLS_SCENE, MenuFlow.PERKS_SCENE]:
				_flow.open_progression(scene)
				out.append_array(await _at(_flow.current, "%s %s" % [tag, scene.resource_path.get_file().get_basename()]))
	return out


func _at(screen: Control, label: String) -> Array[String]:
	await wait_frames(3)
	if screen == null or not screen.is_visible_in_tree() or screen.get(&"focus_chain") == null:
		return [] as Array[String]
	return _problems(screen, label)


func test_every_menu_is_reachable_by_pad_and_on_screen_at_720p() -> void:
	var probs: Array[String] = await _open_all(SIZES[0])
	assert_true(probs.is_empty(), "\n".join(probs))


func test_every_menu_is_reachable_by_pad_and_on_screen_at_1080p() -> void:
	var probs: Array[String] = await _open_all(SIZES[1])
	assert_true(probs.is_empty(), "\n".join(probs))
