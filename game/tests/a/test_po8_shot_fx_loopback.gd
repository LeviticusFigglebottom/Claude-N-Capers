## PO-8 (D-105, impact_fx.md 1.0 §2 "emitted on EVERY peer"): a real host + a real client process
## (coop_loopback_client.tscn, as test_a3_07_coop_loopback.gd) on the dev_sandbox:
## - a host crew shot: shot_fx once per pellet on the host (first person) AND on the client (third person,
##   replayed from the relayed seed: same end point);
## - a remote client's shot: once on the client (its own, first person) and once on the host (replayed),
##   never twice on either;
## - an NPC shot and an explosion reach the client once each.
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
var _shots: Array[Dictionary] = []


func after_each() -> void:
	_cleanup()


func after_all() -> void:
	_cleanup()


func _on_shot_fx(origin: Vector3, end: Vector3, normal: Vector3, surface: StringName, weapon_class: StringName,
		shooter: int, flags: int) -> void:
	_shots.append({"origin": origin, "end": end, "normal": normal, "surface": surface, "class": weapon_class,
		"shooter": shooter, "flags": flags})


func test_shot_fx_on_host_and_client() -> void:
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
	EventBus.shot_fx.connect(_on_shot_fx)
	await _check_host_crew_shot()
	await _check_client_crew_shot(int(snap["local_slot"]))
	await _check_npc_shot_and_explosion()
	EventBus.shot_fx.disconnect(_on_shot_fx)
	assert_true(Time.get_ticks_msec() <= _deadline_ms, "finished within the %.0f s hard timeout" % HARD_TIMEOUT_S)


func _of(list: Array, shooter: int) -> Array:
	return list.filter(func(s: Variant) -> bool: return int((s as Dictionary)["shooter"]) == shooter)


func _check_host_crew_shot() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(c != null and c.is_local(), "slot 0 is the host's own human")
	if c == null:
		return
	c.set_masked(true)
	await wait_seconds(0.3)
	await _clear_fx()
	_shots.clear()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = c.look_yaw
	i.look_pitch = deg_to_rad(-20.0)  # into the floor a few metres ahead: a surface on both peers
	i.fire = true
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	var rel: CrewIntent = CrewIntent.new()
	rel.look_yaw = i.look_yaw
	rel.look_pitch = i.look_pitch
	_rt.set_bot_intent(0, rel)
	await wait_physics_frames(2)
	_rt.clear_bot_intent(0)
	var pellets: int = maxi(c.weapons.stats(c.weapons.equipped_slot).pellets, 1)
	var host_fx: Array = _of(_shots, c.net_id)
	assert_eq(c.weapons.shots_fired, 1, "the host fired once")
	assert_eq(host_fx.size(), pellets, "host: one shot_fx per pellet, no double emission")
	var snap: Dictionary = await _wait_client_fx(c.net_id, pellets)
	var client_fx: Array = _of(snap.get("shot_fx", []), c.net_id)
	assert_eq(client_fx.size(), pellets, "client: the host's shot replayed once per pellet")
	if host_fx.size() == 1 and client_fx.size() == 1:
		var h: Dictionary = host_fx[0]
		var k: Dictionary = client_fx[0]
		assert_true(int(h["flags"]) & ShotFx.FLAG_FIRST_PERSON != 0, "host: first person (own crew)")
		assert_eq(int(k["flags"]) & ShotFx.FLAG_FIRST_PERSON, 0, "client: third person")
		assert_eq(int(k["flags"]) & ShotFx.FLAG_SUPPRESSED, int(h["flags"]) & ShotFx.FLAG_SUPPRESSED, "same suppressed flag")
		assert_true((k["end"] as Vector3).distance_to(h["end"] as Vector3) < 0.05,
			"same impact point (host %s, client %s)" % [h["end"], k["end"]])
		assert_eq(StringName(k["surface"]), StringName(h["surface"]), "same surface")
		assert_ne(StringName(k["surface"]), &"", "the floor was hit")


