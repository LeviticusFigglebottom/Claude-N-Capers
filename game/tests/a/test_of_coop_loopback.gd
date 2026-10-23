## OF network check (LEAD 2026-10-20; the game is co-op): a real host (this process) and a real client (a second
## headless process, coop_loopback_client.tscn, A3-07 harness) play Ostrander Federal's loud line on the host
## (X4OfLoud: keycard + code, lockdown, both drill parts, the burn-through: lid / hole / rope ladder / hoist on, the
## cash cage, bags up the hoist, [secure], the loud escape) plus the door-kind Breach_3 / Breach_4 blasts. At every
## milestone the client's replica must match the host: phase, objectives, every map prefab's enabled / visible state
## (lid, gate, rope ladder `usable`, hoist), door open / locked, the hoist car position, loot bags (ids, loot, rest
## position), NPC positions (hub-loop guards before the alarm), crew items (the keycard carried) and revealed groups.
## Positions compare with a tolerance (interpolation); a discrete mismatch is re-checked a few times before it
## fails (a transition can race the snapshot). D-133 crew_damage_taken_mult 0.25 (harness only), 2 AI teammates.
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
const MAP_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const HEIST: StringName = &"ostrander_federal"
const SEED: int = 5
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const PORT_TRIES: int = 12
const HARD_TIMEOUT_S: float = 900.0
const MILESTONES: Array[StringName] = [&"keycard", &"code_pc", &"drill_delivery", &"vault_breach", &"secure", &"escape"]
const BAG_TOL_M: float = 1.0
const NPC_TOL_M: float = 2.5
const LIFT_TOL_M: float = 1.5
const RETRIES: int = 4

var _probe: Node = null
var _pid: int = -1
var _flow: X4StealthFlow = null
var _reports: Dictionary = {}
var _deadline_ms: int = 0
var _checked: Array[String] = []
var _parity: OfParity = null


func after_each() -> void:
	await _cleanup()


func test_of_host_client_parity_loud_line() -> void:
	if not ResourceLoader.exists(MAP_PATH):
		skip("no ostrander_federal map")
		return
	_deadline_ms = Time.get_ticks_msec() + int(HARD_TIMEOUT_S * 1000.0)
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
		"--timeout=%d" % int(HARD_TIMEOUT_S)]))
	if _pid <= 0:
		fail("client process could not be spawned")
		return
	assert_true(await wait_until(func() -> bool: return Net.human_slots().size() >= 2, 30.0), "client joined")
	_flow = X4StealthFlow.new(get_tree().root)  # the runtime under /root on both peers, or RPC paths do not route
	_flow.ai_teammates = 2
	HeistLauncher.dev_options["crew_damage_taken_mult"] = X4OfLoud.CREW_DMG
	var launched: bool = await _flow.launch(HEIST, SEED)
	HeistLauncher.dev_options.erase("crew_damage_taken_mult")
	assert_true(launched, "host launched OF seed %d" % SEED)
	if not launched:
		return
	var snap: Dictionary = await _snapshot()
	var t0: int = Time.get_ticks_msec()
	while not bool(snap.get("launch_client", false)) and Time.get_ticks_msec() - t0 < 60000:
		await wait_seconds(0.5)
		snap = await _snapshot()
	assert_true(bool(snap.get("launch_client", false)), "the client built its replica (%s)" % [snap.keys()])
	if not bool(snap.get("launch_client", false)):
		return
	_parity = OfParity.attach(_flow.rt, get_tree().root)
	await wait_seconds(3.0)  # guards walk their (hub) loops: positions must track on the client
	await _compare("stealth start (hub-loop guards walking)")
	var loud: X4OfLoud = X4OfLoud.new(_flow)
	var result: Array = [false, false]  # [done, ok]
	var runner: Callable = func() -> void:
		result[1] = await loud.play()
		result[0] = true
	runner.call()
	var seen: int = 0
	var breached: bool = false
	while not bool(result[0]) and Time.get_ticks_msec() < _deadline_ms:
		await wait_seconds(0.5)
		if seen < MILESTONES.size() and _flow.completed.has(MILESTONES[seen]):
			await wait_seconds(0.8)  # let the replication of the step land
			await _compare("after %s" % MILESTONES[seen])
			if MILESTONES[seen] == &"vault_breach" and not breached:
				breached = true
				await _door_breaches()
			seen += 1
	assert_true(bool(result[0]) and bool(result[1]), "the host's OF loud line completed (failures %s)" % [_flow.failures])
	for f: String in _flow.failures:
		fail(f)
	await wait_seconds(0.8)
	await _compare("end (escape)")
	assert_true(_checked.size() >= 6, "parity checked at %d points: %s" % [_checked.size(), _checked])


## Breach_3 / Breach_4 (door kind): blown on the host, the doors must be open on the client.
func _door_breaches() -> void:
	var dir: AssaultDirector = _flow.rt.service(G.SVC_DIRECTOR) as AssaultDirector
	if dir == null or dir.events == null:
		fail("no assault event runner")
		return
	for m: String in ["Breach_3", "Breach_4"]:
		var b: AssaultBreach = dir.events.run(&"breach", {"warning_s": 0.3, "damage": 0.0, "squad": []}, m) as AssaultBreach
		assert_true(b != null and b.breach_kind == "door" and b.door != null, "%s: a door breach on the OF map" % m)
	await wait_seconds(1.5)
	await _compare("Breach_3 / Breach_4 door blasts")


## Client vs host `of_state` (OfParity: against the host's samples since the request - its lag), re-checked up to
## RETRIES times while something differs.
func _compare(label: String) -> void:
	var diffs: Array[String] = []
	for i: int in range(RETRIES):
		var t_req: int = Time.get_ticks_msec()
		var snap: Dictionary = await _snapshot({"of_state": true})
		diffs = _parity.diff(snap.get("of_state", {}) as Dictionary, t_req, {"npcs": NPC_TOL_M, "bags": BAG_TOL_M,
			"lifts": LIFT_TOL_M})
		if diffs.is_empty():
			break
		await wait_seconds(0.5)
	_checked.append(label)
	assert_eq(diffs, [] as Array[String], "%s: client matches the host" % label)


func _host() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i: int in range(PORT_TRIES):
		var port: int = rng.randi_range(PORT_MIN, PORT_MAX)
		if Net.host(port, "Host") == OK:
			return port
	return -1


func _snapshot(args: Dictionary = {}) -> Dictionary:
	_reports.erase("snapshot")
	_probe.call(&"command", "snapshot", args)
	await wait_until(func() -> bool: return _reports.has("snapshot"), 15.0)
	return _reports.get("snapshot", {}) as Dictionary


func _cleanup() -> void:
	HeistLauncher.dev_options.erase("crew_damage_taken_mult")
	if _probe != null and is_instance_valid(_probe) and _pid > 0 and OS.is_process_running(_pid):
		_probe.call(&"command", "quit", {})
		var t: int = Time.get_ticks_msec()
		while OS.is_process_running(_pid) and Time.get_ticks_msec() - t < 3000:
			OS.delay_msec(20)
			multiplayer.poll()
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if _parity != null and is_instance_valid(_parity):
		_parity.queue_free()
	_parity = null
	if _flow != null:
		await _flow.teardown()
	_flow = null
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	_probe = null
	Net.leave()
	await wait_frames(2)
