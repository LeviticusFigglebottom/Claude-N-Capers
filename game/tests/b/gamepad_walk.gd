## D-115 gamepad walk helpers shared by test_gamepad_menus*.gd (no tests of its own). Owner: ENV B.
## See test_gamepad_menus.gd for what a walk checks.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const LOBBY_SCENE: PackedScene = preload("res://content/ui/lobby/lobby_screen.tscn")
const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const RANGE_SCENE: PackedScene = preload("res://content/range/firing_range.tscn")
const NET_SCRIPT: Script = preload("res://core/net.gd")
const WALK_ACTIONS: Array[StringName] = [&"ui_down", &"ui_up", &"ui_right", &"ui_left", &"ui_focus_next",
		&"ui_focus_prev"]
const HEIST: StringName = &"glasshouse"
## Upper bound on controls a walk explores (a runaway list fails instead of hanging).
const MAX_VISITS: int = 400

var _flow: MenuFlow = null
var _nodes: Array[Node] = []
var _branches: Array[Node] = []
var _port: int = 0
var _saved_size: Vector2i


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	_saved_size = get_window().size
	_port = 23000 + (OS.get_process_id() * 11) % 17000
	UiScreen.motion_enabled = false


func after_all() -> void:
	get_window().size = _saved_size
	UiScreen.motion_enabled = true
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	get_window().size = Vector2i(1280, 720)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 30
	p.cash = 5000000
	SaveService.save_profile(p, SLOT)


func after_each() -> void:
	InteractionPanel.pad_active = false
	if _flow != null and is_instance_valid(_flow):
		_flow.queue_free()
	_flow = null
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	for b: Node in _branches:
		var net: Node = b.get_node_or_null(^"Net")
		if net != null:
			net.call(&"leave")
		get_tree().set_multiplayer(null, b.get_path())
		b.queue_free()
	_branches.clear()
	get_viewport().gui_release_focus()
	await wait_frames(2)


# --- input + audit helpers ---------------------------------------------------------------------------------


func _press(action: StringName) -> void:
	for down: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = action
		e.pressed = down
		get_viewport().push_input(e)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## Interactive controls a pad player must be able to reach: visible, enabled, on a real rect.
static func _interactive(c: Control) -> bool:
	if not c.is_visible_in_tree() or c.size.x < 1.0 or c.size.y < 1.0:
		return false
	if c is ScrollBar or c is ProgressBar or c is TextureProgressBar or c is SpinBox:
		return false
	if c is BaseButton:
		return not (c as BaseButton).disabled
	if c is LineEdit:
		return (c as LineEdit).editable
	if c is Slider or c is ItemList or c is TextEdit or c is Tree or c is TabBar:
		return true
	return c.focus_mode == Control.FOCUS_ALL  # focusable panels, card / pin / preview widgets


## Read-only on purpose: no focus and no mouse (e.g. the briefing's blueprint markers).
static func _decorative(c: Control) -> bool:
	return c.focus_mode == Control.FOCUS_NONE and c.mouse_filter == Control.MOUSE_FILTER_IGNORE


static func _collect(root: Node, out: Array[Control]) -> void:
	for ch: Node in root.get_children():
		if ch is Window:
			continue
		if ch is Control and _interactive(ch as Control) and not _decorative(ch as Control):
			out.append(ch as Control)
		_collect(ch, out)


static func _sb_visible(sb: StyleBox) -> bool:
	if sb == null or sb is StyleBoxEmpty:
		return false
	if sb is StyleBoxFlat:
		var f: StyleBoxFlat = sb as StyleBoxFlat
		var border: bool = f.border_color.a > 0.0 and (f.border_width_left + f.border_width_right
				+ f.border_width_top + f.border_width_bottom) > 0
		return (f.draw_center and f.bg_color.a > 0.0) or border or (f.shadow_size > 0 and f.shadow_color.a > 0.0)
	if sb is StyleBoxTexture:
		return (sb as StyleBoxTexture).texture != null
	return true


## The focused control shows that it has focus: a visible "focus" StyleBox (the theme's cyan ring), the
## focus_panel cyan edge (UiBuild.focus_panel), or a script that draws its own focus state (has_focus()).
static func _focus_indicator(c: Control) -> bool:
	if c.has_theme_stylebox(&"focus") and _sb_visible(c.get_theme_stylebox(&"focus")):
		return true
	if c is PanelContainer and c.has_theme_stylebox_override(&"panel"):
		var sb: StyleBoxFlat = c.get_theme_stylebox(&"panel") as StyleBoxFlat
		if sb != null and sb.border_color.is_equal_approx(UiTokens.CYAN):
			return true
	var s: Script = c.get_script() as Script
	while s != null:
		if s.source_code.contains("has_focus()"):
			return true
		s = s.get_base_script()
	return false


