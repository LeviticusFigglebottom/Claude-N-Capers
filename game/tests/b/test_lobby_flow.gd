## B4-11: the co-op lobby inside the app flow (MenuFlow). The crew station opens the lobby; field
## validation; a hosted session (on a Net instance in its own SceneMultiplayer branch, so the global
## Net stays offline) runs host contract -> briefing -> pre-planning -> loadout "Ready Up" -> lobby,
## and a joined client sees the host's contract and its own seat.
extends TestCase

const NET_SCRIPT: Script = preload("res://core/net.gd")
const START_CASH: int = 150000

var _branches: Array[Node] = []
var _port: int = 0


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()
	_port = 20000 + (OS.get_process_id() + 7) % 20000


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Hana"
	p.cash = START_CASH
	p.level = 30
	SaveService.save_profile(p, 0)


func after_each() -> void:
	for c: Node in get_children():
		if c is MenuFlow:
			c.queue_free()
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


func _flow(net: Node = null) -> MenuFlow:
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	if net != null:
		f.lobby = LobbySession.new()
		f.lobby.net = net
	add_child(f)
	return f


func test_crew_station_opens_the_lobby_and_validates_fields() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(2)
	assert_true(f.open_station(&"crew"))
	await wait_frames(2)
	var ls: LobbyScreen = f.lobby_screen
	assert_eq(f.current, ls as Control)
	assert_true(ls.connect_box.visible and not ls.lobby_box.visible, "connect view without a session")
	assert_eq(get_viewport().gui_get_focus_owner(), ls.host_port_edit as Control, "first field focused")
	assert_eq(ls.host_port_edit.text, str(LobbyTweak.load_default().default_port))
	ls.host_port_edit.text = "99"
	assert_eq(ls.host(), ERR_INVALID_PARAMETER)
	assert_eq(ls.error_label.text, UiText.t(&"ui.lobby.error.port", {"min": 1024, "max": 65535}))
	ls.join_address_edit.text = "not an address!"
	assert_eq(ls.join(), ERR_INVALID_PARAMETER)
	assert_eq(ls.error_label.text, UiText.t(&"ui.lobby.error.address"))
	assert_false(f.is_coop(), "nothing started")
	ls.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.hub as Control, "lobby Back (no session) -> hub")


func test_host_path_ready_up_returns_to_the_lobby() -> void:
	var f: MenuFlow = _flow(_branch("HostBranch"))
	await wait_frames(2)
	f.open_station(&"crew")
	await wait_frames(2)
	var ls: LobbyScreen = f.lobby_screen
	ls.host_port_edit.text = str(_port)
	assert_eq(ls.host(), OK)
	await wait_frames(2)
	assert_true(f.is_coop())
	assert_true(ls.lobby_box.visible, "lobby view once hosting")
	assert_eq(String(f.lobby.state.slot_view(0)["name"]), "Hana", "own summary sent on host")
	assert_eq(f.lobby.state.human_slots(), [0] as Array[int])
	assert_true(bool(f.lobby.state.slot_view(3)["is_ai"]), "AI fills the empty seats")
	# Host picks the contract on the planning table -> briefing; the lobby carries it.
	ls.contract_requested.emit(&"heist_select")
	await wait_frames(2)
	assert_eq(f.current, f.heist_select as Control)
	f.heist_select.heist_chosen.emit(&"glasshouse", Enums.Difficulty.TENSE)
	await wait_frames(2)
	assert_eq(f.current, f.briefing_screen as Control)
	assert_eq(f.lobby.state.contract["heist"], &"glasshouse")
	assert_eq(int(f.lobby.state.contract["difficulty"]), Enums.Difficulty.TENSE)
	# Briefing Back -> planning table, its Back -> the lobby (the lobby is home in co-op).
	f.briefing_screen.back_button.pressed.emit()
	await wait_frames(2)
	f.heist_select.back_requested.emit()
	await wait_frames(2)
	assert_eq(f.current, ls as Control, "co-op home is the lobby")
	assert_false(ls.briefing_button.disabled)
	ls.briefing_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.briefing_screen as Control)
	f.briefing_screen.continue_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.preplanning_screen as Control)
	f.preplanning_screen.confirm_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.loadout_screen as Control)
	assert_eq(f.loadout_screen.launch_button.text, UiText.t(&"ui.lobby.ready_up"))
	f.loadout_screen.launch_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, ls as Control, "Ready Up -> lobby")
	assert_true(f.lobby.state.is_ready(0))
	assert_false(f.preplan.is_empty(), "the confirmed plan is kept for the launch")
	assert_eq(f.lobby.state.start_block(), LobbyState.OK, "solo host ready: Start enabled")
	assert_false(ls.start_button.disabled)
	var opts: Dictionary = MenuFlow.build_coop_launch_options(f.lobby.state.launch_loadouts(), f.preplan, f.is_pro)
	assert_eq(int(opts["ai_teammates"]), 3)
	assert_true((opts["loadouts"] as Dictionary).has(0))
	assert_true(opts.has("preplan"))
	# Back on the lobby leaves the session and stays on the connect view.
	ls.back_requested.emit()
	await wait_frames(2)
	assert_false(f.is_coop())
	assert_eq(f.current, ls as Control)
	assert_true(ls.connect_box.visible)


