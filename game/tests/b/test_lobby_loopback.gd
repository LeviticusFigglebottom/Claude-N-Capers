## B4-11: co-op lobby over a real ENet loopback in ONE process (net.md: two SceneMultiplayer branches).
## Each branch holds its own instance of core/net.gd (the Net API) at the same relative path, so the
## Net RPCs (crew sync, lobby_send) travel host <-> client exactly as between two games. The
## LobbySessions use only that Net API. The global Net autoload is not touched.
extends TestCase

const NET_SCRIPT: Script = preload("res://core/net.gd")
const TRIAGE: StringName = &"skill.field_medic.triage"

var _branches: Array[Node] = []
var _port: int = 0


func before_all() -> void:
	# Per-process port so parallel test runs on one machine do not collide.
	_port = 20000 + OS.get_process_id() % 20000


func after_each() -> void:
	for b: Node in _branches:
		var n: Node = b.get_node_or_null(^"Net")
		if n != null:
			n.call(&"leave")
		get_tree().set_multiplayer(null, b.get_path())
		b.queue_free()
	_branches.clear()
	Log.capture = false
	Log.captured.clear()
	await wait_frames(2)


## A branch with its own SceneMultiplayer and Net instance; returns the Net node.
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


func _session(net: Node, player_name: String, level: int) -> LobbySession:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = player_name
	p.level = level
	var s: LobbySession = LobbySession.new()
	s.net = net
	s.profile = p
	net.get_parent().add_child(s)
	return s


## Host + one joined client, both with each other's summaries.
func _connected_pair() -> Array[LobbySession]:
	var host: LobbySession = _session(_branch("HostBranch"), "Host Hana", 20)
	var client: LobbySession = _session(_branch("ClientBranch"), "Client Cole", 8)
	assert_eq(host.host(_port), OK, "host on %d" % _port)
	assert_eq(client.join("127.0.0.1", _port), OK)
	var ok: bool = await wait_until(func() -> bool:
		return client.state.local_slot >= 0 and host.state.summaries.has(client.state.local_slot) \
			and client.state.summaries.has(host.state.local_slot), 10.0)
	assert_true(ok, "client got a slot and both summaries crossed")
	return [host, client] as Array[LobbySession]


func test_join_shows_client_slot_with_summary() -> void:
	var pair: Array[LobbySession] = await _connected_pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	assert_true(host.state.is_host)
	assert_false(client.state.is_host)
	assert_eq(host.state.local_slot, 0)
	var cs: int = client.state.local_slot
	assert_eq(cs, 1, "the client takes the first AI seat")
	assert_eq(client.state.host_slot, 0)
	var view: Dictionary = host.state.slot_view(cs)
	assert_eq(String(view["name"]), "Client Cole", "summary name replaces the Net display name")
	assert_eq(int(view["level"]), 8)
	assert_true(bool(view["legal"]))
	assert_false(bool(view["is_ai"]))
	assert_eq(String((view["loadout"] as Dictionary)["secondary"]), "weapon.kestrel_p9")
	assert_eq(String(client.state.slot_view(0)["name"]), "Host Hana")
	assert_true(bool(client.state.slot_view(0)["is_host"]))
	for s: int in [2, 3]:
		assert_true(bool(host.state.slot_view(s)["is_ai"]), "AI fill in slot %d (host)" % s)
		assert_true(bool(client.state.slot_view(s)["is_ai"]), "AI fill in slot %d (client)" % s)


func test_contract_ready_votes_and_start_cross_the_wire() -> void:
	var pair: Array[LobbySession] = await _connected_pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	var host_starts: Array[Dictionary] = []
	var client_starts: Array[Dictionary] = []
	host.started.connect(func(i: Dictionary) -> void: host_starts.append(i))
	client.started.connect(func(i: Dictionary) -> void: client_starts.append(i))
	assert_false(client.set_contract(&"glasshouse", 2, false), "clients cannot set the contract")
	assert_true(host.set_contract(&"glasshouse", Enums.Difficulty.HAZARDOUS, true))
	assert_true(await wait_until(func() -> bool: return not client.state.contract.is_empty(), 5.0), "contract reached the client")
	assert_eq(client.state.contract["heist"], &"glasshouse")
	assert_eq(int(client.state.contract["difficulty"]), Enums.Difficulty.HAZARDOUS)
	assert_true(bool(client.state.contract["is_pro"]))
	# A client faking a host-only message is rejected by the host (sender slot check).
	Log.capture = true
	var rejected: Array[StringName] = []
	host.message_rejected.connect(func(_slot: int, _kind: StringName, r: StringName) -> void: rejected.append(r))
	client.net.call(&"lobby_send", LobbyState.MSG_CONTRACT, LobbyState.contract_data(&"night_deposit", 0, false))
	assert_true(await wait_until(func() -> bool: return not rejected.is_empty(), 5.0))
	assert_eq(rejected[0], LobbyState.R_NOT_HOST)
	assert_eq(host.state.contract["heist"], &"glasshouse", "host contract unchanged")
	# Plan votes travel through the lobby (PlanVote kinds) and are logged with the sender's slot.
	client.net.call(&"lobby_send", PlanVote.MSG_CAST, {"option": "asset.escape_van@pp_escape"})
	assert_true(await wait_until(func() -> bool: return host.state.vote_log.size() == 1, 5.0), "vote reached the host")
	assert_eq(int(host.state.vote_log[0]["slot"]), 1)
	# Ready flags, then the host-only start.
	assert_eq(host.start(1234), LobbyState.BLOCK_NOT_READY)
	client.set_ready(true)
	host.set_ready(true)
	assert_true(await wait_until(func() -> bool: return host.state.can_start() and client.state.is_ready(0), 5.0), "both ready on both peers")
	assert_eq(client.start(99), LobbyState.BLOCK_NOT_HOST)
	assert_eq(host.start(1234), LobbyState.OK)
	var both: Callable = func() -> bool: return host_starts.size() == 1 and client_starts.size() == 1
	assert_true(await wait_until(both, 5.0), "start reached both peers")
	assert_eq(int(client_starts[0]["seed"]), 1234, "client gets the host's seed")
	assert_eq(client_starts[0]["heist"], &"glasshouse")
	var lo: Dictionary = host.state.launch_loadouts()
	assert_eq(lo.keys().size(), 2, "host launches both humans' loadouts")
	assert_true(lo[1] is Loadout)


