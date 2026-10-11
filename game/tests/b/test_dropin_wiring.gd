## B6-04 wiring to ENV A's HeistDropIn: the co-op host's launch copies LobbyState.dropin_policy into A's service;
## in the heist A alone decides (the host dialog has no gate, shows only A's `ask` requests, answers once, drops a
## request A ended, falls back to a 2-argument answer_join). Joining client (DropInFlow, over a real ENet loopback
## with the B mock as the service): lobby "Drop in to a running heist" -> DropInJoinScreen -> Net.join ->
## request_join only after connected_to_host -> joined switches MenuFlow to its in-heist UI; join_failed shows the
## reason, leaves the session and Back returns to the lobby with it.
extends TestCase

const PEER_A: int = 98
const PEER_B: int = 99

var _port: int = 0
var _port2: int = 0
var _rt: HeistRuntime = null


class TwoArgService:
	extends Node
	signal join_requested(peer_id: int, summary: Dictionary)
	var answers: Array[Array] = []

	func answer_join(peer_id: int, accept: bool) -> void:
		answers.append([peer_id, accept])


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	_port = BTestUtil.port(41)
	_port2 = BTestUtil.port(43)


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Drop Dana"
	p.level = 25
	SaveService.save_profile(p, 0)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	for c: Node in get_children():
		if not c.get_node_or_null(^"Net"):
			c.queue_free()
	BTestUtil.free_net_branches(self)
	var svc: Node = get_tree().root.get_node_or_null(NodePath(HeistDropIn.NODE_NAME))
	if svc != null:
		(svc as HeistDropIn).policy = HeistDropIn.POLICY_ASK
		(svc as HeistDropIn).pending.clear()
	CrewInput.clear()
	Log.capture = false
	Log.captured.clear()
	await wait_frames(2)


func _summary(player: String) -> Dictionary:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = player
	p.level = 10
	return LobbyState.summary_from(p.loadout, p)


func _flow(net: Node) -> MenuFlow:
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	f.lobby = LobbySession.new()
	f.lobby.net = net
	add_child(f)
	return f


func _host(port: int) -> LobbySession:
	var host: LobbySession = LobbySession.new()
	host.net = BTestUtil.net_branch(self, "HostBranch")
	var hp: PlayerProfile = PlayerProfile.new_default()
	hp.profile_name = "Host Hana"
	host.profile = hp
	add_child(host)
	assert_eq(host.host(port), OK)
	host.set_contract(&"glasshouse", Enums.Difficulty.TENSE, true)
	return host


## A client MenuFlow on the lobby's connect view with the B mock as the drop-in service.
func _client(mock: MockDropInService) -> MenuFlow:
	var f: MenuFlow = _flow(BTestUtil.net_branch(self, "ClientBranch"))
	add_child(mock)
	await wait_frames(2)
	f.drop_in.service_provider = func() -> Object: return mock
	f.open_station(&"crew")
	await wait_frames(2)
	return f


## Lobby Drop In button -> DropInJoinScreen; its Drop In (compact loadout) sends the request through DropInFlow.
func _drop_in(f: MenuFlow, port: int) -> DropInJoinScreen:
	var ls: LobbyScreen = f.lobby_screen
	ls.join_address_edit.text = "127.0.0.1"
	ls.join_port_edit.text = str(port)
	ls.dropin_button.pressed.emit()
	await wait_frames(2)
	var j: DropInJoinScreen = f.drop_in_screen
	assert_true(j != null and f.current == (j as Control), "the drop-in screen opened")
	if j != null:
		j.loadout_screen.launch_button.pressed.emit()
	return j


# --- Host -----------------------------------------------------------------------------------------

