## Text chat panel (B6-03), one widget for the lobby screen and the in-heist overlay. Owner: ENV B.
## Bound to a LobbySession (setup()): sends with LobbySession.send_chat (Net.lobby_send, which also works in a
## heist), draws LobbySession.chat_received, and starts with the session's history (lobby chat carries into
## the heist). Every line is a plain Label: player text is never parsed as BBCode.
## * Mode.LOBBY: history + input always shown; the chat key focuses the input, Esc leaves it.
## * Mode.OVERLAY (heist): only the history shows, fading out LobbyTweak.chat_fade_after_s after the last
##   message (over chat_fade_time_s). The chat key opens the input; while it is open the local crew member's
##   gameplay input is paused (CrewInput holder &"chat", the B5-01 options mechanism). Enter sends and
##   closes; Esc closes.
## Crew notices (B6-04): LobbySession.kick_notice draws a dim system line (`ui.chat.kick_notice`), not logged.
## Open key: the InputMap action LobbyTweak.chat_action (`chat` = Enter / keypad Enter, D-072). No fallback key:
## T is `order_menu`.
class_name ChatPanel
extends PanelContainer

signal opened()
signal closed()

enum Mode { LOBBY, OVERLAY }

const PAUSE_HOLDER: StringName = &"chat"
const LOBBY_MIN_SIZE: Vector2 = Vector2(560, 220)
const OVERLAY_MIN_SIZE: Vector2 = Vector2(620, 0)
const OVERLAY_MARGIN: int = 32

var mode: Mode = Mode.LOBBY
var session: LobbySession = null
var tweak: LobbyTweak = null
var scroll: ScrollContainer
var history_box: VBoxContainer
var input: LineEdit
## Rate-limit notice under the input.
var notice_label: Label
## True while the input is open (overlay) / focused (lobby).
var is_open: bool = false
var _idle_s: float = 0.0
var _built: bool = false


## Bind to `p_session` (before or after entering the tree) in `p_mode`.
func setup(p_session: LobbySession, p_mode: Mode = Mode.LOBBY) -> void:
	if session != null and session != p_session and session.chat_received.is_connected(add_entry):
		session.chat_received.disconnect(add_entry)
	if session != null and session != p_session and session.kick_notice.is_connected(_on_kick_notice):
		session.kick_notice.disconnect(_on_kick_notice)
	session = p_session
	mode = p_mode
	if _built:
		_bind()


func _ready() -> void:
	if tweak == null:
		tweak = LobbyTweak.load_default()
	_build()
	_built = true
	_bind()


func _build() -> void:
	var v: VBoxContainer = UiBuild.vbox(6)
	add_child(v)
	if mode == Mode.LOBBY:
		v.add_child(UiBuild.caption(&"ui.chat.title"))  # PO-4 caption head
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_box = UiBuild.vbox(2)
	history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(history_box)
	v.add_child(scroll)
	input = LineEdit.new()
	input.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	input.placeholder_text = UiText.t(&"ui.chat.placeholder")
	input.max_length = tweak.chat_max_length
	input.focus_mode = Control.FOCUS_ALL
	input.text_submitted.connect(_on_submitted)
	input.gui_input.connect(_on_input_gui)
	input.focus_entered.connect(_on_input_focus.bind(true))
	input.focus_exited.connect(_on_input_focus.bind(false))
	v.add_child(input)
	notice_label = UiBuild.label(&"", UiBuild.DIM)
	notice_label.add_theme_color_override(&"font_color", tweak.illegal_color)
	v.add_child(notice_label)
	if mode == Mode.OVERLAY:
		custom_minimum_size = OVERLAY_MIN_SIZE
		theme_type_variation = UiBuild.HUD_PANEL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll.custom_minimum_size = Vector2(0, 260)
		set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, OVERLAY_MARGIN)
		input.visible = false
		_idle_s = tweak.chat_fade_after_s + tweak.chat_fade_time_s
		modulate.a = 0.0
	else:
		custom_minimum_size = LOBBY_MIN_SIZE


func _bind() -> void:
	for c: Node in history_box.get_children():
		history_box.remove_child(c)
		c.queue_free()
	if session == null:
		return
	if not session.chat_received.is_connected(add_entry):
		session.chat_received.connect(add_entry)
	if not session.kick_notice.is_connected(_on_kick_notice):
		session.kick_notice.connect(_on_kick_notice)
	for e: Dictionary in session.chat_history():
		add_entry(e)


