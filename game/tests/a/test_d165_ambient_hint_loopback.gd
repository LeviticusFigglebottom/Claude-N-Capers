## D-165 / LEAD r317: calm ambient hints reach the clients (NetEntityCodec "ah"). A real host on Afterhours and two
## real client processes: one in from the lobby, one dropping in mid-heist (the late joiner gets the current hints
## from the join snapshot). For every calm NPC whose host clip held across the sample (dancers, seated VIPs, the
## bartenders, browse / phone / lean; walkers changing clip mid-sample are left out), the client's AnimDriver plays
## the host's clip. Before D-165 a client showed every calm ambient body in the standing idle.
## D-051 conditions: random free port, hard timeout, the children are always killed.
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const SEED: int = 7165
const HARD_TIMEOUT_S: int = 400
const RETRIES: int = 4
## At least this many calm, stationary-clip bodies compared per client (AH's club has dozens).
const MIN_COMPARED: int = 15

var _probe: Node = null
var _pids: Array[int] = []
var _rt: HeistRuntime = null
var _reports: Dictionary = {}
var _port: int = -1


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
	_reports = {}
	var svc: HeistDropIn = DropInService.find(get_tree()) as HeistDropIn
	if svc != null:
		svc.policy = HeistDropIn.POLICY_ASK
	Net.leave()
	await wait_frames(2)


func test_calm_ambient_clips_match_on_clients() -> void:
	if not ResourceLoader.exists(HeistLauncher.map_path(&"afterhours")):
		skip("no afterhours map on this branch")
		return
	_port = _host()
	if _port < 0:
		fail("cannot open an ENet server on localhost")
		return
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child(_probe)
	_probe.connect(&"reported_by", func(peer: int, kind: String, data: Dictionary) -> void:
		if not _reports.has(peer):
			_reports[peer] = {}
		(_reports[peer] as Dictionary)[kind] = data)
	var lobby_pid: int = _spawn_client([])
	var joined: bool = await wait_until(func() -> bool: return Net.human_slots().size() >= 2, 60.0)
	assert_true(joined, "the lobby client connected")
	if not joined:
		return
	var lobby_peer: int = multiplayer.get_peers()[0]
	_rt = await HeistLauncher.launch(&"afterhours", SEED, Enums.Difficulty.ROUTINE, get_tree().root,
		{"skip_casing": true, "crew_ai": true})
	assert_true(_rt != null, "the host launched afterhours")
	if _rt == null or lobby_pid <= 0:
		return
	var svc: HeistDropIn = DropInService.find(get_tree()) as HeistDropIn
	assert_true(svc != null, "the host's drop-in service")
	if svc == null:
		return
	svc.policy = HeistDropIn.POLICY_AUTO
	await wait_seconds(20.0)  # the club settles into its activities (dance floor, seats, bar)
	await _check(lobby_peer, "lobby client")
	var before: PackedInt32Array = multiplayer.get_peers()
	_spawn_client(["--join=dropin"])
	var in2: bool = await wait_until(func() -> bool: return multiplayer.get_peers().size() > before.size(), 90.0)
	assert_true(in2, "the late joiner dropped in")
	if not in2:
		return
	var late_peer: int = 0
	for p: int in multiplayer.get_peers():
		if not before.has(p):
			late_peer = p
	await wait_seconds(8.0)  # its replica built from the join snapshot
	await _check(late_peer, "late joiner")
	_probe.call(&"command", "quit", {})


## Host clips of every calm NPC (net id -> clip).
func _host_clips() -> Dictionary:
	var out: Dictionary = {}
	for n: Node in _rt.npcs():
		var npc: NpcBase = n as NpcBase
		var d: AnimDriver = AnimDriver.of(n)
		if npc != null and d != null and npc.alive and npc.alert_state == Enums.AlertState.CALM:
			out[npc.net_id] = String(d.clip)
	return out


func _client_clips(peer: int) -> Dictionary:
	if _reports.has(peer):
		(_reports[peer] as Dictionary).erase("anim_clips")
	_probe.rpc_id(peer, &"_rpc_command", "anim_clips", {})
	await wait_until(func() -> bool: return (_reports.get(peer, {}) as Dictionary).has("anim_clips"), 15.0)
	return (_reports.get(peer, {}) as Dictionary).get("anim_clips", {}) as Dictionary


## Host before / client / host after: bodies whose host clip held must match on the client.
func _check(peer: int, who: String) -> void:
	var bad: Array[String] = []
	var compared: int = 0
	var kinds: Dictionary = {}
	for _i: int in RETRIES:
		bad.clear()
		compared = 0
		kinds.clear()
		var h0: Dictionary = _host_clips()
		var cc: Dictionary = await _client_clips(peer)
		await wait_seconds(0.5)
		var h1: Dictionary = _host_clips()
		for id: Variant in h0:
			if not h1.has(id) or h1[id] != h0[id] or String(h0[id]).begins_with("walk") or String(h0[id]).begins_with("turn"):
				continue
			var key: Variant = id if cc.has(id) else str(id)
			if not cc.has(key):
				continue
			compared += 1
			kinds[h0[id]] = int(kinds.get(h0[id], 0)) + 1
			if String(cc[key]) != String(h0[id]):
				bad.append("%s host %s client %s" % [Ids.lookup(int(id)).name if Ids.lookup(int(id)) != null else id, h0[id],
					cc[key]])
		if bad.is_empty() and compared >= MIN_COMPARED:
			break
		await wait_seconds(1.0)
	print("D165 %s: %d calm bodies compared, clips %s, mismatches %d" % [who, compared, kinds, bad.size()])
	assert_true(compared >= MIN_COMPARED, "%s: %d calm stationary bodies compared (>= %d)" % [who, compared,
		MIN_COMPARED])
	assert_eq(bad, [] as Array[String], "%s: every calm body plays the host's clip" % who)


func _spawn_client(extra: Array) -> int:
	var pid: int = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--",
		"--port=%d" % _port, "--timeout=%d" % HARD_TIMEOUT_S] + extra))
	if pid > 0:
		_pids.append(pid)
	return pid


func _host() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _i: int in 12:
		var port: int = rng.randi_range(PORT_MIN, PORT_MAX)
		if Net.host(port, "Host") == OK:
			return port
	return -1
