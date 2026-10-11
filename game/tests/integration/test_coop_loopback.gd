## P3 GATE: co-op loopback (docs/roadmap.md P3 gate, docs/contracts/net.md). Owner: LEAD.
## A real host (this process, ENet server on localhost) and a real client: a second headless Godot
## process running tests/integration/bots/coop_client.tscn, which joins and builds its replica with
## `await HeistLauncher.launch_client()` (heist/README.md "Client heist launch", D-054). Two processes,
## not two SceneMultiplayer branches: gameplay authority checks, EventBus, Ids and HeistRuntime.current()
## are process-wide (see ENV A's test_a3_07_coop_loopback.gd), so only a second process proves parity.
## On the P3 map (HEIST) the client replica must see: the same variants, crew (slot -> net id), NPC
## count and ids; a door the host's bot opens by interaction; a loot bag secured at the van in stealth
## (bag gone + loot_secured [R]; one bag, so the mission's 2-bag escape stays closed and the phase can
## still turn LOUD); the alarm (LOUD + alarm_raised [R]); and heist_ended [R]. Glasshouse's van leaves
## at the alarm and returns after 240 s and a FADE (glasshouse.md "Escape", far beyond D-051's 30 s),
## so the heist ends through the L2.9 all-custody rule: the whole crew is put in custody
## (CrewHealth.go_to_custody, server) -> heist_ended(fail, all_custody), the bag in its result.
## D-051: random free port (retried on bind failure) passed on the child's command line; the test is
## hard-capped at HARD_TIMEOUT_S (the child self-quits after the same time); the child is always
## killed (after_each / after_all, OS.kill fallback); failing to bind, spawn or join FAILS, never skips.
## The child's stdout is inherited, so its SCRIPT ERROR lines fail CI like ours (D-047).
extends TestCase

## P3 map. Glasshouse until Dockside Burn (B5-04 + ENV C) lands; switch this constant then.
const HEIST: StringName = &"glasshouse"
## Seed 3074 resolves escape = esc_pell (secure zone at the Pell van). esc_alley_west (seeds 3071-3073)
## cannot secure bags: its
## VanSecureE1 zone floor sits 0.15 m above the alley ground (reported to ENV C).
const SEED: int = 3074
const PROBE: GDScript = preload("res://tests/integration/bots/coop_probe.gd")
const CLIENT_SCENE: String = "res://tests/integration/bots/coop_client.tscn"
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const PORT_TRIES: int = 12
const HARD_TIMEOUT_S: float = 60.0
const RUNTIME_TARGET_S: float = 30.0
const LOOT_ID: StringName = &"loot.jewelry"
const RISE_FRAMES: int = 3

var _probe: Node = null
var _pid: int = -1
var _rt: HeistRuntime = null
var _reports: Dictionary = {}
var _deadline_ms: int = 0
var _host_facts: Array[Array] = []
var _conns: Array[Array] = []


func after_each() -> void:
	_cleanup()


func after_all() -> void:
	_cleanup()


func test_host_client_parity() -> void:
	var t0: int = Time.get_ticks_msec()
	_deadline_ms = t0 + int(HARD_TIMEOUT_S * 1000.0)
	var port: int = _host()
	if port < 0:
		fail("cannot open an ENet server on localhost (%d random ports tried)" % PORT_TRIES)
		return
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child.call_deferred(_probe)  # the root may still be setting up its children
	await wait_frames(1)
	_probe.connect(&"reported", _on_reported)
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--",
		"--port=%d" % port, "--timeout=%d" % int(HARD_TIMEOUT_S),
	])
	_pid = OS.create_process(OS.get_executable_path(), args)
	if _pid <= 0:
		fail("client process could not be spawned (%s)" % OS.get_executable_path())
		return
	var joined: bool = await wait_until(func() -> bool: return Net.human_slots().size() >= 2, _budget(20.0))
	assert_true(joined, "client connected and got a crew slot")
	if not joined:
		return
	_rt = await HeistLauncher.launch(HEIST, SEED, Enums.Difficulty.ROUTINE, get_tree().root, {"skip_casing": true})
	assert_true(_rt != null, "host launched %s" % HEIST)
	if _rt == null:
		return
	_listen_host([&"loot_secured", &"heist_ended", &"alarm_raised"])
	var snap: Dictionary = await _snapshot()
	assert_true(bool(snap.get("has_rt", false)), "client built a replica (%s)" % snap)
	if not bool(snap.get("has_rt", false)):
		return
	_check_bring_up(snap)
	var slot: int = int(snap["local_slot"])
	await _check_door()
	await _check_bag_secured()
	await _check_alarm()
	await _check_heist_ended(slot)
	var secs: float = float(Time.get_ticks_msec() - t0) / 1000.0
	print("[P3-coop] host+client parity: %.1f s" % secs)
	assert_true(Time.get_ticks_msec() <= _deadline_ms, "finished within the %.0f s hard timeout" % HARD_TIMEOUT_S)
	assert_true(secs < RUNTIME_TARGET_S, "runtime %.1f s < %.0f s (D-051)" % [secs, RUNTIME_TARGET_S])