func test_host_launch_copies_the_policy_into_a_service() -> void:
	var f: MenuFlow = _flow(BTestUtil.net_branch(self, "HostBranch"))
	await wait_frames(2)
	f.lobby.state.reset(true)
	f.lobby.state.dropin_policy = LobbyState.POLICY_AUTO
	Log.capture = true  # the unknown heist below is logged as an error
	await f.launch_coop({"heist": &"no_such_heist_b604", "difficulty": Enums.Difficulty.ROUTINE, "is_pro": false, "seed": 1})
	var svc: HeistDropIn = get_tree().root.get_node_or_null(NodePath(HeistDropIn.NODE_NAME)) as HeistDropIn
	assert_true(svc != null, "A's service exists from the launch")
	if svc != null:
		assert_eq(svc.policy, LobbyState.POLICY_AUTO, "LobbyState.dropin_policy copied at launch")
		assert_eq(DropInService.find(get_tree()), svc as Node, "in G.DROP_IN_SERVICE")
	DropInFlow.apply_host_policy(get_tree(), LobbyState.POLICY_OFF)
	assert_eq(HeistDropIn.ensure(get_tree()).policy, LobbyState.POLICY_OFF)
	DropInFlow.apply_host_policy(get_tree(), &"sometimes")
	assert_eq(HeistDropIn.ensure(get_tree()).policy, LobbyState.POLICY_ASK, "an unknown value falls back to ask")


func test_dialog_on_a_service_only_shows_a_asks_and_answers_once() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 6404, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 2, "skip_casing": true})
	assert_true(_rt != null, "heist running")
	if _rt == null:
		return
	await wait_physics_frames(2)
	var svc: HeistDropIn = DropInService.find(get_tree()) as HeistDropIn
	DropInFlow.apply_host_policy(get_tree(), LobbyState.POLICY_ASK)
	var d: JoinRequestDialog = JoinRequestDialog.new()  # as MenuFlow's heist dialog: auto_find, no gate
	d.auto_find = true
	add_child(d)
	d._process(0.6)
	assert_eq(d.service, svc as Object, "bound to A's service")
	var answered: Array[Array] = []
	d.answered.connect(func(p: int, ok: bool, auto: bool) -> void: answered.append([p, ok, auto]))
	Net.crew[1] = {"peer_id": PEER_A, "is_ai": false, "display_name": "Player %d" % PEER_A}
	Net.crew[2] = {"peer_id": PEER_B, "is_ai": false, "display_name": "Player %d" % PEER_B}
	Net.lobby_message.emit(PEER_A, HeistDropIn.KIND_REQUEST, {"summary": _summary("Ana")})
	assert_true(d.visible and d.current_peer() == PEER_A, "ask: A asks, the dialog shows")
	Net.lobby_message.emit(PEER_A, HeistDropIn.KIND_CANCEL, {})
	assert_false(d.visible, "the joiner cancelled: A's join_failed drops the request")
	var failed: Array[StringName] = []
	svc.join_failed.connect(func(_p: int, r: StringName) -> void: failed.append(r))
	Net.lobby_message.emit(PEER_A, HeistDropIn.KIND_REQUEST, {"summary": _summary("Ana")})
	d._process(d.tweak.dropin_request_timeout_s + 0.1)
	assert_eq(failed, [DropInService.REASON_TIMEOUT] as Array[StringName], "3-argument answer_join: A denies with timeout")
	assert_false(d.visible)
	Net.lobby_message.emit(PEER_A, HeistDropIn.KIND_REQUEST, {"summary": _summary("Ana")})
	assert_true(d.visible)
	d.accept()
	assert_false((_rt.crew_controller(1) as CrewController).is_ai, "A accepted on the dialog's answer")
	assert_false(svc.pending.has(PEER_A))
	DropInFlow.apply_host_policy(get_tree(), LobbyState.POLICY_AUTO)
	Net.lobby_message.emit(PEER_B, HeistDropIn.KIND_REQUEST, {"summary": _summary("Bo")})
	assert_false(d.visible, "auto: A accepts by itself, no dialog")
	assert_false((_rt.crew_controller(2) as CrewController).is_ai, "auto accepted by A")
	assert_eq(answered, [[PEER_A, false, true], [PEER_A, true, false]] as Array[Array],
		"one answer per shown request (timeout, then Accept); none for the cancelled one or auto")


