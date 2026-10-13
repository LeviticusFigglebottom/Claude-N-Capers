## The single owner of Input.mouse_mode (D-087, docs/contracts/input_focus.md 1.0). Owner: ENV P.
## No other code writes Input.mouse_mode. Static API:
##   set_gameplay_active(owner, active)  the local human's PlayerInput while live (heist, walkable safehouse, range)
##   push_release(key) / pop_release(key) any UI that needs the cursor (keys: pause, options, payday, menu, chat,
##                                        dropin, station); keys are a set, pushing a held key again is a no-op
##   is_captured() -> bool               the OS mouse mode really is CAPTURED
##   wants_capture() -> bool             the rule below holds (whether or not the OS agreed yet)
##   notifier()                          an object with `signal changed(captured: bool)` (real mode changes)
## Rule: CAPTURED exactly when some owner has gameplay active AND no release is held AND the window has focus;
## otherwise VISIBLE. When the OS refuses the capture (no user gesture yet, focus just came back), the next left
## click in the game viewport captures and is consumed (PlayerInput latches it, so it does not fire).
## On every switch to CAPTURED the GUI focus owner is released: a menu/HUD Control left focused must not eat
## gameplay keys (Space / Enter = ui_accept) while the player is in the game.
class_name MouseCapture
extends RefCounted


## Lives under the root Window: window focus notifications, click-to-capture and retrying a refused capture.
class Notifier:
	extends Node
	signal changed(captured: bool)

	var last_captured: bool = false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		last_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
				MouseCapture._set_focused(false)
			NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
				MouseCapture._set_focused(true)

	func _input(event: InputEvent) -> void:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if MouseCapture.wants_capture() and not MouseCapture.is_captured():
			MouseCapture.capture_clicks += 1
			MouseCapture._apply()
			get_viewport().set_input_as_handled()

	func _process(_delta: float) -> void:
		var now: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if now != last_captured:
			last_captured = now
			if now:
				var vp: Viewport = get_viewport()
				if vp != null:
					vp.gui_release_focus()
			changed.emit(now)


## Instance ids of the owners with gameplay active.
static var _owners: Dictionary[int, bool] = {}
static var _releases: Dictionary[StringName, bool] = {}
static var _focused: bool = true
static var _notifier: Notifier = null
## Diagnostics / tests: left clicks consumed to (re)capture.
static var capture_clicks: int = 0


static func set_gameplay_active(owner: Object, active: bool) -> void:
	if owner == null:
		return
	var id: int = owner.get_instance_id()
	if active == _owners.has(id):
		return
	if active:
		_owners[id] = true
	else:
		_owners.erase(id)
	_apply()


static func push_release(key: StringName) -> void:
	if _releases.has(key):
		return
	_releases[key] = true
	_apply()


static func pop_release(key: StringName) -> void:
	if not _releases.has(key):
		return
	_releases.erase(key)
	_apply()


static func is_released(key: StringName) -> bool:
	return _releases.has(key)


static func is_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


static func wants_capture() -> bool:
	_prune()
	return not _owners.is_empty() and _releases.is_empty() and _focused


static func notifier() -> Object:
	_ensure_notifier()
	return _notifier


## Tests / a fresh session: forget every owner and release (does not touch the OS mode).
static func reset() -> void:
	_owners.clear()
	_releases.clear()
	_focused = true
	capture_clicks = 0


static func _set_focused(f: bool) -> void:
	if f == _focused:
		return
	_focused = f
	_apply()


static func _apply() -> void:
	_ensure_notifier()
	if DisplayServer.get_name() == "headless":
		return
	var want: Input.MouseMode = Input.MOUSE_MODE_CAPTURED if wants_capture() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


## Owners freed without calling set_gameplay_active(false) drop out.
static func _prune() -> void:
	for id: int in _owners.keys():
		if not is_instance_id_valid(id):
			_owners.erase(id)


static func _ensure_notifier() -> void:
	if _notifier != null and is_instance_valid(_notifier):
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_notifier = Notifier.new()
	_notifier.name = "MouseCapture"
	tree.root.add_child.call_deferred(_notifier)