func _check_client_crew_shot(slot: int) -> void:
	var crew: CrewController = _rt.crew_controller(slot) as CrewController
	assert_true(crew != null and not crew.is_local(), "client slot %d is a remote human" % slot)
	if crew == null:
		return
	crew.set_masked(true)
	await wait_seconds(0.5)
	await _clear_fx()
	_shots.clear()
	var before: int = crew.weapons.shots_fired
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = crew.look_yaw
	i.look_pitch = deg_to_rad(-20.0)
	i.fire = true
	_probe.call(&"command", "intent", {"intent": i.to_dict()})
	var fired: bool = await wait_until(func() -> bool: return crew.weapons.shots_fired > before, _budget(10.0))
	_probe.call(&"command", "clear_intent", {})
	assert_true(fired, "the client's shot was accepted by the host")
	await wait_seconds(0.5)
	var shots: int = crew.weapons.shots_fired - before
	var pellets: int = maxi(crew.weapons.stats(crew.weapons.equipped_slot).pellets, 1)
	assert_eq(_of(_shots, crew.net_id).size(), shots * pellets, "host: the client's shot replayed once per pellet")
	var snap: Dictionary = await _snapshot()
	var mine: Array = _of(snap.get("shot_fx", []), crew.net_id)
	assert_eq(mine.size(), shots * pellets, "client: its own shot emitted once (not again from the relay)")
	for s: Variant in mine:
		assert_true(int((s as Dictionary)["flags"]) & ShotFx.FLAG_FIRST_PERSON != 0, "client: first person")
	for s: Variant in _of(_shots, crew.net_id):
		assert_eq(int((s as Dictionary)["flags"]) & ShotFx.FLAG_FIRST_PERSON, 0, "host: third person")


func _check_npc_shot_and_explosion() -> void:
	var npcs: Array = _rt.npcs(&"guard")
	assert_false(npcs.is_empty(), "dev_sandbox has guards")
	if npcs.is_empty():
		return
	var g: NpcBase = npcs[0] as NpcBase
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _clear_fx()
	_shots.clear()
	# The NpcGunner hook (test_po8_shot_fx.gd) without its gameplay side effects (noise, damage).
	ShotFx.npc_shot(g, g.eye_position(), c.eye_position(), true, c)
	ShotFx.npc_shot(g, g.eye_position(), c.eye_position(), false, c)
	Explosion.apply(c, c.global_position + Vector3(0, 0.5, 30.0), 2.0, 0.0, 0, Safe.C4_ITEM)
	assert_eq(_of(_shots, g.net_id).size(), 2, "host: one shot_fx per NPC shot")
	var snap: Dictionary = await _wait_client_fx(g.net_id, 2)
	var theirs: Array = _of(snap.get("shot_fx", []), g.net_id)
	assert_eq(theirs.size(), 2, "client: one shot_fx per NPC shot")
	if theirs.size() == 2:
		assert_eq(StringName((theirs[0] as Dictionary)["surface"]), &"flesh", "client: the hit lands on the crew")
		assert_true(((theirs[0] as Dictionary)["end"] as Vector3).distance_to(c.eye_position()) < 0.5, "hit end at the aim point")
	var blasts: Array = snap.get("explosion_fx", [])
	assert_eq(blasts.size(), 1, "client: one explosion_fx")
	if blasts.size() == 1:
		assert_eq(StringName((blasts[0] as Dictionary)["kind"]), &"c4")


# --- Helpers -------------------------------------------------------------------------------------

func _clear_fx() -> void:
	_reports.erase("ack")
	_probe.call(&"command", "clear_fx", {})
	await wait_until(func() -> bool: return _reports.has("ack"), _budget(10.0))


## Poll the client until it reports `n` shot_fx of `shooter` (or the budget runs out).
func _wait_client_fx(shooter: int, n: int) -> Dictionary:
	var snap: Dictionary = {}
	var t_end: int = Time.get_ticks_msec() + int(_budget(10.0) * 1000.0)
	while Time.get_ticks_msec() < t_end:
		snap = await _snapshot()
		if _of(snap.get("shot_fx", []), shooter).size() >= n:
			break
		await wait_seconds(0.2)
	await wait_seconds(0.3)  # anything extra (a double emission) would arrive by now
	return await _snapshot()


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
	if EventBus.shot_fx.is_connected(_on_shot_fx):
		EventBus.shot_fx.disconnect(_on_shot_fx)
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
