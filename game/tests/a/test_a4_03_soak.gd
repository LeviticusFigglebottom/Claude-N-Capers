## A4-03 4-client soak (roadmap; feeds the LEAD's P6 gate): this process hosts (ENet on localhost) and three headless
## client processes (coop_loopback_client.tscn) join, so the crew is four real peers. The heist goes loud with the
## director running; every client drives its own crew member (LoopbackProbe "soak_drive": move, sprint, turn to the
## nearest enemy, fire, reload). Every CHECK_S the replicated state (LoopbackProbe.of_state: phase, loud, objectives,
## doors, prefabs, bags, NPC positions) of each client is compared with the host's (a discrete mismatch is re-checked
## RETRIES times before it counts as a desync; positions within a tolerance), and memory is sampled on every peer.
## test_a4_03_two_humans_two_bots_soak: the same with one client process and two AI teammates (the common co-op crew).
## Fails on: a client that does not join or build its replica, a desync that persists, memory growth past
## MEM_GROWTH_MB on any peer, or a peer that drops. SCRIPT ERROR lines of the clients go to this process's stdout
## (inherited), so the CI runner fails on them like on ours (D-047). Duration: SOAK_S, or env CAPER_SOAK_S (a long
## soak: CAPER_SOAK_S=1800). Map: SOAK_MAP, or env CAPER_SOAK_MAP (e.g. dockside_burn: police at the enemy cap).
## D-051: random free port, every child killed in after_each.
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
const CLIENTS: int = 3
const SOAK_S: float = 90.0
const CHECK_S: float = 15.0
const RETRIES: int = 4
const NPC_TOL_M: float = 2.5
const BAG_TOL_M: float = 1.5
const MEM_GROWTH_MB: float = 96.0
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const SEED: int = 4303
const SOAK_MAP: StringName = &"dev_sandbox"

var _probe: Node = null
var _pids: Array[int] = []
var _rt: HeistRuntime = null
## peer id -> kind -> data (the latest report)
var _reports: Dictionary = {}
var _parity: OfParity = null


func after_each() -> void:
	for pid: int in _pids:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_pids.clear()
	if _parity != null and is_instance_valid(_parity):
		_parity.queue_free()
	_parity = null
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	_probe = null
	_reports = {}
	Net.leave()
	await wait_frames(2)


func _soak_s() -> float:
	var env: String = OS.get_environment("CAPER_SOAK_S")
	return float(env) if env.is_valid_float() and float(env) > 0.0 else SOAK_S


func test_a4_03_four_peer_soak() -> void:
	await _soak(CLIENTS)


## LEAD: bots in co-op are the common case. The host and one client process, Net.fill_with_ai gives the other two
## slots to AI teammates (CrewAiBrain on the host, replicated like any crew member).
func test_a4_03_two_humans_two_bots_soak() -> void:
	await _soak(1)
	if _rt != null:
		assert_eq(_rt.crew_members().filter(func(c: CrewController) -> bool: return c.is_ai).size(), 2, "two bots")


