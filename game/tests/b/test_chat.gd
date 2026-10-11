## B6-03: chat validation (ChatLog / LobbyState.MSG_CHAT: attribution, length, control characters, rate limit,
## history cap), a round trip over a real ENet loopback (two Net instances in one process), and the ChatPanel
## (plain-text lines, lobby / overlay modes, gameplay input paused while typing, fade when closed).
extends TestCase

var _port: int = 0


class FakeCrew:
	extends Node
	var slot: int = -1
	var paused: bool = false

	func set_input_paused(p: bool) -> void:
		paused = p


func before_all() -> void:
	_port = BTestUtil.port(13)


func after_each() -> void:
	for c: Node in get_children():
		if c is ChatPanel or c is FakeCrew or c is LobbySession:
			c.queue_free()
	BTestUtil.free_net_branches(self)
	CrewInput.clear()
	Log.capture = false
	Log.captured.clear()
	await wait_frames(2)


func _crew() -> Dictionary:
	return {
		0: {"peer_id": 1, "is_ai": false, "display_name": "Host"},
		1: {"peer_id": 7, "is_ai": false, "display_name": "Player 7"},
		2: {"peer_id": 0, "is_ai": true, "display_name": "AI 2"},
		3: {"peer_id": 0, "is_ai": true, "display_name": "AI 3"},
	}


func _state() -> LobbyState:
	var s: LobbyState = LobbyState.new(true)
	s.set_crew(_crew(), 0, 0)
	return s


func _chat(s: LobbyState, slot: int, text: Variant, now: float = 0.0) -> StringName:
	s.now_s = now
	return s.receive(slot, LobbyState.MSG_CHAT, {"text": text})


func test_clean_text_strips_controls_and_caps_length() -> void:
	assert_eq(ChatLog.clean_text("  hello   world  ", 160), "hello world")
	assert_eq(ChatLog.clean_text("a\u0001b\u0007c\u001bd\u007fe\u0085f", 160), "abcdef", "C0 / DEL / C1 dropped")
	assert_eq(ChatLog.clean_text("line\none\ttab\r\n", 160), "line one tab", "newline / tab become one space")
	assert_eq(ChatLog.clean_text("evil\u202eflip\u200bzw\u2028sep\ufeff", 160), "evilflipzwsep", "bidi / zero-width / separators")
	assert_eq(ChatLog.clean_text("ünïcødé ✓ 漢字", 160), "ünïcødé ✓ 漢字", "printable unicode kept")
	assert_eq(ChatLog.clean_text("[b]bold[/b] [url=x]y[/url]", 160), "[b]bold[/b] [url=x]y[/url]", "BBCode stays literal text")
	assert_eq(ChatLog.clean_text("abcdefghij", 4), "abcd")
	assert_eq(ChatLog.clean_text("\u0001\u0002 \n ", 160), "", "nothing printable")


func test_attribution_is_the_sender_slot() -> void:
	var s: LobbyState = _state()
	assert_eq(s.receive(1, LobbyState.MSG_CHAT, {"text": "hi", "slot": 0, "name": "Host"}), LobbyState.OK)
	var e: Dictionary = s.chat.last()
	assert_eq(int(e["slot"]), 1, "the sender's slot, not a payload field")
	assert_eq(String(e["name"]), "Player 7", "name from the sender's slot")
	assert_eq(String(e["text"]), "hi")
	assert_eq(s.receive(2, LobbyState.MSG_CHAT, {"text": "beep"}), LobbyState.R_BAD_SENDER, "AI slots cannot chat")
	assert_eq(s.receive(-1, LobbyState.MSG_CHAT, {"text": "who"}), LobbyState.R_BAD_SENDER, "unknown peer")
	assert_eq(s.chat.entries.size(), 1)


func test_summary_name_and_control_characters_in_names() -> void:
	var s: LobbyState = _state()
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Wr\u0007en\nX"
	assert_eq(s.receive(1, LobbyState.MSG_PROFILE, LobbyState.summary_from(p.loadout, p)), LobbyState.OK)
	assert_eq(_chat(s, 1, "yo"), LobbyState.OK)
	assert_eq(String(s.chat.last()["name"]), "Wren X", "summary name, cleaned")


func test_payload_validation_and_length_cap() -> void:
	var s: LobbyState = _state()
	assert_eq(_chat(s, 1, 42), LobbyState.R_BAD_PAYLOAD, "text must be a String")
	assert_eq(s.receive(1, LobbyState.MSG_CHAT, {}), LobbyState.R_BAD_PAYLOAD)
	assert_eq(_chat(s, 1, " \n\u0003 "), LobbyState.R_EMPTY)
	var long: String = "x".repeat(s.chat.max_length * 10)
	assert_eq(_chat(s, 1, long), LobbyState.OK)
	assert_eq(String(s.chat.last()["text"]).length(), s.chat.max_length, "cut to chat_max_length")
	assert_eq(s.chat.max_length, LobbyTweak.load_default().chat_max_length)


