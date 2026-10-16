## PQ-B-11b (D-076): the co-op lobby screen fits at 1280x720 (1080-unit canvas) in every state:
## connect (no session), host without contract, host with contract + everyone ready, and the
## client's view. Real ENet loopback in one process (same fixture as test_lobby_loopback).
extends TestCase

const NET_SCRIPT: Script = preload("res://core/net.gd")
const LOBBY_SCENE: PackedScene = preload("res://content/ui/lobby/lobby_screen.tscn")

var _branches: Array[Node] = []
var _port: int = 0


func before_all() -> void:
	_port = 21000 + (OS.get_process_id() * 7) % 19000


func after_each() -> void:
	for b: Node in _branches:
		var n: Node = b.get_node_or_null(^"Net")
		if n != null:
			n.call(&"leave")
		get_tree().set_multiplayer(null, b.get_path())
		b.queue_free()
	_branches.clear()
	await wait_frames(2)


func _branch(branch_name: String) -> Node:
	var root: Node = Node.new()
	root.name = branch_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var n: Node = NET_SCRIPT.new() as Node
	n.name = "Net"
	root.add_child(n)
	_branches.append(root)
	return n


func _session(net: Node, player_name: String) -> LobbySession:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = player_name
	var s: LobbySession = LobbySession.new()
	s.net = net
	s.profile = p
	net.get_parent().add_child(s)
	return s


func _pair() -> Array[LobbySession]:
	var host: LobbySession = _session(_branch("HostBranch"), "Host Hana With A Very Long Crew Name")
	var client: LobbySession = _session(_branch("ClientBranch"), "Client Cole")
	assert_eq(host.host(_port), OK)
	assert_eq(client.join("127.0.0.1", _port), OK)
	assert_true(await wait_until(func() -> bool:
		return client.state.local_slot >= 0 and host.state.summaries.has(client.state.local_slot) \
			and client.state.summaries.has(host.state.local_slot), 10.0), "pair connected")
	return [host, client] as Array[LobbySession]


func _offscreen(screen: LobbyScreen) -> Array[String]:
	var out: Array[String] = []
	var vis: Rect2 = screen.get_viewport().get_visible_rect().grow(1.0)
	var extra: Array[Control] = [screen.block_label, screen.status_label, screen.contract_label, screen.error_label]
	for c: Control in screen.focus_chain + extra:
		if c == null or not c.is_visible_in_tree():
			continue
		var n: Node = c.get_parent()
		var scroll: ScrollContainer = null
		while n != null and scroll == null:
			scroll = n as ScrollContainer
			n = n.get_parent()
		var r: Rect2 = scroll.get_global_rect() if scroll != null else c.get_global_rect()
		if not vis.encloses(r):
			out.append("%s %s" % [c.name, r])
	return out


func _screen(s: LobbySession) -> LobbyScreen:
	var screen: LobbyScreen = LOBBY_SCENE.instantiate() as LobbyScreen
	screen.setup(s, s.profile if s != null else PlayerProfile.new_default())
	add_child(screen)
	await wait_frames(3)
	return screen


func _assert_fits(screen: LobbyScreen, state: String) -> void:
	var bad: Array[String] = _offscreen(screen)
	assert_eq(bad.size(), 0, "lobby/%s off-screen at 720p: %s" % [state, ", ".join(bad)])


func test_connect_state_fits_720p() -> void:
	var screen: LobbyScreen = await _screen(null)
	assert_true(screen.connect_box.visible)
	_assert_fits(screen, "connect")
	screen.queue_free()
	await wait_frames(1)


func test_host_and_client_states_fit_720p() -> void:
	var pair: Array[LobbySession] = await _pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	var hs: LobbyScreen = await _screen(host)
	_assert_fits(hs, "host_no_contract")
	assert_true(host.set_contract(&"glasshouse", Enums.Difficulty.HAZARDOUS, true))
	client.set_ready(true)
	host.set_ready(true)
	assert_true(await wait_until(func() -> bool: return host.state.can_start(), 5.0))
	await wait_frames(3)
	_assert_fits(hs, "host_ready")
	var cs: LobbyScreen = await _screen(client)
	_assert_fits(cs, "client")
	hs.queue_free()
	cs.queue_free()
	await wait_frames(1)


