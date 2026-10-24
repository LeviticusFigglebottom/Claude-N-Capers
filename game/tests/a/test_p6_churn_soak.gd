## P6 drop-in / leave churn (LEAD r313; feeds the P6 4-client gate). A real host process with AI teammates runs a heist;
## a persistent client drops in, then a churning client drops in, plays CHURN_STAY_S and quits, CHURN_N times. After every
## join: both clients agree with the host (OfParity, as A4-03). After every leave: the host's replication forgot the
## peer (no member, no D-168 pending queue), its crew member is an AI teammate again (CrewAiBrain back), the crew count and
## human slots are as before, and the host's memory stays flat.
## Env: CAPER_CHURN_MAP (default rolling_thunder), CAPER_CHURN_LOUD=1 (raise the alarm first), CAPER_CHURN_N (default 3),
## CAPER_CHURN_STAY_S (default 15), CAPER_CHURN_NO_INTERP=1 (clients without NetInterp, to compare).
## The LEAD's soak: N=10, STAY=60 on RT and AH, stealth and loud.
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const SEED: int = 7090
const RETRIES: int = 4
const MEM_GROWTH_MB: float = 60.0

var _probe: Node = null
var _pids: Array[int] = []
var _rt: HeistRuntime = null
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
	var svc: HeistDropIn = DropInService.find(get_tree()) as HeistDropIn
	if svc != null:
		svc.policy = HeistDropIn.POLICY_ASK
	Net.leave()
	await wait_frames(2)


func _env_int(key: String, def: int) -> int:
	var v: String = OS.get_environment(key)
	return int(v) if v.is_valid_int() and int(v) > 0 else def


func test_p6_drop_in_leave_churn() -> void:
	var map: StringName = StringName(OS.get_environment("CAPER_CHURN_MAP")) if OS.get_environment("CAPER_CHURN_MAP") != "" \
		else &"rolling_thunder"
	var loud: bool = OS.get_environment("CAPER_CHURN_LOUD") == "1"
	var n: int = _env_int("CAPER_CHURN_N", 3)
	var stay_s: float = float(_env_int("CAPER_CHURN_STAY_S", 15))
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
	_rt = await HeistLauncher.launch(map, SEED, Enums.Difficulty.HAZARDOUS, get_tree().root,
		{"skip_casing": true, "crew_ai": true})
	assert_true(_rt != null, "the host launched %s" % map)
	if _rt == null:
		return
	var svc: HeistDropIn = DropInService.find(get_tree()) as HeistDropIn
	assert_true(svc != null, "the host's drop-in service")
	if svc == null:
		return
	svc.policy = HeistDropIn.POLICY_AUTO
	var crew_n: int = _rt.crew_members().size()
	for c: CrewController in _rt.crew_members():
		Modifiers.set_source(c.slot, &"churn.immune", {&"defense.damage_taken_mult": 0.0})  # a long, stable session
	if loud:
		_rt.stealth.raise_alarm(&"churn", 0)
	_parity = OfParity.attach(_rt, get_tree().root)
	var timeout_s: int = int(stay_s) * (n + 2) + 240
	var persistent: Array = await _drop_in(svc, port, timeout_s)
	assert_false(persistent.is_empty(), "the persistent client dropped in")
	if persistent.is_empty():
		return
	var p_peer: int = int(persistent[1])
	var mem0: int = OS.get_static_memory_usage()
	var desyncs: Array[String] = []
	for i: int in n:
		var ch: Array = await _drop_in(svc, port, int(stay_s) + 120)
		assert_false(ch.is_empty(), "round %d: the churning client dropped in" % i)
		if ch.is_empty():
			return
		var slot: int = int(ch[0])
		var peer: int = int(ch[1])
		var pid: int = int(ch[2])
		for p: int in [p_peer, peer]:
			var d: Array[String] = await _compare(p)
			if not d.is_empty():
				desyncs.append("round %d join, peer %d: %s" % [i, p, "; ".join(d.slice(0, 4))])
		await _stay(stay_s)
		var d2: Array[String] = await _compare(peer)
		if not d2.is_empty():
			desyncs.append("round %d end, peer %d: %s" % [i, peer, "; ".join(d2.slice(0, 4))])
		_probe.rpc_id(peer, &"_rpc_command", "quit", {})
		var gone: bool = await wait_until(func() -> bool: return not multiplayer.get_peers().has(peer), 15.0)
		assert_true(gone, "round %d: the churning client left" % i)
		await wait_seconds(1.0)
		_pids.erase(pid)
		var c: CrewController = _rt.crew_controller(slot) as CrewController
		var ns: HeistNetSync = _rt.net_sync
		assert_false(ns.replicates_to(peer), "round %d: no longer replicated to" % i)
		assert_false(ns._pending.has(peer), "round %d: no D-168 pending queue left for the peer" % i)
		assert_true(c != null and c.is_ai and c.get_node_or_null(CrewAiBrain.NODE_NAME) != null,
			"round %d: slot %d is an AI teammate again (brain back)" % [i, slot])
		assert_eq(_rt.crew_members().size(), crew_n, "round %d: the crew count is unchanged" % i)
		assert_eq(Net.human_slots().size(), 2, "round %d: host + the persistent client" % i)
		print("PERF churn round %d: slot %d peer %d in and out, host mem %.1f MB, %d NPCs" % [i, slot, peer,
			OS.get_static_memory_usage() / 1048576.0, _rt.npcs().size()])
	var grow: float = float(OS.get_static_memory_usage() - mem0) / 1048576.0
	print("PERF churn %s loud %s: %d rounds of %.0f s, host memory %+.1f MB, desyncs %d" % [map, loud, n, stay_s, grow,
		desyncs.size()])
	assert_true(grow < MEM_GROWTH_MB, "host memory growth %.1f MB < %.0f" % [grow, MEM_GROWTH_MB])
	assert_eq(desyncs, [] as Array[String], "every client agrees with the host after every join")
	_probe.call(&"command", "quit", {})