## Same run: heist, seed, variants, crew, NPC count and ids.
func _check_bring_up(snap: Dictionary) -> void:
	assert_true(bool(snap["replica"]), "client runtime is a replica")
	assert_true(bool(snap["launch_client"]), "await HeistLauncher.launch_client() returned the replica")
	assert_eq(String(snap["heist_id"]), String(HEIST), "same heist")
	assert_eq(int(snap["seed"]), SEED, "same run seed")
	assert_eq(snap["variants"], _rt.variants, "same resolved variants")
	assert_eq(int(snap["missing"]), 0, "every map-placed net id resolved on the client")
	var crew_ids: Dictionary = {}
	for c: CrewController in _rt.crew_members():
		crew_ids[c.slot] = c.net_id
	assert_eq(crew_ids.size(), 4, "host fills the crew to 4 (2 humans + AI)")
	assert_eq(snap["crew_ids"], crew_ids, "same crew slot -> net id map")
	var npc_ids: Array[int] = []
	for n: Node in _rt.npcs():
		npc_ids.append(NetIds.of(n))
	npc_ids.sort()
	assert_true(npc_ids.size() >= 5, "host has guards + civilians (%d)" % npc_ids.size())
	assert_eq((snap["npc_ids"] as Array).size(), npc_ids.size(), "same NPC count")
	assert_eq(snap["npc_ids"], npc_ids, "same NPC net ids")
	assert_eq(int(snap["phase"]), int(_rt.phase), "same heist phase")
	var slot: int = int(snap["local_slot"])
	var mine: CrewController = _rt.crew_controller(slot) as CrewController
	assert_true(mine != null and not mine.is_ai and mine.peer_id != 1, "client slot %d is a remote human" % slot)


## The host's bot opens a closed, unlocked door by interaction; the client's replica door opens.
func _check_door() -> void:
	var door: Door = _closed_door()
	assert_true(door != null, "%s has a closed, unlocked door" % HEIST)
	if door == null:
		return
	var at: Vector3 = door.use_point.global_position if door.use_point != null else door.global_position
	var p: Variant = BotUtil.nav_point_near(door, at, 1.2)
	assert_true(p != null, "navmesh next to %s" % door.name)
	if p == null:
		return
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	if not await _mask_up(crew):
		return
	_rt.teleport_crew(0, BotUtil.facing(p as Vector3, door.global_position))
	await wait_physics_frames(2)
	var i: CrewIntent = BotUtil.look_at_intent(crew.eye_position(), door.global_position + Vector3.UP)
	i.interact = true
	i.interact_target_net_id = door.net_id
	_rt.set_bot_intent(0, i)
	var opened: bool = await wait_until(func() -> bool: return door.is_open, _budget(5.0))
	_rt.clear_bot_intent(0)
	assert_true(opened, "host bot opened %s by interaction" % door.name)
	var door_open: Callable = func(s: Dictionary) -> bool:
		return bool((s.get("doors", {}) as Dictionary).get(door.net_id, false))
	var ok: bool = await _until_client(door_open, 5.0)
	assert_true(ok, "door %s open on the client" % door.name)