func test_illegal_client_loadout_is_flagged_and_blocks_start() -> void:
	var pair: Array[LobbySession] = await _connected_pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	var l: Loadout = client.profile.loadout.duplicate(true) as Loadout
	client.profile.level = 0
	l.skills = {TRIAGE: 2}
	client.send_profile(l)
	assert_true(await wait_until(func() -> bool: return not host.state.is_legal(1), 5.0), "host flags the illegal skill set")
	host.set_contract(&"glasshouse", 0, false)
	client.set_ready(true)
	host.set_ready(true)
	await wait_until(func() -> bool: return host.state.is_ready(1) and host.state.is_ready(0), 5.0)
	assert_eq(host.state.start_block(), LobbyState.BLOCK_ILLEGAL)
	assert_false(host.state.launch_loadouts().has(1))


func test_client_leave_frees_the_seat() -> void:
	var pair: Array[LobbySession] = await _connected_pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	var left: Array[bool] = []
	client.session_left.connect(func() -> void: left.append(true))
	client.leave()
	assert_eq(left.size(), 1)
	assert_false(client.is_active())
	var only_host: Callable = func() -> bool: return host.state.human_slots() == ([0] as Array[int])
	assert_true(await wait_until(only_host, 10.0), "host sees the seat go back to AI")
	assert_false(host.state.summaries.has(1), "the old occupant's summary is forgotten")
	assert_true(bool(host.state.slot_view(1)["is_ai"]))


func test_lobby_screen_draws_the_crew() -> void:
	var pair: Array[LobbySession] = await _connected_pair()
	var host: LobbySession = pair[0]
	var screen: LobbyScreen = (load("res://content/ui/lobby/lobby_screen.tscn") as PackedScene).instantiate() as LobbyScreen
	screen.setup(host, host.profile)
	add_child(screen)
	await wait_frames(2)
	assert_true(screen.lobby_box.visible and not screen.connect_box.visible, "lobby mode while a session is live")
	assert_eq((screen.slot_widgets[1]["name"] as Label).text, "Client Cole")
	assert_eq(((screen.slot_widgets[1]["items"] as Dictionary)["secondary"] as Label).text,
		UiText.t(&"ui.lobby.slot.secondary", {"name": UiText.t(&"item.weapon.kestrel_p9.name")}))
	assert_eq((screen.slot_widgets[2]["name"] as Label).text, UiText.t(&"ui.lobby.slot.ai"))
	assert_true(screen.start_button.visible and screen.start_button.disabled, "host Start, blocked without a contract")
	assert_eq(screen.block_label.text, UiText.t(&"ui.lobby.block.no_contract"))
	assert_true(screen.board_button.visible, "host picks the contract")
	assert_true(screen.focus_chain.has(screen.ready_button))
	screen.queue_free()
	await wait_frames(1)


## D-052: the join carries the profile name into the Net crew registry; host_lost fails the client.
func test_join_name_and_host_lost() -> void:
	var pair: Array[LobbySession] = await _connected_pair()
	var host: LobbySession = pair[0]
	var client: LobbySession = pair[1]
	var cs: int = client.state.local_slot
	var named: Callable = func() -> bool:
		return (host.net.get(&"crew") as Dictionary).get(cs, {}).get("display_name", "") == "Client Cole"
	assert_true(await wait_until(named, 10.0), "Net.join sent the profile name")
	var reasons: Array[StringName] = []
	client.connection_failed.connect(func(r: StringName) -> void: reasons.append(r))
	host.leave()
	assert_true(await wait_until(func() -> bool: return not reasons.is_empty(), 10.0), "client noticed")
	assert_eq(reasons, [LobbySession.FAIL_HOST_LOST] as Array[StringName])
	assert_false(client.is_active(), "Net left the session")


## D-052: Net.connection_failed while joining reports `unreachable` (Net itself leaves).
func test_unreachable_join_fails() -> void:
	var client: LobbySession = _session(_branch("ClientBranch"), "Client Cole", 8)
	assert_eq(client.join("127.0.0.1", _port), OK)
	var reasons: Array[StringName] = []
	client.connection_failed.connect(func(r: StringName) -> void: reasons.append(r))
	client.net.emit_signal(&"connection_failed")
	assert_eq(reasons, [LobbySession.FAIL_UNREACHABLE] as Array[StringName])
	assert_true(client.is_active(), "the session waits for Net's own leave()")
	client.net.call(&"leave")
	assert_false(client.is_active())
