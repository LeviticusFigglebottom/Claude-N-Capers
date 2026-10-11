## QB-B6-DROPIN end to end (two processes, like test_a3_07): the host launches the dev_sandbox with AI
## teammates, THEN a client connects and drops in (coop_loopback_client.tscn --join=dropin ->
## HeistDropIn.request_join). With policy auto the host hands it the AI crew member of its slot and a bring-up
## addressed to it; the client builds the replica, reports joined, and its view matches the host's.
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const PORT_TRIES: int = 12
const HARD_TIMEOUT_S: float = 60.0
const SEED: int = 7072

var _probe: Node = null
var _pid: int = -1
var _rt: HeistRuntime = null
var _reports: Dictionary = {}
var _deadline_ms: int = 0


func after_each() -> void:
	_cleanup()


func after_all() -> void:
	_cleanup()


func test_drop_in_mid_heist() -> void:
	_deadline_ms = Time.get_ticks_msec() + int(HARD_TIMEOUT_S * 1000.0)
	var port: int = _host()
	if port < 0:
		fail("cannot open an ENet server on localhost")
		return
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child(_probe)
	_probe.connect(&"reported", func(kind: String, data: Dictionary) -> void: _reports[kind] = data)
	_rt = await HeistLauncher.launch(&"dev_sandbox", SEED, Enums.Difficulty.ROUTINE, get_tree().root, {"skip_casing": true})
	assert_true(_rt != null, "host launched before anyone joined")
	if _rt == null:
		return
	assert_eq(Net.human_slots().size(), 1, "only the host is human")
	var svc: HeistDropIn = DropInService.find(get_tree()) as HeistDropIn
	assert_true(svc != null, "the host's drop-in service")
	if svc == null:
		return
	svc.policy = HeistDropIn.POLICY_AUTO
	var joined_slots: Array[int] = []
	svc.joined.connect(func(slot: int) -> void: joined_slots.append(slot))
	var failed: Array = []
	svc.join_failed.connect(func(p: int, r: StringName) -> void: failed.append([p, r]))
	_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--",
		"--port=%d" % port, "--timeout=%d" % int(HARD_TIMEOUT_S), "--join=dropin",
	]))
	if _pid <= 0:
		fail("client process could not be spawned")
		return
	var ok: bool = await wait_until(func() -> bool: return not joined_slots.is_empty() or not failed.is_empty(), _budget(40.0))
	assert_true(ok and failed.is_empty(), "dropped in (failed: %s)" % [failed])
	if joined_slots.is_empty():
		return
	var slot: int = joined_slots[0]
	var c: CrewController = _rt.crew_controller(slot) as CrewController
	assert_true(c != null and not c.is_ai and c.peer_id == int(Net.crew[slot]["peer_id"]), "the peer owns the slot's crew member")
	assert_eq(c.display_name, "Dropper", "named from the summary")
	assert_true(c.get_node_or_null(CrewAiBrain.NODE_NAME) == null, "no AI brain")
	_reports.erase("snapshot")
	_probe.call(&"command", "snapshot", {})
	await wait_until(func() -> bool: return _reports.has("snapshot"), _budget(10.0))
	var snap: Dictionary = _reports.get("snapshot", {}) as Dictionary
	assert_true(bool(snap.get("has_rt", false)) and bool(snap.get("replica", false)), "client replica (%s)" % snap)
	if not bool(snap.get("has_rt", false)):
		return
	assert_eq(int(snap["local_slot"]), slot, "the client plays the slot it took")
	assert_eq(int(snap["seed"]), SEED, "same run seed")
	assert_eq(int(snap["missing"]), 0, "every map id resolved")
	var npc_ids: Array[int] = []
	for n: Node in _rt.npcs():
		npc_ids.append(NetIds.of(n))
	npc_ids.sort()
	assert_eq(snap["npc_ids"], npc_ids, "same NPCs as the host")


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
	var svc: HeistDropIn = DropInService.find(get_tree()) as HeistDropIn
	if svc != null:
		svc.policy = HeistDropIn.POLICY_ASK
	Net.leave()
