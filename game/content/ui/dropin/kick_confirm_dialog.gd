## Host kick confirmation (B6-04). Owner: ENV B. A full-rect dimmer with a centered "Kick <name> from the
## crew?" panel; Kick calls `target.kick(slot)` (duck typing: LobbySession in the lobby, a DropInService in
## the heist), Cancel / Esc closes. The safe choice (Cancel) has the focus.
class_name KickConfirmDialog
extends Control

signal confirmed(slot: int, ok: bool)
signal cancelled()

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)

## Anything with kick(slot: int) -> bool.
var target: Object = null
## Slot being asked about (-1 = closed).
var slot: int = -1
var message_label: Label
var kick_button: Button
var cancel_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var v: VBoxContainer = UiBuild.vbox(16)
	v.add_child(UiBuild.label(&"ui.kick.title", UiBuild.SUBHEADER))
	message_label = UiBuild.label(&"")
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(560, 0)
	v.add_child(message_label)
	var row: HBoxContainer = UiBuild.hbox(16)
	kick_button = UiBuild.primary(UiBuild.button(&"ui.kick.yes"))
	cancel_button = UiBuild.button(&"ui.kick.no")
	for b: Button in [cancel_button, kick_button]:
		b.custom_minimum_size = Vector2(240, 0)
		row.add_child(b)
	kick_button.pressed.connect(confirm)
	cancel_button.pressed.connect(cancel)
	UiNav.chain_horizontal([cancel_button, kick_button] as Array[Control])
	v.add_child(row)
	center.add_child(UiBuild.panel(v))
	visible = false


## Ask to kick `p_slot` (shown as `player_name`, plain text).
func ask(p_slot: int, player_name: String) -> void:
	slot = p_slot
	message_label.text = UiText.t(&"ui.kick.confirm", {"name": player_name})
	visible = true
	cancel_button.grab_focus.call_deferred()


func is_asking() -> bool:
	return visible and slot >= 0


## Kick: target.kick(slot). Returns its result (false without a target).
func confirm() -> bool:
	if not is_asking():
		return false
	var s: int = slot
	var ok: bool = false
	if target != null and target.has_method(&"kick"):
		ok = bool(target.call(&"kick", s))
	_close()
	confirmed.emit(s, ok)
	return ok


func cancel() -> void:
	if not is_asking():
		return
	_close()
	cancelled.emit()


func _close() -> void:
	slot = -1
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_asking() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
