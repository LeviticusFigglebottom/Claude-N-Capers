## PO-2 / D-087: MouseCapture is the single owner of Input.mouse_mode (input_focus.md 1.0).
## Logic tests run headless; the capture tests need a real window (skipped headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##     res://tests/framework/runner.tscn -- --dir=p --filter=po2
## With xdotool installed the motion test moves the real X pointer (XTest), else it parses mouse events.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	MouseCapture.reset()
	PlayerInput.test_assume_captured = false
	_inp = PInputDriver.new(self)


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)
	MouseCapture.reset()


func _windowed() -> bool:
	return DisplayServer.get_name() != "headless"


func _launch_glasshouse() -> CrewController:
	_rt = await HeistLauncher.launch(&"glasshouse", 1002, Enums.Difficulty.ROUTINE, self, {"ai_teammates": 0})
	_rt.isolate_npc(null)
	await wait_frames(10)
	return _rt.crew_controller(0) as CrewController


## Real OS capture can need a gesture: click like a player would (that click must not fire).
func _ensure_captured(c: CrewController) -> void:
	if MouseCapture.is_captured():
		return
	_click()
	await wait_frames(3)
	assert_false(c.intent.fire, "the capture click does not fire")


func _click() -> void:
	if _has_xdotool():
		OS.execute("xdotool", ["click", "1"])
	else:
		for down: bool in [true, false]:
			var ev: InputEventMouseButton = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = get_viewport().get_visible_rect().size * 0.5
			Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _move(dx: int) -> void:
	if _has_xdotool():
		OS.execute("xdotool", ["mousemove_relative", "--", str(dx), "0"])
	else:
		_inp.look(float(dx), 0.0)


func _has_xdotool() -> bool:
	return _windowed() and OS.execute("which", ["xdotool"]) == 0


func test_rule_owner_release_focus() -> void:
	var o: RefCounted = RefCounted.new()
	assert_false(MouseCapture.wants_capture(), "no owner: visible")
	MouseCapture.set_gameplay_active(o, true)
	assert_true(MouseCapture.wants_capture(), "owner active: capture")
	MouseCapture.push_release(&"pause")
	MouseCapture.push_release(&"pause")
	MouseCapture.push_release(&"chat")
	assert_false(MouseCapture.wants_capture(), "release held: visible")
	MouseCapture.pop_release(&"pause")
	assert_false(MouseCapture.wants_capture(), "one release still held")
	MouseCapture.pop_release(&"chat")
	assert_true(MouseCapture.wants_capture(), "all releases popped: capture")
	MouseCapture._set_focused(false)
	assert_false(MouseCapture.wants_capture(), "window unfocused: visible")
	MouseCapture._set_focused(true)
	assert_true(MouseCapture.wants_capture(), "focus back: capture")
	MouseCapture.set_gameplay_active(o, false)
	assert_false(MouseCapture.wants_capture(), "owner inactive: visible")


func test_freed_owner_drops_out() -> void:
	var n: Node = Node.new()
	MouseCapture.set_gameplay_active(n, true)
	n.free()
	assert_false(MouseCapture.wants_capture(), "a freed owner no longer holds the capture")


func test_player_input_owns_gameplay_capture() -> void:
	var c: CrewController = await _launch_glasshouse()
	assert_true(MouseCapture.wants_capture(), "live local PlayerInput in a heist wants the capture")
	c.set_input_paused(true)
	assert_false(MouseCapture.wants_capture(), "paused input releases it")
	c.set_input_paused(false)
	assert_true(MouseCapture.wants_capture(), "resumed input captures again")
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	assert_false(MouseCapture.wants_capture(), "heist torn down: visible")


func test_windowed_heist_captures_and_mouse_turns() -> void:
	if not _windowed():
		skip("needs a window (xvfb-run, not --headless)")
		return
	var c: CrewController = await _launch_glasshouse()
	await _ensure_captured(c)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "heist: mouse CAPTURED")
	var yaw0: float = c.look_yaw
	for _i: int in 10:
		_move(40)
		await wait_physics_frames(1)
	await wait_physics_frames(3)
	assert_true(c.look_yaw < yaw0 - 0.2, "moving the mouse right turns right (yaw %.3f -> %.3f)" % [yaw0, c.look_yaw])


func test_windowed_release_and_focus() -> void:
	if not _windowed():
		skip("needs a window (xvfb-run, not --headless)")
		return
	var c: CrewController = await _launch_glasshouse()
	await _ensure_captured(c)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "captured in heist")
	MouseCapture.push_release(&"pause")
	await wait_frames(2)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "pause release: VISIBLE")
	MouseCapture.pop_release(&"pause")
	await wait_frames(2)
	await _ensure_captured(c)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "release popped: CAPTURED")
	var n: Node = MouseCapture.notifier() as Node
	n.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await wait_frames(2)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "focus out: VISIBLE")
	n.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await wait_frames(2)
	await _ensure_captured(c)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "focus in: CAPTURED")


## A Control left focused (menu / HUD button after launch) loses focus when the game captures the mouse.
func test_windowed_capture_drops_stale_gui_focus() -> void:
	if not _windowed():
		skip("needs a window (xvfb-run, not --headless)")
		return
	var c: CrewController = await _launch_glasshouse()
	MouseCapture.push_release(&"menu")
	await wait_frames(2)
	var b: Button = Button.new()
	b.text = "stale"
	add_child(b)
	b.grab_focus()
	assert_true(c.get_node(^"PlayerInput").call(&"ui_has_focus"), "focused button blocks gameplay")
	MouseCapture.pop_release(&"menu")
	await wait_frames(2)
	await _ensure_captured(c)
	await wait_frames(2)
	assert_false(b.has_focus(), "capture released the stale focus")
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	assert_true(c.masked, "mask-up works after the capture")
	b.queue_free()
