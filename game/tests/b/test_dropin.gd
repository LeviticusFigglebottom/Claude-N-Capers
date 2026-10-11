## B6-04: drop-in + kick UI on the B-side mock service (ENV A's drop-in is not there yet): the host's join
## request dialog (accept, deny, auto-deny timeout, queue, gameplay input paused in the heist), the kick confirm
## (confirm / cancel), the lobby kick over a real ENet loopback (LobbyState.MSG_KICK) and the joining player's
## compact loadout + "Joining..." progress with cancel.
extends TestCase

const JOIN_SCENE: PackedScene = preload("res://content/ui/dropin/drop_in_join_screen.tscn")
const LOBBY_SCENE: PackedScene = preload("res://content/ui/lobby/lobby_screen.tscn")

var _port: int = 0


class FakeCrew:
	extends Node
	var slot: int = -1
	var paused: bool = false

	func set_input_paused(p: bool) -> void:
		paused = p


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	_port = BTestUtil.port(19)


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	for c: Node in get_children():
		if not c.get_node_or_null(^"Net"):
			c.queue_free()
	BTestUtil.free_net_branches(self)
	CrewInput.clear()
	Log.capture = false
	Log.captured.clear()
	await wait_frames(2)


func _summary(player: String, level: int, rank: int) -> Dictionary:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = player
	p.level = level
	p.notoriety = rank
	return LobbyState.summary_from(p.loadout, p)


func _dialog(mock: MockDropInService) -> JoinRequestDialog:
	var d: JoinRequestDialog = JoinRequestDialog.new()
	add_child(mock)
	d.bind(mock)
	add_child(d)
	return d


func test_request_shows_name_level_and_badge() -> void:
	var mock: MockDropInService = MockDropInService.new()
	var d: JoinRequestDialog = _dialog(mock)
	assert_false(d.visible, "hidden without a request")
	assert_eq(DropInService.find(get_tree()), mock as Node, "the mock registers in the service group")
	mock.simulate_request(5, _summary("Vex", 42, 3))
	assert_true(d.visible)
	assert_eq(d.current_peer(), 5)
	assert_eq(d.body_label.text, UiText.t(&"ui.dropin.request.body",
		{"level": NotorietyScreen.level_text(42, 3), "name": "Vex"}))
	assert_eq(d.badge_label.text, NotorietyScreen.badge_text(3))
	assert_eq(d.timer_label.text, UiText.t(&"ui.dropin.request.auto_deny", {"seconds": ceili(d.tweak.dropin_request_timeout_s)}))


func test_accept_and_deny_answer_the_service() -> void:
	var mock: MockDropInService = MockDropInService.new()
	var d: JoinRequestDialog = _dialog(mock)
	var got: Array[Array] = []
	d.answered.connect(func(peer: int, ok: bool, auto: bool) -> void: got.append([peer, ok, auto]))
	mock.simulate_request(5, _summary("Vex", 42, 0))
	mock.simulate_request(6, _summary("Ana", 7, 0))
	mock.simulate_request(5, _summary("Vex", 42, 0))
	assert_eq(d.queue.size(), 2, "a repeated request is not queued twice")
	assert_eq(d.more_label.text, UiText.t(&"ui.dropin.request.more", {"count": 1}))
	d.accept_button.pressed.emit()
	assert_eq(mock.answers, [{"peer_id": 5, "accept": true}] as Array[Dictionary])
	assert_true(d.visible, "the next request shows")
	assert_eq(d.current_peer(), 6)
	d.deny_button.pressed.emit()
	assert_eq(mock.answers[1], {"peer_id": 6, "accept": false})
	assert_false(d.visible, "queue empty")
	assert_eq(got, [[5, true, false], [6, false, false]] as Array[Array])


func test_timeout_auto_denies() -> void:
	var mock: MockDropInService = MockDropInService.new()
	var d: JoinRequestDialog = _dialog(mock)
	var autos: Array[bool] = []
	d.answered.connect(func(_p: int, _ok: bool, auto: bool) -> void: autos.append(auto))
	mock.simulate_request(9, _summary("Slow", 1, 0))
	d._process(d.tweak.dropin_request_timeout_s - 1.0)
	assert_true(mock.answers.is_empty(), "still waiting")
	assert_eq(d.timer_label.text, UiText.t(&"ui.dropin.request.auto_deny", {"seconds": 1}))
	d._process(1.1)
	assert_eq(mock.answers, [{"peer_id": 9, "accept": false}] as Array[Dictionary], "auto-denied")
	assert_eq(autos, [true] as Array[bool])
	assert_false(d.visible)


