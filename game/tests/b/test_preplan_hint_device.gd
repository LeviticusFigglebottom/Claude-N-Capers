## LEAD r309 pad pass: the pre-planning foot caption named both devices ("Esc / B returns from a list ..."). It names
## the Back key of the device used last, and follows a switch.
extends TestCase

const SCENE: String = "res://content/ui/preplanning/preplanning_screen.tscn"


func after_all() -> void:
	InteractionPanel.pad_active = false


func _pad_event() -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_DPAD_DOWN
	e.pressed = true
	Input.parse_input_event(e)
	await wait_frames(2)
	e = e.duplicate() as InputEventJoypadButton
	e.pressed = false
	Input.parse_input_event(e)
	await wait_frames(2)


func test_caption_names_the_back_key_of_the_last_device() -> void:
	InteractionPanel.pad_active = false
	var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
	s.save_on_confirm = false
	s.setup(&"glasshouse", Enums.Difficulty.ROUTINE, PlayerProfile.new())
	add_child(s)
	await wait_frames(2)
	var keys: String = InteractionPanel.action_key_text(&"ui_cancel")
	assert_true(s.hint_label.text.contains(keys + " returns"), s.hint_label.text)
	assert_false(s.hint_label.text.contains("{key}") or s.hint_label.text.contains(" / B "), "one device")
	await _pad_event()
	assert_true(InteractionPanel.pad_active)
	var pad: String = InteractionPanel.action_key_text(&"ui_cancel")
	assert_ne(pad, keys)
	assert_true(s.hint_label.text.contains(pad + " returns"), "after a pad press: %s" % s.hint_label.text)
	s.queue_free()
	await wait_frames(1)
