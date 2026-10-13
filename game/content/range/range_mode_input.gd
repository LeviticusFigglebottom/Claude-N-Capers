## Panel mode / aim mode switching while ENV A's crew is the range shooter (B1-05). Owner: ENV B.
## (File name contains `input`: it polls the `fire` action, check_banned.py rule.)
##
## Aim mode: the crew's PlayerInput drives the crew (crew_intent.md); the mouse is captured.
## Tab / Esc or gamepad Start / Back return to the panels. Panel mode: the crew's input is paused
## (RangeCrewBridge.set_input_enabled), the mouse is free, and a left click on the range view
## (a click no panel consumed) asks for aim mode. The click that enters aim mode must not fire: the
## crew input resumes only once `fire` is released.
class_name RangeModeInput
extends Node

signal aim_requested(on: bool)

var crew: Node = null
var aim_active: bool = false

var _await_release: bool = false


func set_aim_active(on: bool) -> void:
	aim_active = on
	_await_release = on
	RangeCrewBridge.set_input_enabled(crew, false)
	if on:
		_try_resume()
	# input_focus.md 1.1: aim mode = the crew's PlayerInput enabled -> MouseCapture captures; the panels
	# (aim off) hold the cursor with the &"menu" release.
	if on:
		MouseCapture.pop_release(&"menu")
	else:
		MouseCapture.push_release(&"menu")


func _physics_process(_delta: float) -> void:
	if aim_active and _await_release:
		_try_resume()


func _try_resume() -> void:
	if InputMap.has_action(&"fire") and Input.is_action_pressed(&"fire"):
		return
	_await_release = false
	RangeCrewBridge.set_input_enabled(crew, true)


func _exit_tree() -> void:
	MouseCapture.pop_release(&"menu")


func _unhandled_input(event: InputEvent) -> void:
	if not aim_active:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			aim_requested.emit(true)
		return
	var back: bool = false
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		back = key.physical_keycode == KEY_TAB or key.physical_keycode == KEY_ESCAPE
	var jb: InputEventJoypadButton = event as InputEventJoypadButton
	if jb != null and jb.pressed:
		back = jb.button_index in [JOY_BUTTON_START, JOY_BUTTON_BACK]  # B is reload on the crew map
	if back:
		get_viewport().set_input_as_handled()
		aim_requested.emit(false)
