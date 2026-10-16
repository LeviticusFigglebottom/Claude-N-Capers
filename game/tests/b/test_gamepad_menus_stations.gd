## D-115 gamepad-only pass, part 2: the other hub stations (masks, jukebox, notoriety, profile, achievements,
## crew / lobby connect, drop-in), the lobby host + client views (real ENet loopback), the payday (result +
## card pick) and the firing range panels. Same checks as test_gamepad_menus.gd (helpers: gamepad_walk.gd).
extends "res://tests/b/gamepad_walk.gd"


# --- other hub stations -------------------------------------------------------------------------------------


func test_masks() -> void:
	var s: Control = await _station(&"masks")
	await _assert_walk(s, "masks")
	await _assert_cancel("masks", _hub_shown())


func test_jukebox() -> void:
	var s: Control = await _station(&"jukebox")
	await _assert_walk(s, "jukebox")
	await _assert_cancel("jukebox", _hub_shown())


func test_notoriety() -> void:
	var s: Control = await _station(&"notoriety")
	await _assert_walk(s, "notoriety")
	await _assert_cancel("notoriety", _hub_shown())


func test_profile() -> void:
	var s: Control = await _station(&"profile")
	await _assert_walk(s, "profile / career")
	await _assert_cancel("profile / career", _hub_shown())


func test_achievements() -> void:
	var f: MenuFlow = await _new_flow()
	f.show_hub()
	f.call(&"_open_achievements")
	await wait_frames(3)
	await _assert_walk(f.current, "achievements")
	await _assert_cancel("achievements", _hub_shown())


func test_crew_station_connect_view() -> void:
	var s: Control = await _station(&"crew")
	assert_true(s is LobbyScreen, "crew opens the lobby")
	await _assert_walk(s, "lobby (connect)")
	await _assert_cancel("lobby (connect)", _hub_shown())


## The lobby's "drop in to a running heist" screen (nothing listens on the port: it shows the join state).
func test_drop_in_screen() -> void:
	await _station(&"crew")
	_flow.call(&"_open_drop_in", "127.0.0.1", _port + 7)
	await wait_frames(3)
	var d: Control = _flow.drop_in_screen
	await _assert_walk(d, "drop-in join")
	await _assert_cancel("drop-in join", _current_is(_flow.lobby_screen))


## The 3D safehouse's pause menu (Quick Stations); standalone, since ENV C's safehouse scene may be absent.
func test_safehouse_pause_menu() -> void:
	var m: SafehousePauseMenu = SafehousePauseMenu.new()
	add_child(m)
	_nodes.append(m)
	await wait_frames(3)
	await _assert_walk(m, "safehouse pause")
	var back: Array[int] = [0]
	m.back_requested.connect(func() -> void: back[0] += 1)
	await _assert_cancel("safehouse pause", func() -> bool: return back[0] > 0)


# --- lobby host + client (real ENet loopback, like test_pp_lobby_720p) --------------------------------------


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


func _lobby_screen(s: LobbySession) -> LobbyScreen:
	var screen: LobbyScreen = LOBBY_SCENE.instantiate() as LobbyScreen
	screen.setup(s, s.profile)
	add_child(screen)
	_nodes.append(screen)
	await wait_frames(3)
	return screen


func test_lobby_host_and_client_views() -> void:
	var host: LobbySession = _session(_branch("HostBranch"), "Host Hana")
	var client: LobbySession = _session(_branch("ClientBranch"), "Client Cole")
	assert_eq(host.host(_port), OK)
	assert_eq(client.join("127.0.0.1", _port), OK)
	assert_true(await wait_until(func() -> bool:
		return client.state.local_slot >= 0 and host.state.summaries.has(client.state.local_slot) \
			and client.state.summaries.has(host.state.local_slot), 10.0), "pair connected")
	assert_true(host.set_contract(HEIST, Enums.Difficulty.ROUTINE, false))
	await wait_frames(5)
	var hs: LobbyScreen = await _lobby_screen(host)
	hs.focus_default()
	await _assert_walk(hs, "lobby (host)")
	var back: Array[int] = [0]
	hs.back_requested.connect(func() -> void: back[0] += 1)
	await _assert_cancel("lobby (host)", func() -> bool: return back[0] > 0)
	hs.visible = false
	var cs: LobbyScreen = await _lobby_screen(client)
	cs.focus_default()
	await _assert_walk(cs, "lobby (client)")
	var cback: Array[int] = [0]
	cs.back_requested.connect(func() -> void: cback[0] += 1)
	await _assert_cancel("lobby (client)", func() -> bool: return cback[0] > 0)


# --- payday + range -----------------------------------------------------------------------------------------


func test_payday_result_and_cards() -> void:
	SaveService.delete_profile(SLOT)
	var s: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	add_child(s)
	_nodes.append(s)
	await wait_frames(1)
	s.show_result(HeistCatalog.sample_result())
	s.continue_pressed.connect(func() -> void: pass)
	await wait_frames(3)
	s.skip_count()
	await _assert_walk(s, "payday (result)")
	if s.has_card_pick():
		s.continue_button.grab_focus()
		_press(&"ui_accept")
		await wait_frames(2)
		assert_true(s.cards_stage, "A on Continue opens the cards")
		s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
		await _assert_walk(s, "payday (cards)")
	# The payday has no Back (PD2: results always continue); B must not leave it or break focus.
	_press(&"ui_cancel")
	await wait_frames(2)
	assert_true(s.is_visible_in_tree() and _focus() != null and s.is_ancestor_of(_focus()), "payday: B keeps the screen and its focus")


func test_firing_range_panels() -> void:
	var r: FiringRange = RANGE_SCENE.instantiate() as FiringRange
	add_child(r)
	_nodes.append(r)
	await wait_frames(3)
	var o: RangeOverlay = r.overlay
	assert_true(o != null, "range overlay")
	if o == null:
		return
	if not o.interactive:
		o.set_interactive(true)
	await wait_frames(2)
	await _assert_walk(o, "firing range panels")
	var left: Array[int] = [0]
	o.exit_requested.connect(func() -> void: left[0] += 1)
	await _assert_cancel("firing range", func() -> bool: return left[0] > 0)
