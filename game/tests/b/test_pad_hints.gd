## Pad QA walk (lead r242): a screen that was hidden while the player switched to the pad shows the pad's key caps as
## soon as it is shown again (the Board kept "Enter / Escape" after pad play).
extends TestCase

var _was_pad: bool = false


func before_each() -> void:
	_was_pad = InteractionPanel.pad_active


func after_each() -> void:
	InteractionPanel.pad_active = _was_pad


func _caps(s: UiScreen) -> Array[String]:
	var out: Array[String] = []
	for n: Node in s.control_hints.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func test_hidden_screen_catches_up_on_show() -> void:
	InteractionPanel.pad_active = false
	var s: UiScreen = UiScreen.new()
	add_child(s)
	await wait_frames(1)
	var accept_key: String = InteractionPanel.action_key_text(&"ui_accept")
	assert_has(_caps(s), accept_key, "keyboard caps first")
	s.hide()
	InteractionPanel.pad_active = true  # the player picked up the pad on another screen
	var accept_pad: String = InteractionPanel.action_key_text(&"ui_accept")
	assert_ne(accept_pad, accept_key)
	s.show()
	await wait_frames(1)
	assert_has(_caps(s), accept_pad, "pad caps as soon as it is shown")
	assert_false(_caps(s).has(accept_key))
	s.queue_free()
	await wait_frames(1)
