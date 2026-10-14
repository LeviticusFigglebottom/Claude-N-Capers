## Ruling C11 (PD2): after a co-op payday, Continue returns every peer to the crew lobby with the Net session
## KEPT (only Leave ends it), and the next heist starts again from that lobby. Two processes like
## test_a3_07_coop_loopback.gd: the host (this process) and a client (coop_loopback_client.tscn) connect ONCE;
## heist 1 is launched (host HeistLauncher.launch, client HeistLauncher.launch_client) and ended; the host tears
## down FIRST while the client is still on its payday screen (its replica alive), then the client tears down, both
## WITHOUT Net.leave(); the session must still be up (peer connected, the client's human slot in Net.crew; AI seats
## stay for the lobby's Crew AI and a joiner takes one over); heist 2 is launched on the same session with another seed and the
## client gets a fresh replica of it: new seed, every map id resolved, objectives seeded, same NPC and crew ids.
## SCRIPT ERRORs on either side (the client's stdout is inherited) fail the run (run_tests.sh, D-047).
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const PORT_TRIES: int = 12
const HARD_TIMEOUT_S: float = 90.0
const SEED_1: int = 7111
const SEED_2: int = 7222

var _probe: Node = null
var _pid: int = -1
var _rt: HeistRuntime = null
var _reports: Dictionary = {}
var _acks: Array[Dictionary] = []
var _deadline_ms: int = 0


func after_each() -> void:
	_cleanup()


func after_all() -> void:
	_cleanup()


func test_two_heists_on_one_session() -> void:
	_deadline_ms = Time.get_ticks_msec() + int(HARD_TIMEOUT_S * 1000.0)
	if not await _connect():
		return
	var client_peer: int = _client_peer()
	var client_slot: int = Net.slot_of_peer(client_peer)
	if not await _launch_and_check(SEED_1, client_slot, "heist 1"):
		return
	await _payday_host_first(client_peer, client_slot)
	var ack: Dictionary = await _command("launch_client", {"timeout": _budget(40.0)})
	assert_true(not ack.is_empty(), "client waits for the next bring-up")
	if not await _launch_and_check(SEED_2, client_slot, "heist 2"):
		return
	await _payday_client_first(client_peer, client_slot)
	assert_true(Time.get_ticks_msec() <= _deadline_ms, "finished within the %.0f s hard timeout" % HARD_TIMEOUT_S)


## Host + client process, connected once (the client's launch_client() already waits for heist 1).
func _connect() -> bool:
	var port: int = _host()
	if port < 0:
		fail("cannot open an ENet server on localhost (%d random ports tried)" % PORT_TRIES)
		return false
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child(_probe)
	_probe.connect(&"reported", _on_reported)
	_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--",
		"--port=%d" % port, "--timeout=%d" % int(HARD_TIMEOUT_S),
	]))
	if _pid <= 0:
		fail("client process could not be spawned (%s)" % OS.get_executable_path())
		return false
	var joined: bool = await wait_until(func() -> bool: return Net.human_slots().size() >= 2, _budget(30.0))
	assert_true(joined, "client connected and got a crew slot")
	return joined


func _launch_and_check(seed: int, client_slot: int, what: String) -> bool:
	_rt = await HeistLauncher.launch(&"dev_sandbox", seed, Enums.Difficulty.ROUTINE, get_tree().root, {"skip_casing": true})
	assert_true(_rt != null, "%s launched on the session" % what)
	if _rt == null:
		return false
	assert_true(_rt.net_sync.replicates_to(_client_peer()), "%s: the host replicates to the client" % what)
	var snap: Dictionary = await _wait_replica(seed)
	assert_true(bool(snap.get("launch_client", false)), "%s: launch_client() returned a fresh replica (%s)" % [what, _brief(snap)])
	if not bool(snap.get("has_rt", false)):
		return false
	_check_replica(snap, seed, client_slot, what)
	return true


## Payday 1: the host Continues first while the client is still on its payday screen, then the client.
func _payday_host_first(client_peer: int, client_slot: int) -> void:
	_rt.end_heist(true)
	await wait_seconds(0.5)  # heist_ended [R] reaches the client
	_rt.teardown()
	_rt = null
	await wait_seconds(1.5)  # the client's replica outlives the host's: nothing may break on either side
	var snap: Dictionary = await _snapshot()
	assert_true(bool(snap.get("has_rt", false)), "the client's replica outlives the host's teardown (payday screen)")
	assert_eq(int(snap.get("phase", -1)), int(Enums.HeistPhase.ENDED), "the client saw the heist end")
	assert_true(bool(snap.get("host_closed", false)), "the client learned the host closed the heist (replica frozen)")
	var ack: Dictionary = await _command("teardown")
	assert_true(bool(ack.get("had_rt", false)), "client tore its replica down (Continue)")
	assert_true(bool(ack.get("session", false)), "client still connected to the host after its teardown")
	await wait_seconds(0.5)
	snap = await _snapshot()
	assert_true(not snap.is_empty() and not bool(snap.get("has_rt", true)), "no runtime left on the client")
	_check_lobby(client_peer, client_slot, "after payday 1")
	assert_true(HeistRuntime.current() == null, "no runtime left on the host")