func test_client_sees_host_contract_and_its_seat() -> void:
	var host: LobbySession = LobbySession.new()
	host.net = _branch("HostBranch")
	var hp: PlayerProfile = PlayerProfile.new_default()
	hp.profile_name = "Host Hana"
	host.profile = hp
	add_child(host)
	assert_eq(host.host(_port), OK)
	host.set_contract(&"glasshouse", Enums.Difficulty.ROUTINE, false)
	var f: MenuFlow = _flow(_branch("ClientBranch"))
	await wait_frames(2)
	f.open_station(&"crew")
	await wait_frames(2)
	var ls: LobbyScreen = f.lobby_screen
	ls.join_port_edit.text = str(_port)
	assert_eq(ls.join_loopback(), OK, "loopback quick-join")
	assert_eq(ls.join_address_edit.text, "127.0.0.1")
	assert_true(await wait_until(func() -> bool: return not f.lobby.state.contract.is_empty() \
		and f.lobby.state.summaries.has(0), 10.0), "contract + host summary reached the client")
	await wait_frames(2)
	assert_eq(f.lobby.state.local_slot, 1)
	assert_false(ls.start_button.visible, "clients have no Start")
	assert_false(ls.board_button.visible, "clients do not pick the contract")
	assert_eq(ls.contract_label.text, UiText.t(&"heist.glasshouse.name"))
	assert_true((ls.slot_widgets[1]["tags"] as Label).text.contains(UiText.t(&"ui.lobby.slot.you")))
	assert_true((ls.slot_widgets[0]["tags"] as Label).text.contains(UiText.t(&"ui.lobby.slot.host")))
	assert_true(await wait_until(func() -> bool: return host.state.summaries.has(1), 5.0), "host got the client's summary")
	assert_eq(String(host.state.slot_view(1)["name"]), "Hana")
	host.queue_free()


## Co-op windowed pass: a client's HUD named its crew "Host / AI 2" (the heister map was only handed over
## on the host's launch). The client heist UI now takes the lobby's heister assignment.
func test_client_heist_ui_names_heisters_from_the_lobby() -> void:
	var f: MenuFlow = _flow(_branch("HostBranch"))
	await wait_frames(2)
	f.open_station(&"crew")
	await wait_frames(2)
	f.lobby_screen.host_port_edit.text = str(_port)
	assert_eq(f.lobby_screen.host(), OK)
	await wait_frames(2)
	var expected: Dictionary = f.lobby.state.heister_assignment()
	assert_false(expected.is_empty(), "the lobby assigns heisters")
	f.call(&"_begin_client_heist", {"heist": &"glasshouse", "difficulty": 0, "is_pro": false})
	await wait_frames(1)
	var hud: Hud = f.get(&"_hud") as Hud
	assert_true(hud != null, "heist HUD up")
	assert_eq(hud.crew_heisters, expected, "rows name the heisters")
	f.call(&"_leave_heist")