## A bag dropped into the van's SECURE_LOOT zone: secured on the host, gone on the client, and the
## client received the loot_secured fact.
func _check_bag_secured() -> void:
	var zone: Area3D = _secure_zone()
	assert_true(zone != null, "%s has a SECURE_LOOT zone" % HEIST)
	if zone == null:
		return
	var mgr: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	var bag: LootBag = mgr.spawn_bag(LOOT_ID, Transform3D(Basis.IDENTITY, crew.global_position + Vector3(1.0, 0.4, 0.0)))
	var id: int = NetIds.of(bag)
	var present: Callable = func(s: Dictionary) -> bool: return bool((s.get("present", {}) as Dictionary).get(id, false))
	var spawned: bool = await _until_client(present, 5.0, {"probe_ids": [id]})
	assert_true(spawned, "spawned bag exists on the client")
	bag.release(BotUtil.zone_center(zone) + Vector3(0.0, 0.4, 0.0), Vector3.ZERO, false)
	var secured: bool = await wait_until(func() -> bool: return _host_count(&"loot_secured") >= 1, _budget(5.0))
	assert_true(secured, "bag secured on the host")
	var gone: Callable = func(s: Dictionary) -> bool:
		return _fact_count(s, "loot_secured") >= 1 and not bool((s.get("present", {}) as Dictionary).get(id, true))
	var ok: bool = await _until_client(gone, 5.0, {"probe_ids": [id]})
	assert_true(ok, "client: bag secured (despawned + loot_secured [R])")
	assert_eq(_rt.phase, Enums.HeistPhase.STEALTH, "one bag: still STEALTH (the escape needs 2)")


func _check_alarm() -> void:
	_rt.stealth.raise_alarm(&"p3_loopback", 0)
	var loud: bool = await wait_until(func() -> bool: return _rt.phase == Enums.HeistPhase.LOUD, _budget(3.0))
	assert_true(loud, "host is LOUD")
	var client_loud: Callable = func(s: Dictionary) -> bool:
		return int(s.get("phase", -1)) == Enums.HeistPhase.LOUD and bool(s.get("went_loud", false)) \
			and _fact_count(s, "alarm_raised") >= 1
	var ok: bool = await _until_client(client_loud, 5.0)
	assert_true(ok, "client: LOUD, went_loud and alarm_raised [R]")


## L2.9: the whole crew in custody (both humans and the AI) -> heist_ended(fail, all_custody) [R] after
## CustodyTweak.all_custody_fail_delay_s; the client's copy of the result matches the host's.
func _check_heist_ended(client_slot: int) -> void:
	for c: CrewController in _rt.crew_members():
		c.health.go_to_custody()
	var ended: bool = await wait_until(func() -> bool: return _host_count(&"heist_ended") > 0, _budget(5.0))
	assert_true(ended, "host heist_ended (whole crew in custody)")
	if not ended:
		return
	var host_r: Dictionary = _host_facts[_host_facts.find_custom(func(f: Array) -> bool: return f[0] == &"heist_ended")][1]
	var ok: bool = await _until_client(func(s: Dictionary) -> bool: return _fact_count(s, "heist_ended") >= 1, 5.0)
	assert_true(ok, "client received heist_ended [R]")
	if not ok:
		return
	var snap: Dictionary = _reports.get("snapshot", {}) as Dictionary
	var ended_phase: bool = await _until_client(func(s: Dictionary) -> bool:
		return int(s.get("phase", -1)) == Enums.HeistPhase.ENDED, 3.0)
	assert_true(ended_phase, "client replica phase ENDED (got %s)" % (_reports.get("snapshot", {}) as Dictionary).get("phase"))
	for f: Variant in snap.get("facts", []):
		var row: Array = f as Array
		if row[0] != "heist_ended":
			continue
		var r: Dictionary = row[1] as Dictionary
		assert_false(bool(r.get("success", true)), "client result: failed")
		assert_eq(StringName(r.get("fail_reason", &"")), &"all_custody", "client result: fail_reason all_custody")
		assert_false(bool(r.get("stealth", true)), "client result: loud")
		assert_eq(int(r.get("seed", -1)), SEED, "client result: seed")
		assert_eq((r.get("loot", []) as Array).size(), 1, "client result: the secured bag")
		assert_eq(r, host_r, "client result == host result")
		var rows: Array = r.get("crew", []) as Array
		var mine: Array = rows.filter(func(cr: Variant) -> bool: return int((cr as Dictionary)["slot"]) == client_slot)
		assert_true(mine.size() == 1 and bool((mine[0] as Dictionary)["in_custody"]), "client's crew row in custody")