func test_heist_dialog_pauses_local_input_and_finds_the_service() -> void:
	var me: FakeCrew = FakeCrew.new()
	me.slot = 0
	me.add_to_group(G.CREW)
	add_child(me)
	var d: JoinRequestDialog = JoinRequestDialog.new()
	d.pause_gameplay = true
	d.auto_find = true
	d.local_slot = 0
	add_child(d)
	var mock: MockDropInService = MockDropInService.new()
	add_child(mock)
	d._process(0.6)
	assert_eq(d.service, mock as Object, "service found in its group")
	mock.simulate_request(3, _summary("Late", 12, 0))
	assert_true(me.paused, "host's gameplay input paused while answering")
	d.accept()
	assert_false(me.paused, "given back")


func test_kick_confirm_and_cancel() -> void:
	var mock: MockDropInService = MockDropInService.new()
	add_child(mock)
	var k: KickConfirmDialog = KickConfirmDialog.new()
	k.target = mock
	add_child(k)
	await wait_frames(1)
	assert_false(k.visible)
	k.ask(2, "Bob")
	assert_true(k.is_asking())
	assert_eq(k.message_label.text, UiText.t(&"ui.kick.confirm", {"name": "Bob"}))
	k.cancel_button.pressed.emit()
	assert_false(k.visible)
	assert_true(mock.kicks.is_empty(), "cancel kicks nobody")
	k.ask(3, "Cy")
	var conf: Array[int] = []
	k.confirmed.connect(func(s: int, ok: bool) -> void:
		if ok:
			conf.append(s))
	k.kick_button.pressed.emit()
	assert_eq(mock.kicks, [3] as Array[int])
	assert_eq(conf, [3] as Array[int])
	assert_false(k.is_asking())


func test_kick_message_validation() -> void:
	var s: LobbyState = LobbyState.new(true)
	s.set_crew({0: {"peer_id": 1, "is_ai": false, "display_name": "H"}, 1: {"peer_id": 7, "is_ai": false, "display_name": "C"},
		2: {"peer_id": 0, "is_ai": true, "display_name": "AI"}}, 0, 0)
	assert_eq(s.receive(1, LobbyState.MSG_KICK, {"slot": 0}), LobbyState.R_NOT_HOST, "only the host kicks")
	assert_eq(s.receive(0, LobbyState.MSG_KICK, {"slot": 0}), LobbyState.R_BAD_PAYLOAD, "not the host itself")
	assert_eq(s.receive(0, LobbyState.MSG_KICK, {"slot": 2}), LobbyState.R_BAD_PAYLOAD, "not an AI seat")
	assert_eq(s.receive(0, LobbyState.MSG_KICK, {"slot": "1"}), LobbyState.R_BAD_PAYLOAD)
	assert_eq(s.receive(0, LobbyState.MSG_KICK, {"slot": 1}), LobbyState.OK)


func _session(net: Node, player_name: String) -> LobbySession:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = player_name
	var s: LobbySession = LobbySession.new()
	s.net = net
	s.profile = p
	net.get_parent().add_child(s)
	return s


