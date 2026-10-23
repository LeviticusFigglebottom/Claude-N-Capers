## B6-05 LanDiscovery on localhost: a host beacon (to 127.0.0.1 on a random port) shows up in a browser's host list with
## its address, game port, name, players and heist; an update changes the row; a beacon of another protocol version
## or not ours is ignored; a stopped beacon expires after EXPIRY_S.
extends TestCase

var _host: LanDiscovery = null
var _browser: LanDiscovery = null
var _lists: Array = []


func after_each() -> void:
	for n: LanDiscovery in [_host, _browser]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_host = null
	_browser = null
	_lists.clear()
	await wait_frames(2)


func _pair() -> bool:
	var port: int = 0
	_browser = LanDiscovery.new()
	add_child(_browser)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _i: int in 10:
		port = rng.randi_range(40000, 48000)
		_browser.discovery_port = port
		if _browser.start_listening():
			break
	_browser.hosts_changed.connect(func(h: Array) -> void: _lists.append(h))
	_host = LanDiscovery.new()
	add_child(_host)
	_host.discovery_port = port
	_host.beacon_address = "127.0.0.1"
	return _browser.listening


func test_beacon_listed_updated_and_expired() -> void:
	assert_true(await _pair(), "the browser listens")
	assert_true(_host.start_beacon({"name": "Dallas", "port": 7777, "players": 1, "max_players": 4,
		"heist": &"dockside_burn"}), "the host beacons")
	assert_true(await wait_until(func() -> bool: return _browser.hosts().size() == 1, 3.0), "the host is listed")
	var row: Dictionary = _browser.hosts()[0] if not _browser.hosts().is_empty() else {}
	assert_eq(str(row.get("address", "")), "127.0.0.1", "sender address")
	assert_eq(int(row.get("port", 0)), 7777, "the game port from the beacon")
	assert_eq(str(row.get("name", "")), "Dallas")
	assert_eq(StringName(row.get("heist", &"")), &"dockside_burn")
	assert_eq(int(row.get("version", -1)), LanDiscovery.VERSION)
	_host.update_beacon({"players": 3})
	assert_true(await wait_until(func() -> bool:
		return not _browser.hosts().is_empty() and int(_browser.hosts()[0]["players"]) == 3, 3.0), "the update arrives")
	assert_true(_lists.size() >= 2, "hosts_changed on add and on change")
	_host.stop_beacon()
	await wait_seconds(LanDiscovery.EXPIRY_S * 0.5)
	assert_eq(_browser.hosts().size(), 1, "still listed within EXPIRY_S")
	assert_true(await wait_until(func() -> bool: return _browser.hosts().is_empty(), LanDiscovery.EXPIRY_S + 1.0),
		"expired after the last beacon")


func test_foreign_packets_are_ignored() -> void:
	assert_true(await _pair(), "the browser listens")
	var raw: PacketPeerUDP = PacketPeerUDP.new()
	raw.set_dest_address("127.0.0.1", _browser.discovery_port)
	raw.put_packet(var_to_bytes({"magic": LanDiscovery.MAGIC, "version": LanDiscovery.VERSION + 1, "port": 7000}))
	raw.put_packet(var_to_bytes({"magic": "SOMETHING-ELSE", "version": LanDiscovery.VERSION, "port": 7001}))
	raw.put_packet("not a variant".to_utf8_buffer())
	await wait_seconds(0.5)
	raw.close()
	assert_eq(_browser.hosts().size(), 0, "another version, another magic and garbage are not hosts")


func test_ensure_is_one_node_per_tree() -> void:
	var a: LanDiscovery = LanDiscovery.ensure(get_tree())
	var b: LanDiscovery = LanDiscovery.ensure(get_tree())
	assert_eq(a, b, "one LanDiscovery under the root")
	a.queue_free()
