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
