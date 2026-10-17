## D-116 npc_oneshot (net.md): a real host + a real client process (coop_loopback_client.tscn, as
## test_po8_shot_fx_loopback.gd) on the dev_sandbox:
## - a host NPC one-shot (NetOneshot.play: the door breach's door_kick_<fam> path) reaches the client once, with the
##   same clip / start offset / speed, and the client's AnimDriver plays it;
## - the held cuff hint replicates through the NPC entity state ("ah"): the client's driver sees `cuff` while the
##   host's brain holds it, and loses it after;
## - a civilian's panic_start cue reaches the client (when the sandbox has an animated civilian).
## D-051 conditions: random free port, hard timeout, the child is always killed.
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const PORT_TRIES: int = 12
const HARD_TIMEOUT_S: float = 90.0
const SEED: int = 8108

var _probe: Node = null
var _pid: int = -1
var _rt: HeistRuntime = null
var _reports: Dictionary = {}
var _deadline_ms: int = 0


func after_each() -> void:
	_cleanup()


func after_all() -> void:
	_cleanup()


func test_npc_oneshots_reach_the_client() -> void:
	_deadline_ms = Time.get_ticks_msec() + int(HARD_TIMEOUT_S * 1000.0)
	var port: int = _host()
	if port < 0:
		fail("cannot open an ENet server on localhost (%d random ports tried)" % PORT_TRIES)
		return
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child(_probe)
	_probe.connect(&"reported", _on_reported)
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--", "--port=%d" % port,
		"--timeout=%d" % int(HARD_TIMEOUT_S),
	])
	_pid = OS.create_process(OS.get_executable_path(), args)
	if _pid <= 0:
		fail("client process could not be spawned (%s)" % OS.get_executable_path())
		return
	var joined: bool = await wait_until(func() -> bool: return Net.human_slots().size() >= 2, _budget(40.0))
	assert_true(joined, "client connected and got a crew slot")
	if not joined:
		return
	_rt = await HeistLauncher.launch(&"dev_sandbox", SEED, Enums.Difficulty.ROUTINE, get_tree().root,
		{"skip_casing": true})
	assert_true(_rt != null, "host launched the dev_sandbox")
	if _rt == null:
		return
	var snap: Dictionary = await _snapshot()
	var t0: int = Time.get_ticks_msec()
	while not bool(snap.get("launch_client", false)) and Time.get_ticks_msec() - t0 < int(_budget(30.0) * 1000.0):
		await wait_seconds(0.25)
		snap = await _snapshot()
	if not bool(snap.get("has_rt", false)):
		fail("client built no replica (%s)" % snap)
		return
	var g: NpcBase = _animated(&"guard")
	if g == null:
		fail("dev_sandbox has no animated guard (AnimDriver)")
		return
	_freeze(g)
	await wait_seconds(0.5)  # the client's velocity estimate settles (a one-shot shows standing)
	await _check_oneshot(g)
	await _check_cuff_hint(g)
	var c: NpcBase = _animated(&"civilian")
	if c != null:
		await _check_panic_start(c)
	else:
		print("[d116 npc_oneshot loopback] skip panic_start: no animated civilian in the dev_sandbox")
	assert_true(Time.get_ticks_msec() <= _deadline_ms, "finished within the %.0f s hard timeout" % HARD_TIMEOUT_S)


func _check_oneshot(g: NpcBase) -> void:
	var d: AnimDriver = AnimDriver.of(g)
	var clip: StringName = StringName("door_kick_" + String(d.aim_family()))
	if not d._has_clip(clip):
		clip = &"melee"
	var start: float = 0.4
	var speed: float = 1.25
	var length: float = d.player.get_animation("%s/%s" % [AnimDriver.LIBRARY, clip]).length
	NetOneshot.play(d, clip, (length - start) / speed, speed, start)
	var e: Dictionary = await _wait_anim(g.net_id, func(a: Dictionary) -> bool:
		return (a.get("net", []) as Array).size() == 3)
	var net: Array = e.get("net", [])
	assert_eq(net.size(), 3, "client: the npc_oneshot arrived (%s)" % [e])
	if net.size() == 3:
		assert_eq(StringName(net[0]), clip, "client: same clip")
		assert_near(float(net[1]), start, 0.0001, "client: same start offset")
		assert_near(float(net[2]), speed, 0.0001, "client: same speed")
	assert_eq(StringName(e.get("oneshot", &"")), clip, "client: its AnimDriver plays it (%s)" % [e])


func _check_cuff_hint(g: NpcBase) -> void:
	var brain: Node = g.get_node(^"Brain")
	brain.set(&"anim_hint", &"cuff")
	var e: Dictionary = await _wait_anim(g.net_id, func(a: Dictionary) -> bool: return a.get("hint", &"") == &"cuff")
	assert_eq(StringName(e.get("hint", &"")), &"cuff", "client: the cuff hint arrived (%s)" % [e])
	brain.set(&"anim_hint", &"idle")
	e = await _wait_anim(g.net_id, func(a: Dictionary) -> bool: return a.get("hint", &"x") == &"")
	assert_eq(StringName(e.get("hint", &"x")), &"", "client: and cleared after")


func _check_panic_start(c: NpcBase) -> void:
	_freeze(c)
	var d: AnimDriver = AnimDriver.of(c)
	NetOneshot.relay(d, CivPanic.PANIC_START, 0.0, 1.0)
	var e: Dictionary = await _wait_anim(c.net_id, func(a: Dictionary) -> bool:
		return (a.get("net", []) as Array).size() == 3)
	var net: Array = e.get("net", [])
	assert_eq(net, [CivPanic.PANIC_START, 0.0, 1.0], "client: the panic_start cue arrived (%s)" % [e])


# --- Helpers -------------------------------------------------------------------------------------

## A host NPC of `role` with an AnimDriver, or null.
func _animated(role: StringName) -> NpcBase:
	for n: Node in _rt.npcs(role):
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.alive and AnimDriver.of(npc) != null and AnimDriver.of(npc).player != null:
			return npc
	return null


## Brain / gunner off and the motor stopped: the test owns the NPC's hint and it stands still.
func _freeze(npc: NpcBase) -> void:
	for nm: String in ["Brain", "Gunner"]:
		var c: Node = npc.get_node_or_null(nm)
		if c != null:
			c.set_physics_process(false)
			c.set_process(false)
	var m: NpcMotor = npc.get_node_or_null(^"Motor") as NpcMotor
	if m != null:
		m.stop()


## Poll the client's AnimDriver report for `net_id` until `ok` holds (or the budget runs out).
func _wait_anim(net_id: int, ok: Callable) -> Dictionary:
	var e: Dictionary = {}
	var t_end: int = Time.get_ticks_msec() + int(_budget(10.0) * 1000.0)
	while Time.get_ticks_msec() < t_end:
		var snap: Dictionary = await _snapshot({"anim_ids": [net_id]})
		e = (snap.get("anim", {}) as Dictionary).get(net_id, {}) as Dictionary
		if not e.is_empty() and bool(ok.call(e)):
			break
		await wait_seconds(0.1)
	return e


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


func _on_reported(kind: String, data: Dictionary) -> void:
	_reports[kind] = data


func _snapshot(args: Dictionary = {}) -> Dictionary:
	_reports.erase("snapshot")
	_probe.call(&"command", "snapshot", args)
	await wait_until(func() -> bool: return _reports.has("snapshot"), _budget(10.0))
	return _reports.get("snapshot", {}) as Dictionary


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