func test_lobby_kick_over_loopback() -> void:
	var host: LobbySession = _session(BTestUtil.net_branch(self, "HostBranch"), "Host Hana")
	var client: LobbySession = _session(BTestUtil.net_branch(self, "ClientBranch"), "Client Cole")
	assert_eq(host.host(_port), OK)
	assert_eq(client.join("127.0.0.1", _port), OK)
	assert_true(await wait_until(func() -> bool: return client.state.local_slot >= 0 and host.state.summaries.has(1), 10.0))
	var screen: LobbyScreen = LOBBY_SCENE.instantiate() as LobbyScreen
	screen.setup(host, host.profile)
	add_child(screen)
	await wait_frames(2)
	var kick_buttons: Array[bool] = []
	for w: Dictionary in screen.slot_widgets:
		kick_buttons.append((w["kick"] as Button).visible)
	assert_eq(kick_buttons, [false, true, false, false] as Array[bool], "host: kick only on the other human")
	assert_false(client.kick(0), "clients cannot kick")
	var reasons: Array[StringName] = []
	client.connection_failed.connect(func(r: StringName) -> void: reasons.append(r))
	(screen.slot_widgets[1]["kick"] as Button).pressed.emit()
	assert_true(screen.kick_dialog.is_asking(), "confirm first")
	assert_eq(screen.kick_dialog.message_label.text, UiText.t(&"ui.kick.confirm", {"name": "Client Cole"}))
	screen.kick_dialog.kick_button.pressed.emit()
	assert_true(await wait_until(func() -> bool: return not reasons.is_empty(), 10.0), "the client was told")
	assert_eq(reasons, [LobbySession.FAIL_KICKED] as Array[StringName])
	assert_false(client.is_active(), "the kicked client left")
	assert_true(await wait_until(func() -> bool: return host.state.human_slots() == ([0] as Array[int]), 10.0), "seat freed")


func _join_screen(mock: MockDropInService) -> DropInJoinScreen:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Drop Dana"
	p.level = 25
	var j: DropInJoinScreen = JOIN_SCENE.instantiate() as DropInJoinScreen
	j.setup(mock, p)
	add_child(mock)
	add_child(j)
	return j


func test_join_screen_pick_progress_and_join() -> void:
	var mock: MockDropInService = MockDropInService.new()
	var j: DropInJoinScreen = _join_screen(mock)
	await wait_frames(2)
	assert_eq(j.phase, DropInJoinScreen.Phase.PICK)
	assert_true(j.loadout_screen.visible and not j.progress_panel.visible)
	assert_true(j.loadout_screen.compact_mode)
	assert_false(j.loadout_screen.skills_button.visible or j.loadout_screen.workshop_button.visible, "compact mode")
	assert_eq(j.loadout_screen.launch_button.text, UiText.t(&"ui.dropin.join_button"))
	var slots: Array[int] = []
	j.joined.connect(func(s: int) -> void: slots.append(s))
	j.loadout_screen.launch_button.pressed.emit()
	assert_eq(String(mock.requested.get("name", "")), "Drop Dana", "request carries the summary")
	assert_eq(int(mock.requested.get("level", 0)), 25)
	assert_eq(j.phase, DropInJoinScreen.Phase.JOINING)
	assert_true(j.progress_panel.visible and not j.loadout_screen.visible)
	assert_eq(j.status_label.text, UiText.t(&"ui.dropin.waiting_host"))
	mock.advance(1.0)
	assert_near(j.progress(), 0.5)
	assert_eq(j.status_label.text, UiText.t(&"ui.dropin.progress", {"pct": 50}))
	mock.advance(1.0)
	assert_eq(slots, [mock.assign_slot] as Array[int])
	assert_eq(j.phase, DropInJoinScreen.Phase.JOINED)


func test_join_screen_cancel_and_denied() -> void:
	var mock: MockDropInService = MockDropInService.new()
	var j: DropInJoinScreen = _join_screen(mock)
	await wait_frames(2)
	var backs: Array[bool] = []
	j.back_requested.connect(func() -> void: backs.append(true))
	var fails: Array[StringName] = []
	j.join_failed.connect(func(r: StringName) -> void: fails.append(r))
	j.request_join(j.loadout_screen.current_loadout())
	j.cancel_button.pressed.emit()
	assert_false(mock.joining, "cancel_join reached the service")
	assert_eq(backs.size(), 1, "cancel leaves the screen")
	assert_true(fails.is_empty(), "a cancel is not reported as a failure")
	var j2: DropInJoinScreen = _join_screen(MockDropInService.new())
	await wait_frames(2)
	var mock2: MockDropInService = j2.service as MockDropInService
	j2.request_join(j2.loadout_screen.current_loadout())
	mock2.deny_local(DropInService.REASON_DENIED)
	assert_eq(j2.phase, DropInJoinScreen.Phase.FAILED)
	assert_eq(j2.status_label.text, UiText.t(&"ui.dropin.failed.denied"))
	assert_eq(j2.cancel_button.text, UiText.t(&"ui.menu.back"))
