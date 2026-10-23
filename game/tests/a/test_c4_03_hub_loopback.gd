## C4-03 hub check (LEAD; B6-06 + A3-11 on C's real staged safehouse_g1.tscn), host + 1 client process: with the ENet
## session up, each peer runs HubCheck (MenuFlow's 3D safehouse, ENV A's hub crew): spawn at ReturnHeist, the armory
## pressed through the crew's own interaction opens its screen, Back returns to its UsePoint, ReturnRange /
## ReturnHeist / an unknown marker (-> Spawn) on re-entry. The client is not the authority: the hub must not need it.
## D-051: random free port, the child killed in after_each.
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
## Spawn / teleport settle tolerance (m, flat).
const TOL_M: float = 0.3

var _probe: Node = null
var _pid: int = -1
var _reports: Dictionary = {}


func after_each() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	_probe = null
	Net.leave()
	await wait_frames(2)


func test_c4_03_safehouse_on_host_and_client() -> void:
	if not ResourceLoader.exists(HubCheck.SCENE):
		skip("safehouse_g1.tscn not on this branch")
		return
	var port: int = _host()
	if port < 0:
		fail("cannot open an ENet server on localhost")
		return
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child(_probe)
	_probe.connect(&"reported", func(kind: String, data: Dictionary) -> void: _reports[kind] = data)
	_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--", "--port=%d" % port,
		"--timeout=240"]))
	assert_true(_pid > 0, "client spawned")
	assert_true(await wait_until(func() -> bool: return Net.human_slots().size() >= 2, 60.0), "client joined")
	var host_res: Dictionary = await HubCheck.run(self, "user://a_c403_host")
	_check("host", host_res, true)
	_probe.call(&"command", "hub_check", {"root_dir": "user://a_c403_client"})
	assert_true(await wait_until(func() -> bool: return _reports.has("hub_check"), 90.0), "client reported")
	_check("client", _reports.get("hub_check", {}) as Dictionary, false)
	_probe.call(&"command", "quit", {})


func _check(who: String, r: Dictionary, authority: bool) -> void:
	print("HUB %s %s" % [who, r])
	assert_eq(bool(r.get("authority", not authority)), authority, "%s authority %s" % [who, authority])
	assert_true(int(r.get("peers", 0)) >= 1, "%s: the session is up" % who)
	assert_true(bool(r.get("active", false)), "%s: the 3D safehouse entered" % who)
	assert_true(bool(r.get("hub_crew", false)), "%s: ENV A's hub crew is the walker" % who)
	assert_true(bool(r.get("civilian", false)), "%s: unmasked civilian" % who)
	assert_true(float(r.get("spawn_m", 99.0)) < TOL_M and float(r.get("spawn_m", -1.0)) >= 0.0,
		"%s: spawned at ReturnHeist (%.2f m)" % [who, r.get("spawn_m", -1.0)])
	assert_eq(int(r.get("stations", 0)), 9, "%s: C's nine stations" % who)
	assert_true(bool(r.get("station_found", false)), "%s: the armory with its UsePoint and Interactable" % who)
	assert_true(bool(r.get("opened", false)), "%s: aim + interact on the armory opens the loadout screen" % who)
	assert_true(bool(r.get("back_hud", false)), "%s: Back -> walking again" % who)
	assert_true(float(r.get("back_m", 99.0)) < TOL_M, "%s: back at the armory UsePoint (%.2f m)" % [who, r.get("back_m", -1.0)])
	for m: String in ["ReturnRange", "ReturnHeist", "NoSuchMarker"]:
		var d: float = float(r.get("return_%s_m" % m, -1.0))
		assert_true(d >= 0.0 and d < TOL_M, "%s: re-entry at %s (%.2f m)" % [who, m, d])


func _host() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _i: int in 12:
		var port: int = rng.randi_range(PORT_MIN, PORT_MAX)
		if Net.host(port, "Host") == OK:
			return port
	return -1