func test_dialog_falls_back_to_a_two_argument_answer_join() -> void:
	var s: TwoArgService = TwoArgService.new()
	add_child(s)
	var d: JoinRequestDialog = JoinRequestDialog.new()
	d.bind(s)
	add_child(d)
	s.join_requested.emit(5, _summary("Vex"))
	d._process(d.tweak.dropin_request_timeout_s + 0.1)
	assert_eq(s.answers, [[5, false]] as Array[Array], "timeout deny without a reason argument")
	s.join_requested.emit(6, _summary("Ana"))
	d.accept()
	assert_eq(s.answers[1], [6, true])


# --- Joining client -----------------------------------------------------------------------------

func test_lobby_drop_in_button_validates_and_opens_the_screen() -> void:
	var f: MenuFlow = await _client(MockDropInService.new())
	var ls: LobbyScreen = f.lobby_screen
	assert_true(ls.dropin_button.visible, "next to Join")
	assert_eq(ls.dropin_button.text, UiText.t(&"ui.lobby.dropin_join"))
	ls.join_address_edit.text = "not an address!"
	assert_eq(ls.drop_in(), ERR_INVALID_PARAMETER)
	assert_eq(ls.error_label.text, UiText.t(&"ui.lobby.error.address"))
	assert_eq(f.current, ls as Control, "nothing opened")
	ls.join_address_edit.text = ""
	ls.code_edit.text = LobbyCode.display(LobbyCode.encode("192.168.1.20", _port, ls.tweak.default_port))
	assert_eq(ls.drop_in(), OK, "a lobby code works too")
	await wait_frames(2)
	assert_true(f.current is DropInJoinScreen)
	assert_eq(f.drop_in.address, "192.168.1.20")
	assert_eq(f.drop_in.port, _port)
	assert_eq(f.drop_in_screen.service, f.drop_in as Object, "the screen talks to DropInFlow")
	assert_false(f.drop_in.is_in_group(DropInService.GROUP), "the proxy is not a host-side service")
	assert_true(f.drop_in_screen.loadout_screen.compact_mode)
	f.drop_in_screen.back_requested.emit()
	await wait_frames(2)
	assert_eq(f.current, ls as Control, "Back before asking: the lobby")
	assert_false(f.is_coop(), "nothing connected")


func test_client_requests_after_connect_and_joined_enters_the_heist() -> void:
	var host: LobbySession = _host(_port)
	var mock: MockDropInService = MockDropInService.new()
	var f: MenuFlow = await _client(mock)
	var order: Array[String] = []
	f.lobby.net.connect(&"connected_to_host", func() -> void: order.append("connected"))
	mock.join_progress.connect(func(_p: int, _f: float) -> void:
		if order.size() == 1:
			order.append("progress"))
	var j: DropInJoinScreen = await _drop_in(f, _port)
	assert_eq(f.drop_in.phase, DropInFlow.Phase.CONNECTING, "connecting first")
	assert_true(mock.requested.is_empty(), "no request before connected_to_host")
	assert_true(f.is_coop(), "lobby.join -> Net.join")
	assert_eq(j.phase, DropInJoinScreen.Phase.JOINING)
	assert_true(await wait_until(func() -> bool: return not mock.requested.is_empty(), 10.0), "asked once connected")
	assert_eq(order[0], "connected")
	assert_eq(String(mock.requested["name"]), "Drop Dana", "the picked loadout's summary")
	assert_eq(f.drop_in.phase, DropInFlow.Phase.REQUESTED)
	assert_true(await wait_until(func() -> bool: return f.lobby.state.contract.has("heist"), 10.0), "contract known")
	var launched: Array[Object] = []
	f.heist_launched.connect(func(rt: Object) -> void: launched.append(rt))
	mock.advance(1.0)
	assert_near(j.progress(), 0.5, 0.0001, "progress passed on")
	mock.advance(1.0)
	await wait_frames(2)
	assert_true(f.in_heist_ui_spawned(), "joined: in-heist UI up")
	assert_false(f.visible, "menus hidden")
	assert_true(f.drop_in_screen == null, "drop-in screen gone")
	assert_true(f.heist_chat != null, "co-op chat overlay")
	assert_true(f.heist_join_dialog == null, "no host dialog on a client")
	assert_eq(f._heist_id, &"glasshouse", "heist from the lobby contract (no replica in this test)")
	assert_true(f.is_pro, "is_pro from the contract")
	assert_true(launched.is_empty(), "no runtime here: heist_launched waits for a replica")
	assert_true(f.is_coop(), "the session stays up in the heist")
	host.queue_free()