## C11 (lead ruling, PD2): a co-op payday's Continue returns to the crew lobby with the session kept and the
## ready flag cleared; only Leave ends the session.
func test_coop_payday_continue_returns_to_the_lobby() -> void:
	var f: MenuFlow = _flow(_branch("HostBranch"))
	await wait_frames(2)
	f.open_station(&"crew")
	await wait_frames(2)
	f.lobby_screen.host_port_edit.text = str(_port)
	assert_eq(f.lobby_screen.host(), OK)
	await wait_frames(2)
	f.lobby.set_ready(true)
	f.lobby.state.started = {"heist": &"glasshouse", "difficulty": 0, "is_pro": false, "seed": 1}  # as MSG_START leaves it
	f.call(&"_begin_client_heist", {"heist": &"glasshouse", "difficulty": 0, "is_pro": false})
	await wait_frames(1)
	assert_true(f.in_heist_ui_spawned())
	# The payday saved a new level (end-of-heist sweep: the kept lobby still advertised the old one).
	var saved: PlayerProfile = SaveService.load_profile(f.profile_slot)
	saved.level = 7
	SaveService.save_profile(saved, f.profile_slot)
	f.call(&"_on_heist_payday_continue")
	await wait_frames(2)
	assert_false(f.in_heist_ui_spawned(), "heist UI gone")
	assert_eq(f.lobby.profile.level, 7, "the kept lobby advertises the profile the payday saved")
	assert_eq(int((f.lobby.state.summaries.get(f.lobby.state.local_slot, {}) as Dictionary).get("level", -1)), 7,
			"and its summary carries the new level")
	assert_true(f.is_coop(), "the session is kept")
	assert_eq(f.current, f.lobby_screen as Control, "back in the crew lobby")
	assert_false(f.lobby.state.is_ready(f.lobby.state.local_slot), "ready cleared for the next job")
	assert_true(f.lobby.state.started.is_empty(), "the spent launch order is cleared: the host can Start again")


## Stand-ins for a client HeistRuntime and its HeistNetSync (only the C11 host_closed hook is exercised).
class FakeSync extends Node:
	signal host_closed()


class FakeRuntime extends Node:
	var net_sync: Node = null


## C11 (A's round 100): the host tore its heist down while this client was still mid-heist (no payday reached
## it). HeistNetSync.host_closed takes the client back to the crew lobby with the session kept and says why.
func test_client_mid_heist_returns_to_the_lobby_on_host_closed() -> void:
	var f: MenuFlow = _flow(_branch("HostBranch"))
	await wait_frames(2)
	f.open_station(&"crew")
	await wait_frames(2)
	f.lobby_screen.host_port_edit.text = str(_port)
	assert_eq(f.lobby_screen.host(), OK)
	await wait_frames(2)
	f.call(&"_begin_client_heist", {"heist": &"glasshouse", "difficulty": 0, "is_pro": false})
	var rt: FakeRuntime = FakeRuntime.new()
	rt.net_sync = FakeSync.new()
	rt.add_child(rt.net_sync)
	f.runtime = rt
	f.call(&"_watch_host_closed")
	(rt.net_sync as FakeSync).host_closed.emit()
	await wait_frames(2)
	assert_false(f.in_heist_ui_spawned(), "the frozen replica's UI is gone")
	assert_true(f.is_coop(), "session kept")
	assert_eq(f.current, f.lobby_screen as Control, "back in the crew lobby")
	assert_eq(f.lobby_screen.error_label.text, UiText.t(&"ui.lobby.host_closed"), "says why")

	rt.free()
