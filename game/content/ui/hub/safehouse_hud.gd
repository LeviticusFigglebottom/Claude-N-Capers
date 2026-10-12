## Minimal 3D safehouse HUD (B6-06; QC-47 / QC-49). Owner: ENV B. A MenuFlow screen shown while the
## player walks the safehouse (SafehouseHost.show_home): a centre dot and the focused station's interaction
## prompt (InteractionPanel bound to the walker's LocalHudModel `interaction`: `ui.prompt.station.<id>`).
## It ignores the mouse so look input reaches the walker. Esc / `pause` -> back_requested, which
## SafehouseHost turns into the pause menu.
class_name SafehouseHud
extends UiScreen

## Centre dot radius (px at 1080p) and colour.
const DOT_RADIUS: float = 3.0
const DOT_COLOR: Color = Color(0.94, 0.92, 0.86, 0.9)
const PAUSE_ACTION: StringName = &"pause"

var dot: Control
var prompt: InteractionPanel
## The HUD model the prompt reads (null = no prompt).
var model: Node = null


func build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot = Control.new()
	dot.name = "CrosshairDot"
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.custom_minimum_size = Vector2(DOT_RADIUS, DOT_RADIUS) * 2.0
	dot.draw.connect(_draw_dot)
	add_child(dot)
	prompt = InteractionPanel.new()
	prompt.name = "Prompt"
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.offset_left = -360.0
	prompt.offset_right = 360.0
	prompt.offset_top = 48.0
	prompt.offset_bottom = 160.0
	add_child(prompt)
	prompt.bind(model)


## Follows `m` (LocalHudModel or a stand-in with `interaction` / `interaction_changed`); null clears it.
func bind_model(m: Node) -> void:
	model = m
	if prompt != null:
		prompt.bind(m)


## The prompt text on screen ("" when nothing is focused).
func prompt_text() -> String:
	if prompt == null or not prompt.visible:
		return ""
	return prompt.prompt_label.text


func _draw_dot() -> void:
	dot.draw_circle(dot.size * 0.5, DOT_RADIUS, DOT_COLOR)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Walking the 3D safehouse, pad B is a gameplay button: only Esc (ui_cancel) or Start (pause) open the menu.
	var esc: bool = event.is_action_pressed(&"ui_cancel") and not event is InputEventJoypadButton
	if esc or (InputMap.has_action(PAUSE_ACTION) and event.is_action_pressed(PAUSE_ACTION)):
		get_viewport().set_input_as_handled()
		back_requested.emit()
