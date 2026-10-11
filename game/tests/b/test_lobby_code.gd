## B6-05: lobby codes (LobbyCode, pure): round trip over many addresses and ports, checksum rejection, case /
## dash / Crockford-confusable insensitivity, IPv6 unsupported, LAN address choice; and the lobby screen: the
## host sees its code (and copies it), a joiner joins by code over a real ENet loopback.
extends TestCase

const LOBBY_SCENE: PackedScene = preload("res://content/ui/lobby/lobby_screen.tscn")
const DEFAULT_PORT: int = 27655

var _port: int = 0


func before_all() -> void:
	_port = BTestUtil.port(23)


func after_each() -> void:
	for c: Node in get_children():
		if not c.get_node_or_null(^"Net"):
			c.queue_free()
	BTestUtil.free_net_branches(self)
	await wait_frames(2)


func test_round_trip_many_addresses_and_ports() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6005
	var fixed: Array[String] = ["0.0.0.1", "10.0.0.2", "127.0.0.1", "172.16.5.4", "192.168.0.10", "255.255.255.255", "8.8.4.4"]
	var cases: Array[Array] = []
	for a: String in fixed:
		for p: int in [1, 1024, DEFAULT_PORT, 27656, 65535]:
			cases.append([a, p])
	for i: int in range(400):
		var a: String = "%d.%d.%d.%d" % [rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255)]
		cases.append([a, rng.randi_range(1, 65535)])
	for c: Array in cases:
		var code: String = LobbyCode.encode(c[0], c[1], DEFAULT_PORT)
		assert_eq(code.length(), LobbyCode.SHORT_LENGTH if c[1] == DEFAULT_PORT else LobbyCode.LONG_LENGTH, "length of %s" % code)
		var d: Dictionary = LobbyCode.decode(code, DEFAULT_PORT)
		assert_eq(d, {"address": c[0], "port": c[1]}, "round trip %s:%d via %s" % [c[0], c[1], code])


func test_default_port_from_the_tweak() -> void:
	var tw_port: int = LobbyTweak.load_default().default_port
	var code: String = LobbyCode.encode("192.168.1.20", tw_port)
	assert_eq(code.length(), LobbyCode.SHORT_LENGTH, "the default port gives the short code")
	assert_eq(LobbyCode.decode(code), {"address": "192.168.1.20", "port": tw_port})
	assert_eq(LobbyCode.display(code).length(), LobbyCode.SHORT_LENGTH + 1, "ABCD-EFGH")
	assert_eq(LobbyCode.display(LobbyCode.encode("192.168.1.20", 4000)).count("-"), 2, "ABCD-EFGH-JKL")


func test_every_single_symbol_error_is_rejected() -> void:
	for c: Array in [["192.168.0.10", DEFAULT_PORT], ["10.1.2.3", 30000]]:
		var code: String = LobbyCode.encode(c[0], c[1], DEFAULT_PORT)
		for i: int in range(code.length()):
			for s: String in LobbyCode.ALPHABET.split(""):
				if s == code[i]:
					continue
				var bad: String = code.left(i) + s + code.substr(i + 1)
				var d: Dictionary = LobbyCode.decode(bad, DEFAULT_PORT)
				assert_true(d.has("error"), "%s (from %s) must be rejected" % [bad, code])
	var good: String = LobbyCode.encode("192.168.0.10", 30000, DEFAULT_PORT)
	var last: String = good.right(1)
	var wrong: String = LobbyCode.ALPHABET[(LobbyCode.ALPHABET.find(last) + 1) % LobbyCode.BASE]
	assert_eq(LobbyCode.decode(good.left(good.length() - 1) + wrong, DEFAULT_PORT), {"error": LobbyCode.E_CHECKSUM})


func test_case_dashes_and_confusables() -> void:
	var code: String = LobbyCode.encode("192.168.0.10", 31337, DEFAULT_PORT)
	var want: Dictionary = {"address": "192.168.0.10", "port": 31337}
	assert_eq(LobbyCode.decode(code.to_lower(), DEFAULT_PORT), want, "lower case")
	assert_eq(LobbyCode.decode("  " + LobbyCode.display(code).to_lower() + " ", DEFAULT_PORT), want, "dashes and spaces")
	var loose: String = code.replace("0", "o").replace("1", "l")
	assert_eq(LobbyCode.decode(loose, DEFAULT_PORT), want, "O / L read as 0 / 1")
	assert_eq(LobbyCode.normalize("i-L o"), "110")


