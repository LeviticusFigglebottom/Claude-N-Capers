## Minimal 3D safehouse HUD (B6-06; QC-47 / QC-49). Owner: ENV B. A MenuFlow screen shown while the
## player walks the safehouse (SafehouseHost.show_home): a centre dot and the focused station's interaction
## prompt (InteractionPanel bound to the walker's LocalHudModel `interaction`: `ui.prompt.station.<id>`).
## It ignores the mouse so look input reaches the walker. Esc / `pause` -> back_requested, which
## SafehouseHost turns into the pause menu.
## D-115 new-player flow: while the profile has never finished a heist (HubMenu.is_first_time) a "START HERE"
## note at the top names the Board and the interact key (the 2D hub's START HERE chip, for the walked hub).
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
## D-115 first-time note (hidden once a heist is on the career record).
var start_here: PanelContainer
var start_here_prompt: KeyPrompt
var first_time: bool = false
var _keys_pad: bool = false


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
	_build_start_here()
	GameSettings.current().changed.connect(_on_settings_changed)


func _build_start_here() -> void:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap: Label = UiBuild.caption(&"ui.hub.start_here")
	cap.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	start_here_prompt = KeyPrompt.new(UiTokens.FONT_BODY)
	v.add_child(start_here_prompt)
	start_here = UiBuild.panel(v, UiBuild.HUD_PANEL)
	start_here.name = "StartHere"
	start_here.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_here.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, UiTokens.MARGIN)
	start_here.grow_horizontal = Control.GROW_DIRECTION_BOTH
	start_here.visible = false
	add_child(start_here)


## Shows the START HERE note when `p` has never finished a heist (SafehouseHost calls it on every return home).
func set_profile(p: PlayerProfile) -> void:
	first_time = HubMenu.is_first_time(p)
	refresh_start_here()


## Redraws the note's key cap from the current binding of `interact` (rebinding, device switch).
func refresh_start_here() -> void:
	if start_here == null:
		return
	start_here.visible = first_time
	if first_time:
		start_here_prompt.set_prompt(&"ui.hub.start_here_walk", {},
				InteractionPanel.action_key_text(InteractionPanel.INTERACT_ACTION))


## Options applies bindings after `changed` fires (copy_from, then apply): redraw the key caps a frame later.
func _on_settings_changed(section: StringName, _key: StringName) -> void:
	if section == GameSettings.BINDINGS:
		_refresh_keys.call_deferred()


func _refresh_keys() -> void:
	refresh_start_here()
	if prompt != null and is_instance_valid(prompt):
		prompt.refresh()


func _input(event: InputEvent) -> void:
	super(event)
	InteractionPanel.note_input(event)
	if InteractionPanel.pad_active != _keys_pad:
		_keys_pad = InteractionPanel.pad_active
		_refresh_keys()


## Follows `m` (LocalHudModel or a stand-in with `interaction` / `interaction_changed`); null clears it.
func bind_model(m: Node) -> void:
	model = m
	if prompt != null:
		prompt.bind(m)


## The prompt text on screen ("" when nothing is focused).
func prompt_text() -> String:
	if prompt == null or not prompt.visible:
		return ""
	return prompt.prompt.text


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