func _pad(button: JoyButton) -> void:
	UiNav.ensure_pad_ui_actions()
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func _nav_to(target: Control) -> bool:
	var dirs: Array[JoyButton] = [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_LEFT]
	var d: int = 0
	var seen: Dictionary = {}
	for _i: int in range(40):
		var f: Control = get_viewport().gui_get_focus_owner()
		if f == target:
			return true
		seen[f] = true
		await _pad(dirs[d])
		if seen.has(get_viewport().gui_get_focus_owner()):
			d = (d + 1) % dirs.size()
	return get_viewport().gui_get_focus_owner() == target


## PQ-B-16: the host readies up and starts with the pad only (contract set by the session = setup).
func test_host_ready_and_start_gamepad_only() -> void:
	var pair: Array[LobbySession] = await _pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	var started: Array[bool] = [false]
	host.started.connect(func(_i: Dictionary) -> void: started[0] = true)
	var hs: LobbyScreen = await _screen(host)
	assert_true(host.set_contract(&"glasshouse", Enums.Difficulty.ROUTINE, false))
	client.set_ready(true)
	await wait_frames(5)
	assert_true(await _nav_to(hs.ready_button), "Ready reachable by d-pad")
	await _pad(JOY_BUTTON_A)
	assert_true(await wait_until(func() -> bool: return host.state.can_start(), 5.0), "A readied the host")
	await wait_frames(3)
	assert_true(await _nav_to(hs.start_button), "Start reachable by d-pad")
	await _pad(JOY_BUTTON_A)
	assert_true(await wait_until(func() -> bool: return started[0], 5.0), "A on Start started the run")
	hs.queue_free()
	await wait_frames(1)


## PO-B-C6: a crew card shows whole (down to the mask row) without scrolling the lobby body, on the host
## (contract set, a Kick on the client's card) and on the client.
func test_crew_cards_whole_without_scrolling() -> void:
	var saved: Vector2i = get_window().size
	get_window().size = Vector2i(1280, 720)
	var pair: Array[LobbySession] = await _pair()
	var host: LobbySession = pair[0]
	assert_true(host.set_contract(&"glasshouse", Enums.Difficulty.HAZARDOUS, true))
	var hs: LobbyScreen = await _screen(host)
	var cs: LobbyScreen = await _screen(pair[1])
	await wait_frames(3)
	for screen: LobbyScreen in [hs, cs]:
		var scroll: ScrollContainer = screen.find_child("LobbyBodyScroll", true, false) as ScrollContainer
		scroll.scroll_vertical = 0
		await wait_frames(2)
		var view: Rect2 = scroll.get_global_rect().intersection(screen.get_viewport().get_visible_rect()).grow(1.0)
		for w: Dictionary in screen.slot_widgets:
			var p: Control = w["panel"] as Control
			if not p.is_visible_in_tree():
				continue
			# End-of-heist sweep: the level / ready line was laid out at width 0 (blank) after C6.
			for k: String in ["level", "ready"]:
				var l: Label = w[k] as Label
				if l.is_visible_in_tree() and l.text != "":
					var need: float = l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
							l.get_theme_font_size(&"font_size")).x
					assert_true(l.size.x + 1.0 >= need, "%s '%s' shown whole (%.0f of %.0f px)" % [k, l.text, l.size.x, need])
			var last: Control = (w["mask"] as Control).get_parent() as Control
			var bottom: float = last.get_global_rect().end.y
			var kick: Control = w["kick"] as Control
			if kick.is_visible_in_tree():
				bottom = maxf(bottom, kick.get_global_rect().end.y)
			assert_true(bottom <= view.end.y, "%s card ends at %.0f, view at %.0f" % [
				"host" if screen == hs else "client", bottom, view.end.y])
		# r223 co-op capture: a card with Kick sat ~6 px lower; the heister rows of every human card line up.
		var ys: Array[float] = []
		for w2: Dictionary in screen.slot_widgets:
			if (w2["panel"] as Control).is_visible_in_tree() and (w2["heister"] as Control).is_visible_in_tree():
				ys.append((w2["heister"] as Control).get_global_rect().position.y)
		for y: float in ys:
			assert_near(y, ys[0], 1.0, "heister rows aligned across cards")
	hs.queue_free()
	cs.queue_free()
	get_window().size = saved
	await wait_frames(1)