static func _name(c: Control) -> String:
	if c is Button and (c as Button).text != "":
		return "'%s'(%s)" % [(c as Button).text.left(24), c.name]
	return "%s:%s" % [c.get_class(), c.name]


## Problems with the focused control `c` (empty when fine).
func _landing_problems(root: Control, c: Control, label: String) -> Array[String]:
	var out: Array[String] = []
	if c == null:
		out.append("%s: focus lost (nothing focused)" % label)
		return out
	if not root.is_ancestor_of(c) and c != root:
		out.append("%s: focus left the screen to %s (%s)" % [label, _name(c), root.get_path_to(c)])
		return out
	if not c.is_visible_in_tree() or c.size.x < 1.0 or c.size.y < 1.0:
		out.append("%s: focus on an invisible / zero-size %s" % [label, _name(c)])
	elif not _focus_indicator(c):
		out.append("%s: %s has no visible focus indicator" % [label, _name(c)])
	return out


## Walks `root` from its current focus with every navigation action and returns the problems (a)(b)(d).
func _walk(root: Control, label: String) -> Array[String]:
	await wait_frames(3)
	var out: Array[String] = []
	var start: Control = _focus()
	if start == null or not (root.is_ancestor_of(start) or start == root):
		out.append("%s: no initial focus inside the screen (focus on %s)" % [label, _name(start) if start != null else "nothing"])
		return out
	var targets: Array[Control] = []
	_collect(root, targets)
	var seen: Dictionary = {start: true}
	var queue: Array[Control] = [start]
	out.append_array(_landing_problems(root, start, label))
	var reported: Dictionary = {}
	while not queue.is_empty() and seen.size() < MAX_VISITS:
		var from: Control = queue.pop_front()
		for action: StringName in WALK_ACTIONS:
			if not is_instance_valid(from) or not from.is_visible_in_tree():
				break
			from.grab_focus()
			_press(action)
			var to: Control = _focus()
			if from is ItemList or from is Tree:
				# A list moves its own selection on up / down (and may rebuild the screen around it): keep
				# pressing like a player until the d-pad leaves the list at its edge.
				var guard: int = (from as ItemList).item_count + 1 if from is ItemList else 64
				while to == from and guard > 0 and (action == &"ui_down" or action == &"ui_up"):
					await wait_frames(1)
					_press(action)
					to = _focus()
					guard -= 1
				await wait_frames(1)
				to = _focus()
			if to == from:
				continue
			if to == null or not seen.has(to):
				var probs: Array[String] = _landing_problems(root, to, label)
				for p: String in probs:
					if not reported.has(p):
						reported[p] = true
						out.append("%s (from %s via %s)" % [p, _name(from), action])
				if to != null and probs.is_empty():
					seen[to] = true
					queue.append(to)
	# Screens that rebuild while walked (the workshop's slot tabs follow the weapon list) are judged on
	# what they show at the end, plus every original control that still exists.
	await wait_frames(1)
	var now: Array[Control] = []
	_collect(root, now)
	for c: Control in now:
		if not targets.has(c):
			targets.append(c)
	for c: Control in targets:
		if is_instance_valid(c) and _interactive(c) and not _decorative(c) and not seen.has(c):
			out.append("%s: %s not reachable by pad (%s, focus_mode %d)" % [label, _name(c), root.get_path_to(c),
					c.focus_mode])
	var live: int = targets.filter(func(c: Variant) -> bool: return is_instance_valid(c) and _interactive(c as Control)).size()
	print("[gamepad] %s: %d controls reached, %d interactive" % [label, seen.size(), live])
	if start != null and is_instance_valid(start) and start.is_visible_in_tree():
		start.grab_focus()
	return out


func _assert_walk(root: Control, label: String) -> void:
	assert_true(root != null and root.is_visible_in_tree(), "%s is open" % label)
	if root == null or not root.is_visible_in_tree():
		return
	var probs: Array[String] = await _walk(root, label)
	assert_true(probs.is_empty(), "\n".join(probs))


## ui_cancel on the open screen: `went_back` (checked after the press) must turn true.
func _assert_cancel(label: String, went_back: Callable) -> void:
	await wait_frames(1)
	_press(&"ui_cancel")
	await wait_frames(2)
	assert_true(went_back.call(), "%s: ui_cancel goes back" % label)


func _new_flow() -> MenuFlow:
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(3)
	return _flow


func _station(id: StringName) -> Control:
	var f: MenuFlow = await _new_flow()
	f.show_hub()
	await wait_frames(2)
	assert_true(f.open_station(id), "station %s opens" % id)
	await wait_frames(3)
	return f.current


func _current_is(c: Control) -> Callable:
	return func() -> bool: return _flow.current == c


func _hub_shown() -> Callable:
	return func() -> bool: return _flow.current == (_flow.hub as Control) or _flow.safehouse.is_active()