## Payday 2: the client Continues first while the host is still on its payday screen, then the host.
func _payday_client_first(client_peer: int, client_slot: int) -> void:
	_rt.end_heist(true)
	await wait_seconds(0.5)
	var ack: Dictionary = await _command("teardown")
	assert_true(bool(ack.get("had_rt", false)), "client tore heist 2 down first")
	var rt: HeistRuntime = _rt
	var left: bool = await wait_until(func() -> bool: return not rt.net_sync.replicates_to(client_peer), _budget(5.0))
	assert_true(left, "the host stopped replicating heist 2 to the client that left it")
	await wait_seconds(1.0)  # the host keeps simulating its ended heist: nothing may reach the client's freed replica
	_rt.teardown()
	_rt = null
	await wait_seconds(0.5)
	_check_lobby(client_peer, client_slot, "after payday 2")
	var snap: Dictionary = await _snapshot()
	assert_true(not snap.is_empty() and not bool(snap.get("has_rt", true)), "client answers from the lobby")


func _check_lobby(client_peer: int, client_slot: int, what: String) -> void:
	assert_true(multiplayer.get_peers().has(client_peer), "C11 %s: the client is still connected" % what)
	assert_eq(Net.slot_of_peer(client_peer), client_slot, "C11 %s: the client keeps its human slot" % what)
	assert_true(Net.crew.has(Net.local_slot()), "C11 %s: the host keeps its slot" % what)


func _check_replica(snap: Dictionary, seed: int, client_slot: int, what: String) -> void:
	assert_true(bool(snap.get("replica", false)), "%s: the client runtime is a replica" % what)
	assert_eq(int(snap.get("seed", -1)), seed, "%s: the replica has the run seed" % what)
	assert_eq(int(snap.get("missing", -1)), 0, "%s: every map id resolved on the client" % what)
	assert_eq(snap.get("variants"), _rt.variants, "%s: same resolved variants" % what)
	assert_eq(snap.get("map_ids"), _rt.net_sync.map_id_table(), "%s: same map-placed net ids" % what)
	var host_obj: Array = _rt.hud_model.objectives.map(func(o: Dictionary) -> String:
		return "%s:%d" % [o["id"], int(o["state"])])
	assert_true(not host_obj.is_empty(), "%s: the host mission has objectives" % what)
	assert_eq(snap.get("hud_objectives", []), host_obj, "%s: the client HUD has the host's objectives" % what)
	var npc_ids: Array[int] = []
	for n: Node in _rt.npcs():
		npc_ids.append(NetIds.of(n))
	npc_ids.sort()
	assert_eq(snap.get("npc_ids"), npc_ids, "%s: same NPC net ids" % what)
	var crew_ids: Dictionary = {}
	for c: CrewController in _rt.crew_members():
		crew_ids[c.slot] = c.net_id
	assert_eq(snap.get("crew_ids"), crew_ids, "%s: same crew slot -> net id map" % what)
	assert_eq(int(snap.get("local_slot", -1)), client_slot, "%s: the client plays its lobby slot" % what)
	var c: CrewController = _rt.crew_controller(client_slot) as CrewController
	assert_true(c != null and not c.is_ai and c.peer_id == _client_peer(), "%s: the client's crew member is remote-owned" % what)


## Polls the client until its launch_client() returned the replica of the heist with `seed`.
func _wait_replica(seed: int) -> Dictionary:
	var snap: Dictionary = await _snapshot()
	var t0: int = Time.get_ticks_msec()
	while not (bool(snap.get("launch_client", false)) and int(snap.get("seed", -1)) == seed) \
			and Time.get_ticks_msec() - t0 < int(_budget(30.0) * 1000.0):
		await wait_seconds(0.25)
		snap = await _snapshot()
	return snap


func _snapshot() -> Dictionary:
	_reports.erase("snapshot")
	_probe.call(&"command", "snapshot", {})
	await wait_until(func() -> bool: return _reports.has("snapshot"), _budget(10.0))
	return _reports.get("snapshot", {}) as Dictionary


func _command(cmd: String, args: Dictionary = {}) -> Dictionary:
	_acks.clear()
	_probe.call(&"command", cmd, args)
	var got: Array = []
	var acked: Callable = func() -> bool:
		for a: Dictionary in _acks:
			if String(a.get("cmd", "")) == cmd:
				got.append(a)
				return true
		return false
	await wait_until(acked, _budget(10.0))
	return got[0] as Dictionary if not got.is_empty() else {}


func _on_reported(kind: String, data: Dictionary) -> void:
	if kind == "ack":
		_acks.append(data)
	else:
		_reports[kind] = data


func _client_peer() -> int:
	for p: int in multiplayer.get_peers():
		return p
	return -1


static func _brief(snap: Dictionary) -> String:
	return "has_rt=%s seed=%s missing=%s" % [snap.get("has_rt"), snap.get("seed"), snap.get("missing")]


func _host() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i: int in range(PORT_TRIES):
		var port: int = rng.randi_range(PORT_MIN, PORT_MAX)
		if Net.host(port, "Host") == OK:
			return port
	return -1


func _budget(cap: float) -> float:
	return clampf(minf(cap, float(_deadline_ms - Time.get_ticks_msec()) / 1000.0), 0.05, cap)


func _cleanup() -> void:
	if _probe != null and is_instance_valid(_probe) and _pid > 0 and OS.is_process_running(_pid):
		_probe.call(&"command", "quit", {})
		var t: int = Time.get_ticks_msec()
		while OS.is_process_running(_pid) and Time.get_ticks_msec() - t < 3000:
			OS.delay_msec(20)
			multiplayer.poll()
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	_probe = null
	Net.leave()
