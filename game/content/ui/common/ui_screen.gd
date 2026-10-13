## Base for full-screen menu screens. Owner: ENV B.
## A screen never changes scenes itself: it emits signals and MenuFlow (menus/menu_flow.gd) swaps
## screens, so every screen also works standalone and in headless tests.
## ui_cancel (Esc / gamepad B) emits back_requested. Screens build their layout in build_ui().
class_name UiScreen
extends Control

signal back_requested()

## PO-4 motion (style.md §6): a shown screen fades in over UiTokens.T_BASE. Off for captures / tests
## that read pixels right away.
static var motion_enabled: bool = true

## PO-4 control hints along the bottom edge ("[Enter] Select   [Esc] Back"), following the last
## device used. Screens with their own hints (or none) turn this off before _ready.
var show_control_hints: bool = true
## The hint strip (null when show_control_hints is off).
var control_hints: HBoxContainer = null

## Focus order for keyboard/gamepad; the first enabled one gets focus when the screen is shown.
var focus_chain: Array[Control] = []
var _hints_pad: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme == null:
		theme = UiBuild.theme()
	UiNav.ensure_pad_ui_actions()
	build_ui()
	if show_control_hints:
		_build_control_hints()
	UiNav.chain_vertical(focus_chain)
	visibility_changed.connect(_on_visibility_changed)
	focus_default()


## Override: create child controls and fill focus_chain.
func build_ui() -> void:
	pass


func focus_default() -> void:
	if is_visible_in_tree():
		UiNav.focus_first(focus_chain)


func _build_control_hints() -> void:
	control_hints = UiBuild.hbox(UiTokens.S5)
	control_hints.name = "ControlHints"
	control_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_hints.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE)
	control_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	control_hints.offset_bottom = -UiTokens.S2
	add_child(control_hints)
	refresh_control_hints()


## Rebuilds the hint strip for the device used last (InteractionPanel.pad_active).
func refresh_control_hints() -> void:
	if control_hints == null:
		return
	_hints_pad = InteractionPanel.pad_active
	for c: Node in control_hints.get_children():
		control_hints.remove_child(c)
		c.queue_free()
	for pair: Array in control_hint_pairs():
		var h: HBoxContainer = UiBuild.hbox(UiTokens.S2)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UiBuild.keycap(InteractionPanel.action_key_text(StringName(pair[0])), UiTokens.FONT_SMALL))
		h.add_child(UiBuild.caption(StringName(pair[1])))
		control_hints.add_child(h)


## Override: [[action, strings key], ...] shown in the hint strip.
func control_hint_pairs() -> Array:
	return [[&"ui_accept", &"ui.hint.select"], [&"ui_cancel", &"ui.hint.back"]]


func _input(event: InputEvent) -> void:
	if control_hints == null or not is_visible_in_tree():
		return
	InteractionPanel.note_input(event)
	if InteractionPanel.pad_active != _hints_pad:
		refresh_control_hints()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


## Deferred: visibility_changed fires on the screen before its children's visible-in-tree state is
## updated, so focusing right away would find no visible control (menu transitions lost focus).
func _on_visibility_changed() -> void:
	focus_default.call_deferred()
	if visible and motion_enabled and is_inside_tree() and DisplayServer.get_name() != "headless":
		modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(self, ^"modulate:a", 1.0, UiTokens.T_BASE)
