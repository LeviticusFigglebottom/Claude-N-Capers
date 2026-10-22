## A4-03 4-client soak (roadmap; feeds the LEAD's P6 gate): this process hosts (ENet on localhost) and three headless
## client processes (coop_loopback_client.tscn) join, so the crew is four real peers. The heist goes loud with the
## director running; every client drives its own crew member (LoopbackProbe "soak_drive": move, sprint, turn to the
## nearest enemy, fire, reload). Every CHECK_S the replicated state (LoopbackProbe.of_state: phase, loud, objectives,
## doors, prefabs, bags, NPC positions) of each client is compared with the host's (a discrete mismatch is re-checked
## RETRIES times before it counts as a desync; positions within a tolerance), and memory is sampled on every peer.
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


func after_each() -> void:
	for pid: int in _pids:
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	_pids.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	_probe = null
	Net.leave()
	await wait_frames(2)


func _soak_s() -> float:
	var env: String = OS.get_environment("CAPER_SOAK_S")
	return float(env) if env.is_valid_float() and float(env) > 0.0 else SOAK_S


func test_a4_03_four_peer_soak() -> void:
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
	for i: int in CLIENTS:
		var pid: int = OS.create_process(OS.get_executable_path(), PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--", "--port=%d" % port,
			"--timeout=%d" % timeout_s]))
		if pid <= 0:
			fail("client %d could not be spawned" % i)
			return
		_pids.append(pid)
	var joined: bool = await wait_until(func() -> bool: return Net.human_slots().size() >= CLIENTS + 1, 90.0)
	assert_true(joined, "%d clients joined (%d humans)" % [CLIENTS, Net.human_slots().size()])
	if not joined:
		return
	var map_env: String = OS.get_environment("CAPER_SOAK_MAP")
	var heist: StringName = StringName(map_env) if map_env != "" else SOAK_MAP
	_rt = await HeistLauncher.launch(heist, SEED, Enums.Difficulty.HAZARDOUS, get_tree().root, {"skip_casing": true})
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
	print("PERF soak %s %.0f s, %d peers, %d check rounds, %d NPCs at the end, loud %s" % [_rt.heist_id, soak_s,
		peers.size() + 1, rounds, npcs, _rt.went_loud])
	for k: Variant in mem0:
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
		var snap: Dictionary = await _snap(p, {})
		out["peer %d" % p] = int(snap.get("mem", 0))
	return out


func _snap(peer: int, args: Dictionary) -> Dictionary:
	if _reports.has(peer):
		(_reports[peer] as Dictionary).erase("snapshot")
	_probe.rpc_id(peer, &"_rpc_command", "snapshot", args)
	await wait_until(func() -> bool: return (_reports.get(peer, {}) as Dictionary).has("snapshot"), 15.0)
	return (_reports.get(peer, {}) as Dictionary).get("snapshot", {}) as Dictionary


## Client `peer` vs the host, re-checked while it differs (spawns / despawns in flight, interpolation).
func _compare(peer: int) -> Array[String]:
	var diffs: Array[String] = []
	for _i: int in RETRIES:
		var snap: Dictionary = await _snap(peer, {"of_state": true})
		diffs = _diff(PROBE.of_state(_rt), snap.get("of_state", {}) as Dictionary)
		if diffs.is_empty():
			break
		await wait_seconds(0.5)
	return diffs


func _diff(h: Dictionary, c: Dictionary) -> Array[String]:
	if c.is_empty():
		return ["no client snapshot"]
	var out: Array[String] = []
	for k: String in ["phase", "went_loud", "objectives", "reveals"]:
		if str(h[k]) != str(c.get(k)):
			out.append("%s host %s client %s" % [k, h[k], c.get(k)])
	for k: String in ["prefabs", "doors"]:
		var hd: Dictionary = h[k]
		var cd: Dictionary = c.get(k, {})
		for id: Variant in hd:
			if str(hd[id]) != str(cd.get(id)):
				var n: Node = Ids.lookup(int(id))
				out.append("%s %s (%s) host %s client %s" % [k, id, _rt.map.get_path_to(n) if n != null else "?", hd[id], cd.get(id)])
	out.append_array(_pos_diff("npcs", h["npcs"], c.get("npcs", {}), NPC_TOL_M, false))
	out.append_array(_pos_diff("bags", h["bags"], c.get("bags", {}), BAG_TOL_M, true))
	return out


func _pos_diff(k: String, hd: Dictionary, cd: Dictionary, tol: float, with_id: bool) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in hd:
		if not cd.has(id):
			out.append("%s %s missing on the client" % [k, id])
			continue
		var hp: Vector3 = (hd[id][1] if with_id else hd[id]) as Vector3
		var cp: Vector3 = (cd[id][1] if with_id else cd[id]) as Vector3
		if hp.distance_to(cp) > tol:
			out.append("%s %s %.1f m apart" % [k, id, hp.distance_to(cp)])
	for id: Variant in cd:
		if not hd.has(id):
			out.append("%s %s only on the client" % [k, id])
	return out


func _host() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _i: int in 12:
		var port: int = rng.randi_range(PORT_MIN, PORT_MAX)
		if Net.host(port, "Host") == OK:
			return port
	return -1