func test_join_failed_shows_the_reason_and_returns_to_the_lobby() -> void:
	var host: LobbySession = _host(_port2)
	var mock: MockDropInService = MockDropInService.new()
	var f: MenuFlow = await _client(mock)
	var j: DropInJoinScreen = await _drop_in(f, _port2)
	assert_true(await wait_until(func() -> bool: return not mock.requested.is_empty(), 10.0))
	mock.deny_local(DropInService.REASON_DENIED)
	assert_eq(j.phase, DropInJoinScreen.Phase.FAILED)
	assert_eq(j.status_label.text, UiText.t(&"ui.dropin.failed.denied"), "the reason on the screen")
	assert_eq(f.drop_in.last_failure, DropInService.REASON_DENIED)
	assert_true(await wait_until(func() -> bool: return not f.is_coop(), 5.0), "the session was left (Net.leave)")
	j.cancel_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.lobby_screen as Control, "Back: the lobby")
	assert_true(f.lobby_screen.connect_box.visible, "connect view")
	assert_eq(f.lobby_screen.error_label.text, UiText.t(&"ui.dropin.failed.denied"), "the reason stays visible")
	assert_false(f.in_heist_ui_spawned())
	host.queue_free()


func test_cancel_while_connecting() -> void:
	var mock: MockDropInService = MockDropInService.new()
	var f: MenuFlow = await _client(mock)
	var j: DropInJoinScreen = await _drop_in(f, BTestUtil.port(47))  # nobody hosts there
	assert_eq(f.drop_in.phase, DropInFlow.Phase.CONNECTING)
	j.cancel_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.drop_in.last_failure, DropInService.REASON_CANCELLED)
	assert_false(f.is_coop(), "left")
	assert_true(mock.requested.is_empty(), "never asked")
	assert_eq(f.current, f.lobby_screen as Control)
	assert_eq(f.lobby_screen.error_label.text, "", "a cancel is not an error")


func test_failure_reasons_have_strings() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for r: StringName in DropInService.REASONS:
		assert_has(table, "ui.dropin.failed.%s" % r)
	for r: StringName in DropInFlow.LOBBY_FAIL_REASONS.values():
		assert_true(DropInService.REASONS.has(r), "lobby failure %s maps to a known reason" % r)
	for k: String in ["ui.lobby.dropin_join", "ui.lobby.dropin_join.hint"]:
		assert_has(table, k)


## Lead ruling: a host's Options change of gameplay/dropin_policy applies to the running heist at once (PD2).
func test_options_change_applies_to_the_live_heist() -> void:
	var saved: GameSettings = GameSettings.current()
	GameSettings.set_current(GameSettings.new())  # in-memory only: nothing is saved here
	var flow: DropInFlow = DropInFlow.new()
	add_child(flow)
	assert_false(DropInFlow.apply_live_policy(get_tree(), null, LobbyState.POLICY_OFF), "no running heist: nothing live")
	_rt = await HeistLauncher.launch(&"unit_map", 6405, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 2, "skip_casing": true})
	assert_true(_rt != null, "heist running")
	if _rt != null:
		await wait_physics_frames(2)
		var svc: HeistDropIn = HeistDropIn.ensure(get_tree())
		DropInFlow.apply_host_policy(get_tree(), LobbyState.POLICY_ASK)
		GameSettings.current().set_value(GameSettings.GAMEPLAY, &"dropin_policy", "off")
		assert_eq(svc.policy, LobbyState.POLICY_OFF, "the Options change reached the live service")
		assert_false(DropInFlow.apply_live_policy(get_tree(), null, &"sometimes"), "unknown values are ignored")
		assert_eq(svc.policy, LobbyState.POLICY_OFF)
	flow.queue_free()
	GameSettings.set_current(saved)