## Open the input (overlay: show it and pause gameplay input; lobby: focus it).
func open() -> void:
	if is_open:
		return
	is_open = true
	input.visible = true
	input.editable = true
	notice_label.text = ""
	_idle_s = 0.0
	modulate.a = 1.0
	if mode == Mode.OVERLAY:
		CrewInput.set_paused(get_tree(), PAUSE_HOLDER, true, _local_slot())
	if input.is_inside_tree():
		input.grab_focus()
	opened.emit()


## Close the input (the typed text is dropped in the overlay) and give gameplay input back.
func close() -> void:
	if not is_open:
		return
	is_open = false
	_idle_s = 0.0
	if input.has_focus():
		input.release_focus()
	if mode == Mode.OVERLAY:
		input.text = ""
		input.visible = false
		CrewInput.set_paused(get_tree(), PAUSE_HOLDER, false, _local_slot())
	closed.emit()


## Send `text` through the session. Returns LobbyState.OK or the reason (rate limit shows a notice).
func send(text: String) -> StringName:
	if session == null:
		return LobbyState.R_BAD_SENDER
	var r: StringName = session.send_chat(text)
	notice_label.text = UiText.t(&"ui.chat.rate_limited") if r == LobbyState.R_RATE_LIMITED else ""
	return r


## Draw one log entry (also used for history replay). Oldest lines beyond chat_history_cap are dropped.
func add_entry(entry: Dictionary) -> void:
	_add_line(line_text(entry), false)


## Draw a system line (plain text, dimmed): crew notices such as a kick.
func add_notice(text: String) -> void:
	_add_line(text, true)


func _on_kick_notice(_slot: int, player_name: String) -> void:
	add_notice(UiText.t(&"ui.chat.kick_notice", {"name": player_name}))


func _add_line(text: String, dim: bool) -> void:
	var l: Label = Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mode == Mode.OVERLAY:
		l.theme_type_variation = UiBuild.HUD
	elif dim:
		l.theme_type_variation = UiBuild.DIM
	if dim:
		l.modulate = Color(1, 1, 1, 0.75)
	l.text = text
	history_box.add_child(l)
	while history_box.get_child_count() > tweak.chat_history_cap:
		var old: Node = history_box.get_child(0)
		history_box.remove_child(old)
		old.queue_free()
	_idle_s = 0.0
	modulate.a = 1.0
	_scroll_to_end.call_deferred()


func line_count() -> int:
	return history_box.get_child_count()


## The Label of line `i` (0 = oldest shown).
func line_label(i: int) -> Label:
	return history_box.get_child(i) as Label


## "<name>: <text>" as plain text. Player strings are concatenated, never used as a format template.
static func line_text(entry: Dictionary) -> String:
	return UiText.t(&"ui.chat.line", {"name": String(entry.get("name", ""))}) + " " + String(entry.get("text", ""))


func _process(delta: float) -> void:
	if mode != Mode.OVERLAY or is_open:
		return
	_idle_s += delta
	var fade: float = clampf((_idle_s - tweak.chat_fade_after_s) / maxf(tweak.chat_fade_time_s, 0.001), 0.0, 1.0)
	modulate.a = 1.0 - fade


func _unhandled_input(event: InputEvent) -> void:
	if is_open or not is_visible_in_tree() or session == null or not is_open_event(event):
		return
	get_viewport().set_input_as_handled()
	open()


## True for the chat key press (the `chat` action; false while the action is missing).
func is_open_event(event: InputEvent) -> bool:
	return InputMap.has_action(tweak.chat_action) and event.is_action_pressed(tweak.chat_action)


func _on_submitted(text: String) -> void:
	var r: StringName = send(text) if text.strip_edges() != "" else LobbyState.R_EMPTY
	if r == LobbyState.R_RATE_LIMITED:
		return
	input.text = ""
	if mode == Mode.OVERLAY:
		close()
	else:
		input.grab_focus.call_deferred()


func _on_input_gui(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		input.accept_event()
		close()


func _on_input_focus(focused: bool) -> void:
	if mode != Mode.LOBBY:
		return
	if focused and not is_open:
		is_open = true
		opened.emit()
	elif not focused and is_open:
		close()


func _scroll_to_end() -> void:
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _local_slot() -> int:
	return session.state.local_slot if session != null else -1


func _exit_tree() -> void:
	if mode == Mode.OVERLAY and CrewInput.is_held(PAUSE_HOLDER):
		CrewInput.set_paused(get_tree(), PAUSE_HOLDER, false, _local_slot())