func test_bad_inputs() -> void:
	assert_eq(LobbyCode.encode("::1", DEFAULT_PORT), "", "IPv6 unsupported")
	assert_eq(LobbyCode.encode("fe80::1", 4000), "")
	assert_eq(LobbyCode.encode("example.com", 4000), "", "host names are not encoded")
	assert_eq(LobbyCode.encode("10.0.0.1", 0), "", "port 0")
	assert_eq(LobbyCode.encode("10.0.0.1", 70000), "")
	assert_eq(LobbyCode.decode(""), {"error": LobbyCode.E_EMPTY})
	assert_eq(LobbyCode.decode("ABCD-UFGH"), {"error": LobbyCode.E_CHAR}, "U is not Crockford")
	assert_eq(LobbyCode.decode("ABCD-EF#H"), {"error": LobbyCode.E_CHAR})
	assert_eq(LobbyCode.decode("ABCDEFGHJ"), {"error": LobbyCode.E_LENGTH})
	# A correct check symbol over data whose pad bits are set is still rejected.
	var data: String = "ZZZZZZZ"
	assert_eq(LobbyCode.decode(data + LobbyCode.check_symbol(data)), {"error": LobbyCode.E_FORMAT}, "pad bits")


func test_pick_lan_ipv4() -> void:
	var addrs: PackedStringArray = PackedStringArray(["127.0.0.1", "::1", "fe80::1c2:3", "169.254.3.4", "81.2.69.160",
		"192.168.1.33", "10.0.0.7"])
	assert_eq(LobbyCode.pick_lan_ipv4(addrs), "192.168.1.33", "first private LAN IPv4")
	assert_eq(LobbyCode.pick_lan_ipv4(PackedStringArray(["127.0.0.1", "81.2.69.160"])), "81.2.69.160", "else routable")
	assert_eq(LobbyCode.pick_lan_ipv4(PackedStringArray(["127.0.0.1", "::1"])), "", "nothing shareable")
	assert_true(LobbyCode.is_private_ipv4(LobbyCode.ipv4_to_int("172.31.255.1")))
	assert_false(LobbyCode.is_private_ipv4(LobbyCode.ipv4_to_int("172.32.0.1")))


func _session(net: Node, player_name: String) -> LobbySession:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = player_name
	var s: LobbySession = LobbySession.new()
	s.net = net
	s.profile = p
	net.get_parent().add_child(s)
	return s


func _screen(session: LobbySession) -> LobbyScreen:
	var screen: LobbyScreen = LOBBY_SCENE.instantiate() as LobbyScreen
	screen.setup(session, session.profile)
	add_child(screen)
	return screen


func test_host_sees_code_and_copies_it() -> void:
	var host: LobbySession = _session(BTestUtil.net_branch(self, "HostBranch"), "Host Hana")
	var screen: LobbyScreen = _screen(host)
	await wait_frames(2)
	assert_false(screen.code_box.visible, "no code before hosting")
	screen.host_port_edit.text = str(_port)
	assert_eq(screen.host(), OK)
	await wait_frames(2)
	assert_true(screen.code_box.visible, "host sees its code")
	var code: String = screen.lobby_code()
	var lan: String = LobbyCode.pick_lan_ipv4(IP.get_local_addresses())
	if lan == "":
		assert_eq(code, "")
		assert_eq(screen.code_label.text, UiText.t(&"ui.lobby.code.unavailable"))
		return
	assert_eq(LobbyCode.decode(code), {"address": lan, "port": _port}, "code = LAN address + hosted port")
	assert_eq(screen.code_label.text, UiText.t(&"ui.lobby.code.value", {"code": LobbyCode.display(code)}))
	screen.copy_button.pressed.emit()
	assert_eq(screen.last_copied, LobbyCode.display(code))
	assert_eq(screen.code_hint_label.text, UiText.t(&"ui.lobby.code.copied"))


func test_join_by_code_over_loopback() -> void:
	var host: LobbySession = _session(BTestUtil.net_branch(self, "HostBranch"), "Host Hana")
	assert_eq(host.host(_port), OK)
	var client: LobbySession = _session(BTestUtil.net_branch(self, "ClientBranch"), "Client Cole")
	var screen: LobbyScreen = _screen(client)
	await wait_frames(2)
	assert_true(screen.code_edit.visible and screen.code_join_button.visible, "join-by-code field on the connect view")
	screen.code_edit.text = "not#code"
	assert_eq(screen.join_by_code(), ERR_INVALID_DATA)
	assert_eq(screen.error_label.text, UiText.t(&"ui.lobby.code.error.char"))
	var good: String = LobbyCode.encode("127.0.0.1", _port)
	var bad: String = good.left(good.length() - 1) + ("0" if good.right(1) != "0" else "1")
	screen.code_edit.text = bad
	assert_eq(screen.join_by_code(), ERR_INVALID_DATA)
	assert_eq(screen.error_label.text, UiText.t(&"ui.lobby.code.error.checksum"))
	assert_false(client.is_active(), "nothing joined on a bad code")
	screen.code_edit.text = LobbyCode.display(good).to_lower()
	screen.code_join_button.pressed.emit()
	assert_eq(screen.join_address_edit.text, "127.0.0.1", "the code filled the address field")
	assert_eq(screen.join_port_edit.text, str(_port))
	assert_true(client.is_active(), "joined through the existing join path")
	assert_true(await wait_until(func() -> bool: return client.state.local_slot >= 0, 10.0), "client got a seat")
	assert_eq(host.state.human_slots().size(), 2)