func test_rate_limit_per_sender() -> void:
	var s: LobbyState = _state()
	var n: int = s.chat.rate_count
	var window: float = s.chat.rate_window_s
	for i: int in range(n):
		assert_eq(_chat(s, 1, "m%d" % i, 10.0 + i * 0.1), LobbyState.OK, "message %d inside the limit" % i)
	assert_eq(_chat(s, 1, "spam", 10.0 + n * 0.1), LobbyState.R_RATE_LIMITED)
	assert_false(s.chat.can_send(1, 10.0 + n * 0.1))
	assert_eq(_chat(s, 0, "host is fine", 10.0 + n * 0.1), LobbyState.OK, "limit is per sender")
	assert_eq(s.chat.entries.size(), n + 1, "the rejected message was not logged")
	assert_eq(_chat(s, 1, "later", 10.0 + window + 0.05), LobbyState.OK, "the first message left the window")
	s.reset(true)
	assert_true(s.chat.entries.is_empty(), "reset clears the log")


func test_history_cap() -> void:
	var tw: LobbyTweak = LobbyTweak.new()
	tw.chat_history_cap = 3
	tw.chat_rate_count = 100
	var chat_log: ChatLog = ChatLog.new(tw)
	for i: int in range(5):
		assert_eq(chat_log.receive(0, "A", ChatLog.message("m%d" % i), float(i)), ChatLog.R_OK)
	assert_eq(chat_log.entries.size(), 3)
	assert_eq(String(chat_log.entries[0]["text"]), "m2", "oldest dropped")
	assert_true(int(chat_log.entries[2]["id"]) > int(chat_log.entries[0]["id"]))


func _session(net: Node, player_name: String) -> LobbySession:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = player_name
	var s: LobbySession = LobbySession.new()
	s.net = net
	s.profile = p
	net.get_parent().add_child(s)
	return s


func _pair() -> Array[LobbySession]:
	var host: LobbySession = _session(BTestUtil.net_branch(self, "HostBranch"), "Host Hana")
	var client: LobbySession = _session(BTestUtil.net_branch(self, "ClientBranch"), "Client Cole")
	assert_eq(host.host(_port), OK, "host on %d" % _port)
	assert_eq(client.join("127.0.0.1", _port), OK)
	var ok: bool = await wait_until(func() -> bool:
		return client.state.local_slot >= 0 and host.state.summaries.has(client.state.local_slot) \
			and client.state.summaries.has(0), 10.0)
	assert_true(ok, "client joined and summaries crossed")
	return [host, client] as Array[LobbySession]


func test_round_trip_over_loopback() -> void:
	var pair: Array[LobbySession] = await _pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	var host_got: Array[Dictionary] = []
	host.chat_received.connect(func(e: Dictionary) -> void: host_got.append(e))
	assert_eq(client.send_chat("  hello\u0001 crew [b]x[/b] "), LobbyState.OK)
	var both: Callable = func() -> bool: return host.state.chat.entries.size() == 1 and client.state.chat.entries.size() == 1
	assert_true(await wait_until(both, 5.0), "the line reached both peers")
	for s: LobbySession in pair:
		var e: Dictionary = s.state.chat.last()
		assert_eq(int(e["slot"]), 1, "attributed to the client's slot")
		assert_eq(String(e["name"]), "Client Cole")
		assert_eq(String(e["text"]), "hello crew [b]x[/b]")
	assert_eq(host_got.size(), 1, "chat_received on the host")
	assert_eq(host.send_chat("back at you"), LobbyState.OK)
	assert_true(await wait_until(func() -> bool: return client.state.chat.entries.size() == 2, 5.0))
	assert_eq(int(client.state.chat.last()["slot"]), 0)
	assert_eq(client.send_chat(" \n "), LobbyState.R_EMPTY, "nothing sent")


func test_spammer_is_limited_on_the_receiver() -> void:
	var pair: Array[LobbySession] = await _pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	Log.capture = true
	var n: int = host.state.chat.rate_count
	for i: int in range(n + 3):
		client.net.call(&"lobby_send", LobbyState.MSG_CHAT, ChatLog.message("spam %d" % i))  # bypasses send_chat
	assert_true(await wait_until(func() -> bool: return client.state.chat.entries.size() >= n, 5.0))
	await wait_frames(10)
	assert_eq(host.state.chat.entries.size(), n, "the host keeps only rate_count lines")
	assert_eq(client.send_chat("one more"), LobbyState.R_RATE_LIMITED, "the sender's own check agrees")