func _soak(clients: int) -> void:
	var soak_s: float = _soak_s()
	var timeout_s: int = int(soak_s) + 240
	var port: int = _host()
	if port < 0:
		fail("cannot open an ENet server on localhost")
		return
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child(_probe)
	_probe.connect(&"reported_by", func(peer: int, kind: String, data: Dictionary) -> void:
		if not _reports.has(peer):
			_reports[peer] = {}
		(_reports[peer] as Dictionary)[kind] = data)
	for i: int in clients:
		var pid: int = OS.create_process(OS.get_executable_path(), PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--", "--port=%d" % port,
			"--timeout=%d" % timeout_s]))
		if pid <= 0:
			fail("client %d could not be spawned" % i)
			return
		_pids.append(pid)
	var joined: bool = await wait_until(func() -> bool: return Net.human_slots().size() >= clients + 1, 90.0)
	assert_true(joined, "%d clients joined (%d humans)" % [clients, Net.human_slots().size()])
	if not joined:
		return
	var map_env: String = OS.get_environment("CAPER_SOAK_MAP")
	var heist: StringName = StringName(map_env) if map_env != "" else SOAK_MAP
	_rt = await HeistLauncher.launch(heist, SEED, Enums.Difficulty.HAZARDOUS, get_tree().root, {"skip_casing": true, "crew_ai": true})
	assert_true(_rt != null, "the host launched")
	if _rt == null:
		return
	var peers: Array[int] = []
	for p: int in multiplayer.get_peers():
		peers.append(p)
	var ready: bool = await wait_until(func() -> bool:
		_probe.call(&"command", "snapshot", {})
		return peers.all(func(p: int) -> bool: return bool(((_reports.get(p, {}) as Dictionary).get("snapshot", {})
			as Dictionary).get("launch_client", false))), 120.0)
	assert_true(ready, "every client built its replica")
	if not ready:
		return
	for slot: int in _rt.crew_members().map(func(c: CrewController) -> int: return c.slot):
		Modifiers.set_source(slot, &"soak.immune", {&"defense.damage_taken_mult": 0.0})  # a long, stable fight
	_rt.stealth.raise_alarm(&"soak", 0)
	_parity = OfParity.attach(_rt, get_tree().root)
	var i_peer: int = 0
	for p: int in peers:
		i_peer += 1
		_probe.rpc_id(p, &"_rpc_command", "soak_drive", {"seconds": soak_s, "seed": SEED + i_peer})
	await wait_seconds(5.0)
	var mem0: Dictionary = await _memory(peers)
	var desyncs: Array[String] = []
	var rounds: int = 0
	var t_end: int = Time.get_ticks_msec() + int(soak_s * 1000.0)
	while Time.get_ticks_msec() < t_end:
		await wait_seconds(minf(CHECK_S, maxf(float(t_end - Time.get_ticks_msec()) / 1000.0, 0.5)))
		rounds += 1
		for p: int in peers:
			assert_true(multiplayer.get_peers().has(p), "peer %d still connected (round %d)" % [p, rounds])
			var d: Array[String] = await _compare(p)
			if not d.is_empty():
				desyncs.append("round %d peer %d: %s" % [rounds, p, "; ".join(d.slice(0, 4))])
	var mem1: Dictionary = await _memory(peers)
	var npcs: int = _rt.npcs().size()
	var bots: int = _rt.crew_members().filter(func(c: CrewController) -> bool: return c.is_ai).size()
	print("PERF soak %s %.0f s, %d peers + %d bots, %d check rounds, %d NPCs at the end, loud %s" % [_rt.heist_id, soak_s,
		peers.size() + 1, bots, rounds, npcs, _rt.went_loud])
	for k: Variant in mem0:
		assert_true(int(mem0[k]) > 0 and int(mem1.get(k, 0)) > 0, "memory sampled on %s" % k)
		var grow: float = (float(mem1.get(k, 0)) - float(mem0[k])) / 1048576.0
		print("PERF soak memory %s: %.1f -> %.1f MB (%+.1f)" % [k, float(mem0[k]) / 1048576.0, float(mem1.get(k, 0)) / 1048576.0,
			grow])
		assert_true(grow < MEM_GROWTH_MB, "memory growth on %s %.1f MB < %.0f" % [k, grow, MEM_GROWTH_MB])
	assert_eq(desyncs, [] as Array[String], "no persistent desync in %d rounds" % rounds)
	assert_true(_rt.went_loud, "the run stayed loud")
	_probe.call(&"command", "quit", {})


## Static memory per peer ("host" and each client peer id).
func _memory(peers: Array[int]) -> Dictionary:
	var out: Dictionary = {"host": OS.get_static_memory_usage()}
	for p: int in peers:
		var mem: int = 0
		for _i: int in 3:  # a snapshot can time out under load: never count a missing sample as 0 MB
			mem = int((await _snap(p, {})).get("mem", 0))
			if mem > 0:
				break
		out["peer %d" % p] = mem
	return out


func _snap(peer: int, args: Dictionary) -> Dictionary:
	if _reports.has(peer):
		(_reports[peer] as Dictionary).erase("snapshot")
	_probe.rpc_id(peer, &"_rpc_command", "snapshot", args)
	await wait_until(func() -> bool: return (_reports.get(peer, {}) as Dictionary).has("snapshot"), 15.0)
	return (_reports.get(peer, {}) as Dictionary).get("snapshot", {}) as Dictionary


## Client `peer` vs the host (OfParity: against the host's samples since the request - its lag), re-checked while it
## differs (spawns / despawns in flight).
func _compare(peer: int) -> Array[String]:
	var diffs: Array[String] = []
	for _i: int in RETRIES:
		var t_req: int = Time.get_ticks_msec()
		var snap: Dictionary = await _snap(peer, {"of_state": true})
		diffs = _parity.diff(snap.get("of_state", {}) as Dictionary, t_req, {"npcs": NPC_TOL_M, "bags": BAG_TOL_M})
		if diffs.is_empty():
			break
		await wait_seconds(0.5)
	return diffs


func _host() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _i: int in 12:
		var port: int = rng.randi_range(PORT_MIN, PORT_MAX)
		if Net.host(port, "Host") == OK:
			return port
	return -1
