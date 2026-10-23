## B6-05 LAN host list: a hosting LobbySession advertises itself through ENV A's LanDiscovery (name, port, humans, the
## contract's heist; stops on leave), and the lobby screen's Join panel lists the hosts and joins one on a press.
## One process: the beacon and the listener share the tree's single LanDiscovery node (UDP broadcast on localhost).
extends TestCase

const NET_SCRIPT: Script = preload("res://core/net.gd")
const LOBBY_SCENE: PackedScene = preload("res://content/ui/lobby/lobby_screen.tscn")

var _branches: Array[Node] = []
var _port: int = 0


func before_all() -> void:
	_port = BTestUtil.port(311)


func after_each() -> void:
	var lan: LanDiscovery = LanDiscovery.ensure(get_tree())
	lan.stop_beacon()
	lan.stop_listening()
	for b: Node in _branches:
		var n: Node = b.get_node_or_null(^"Net")
		if n != null:
			n.call(&"leave")
		get_tree().set_multiplayer(null, b.get_path())
		b.queue_free()
	_branches.clear()
	await wait_frames(2)


func _host_session() -> LobbySession:
	var root: Node = Node.new()
	root.name = "HostBranch"
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var n: Node = NET_SCRIPT.new() as Node
	n.name = "Net"
	root.add_child(n)
	_branches.append(root)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Lan Lena"
	var s: LobbySession = LobbySession.new()
	s.net = n
	s.profile = p
	root.add_child(s)
	return s


func _row(lan: LanDiscovery, host_name: String) -> Dictionary:
	for h: Variant in lan.hosts():
		if String((h as Dictionary).get("name", "")) == host_name:
			return h as Dictionary
	return {}


func test_host_is_listed_updated_and_dropped() -> void:
	var lan: LanDiscovery = LanDiscovery.ensure(get_tree())
	if not lan.start_listening():
		assert_true(false, "the discovery port is free for the test")
		return
	var host: LobbySession = _host_session()
	assert_eq(host.host(_port), OK)
	var seen: bool = await wait_until(func() -> bool: return not _row(lan, "Lan Lena").is_empty(), 5.0)
	assert_true(seen, "the hosting lobby is listed")
	var row: Dictionary = _row(lan, "Lan Lena")
	assert_eq(int(row.get("port", -1)), _port, "with its game port")
	assert_eq(int(row.get("players", 0)), 1, "one human")
	assert_eq(StringName(row.get("heist", &"x")), &"", "no job yet")
	host.set_contract(&"glasshouse", Enums.Difficulty.TENSE, false)
	var job: bool = await wait_until(func() -> bool:
		return StringName(_row(lan, "Lan Lena").get("heist", &"")) == &"glasshouse", 5.0)
	assert_true(job, "the contract's heist reaches the list")
	host.leave()
	var gone: bool = await wait_until(func() -> bool: return _row(lan, "Lan Lena").is_empty(), 6.0)
	assert_true(gone, "leaving stops the beacon; the row expires")


func test_join_panel_lists_and_joins() -> void:
	var s: LobbyScreen = LOBBY_SCENE.instantiate() as LobbyScreen
	var host: LobbySession = _host_session()  # a session object for the screen (not hosting)
	s.setup(host, PlayerProfile.new_default())
	add_child(s)
	await wait_frames(2)
	assert_true(s.lan_note.visible, "an empty list says so")
	s.call(&"_refresh_lan", [{"address": "127.0.0.1", "port": _port, "name": "Rook", "players": 2, "max_players": 4,
		"heist": &"glasshouse", "version": 1, "age_s": 0.1}])
	assert_eq(s.lan_buttons.size(), 1, "one row per host")
	assert_false(s.lan_note.visible)
	var text: String = s.lan_buttons[0].text
	assert_true(text.contains("Rook") and text.contains(UiText.t(&"heist.glasshouse.name")) and text.contains("2/4"), text)
	assert_true(s.focus_chain.has(s.lan_buttons[0]), "the rows are reachable by keys / pad")
	s.lan_buttons[0].pressed.emit()
	assert_eq(s.join_address_edit.text, "127.0.0.1", "a press fills the address")
	assert_eq(s.join_port_edit.text, str(_port), "and the port, then joins")
	host.leave()
	s.queue_free()
	await wait_frames(2)
