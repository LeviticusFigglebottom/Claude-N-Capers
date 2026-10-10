## Base for full-screen menu screens. Owner: ENV B.
## A screen never changes scenes itself: it emits signals and MenuFlow (menus/menu_flow.gd) swaps
## screens, so every screen also works standalone and in headless tests.
## ui_cancel (Esc / gamepad B) emits back_requested. Screens build their layout in build_ui().
class_name UiScreen
extends Control

signal back_requested()

## Focus order for keyboard/gamepad; the first enabled one gets focus when the screen is shown.
var focus_chain: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme == null:
		theme = UiBuild.theme()
	build_ui()
	UiNav.chain_vertical(focus_chain)
	visibility_changed.connect(_on_visibility_changed)
	focus_default()


## Override: create child controls and fill focus_chain.
func build_ui() -> void:
	pass


func focus_default() -> void:
	if is_visible_in_tree():
		UiNav.focus_first(focus_chain)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _on_visibility_changed() -> void:
	focus_default()