# --- Helpers ---------------------------------------------------------------------------------------

## Hold mask-up on the host's bot until it is masked (an unmasked crew member is casing, S1.1).
func _mask_up(crew: CrewController) -> bool:
	var i: CrewIntent = CrewIntent.new()
	i.mask_up = true
	i.look_yaw = crew.look_yaw
	_rt.set_bot_intent(0, i)
	var ok: bool = await wait_until(func() -> bool: return crew.masked, _budget(5.0))
	_rt.clear_bot_intent(0)
	assert_true(ok, "host bot masks up")
	return ok


func _closed_door() -> Door:
	var best: Door = null
	var best_d: float = INF
	var from: Vector3 = (_rt.crew_controller(0) as Node3D).global_position
	for n: Node in _rt.map.find_children("*", "Door", true, false):
		var d: Door = n as Door
		if d == null or d.is_open or d.locked or not d.is_visible_in_tree():
			continue
		var at: Vector3 = d.use_point.global_position if d.use_point != null else d.global_position
		if BotUtil.nav_point_near(d, at, 1.2) == null:
			continue
		var dist: float = from.distance_to(d.global_position)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func _secure_zone() -> Area3D:
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		if _rt.is_ancestor_of(n):
			return n as Area3D
	return null


## Up to `n` navmesh points inside `zone`, >= 0.7 m apart.
func _points_in_zone(zone: Area3D, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var center: Vector3 = BotUtil.zone_center(zone)
	for r: float in [0.0, 0.7, 1.2, 1.8]:
		for deg: int in range(0, 360, 45):
			var want: Vector3 = center + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg))) * r
			var p: Variant = BotUtil.nav_point_near(zone, want, 0.4)
			if p == null or not ZoneUtil.contains(zone, (p as Vector3) + Vector3.UP * 0.5):
				continue
			var ok: bool = true
			for q: Vector3 in out:
				ok = ok and q.distance_to(p as Vector3) >= 0.7
			if ok:
				out.append(p as Vector3)
			if out.size() >= n:
				return out
	return out


func _listen_host(tags: Array[StringName]) -> void:
	for tag: StringName in tags:
		var t: StringName = tag
		var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			_host_facts.append([t, a, b, c])
		var sig: Signal = Signal(EventBus, tag)
		sig.connect(cb)
		_conns.append([sig, cb])


func _host_count(tag: StringName) -> int:
	var k: int = 0
	for f: Array in _host_facts:
		k += 1 if f[0] == tag else 0
	return k


static func _fact_count(snap: Dictionary, tag: String) -> int:
	var k: int = 0
	for f: Variant in snap.get("facts", []):
		k += 1 if (f as Array)[0] == tag else 0
	return k


## A random free port (test code: a local RNG is fine, D-051), retried on bind failure.
func _host() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i: int in range(PORT_TRIES):
		var port: int = rng.randi_range(PORT_MIN, PORT_MAX)
		if Net.host(port, "Host") == OK:
			return port
	return -1


## `cap` seconds, but never past the test's hard deadline.
func _budget(cap: float) -> float:
	return clampf(minf(cap, float(_deadline_ms - Time.get_ticks_msec()) / 1000.0), 0.05, cap)


func _on_reported(kind: String, data: Dictionary) -> void:
	_reports[kind] = data


func _snapshot(args: Dictionary = {}) -> Dictionary:
	_reports.erase("snapshot")
	_probe.call(&"command", "snapshot", args)
	await wait_until(func() -> bool: return _reports.has("snapshot"), _budget(5.0))
	return _reports.get("snapshot", {}) as Dictionary


## Poll client snapshots until `cond(snapshot)` holds (or `cap` s / the hard deadline pass).
func _until_client(cond: Callable, cap: float, args: Dictionary = {}) -> bool:
	var end_ms: int = Time.get_ticks_msec() + int(_budget(cap) * 1000.0)
	while Time.get_ticks_msec() < end_ms:
		var snap: Dictionary = await _snapshot(args)
		if not snap.is_empty() and bool(cond.call(snap)):
			return true
		await wait_physics_frames(RISE_FRAMES)
	return false


func _cleanup() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	_host_facts.clear()
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
