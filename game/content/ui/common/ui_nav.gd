## Focus navigation and dynamic-lookup helpers shared by every UI screen. Owner: ENV B.
## Keyboard, mouse and gamepad: screens chain their focusable controls explicitly (ui_up/ui_down
## and ui_left/ui_right follow the chain) and grab focus on the first enabled one.
class_name UiNav
extends RefCounted


## Link controls top-to-bottom (wraps). Disabled buttons stay in the chain so the order is stable;
## Godot skips controls whose focus_mode is NONE.
static func chain_vertical(controls: Array[Control], wrap: bool = true) -> void:
	_chain(controls, wrap, SIDE_TOP, SIDE_BOTTOM)


## Link controls left-to-right (wraps).
static func chain_horizontal(controls: Array[Control], wrap: bool = true) -> void:
	_chain(controls, wrap, SIDE_LEFT, SIDE_RIGHT)


## Grab focus on the first visible, enabled control. Returns it (or null).
static func focus_first(controls: Array[Control]) -> Control:
	for c: Control in controls:
		if c == null or not c.is_visible_in_tree() or c.focus_mode == Control.FOCUS_NONE:
			continue
		if c is BaseButton and (c as BaseButton).disabled:
			continue
		c.grab_focus.call_deferred()
		return c
	return null


## The script of a global class by name (e.g. &"HeistLauncher"), or null when it does not exist yet.
## Lets content code use ENV A classes without a hard dependency.
static func global_class(class_id: StringName) -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(c["class"]) == class_id:
			return load(String(c["path"])) as Script
	return null


static func _chain(controls: Array[Control], wrap: bool, prev_side: Side, next_side: Side) -> void:
	var n: int = controls.size()
	for i: int in range(n):
		var c: Control = controls[i]
		var prev: Control = controls[i - 1] if i > 0 else (controls[n - 1] if wrap else c)
		var next: Control = controls[i + 1] if i < n - 1 else (controls[0] if wrap else c)
		c.set_focus_neighbor(prev_side, c.get_path_to(prev))
		c.set_focus_neighbor(next_side, c.get_path_to(next))
		if prev_side == SIDE_TOP:
			c.focus_previous = c.get_path_to(prev)
			c.focus_next = c.get_path_to(next)
