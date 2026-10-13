## The rebind list of the options screen (B5-01). Owner: ENV B.
## One row per game action (InputBindings.actions()): name, Keyboard/Mouse button, Gamepad button,
## Reset. Pressing a binding button starts a "press a key" capture for that column (Esc or
## CAPTURE_TIMEOUT_S cancels; every key / pad event is swallowed meanwhile). A captured input that
## another action uses (InputBindings.conflicts) opens the conflict bar: Swap / Keep both / Cancel.
## Edits go to `settings` (the screen's draft); the screen applies them.
## Test API: begin_capture(action, column), submit_capture(binding dict), resolve_conflict(choice).
class_name OptionsControlsTab
extends VBoxContainer

signal bindings_changed()

const CAPTURE_TIMEOUT_S: float = 6.0
const SWAP: StringName = &"swap"
const KEEP: StringName = &"keep"
const CANCEL: StringName = &"cancel"

var settings: GameSettings
## action -> {"kbm": Button, "pad": Button, "reset": Button}
var rows: Dictionary = {}
var reset_all_button: Button
var conflict_bar: PanelContainer
var conflict_label: Label
var swap_button: Button
var keep_button: Button
var cancel_button: Button
var capture_label: Label
## Pending capture {action, column} ({} = none) and pending conflict {action, binding, others}.
var capturing: Dictionary = {}
var pending_conflict: Dictionary = {}
var _capture_t: float = 0.0


func setup(s: GameSettings) -> void:
	settings = s
	add_theme_constant_override(&"separation", UiTokens.S2)
	capture_label = UiBuild.label(&"ui.options.controls.press_key", UiBuild.SUBHEADER)
	capture_label.visible = false
	add_child(capture_label)
	_build_conflict_bar()
	var head: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	for k: StringName in [&"ui.options.controls.action", &"ui.options.controls.kbm", &"ui.options.controls.pad"]:
		var l: Label = UiBuild.caption(k)
		l.custom_minimum_size = Vector2(OptionsRows.LABEL_WIDTH if k == &"ui.options.controls.action" else 300.0, 0)
		head.add_child(l)
	add_child(head)
	for action: StringName in InputBindings.actions():
		add_child(_row(action))
	reset_all_button = UiBuild.button(&"ui.options.controls.reset_all")
	reset_all_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_all_button.pressed.connect(func() -> void:
		InputBindings.reset_all(settings)
		refresh())
	add_child(reset_all_button)
	refresh()


## Controls for the screen's vertical focus chain (the KB/M column, then Reset all).
func focus_controls() -> Array[Control]:
	var out: Array[Control] = []
	for action: StringName in InputBindings.actions():
		out.append((rows[action] as Dictionary)[InputEventCodec.KBM] as Control)
	out.append(reset_all_button)
	return out


func refresh() -> void:
	for action: Variant in rows:
		var r: Dictionary = rows[action]
		for col: StringName in InputEventCodec.COLUMNS:
			(r[col] as Button).text = InputBindings.column_text(settings, StringName(action), col)
		(r["reset"] as Button).disabled = (settings.get_value(GameSettings.BINDINGS, StringName(action)) as Dictionary).is_empty()


func is_capturing() -> bool:
	return not capturing.is_empty()


func begin_capture(action: StringName, column: StringName) -> void:
	cancel_conflict()
	capturing = {"action": action, "column": column}
	_capture_t = CAPTURE_TIMEOUT_S
	capture_label.text = UiText.t(&"ui.options.controls.press_key" if column == InputEventCodec.KBM else &"ui.options.controls.press_pad",
			{"action": UiText.t(InputBindings.name_key(action))})
	capture_label.visible = true
	((rows[action] as Dictionary)[column] as Button).text = UiText.t(&"ui.options.controls.waiting")
	set_process(true)


func cancel_capture() -> void:
	var was: Dictionary = capturing
	capturing = {}
	capture_label.visible = false
	set_process(false)
	refresh()
	if not was.is_empty():
		OptionsRows.focus_later((rows[was["action"]] as Dictionary)[was["column"]] as Button)