## Play on for `seconds`, releasing custody every 2 s: damage immunity does not stop kicks / tasers / cuffs, and a full
## custody wipe would end the heist (a drop-in is then denied, as it should be).
func _stay(seconds: float) -> void:
	var t_end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < t_end:
		await wait_seconds(minf(2.0, float(t_end - Time.get_ticks_msec()) / 1000.0 + 0.01))
		var cs: CustodySystem = CustodySystem.of(_rt)
		for c: CrewController in _rt.crew_members():
			if cs != null and c.crew_state == Enums.CrewState.CUSTODY:
				cs.release(c.slot)


## Spawn a client that drops into the running heist; [slot, peer, pid] once joined, [] on failure.
func _drop_in(svc: HeistDropIn, port: int, timeout_s: int) -> Array:
	var joined: Array[int] = []
	var failed: Array = []
	var on_join: Callable = func(slot: int) -> void: joined.append(slot)
	var on_fail: Callable = func(p: int, r: StringName) -> void: failed.append([p, r])
	svc.joined.connect(on_join)
	svc.join_failed.connect(on_fail)
	var before: PackedInt32Array = multiplayer.get_peers()
	var pid: int = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--",
		"--port=%d" % port, "--timeout=%d" % timeout_s, "--join=dropin"]
		+ (["--no-interp"] if OS.get_environment("CAPER_CHURN_NO_INTERP") == "1" else [])))
	if pid > 0:
		_pids.append(pid)
	var ok: bool = pid > 0 and await wait_until(func() -> bool: return not joined.is_empty() or not failed.is_empty(), 90.0)
	svc.joined.disconnect(on_join)
	svc.join_failed.disconnect(on_fail)
	if not ok or joined.is_empty():
		assert_eq(failed, [], "join failures")
		return []
	var peer: int = 0
	for p: int in multiplayer.get_peers():
		if not before.has(p):
			peer = p
	return [joined[0], peer, pid]


func _snap(peer: int, args: Dictionary) -> Dictionary:
	if _reports.has(peer):
		(_reports[peer] as Dictionary).erase("snapshot")
	_probe.rpc_id(peer, &"_rpc_command", "snapshot", args)
	var want_of: bool = bool(args.get("of_state", false))
	await wait_until(func() -> bool:
		var r: Dictionary = _reports.get(peer, {}) as Dictionary
		if not r.has("snapshot"):
			return false
		if want_of and ((r["snapshot"] as Dictionary).get("of_state", {}) as Dictionary).is_empty():
			r.erase("snapshot")
			return false
		return true, 15.0)
	return (_reports.get(peer, {}) as Dictionary).get("snapshot", {}) as Dictionary


func _compare(peer: int) -> Array[String]:
	var diffs: Array[String] = []
	for _i: int in RETRIES:
		var t_req: int = Time.get_ticks_msec()
		var snap: Dictionary = await _snap(peer, {"of_state": true})
		diffs = _parity.diff(snap.get("of_state", {}) as Dictionary, t_req, {"npcs": 2.5, "bags": 1.5})
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
