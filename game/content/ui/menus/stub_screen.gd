## Generic "not available yet" screen (settings stub, missing HeistLauncher). Owner: ENV B.
## setup(message_key, show_sample_payday): the optional button previews the payday screen with the
## sample HeistResult so the results UI can be tested before ENV A's launcher lands.
class_name StubScreen
extends UiScreen

signal sample_payday_requested()

var message_label: Label
var sample_button: Button
var back_button: Button
var _message_key: StringName = &"ui.menu.coming_soon"
var _show_sample: bool = false


func setup(message_key: StringName, show_sample_payday: bool = false) -> void:
	_message_key = message_key
	_show_sample = show_sample_payday
	if message_label != null:
		_apply()


func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(20)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	UiBuild.screen_margin(self, root)
	message_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(600, 0)
	root.add_child(message_label)
	sample_button = UiBuild.button(&"ui.stub.sample_payday")
	sample_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sample_button.pressed.connect(sample_payday_requested.emit)
	root.add_child(sample_button)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(back_requested.emit)
	root.add_child(back_button)
	focus_chain.append(sample_button)
	focus_chain.append(back_button)
	_apply()


func _apply() -> void:
	message_label.text = UiText.t(_message_key)
	sample_button.visible = _show_sample
	focus_default()