func _panel(session: LobbySession, mode: ChatPanel.Mode) -> ChatPanel:
	var c: ChatPanel = ChatPanel.new()
	c.setup(session, mode)
	add_child(c)
	return c


func test_panel_draws_plain_text_and_history() -> void:
	var pair: Array[LobbySession] = await _pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	client.send_chat("[color=red]red?[/color]")
	assert_true(await wait_until(func() -> bool: return host.state.chat.entries.size() == 1, 5.0))
	var panel: ChatPanel = _panel(host, ChatPanel.Mode.LOBBY)
	await wait_frames(1)
	assert_eq(panel.line_count(), 1, "history replayed on bind")
	assert_true(panel.line_label(0) is Label, "a Label, never a RichTextLabel")
	assert_eq(panel.line_label(0).text, UiText.t(&"ui.chat.line", {"name": "Client Cole"}) + " [color=red]red?[/color]")
	assert_true(panel.input.visible, "lobby input always shown")
	assert_eq(panel.send("from the panel"), LobbyState.OK)
	assert_true(await wait_until(func() -> bool: return panel.line_count() == 2, 5.0), "own line comes back")
	assert_eq(ChatPanel.line_text({"name": "{text}", "text": "x"}), UiText.t(&"ui.chat.line", {"name": "{text}"}) + " x",
		"player text is never a format template")


func test_overlay_pauses_local_input_and_fades() -> void:
	var pair: Array[LobbySession] = await _pair()
	var client: LobbySession = pair[1]
	var me: FakeCrew = FakeCrew.new()
	me.slot = client.state.local_slot
	me.add_to_group(G.CREW)
	var other: FakeCrew = FakeCrew.new()
	other.slot = 0
	other.add_to_group(G.CREW)
	add_child(me)
	add_child(other)
	var panel: ChatPanel = _panel(client, ChatPanel.Mode.OVERLAY)
	await wait_frames(1)
	assert_false(panel.input.visible, "overlay input hidden until opened")
	assert_eq(panel.modulate.a, 0.0, "empty overlay is invisible")
	assert_true(InputMap.has_action(&"chat"), "project.godot has the chat action (D-072)")
	var enter: InputEventKey = InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	assert_true(panel.is_open_event(enter), "Enter opens the chat")
	var kp: InputEventKey = InputEventKey.new()
	kp.physical_keycode = KEY_KP_ENTER
	kp.pressed = true
	assert_true(panel.is_open_event(kp), "keypad Enter opens the chat")
	var t_key: InputEventKey = InputEventKey.new()
	t_key.physical_keycode = KEY_T
	t_key.keycode = KEY_T
	t_key.pressed = true
	assert_false(panel.is_open_event(t_key), "T is order_menu, not chat")
	panel.open()
	assert_true(panel.is_open and panel.input.visible)
	assert_true(me.paused, "local crew member's input paused while typing")
	assert_false(other.paused, "other crew members untouched")
	panel.input.text = "on my way"
	panel.input.text_submitted.emit(panel.input.text)
	assert_false(panel.is_open, "Enter sends and closes")
	assert_false(me.paused, "input given back")
	assert_true(await wait_until(func() -> bool: return panel.line_count() == 1, 5.0), "line drawn")
	assert_eq(panel.modulate.a, 1.0, "a new line shows the panel")
	panel._process(panel.tweak.chat_fade_after_s - 0.1)
	assert_eq(panel.modulate.a, 1.0, "still shown before the fade")
	panel._process(0.1 + panel.tweak.chat_fade_time_s * 0.5)
	assert_true(panel.modulate.a > 0.0 and panel.modulate.a < 1.0, "fading")
	panel._process(panel.tweak.chat_fade_time_s)
	assert_eq(panel.modulate.a, 0.0, "faded out")
	panel.open()
	assert_eq(panel.modulate.a, 1.0, "opening shows the history")
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	panel.input.gui_input.emit(esc)
	assert_false(panel.is_open, "Esc closes")
	assert_false(me.paused)


func test_chat_pause_keeps_the_options_pause() -> void:
	var me: FakeCrew = FakeCrew.new()
	me.slot = 0
	me.add_to_group(G.CREW)
	add_child(me)
	CrewInput.set_paused(get_tree(), &"options", true, 0)
	CrewInput.set_paused(get_tree(), ChatPanel.PAUSE_HOLDER, true, 0)
	CrewInput.set_paused(get_tree(), ChatPanel.PAUSE_HOLDER, false, 0)
	assert_true(me.paused, "options still holds the pause")
	CrewInput.set_paused(get_tree(), &"options", false, 0)
	assert_false(me.paused)