## Finishes the capture with binding dict `d` (InputEventCodec). Conflicts open the conflict bar.
func submit_capture(d: Dictionary) -> void:
	if capturing.is_empty() or d.is_empty():
		return
	var action: StringName = capturing["action"]
	cancel_capture()
	var others: Array[StringName] = InputBindings.conflicts(settings, action, d)
	if others.is_empty():
		InputBindings.rebind(settings, action, d, false)
		_changed()
		return
	pending_conflict = {"action": action, "binding": d, "others": others}
	var names: PackedStringArray = PackedStringArray()
	for o: StringName in others:
		names.append(UiText.t(InputBindings.name_key(o)))
	conflict_label.text = UiText.t(&"ui.options.controls.conflict",
			{"input": InputEventCodec.text(d), "actions": ", ".join(names), "action": UiText.t(InputBindings.name_key(action))})
	conflict_bar.visible = true
	OptionsRows.focus_later(swap_button)


## SWAP: the other actions take this one's old input; KEEP: both stay bound; CANCEL: nothing changes.
func resolve_conflict(choice: StringName) -> void:
	if pending_conflict.is_empty():
		return
	var c: Dictionary = pending_conflict
	cancel_conflict()
	if choice == SWAP or choice == KEEP:
		InputBindings.rebind(settings, c["action"], c["binding"], choice == SWAP)
		_changed()
	OptionsRows.focus_later((rows[c["action"]] as Dictionary)[InputEventCodec.column_of(c["binding"])] as Button)


func cancel_conflict() -> void:
	pending_conflict = {}
	if conflict_bar != null:
		conflict_bar.visible = false


func _input(event: InputEvent) -> void:
	if capturing.is_empty() or not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and k.physical_keycode == KEY_ESCAPE:
		cancel_capture()
		return
	var d: Dictionary = InputEventCodec.capture(event, StringName(capturing["column"]))
	if not d.is_empty():
		submit_capture(d)


func _process(delta: float) -> void:
	if capturing.is_empty():
		set_process(false)
		return
	_capture_t -= delta
	if _capture_t <= 0.0:
		cancel_capture()


func _ready() -> void:
	set_process(false)


func _row(action: StringName) -> HBoxContainer:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	row.name = "Bind_%s" % action
	var l: Label = UiBuild.caption(InputBindings.name_key(action))
	l.custom_minimum_size = Vector2(OptionsRows.LABEL_WIDTH, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var r: Dictionary = {}
	for col: StringName in InputEventCodec.COLUMNS:
		var b: Button = UiBuild.button(&"ui.options.controls.unbound")
		b.custom_minimum_size = Vector2(300, 0)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(begin_capture.bind(action, col))
		row.add_child(b)
		r[col] = b
	var reset: Button = UiBuild.button(&"ui.options.controls.reset")
	reset.custom_minimum_size = Vector2(140, 0)
	reset.pressed.connect(func() -> void:
		InputBindings.reset_action(settings, action)
		_changed())
	row.add_child(reset)
	r["reset"] = reset
	rows[action] = r
	return row


func _build_conflict_bar() -> void:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	conflict_label = UiBuild.label()
	conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(conflict_label)
	var h: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	swap_button = UiBuild.button(&"ui.options.controls.swap")
	keep_button = UiBuild.button(&"ui.options.controls.keep_both")
	cancel_button = UiBuild.button(&"ui.menu.cancel")
	for pair: Array in [[swap_button, SWAP], [keep_button, KEEP], [cancel_button, CANCEL]]:
		var b: Button = pair[0]
		b.custom_minimum_size = Vector2(220, 0)
		b.pressed.connect(resolve_conflict.bind(pair[1]))
		h.add_child(b)
	v.add_child(h)
	var chain: Array[Control] = [swap_button, keep_button, cancel_button]
	UiNav.chain_horizontal(chain)
	conflict_bar = UiBuild.panel(v, &"AlertPanel")  # PO-4: a binding clash is a warning box
	conflict_bar.visible = false
	add_child(conflict_bar)


func _changed() -> void:
	refresh()
	bindings_changed.emit()
