## A3-07 co-op loopback (docs/contracts/net.md): a real host (this process, ENet server on
## localhost) and a real client (a second headless Godot process running
## coop_loopback_client.tscn, which joins and builds its replica through `await HeistLauncher.launch_client()`).
## Asserts host/client parity on the dev_sandbox: variants, map ids, NPC and crew net ids; a client
## crew intent moves its crew on the server; a client interaction completes on the server while the
## client's LocalHudModel shows its progress; the alarm (LOUD on both), a server door, a known code and a
## bag spawn + secure reach the client; Commander Brandt's presence/resistance reaches the client's
## LocalHudModel (ui_hud v1.3).
##
## Why two processes and not two SceneMultiplayer branches in one: every gameplay system guards with
## `Net.is_authority()` (the root multiplayer of the Net autoload, ~150 call sites), and EventBus,
## Ids, Services, Modifiers, GameRng and HeistRuntime.current() are process-wide singletons. A client
## branch in the host process would run the server code paths and share the host's id registry and
## event bus, so its "parity" would prove nothing. A second process exercises the real client path.
## The client's stdout is inherited, so its SCRIPT ERROR lines fail CI like ours (D-047).
## D-051 conditions: random free port (retried on bind failure) passed to the child on its command
## line; whole test hard-capped at HARD_TIMEOUT_S (the child self-quits after the same time); the child
## is always killed in after_each / after_all (OS.kill fallback); failing to bind or spawn FAILS.
extends TestCase

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/a/coop_loopback_client.tscn"
## Ephemeral range for the random server port (IANA dynamic ports).
const PORT_MIN: int = 49152
const PORT_MAX: int = 65000
const PORT_TRIES: int = 12
const HARD_TIMEOUT_S: float = 60.0
const SEED: int = 7071

var _probe: Node = null
var _pid: int = -1
var _rt: HeistRuntime = null
var _reports: Dictionary = {}
var _deadline_ms: int = 0


func after_each() -> void:
	_cleanup()


func after_all() -> void:
	_cleanup()


func test_host_client_parity() -> void:
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
	var joined: bool = await wait_until(func() -> bool: return Net.human_slots().size() >= 2, _budget(30.0))
	assert_true(joined, "client connected and got a crew slot")
	if not joined:
		return
	_rt = await HeistLauncher.launch(&"dev_sandbox", SEED, Enums.Difficulty.ROUTINE, get_tree().root,
		{"skip_casing": true, "music_track": &"music.test_pick"})
	assert_true(_rt != null, "host launched the dev_sandbox")
	if _rt == null:
		return
	# The replica exists before `await launch_client()` returns on the client (bring-up waits): poll until it has.
	var snap: Dictionary = await _snapshot()
	var t0: int = Time.get_ticks_msec()
	while not bool(snap.get("launch_client", false)) and Time.get_ticks_msec() - t0 < int(_budget(20.0) * 1000.0):
		await wait_seconds(0.25)
		snap = await _snapshot()
	var ok: bool = bool(snap.get("has_rt", false))
	assert_true(ok, "client built a replica (%s)" % snap)
	# D-168: the host replicates to the client only once it reported its replica ready (no RPC to a missing NetSync).
	var peer: int = multiplayer.get_peers()[0] if not multiplayer.get_peers().is_empty() else 0
	var gated: bool = await wait_until(func() -> bool: return _rt.net_sync.replicates_to(peer), _budget(5.0))
	assert_true(gated and _rt.net_sync._pending.is_empty(), "the client's KIND_READY arrived: replicated to, nothing held")
	if ok:
		await _check_bring_up(snap)
		var slot: int = int(snap["local_slot"])
		await _check_intent_moves(slot)
		await _check_interaction(slot)
		await _check_alarm()
		await _check_door_code_bag()
		await _check_captain()
	assert_true(Time.get_ticks_msec() <= _deadline_ms, "finished within the %.0f s hard timeout" % HARD_TIMEOUT_S)


func _check_bring_up(snap: Dictionary) -> void:
	assert_true(bool(snap["replica"]), "client runtime is a replica")
	assert_true(bool(snap.get("launch_client", false)), "await HeistLauncher.launch_client() returned the replica")
	assert_eq(int(snap["seed"]), SEED, "same run seed")
	assert_eq(StringName(snap.get("music_track", &"")), &"music.test_pick", "D-062: the host's launch_options reach the client")
	assert_eq(snap["variants"], _rt.variants, "same resolved variants")
	assert_eq(snap["active_slots"], PROBE.active_variant_slots(_rt), "same active variant slots in the map")
	assert_eq(int(snap["missing"]), 0, "every map id resolved on the client")
	var host_obj: Array = _rt.hud_model.objectives.map(func(o: Dictionary) -> String:
		return "%s:%d" % [o["id"], int(o["state"])])
	assert_true(not host_obj.is_empty(), "the host mission has objectives")
	assert_eq(snap.get("hud_objectives", []), host_obj, "PO-B-C7: the client HUD has the host's objectives (bring-up)")
	assert_eq(snap["map_ids"], _rt.net_sync.map_id_table(), "same map-placed net ids")
	var npc_ids: Array[int] = []
	for n: Node in _rt.npcs():
		npc_ids.append(NetIds.of(n))
	npc_ids.sort()
	assert_true(npc_ids.size() >= 5, "host has guards + civilians (%d)" % npc_ids.size())
	assert_eq(snap["npc_ids"], npc_ids, "same NPC count and net ids")
	var crew_ids: Dictionary = {}
	for c: CrewController in _rt.crew_members():
		crew_ids[c.slot] = c.net_id
	assert_eq(snap["crew_ids"], crew_ids, "same crew slot -> net id map")
	assert_eq(int(snap["phase"]), int(_rt.phase), "same phase")
	assert_true(int(snap["local_slot"]) >= 1, "client owns a crew slot (%d)" % int(snap["local_slot"]))


func _check_intent_moves(slot: int) -> void:
	var crew: CrewController = _rt.crew_controller(slot) as CrewController
	assert_true(crew != null and not crew.is_ai and crew.peer_id != 1, "client slot %d is a remote human" % slot)
	if crew == null:
		return
	crew.set_masked(true)
	var p0: Vector3 = crew.global_position
	var intent: CrewIntent = CrewIntent.new()
	intent.move = Vector2(0.0, 1.0)
	intent.look_yaw = crew.look_yaw
	_probe.call(&"command", "intent", {"intent": intent.to_dict()})
	var moved: bool = await wait_until(func() -> bool: return crew.global_position.distance_to(p0) > 1.0, _budget(10.0))
	assert_true(moved, "client intent moved its crew on the server (%.2f m)" % crew.global_position.distance_to(p0))
	_probe.call(&"command", "clear_intent", {})
	await wait_seconds(0.3)
	assert_true(crew.masked, "crew stays masked")


func _check_interaction(slot: int) -> void:
	var loot: Node3D = _rt.map.get_node_or_null(^"Gameplay/SmallLootA") as Node3D
	assert_true(loot != null, "dev_sandbox has Gameplay/SmallLootA")
	if loot == null:
		return
	var loot_id: int = NetIds.of(loot)
	var comp: InteractableComponent = loot.get_node(^"Interactable") as InteractableComponent
	var use_point: Node3D = loot.get_node_or_null(^"UsePoint") as Node3D
	var stand: Vector3 = use_point.global_position if use_point != null else comp.global_position + Vector3(0.0, 0.0, 0.8)
	stand.y = loot.global_position.y + 0.05
	_rt.teleport_crew(slot, Transform3D(Basis.IDENTITY, stand))
	await wait_seconds(0.6)
	var done: Array[bool] = [false]
	var on_done: Callable = func(owner_id: int, s: int, _k: StringName) -> void:
		if owner_id == loot_id and s == slot:
			done[0] = true
	EventBus.interaction_completed.connect(on_done)
	var intent: CrewIntent = CrewIntent.new()
	intent.interact = true
	intent.interact_target_net_id = loot_id
	_probe.call(&"command", "intent", {"intent": intent.to_dict()})
	var ok: bool = await wait_until(func() -> bool: return done[0], _budget(10.0))
	EventBus.interaction_completed.disconnect(on_done)
	_probe.call(&"command", "clear_intent", {})
	assert_true(ok, "client interaction on SmallLootA completed on the server")
	await wait_seconds(0.4)
	var snap: Dictionary = await _snapshot({"probe_ids": [loot_id]})
	var hud_p: float = float(snap.get("hud_max_progress", 0.0))
	assert_true(hud_p > 0.0, "client HUD model showed interaction progress (%s)" % hud_p)
	assert_false(bool((snap.get("present", {}) as Dictionary).get(loot_id, true)), "taken small loot despawned on the client")


func _check_door_code_bag() -> void:
	var door: Door = _rt.map.get_node_or_null(^"Gameplay/BackRoomDoor") as Door
	assert_true(door != null, "dev_sandbox has Gameplay/BackRoomDoor")
	var want_open: bool = door != null and not door.is_open
	if door != null:
		door.set_open(want_open)
	var codes: CodeRegistry = _rt.service(CodeRegistry.SERVICE) as CodeRegistry
	codes.reveal(&"loopback_vault", 0)
	var mgr: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var crew0: CrewController = _rt.crew_controller(0) as CrewController
	var bag: LootBag = mgr.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, crew0.global_position + Vector3(1.5, 0.3, 0.0)))
	var bag_id: int = NetIds.of(bag)
	await wait_seconds(0.4)
	var snap: Dictionary = await _snapshot({"probe_ids": [bag_id]})
	if door != null:
		assert_eq(bool((snap["doors"] as Dictionary).get(door.net_id, not want_open)), want_open, "door state reached the client")
	assert_eq(snap["codes"], codes.known_codes(), "known codes reached the client")
	assert_true(bool((snap["present"] as Dictionary).get(bag_id, false)), "spawned bag exists on the client")
	var secured: Array[bool] = [false]
	var on_secured: Callable = func(id: int, _l: StringName, _v: int) -> void:
		if id == bag_id:
			secured[0] = true
	EventBus.loot_secured.connect(on_secured)
	var zone: Node3D = _rt.map.get_node(^"Zones/SecureLootVan/Shape") as Node3D
	# Onto the van roof (inside the zone): at floor height the release point is inside VanSecure's collision box,
	# and the depenetration pushed the bag below the floor (out of the zone) whenever a launch came before.
	bag.release(Vector3(zone.global_position.x, zone.global_position.y + 1.1, zone.global_position.z), Vector3.ZERO, false)
	var ok: bool = await wait_until(func() -> bool: return secured[0], _budget(10.0))
	EventBus.loot_secured.disconnect(on_secured)
	assert_true(ok, "bag secured on the server")
	await wait_seconds(0.4)
	snap = await _snapshot({"probe_ids": [bag_id]})
	assert_false(bool((snap["present"] as Dictionary).get(bag_id, true)), "secured bag disappeared on the client")
	assert_eq(int(snap["phase"]), int(_rt.phase), "same phase after the secure (escape may have opened)")


func _check_alarm() -> void:
	_rt.stealth.raise_alarm(&"loopback_test", 0)
	await wait_seconds(0.4)
	assert_eq(int(_rt.phase), int(Enums.HeistPhase.LOUD), "host is LOUD")
	var snap: Dictionary = await _snapshot()
	assert_eq(int(snap["phase"]), int(Enums.HeistPhase.LOUD), "client is LOUD")
	assert_true(bool(snap["went_loud"]) and bool(snap["stealth_alarm"]), "client saw the alarm")


## ui_hud v1.3: the host's captain state is replicated (HeistNetSync services) to the client HUD. The
## AegisCaptain state is driven directly (its tick paused): spawn validity is not under test here.
func _check_captain() -> void:
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(d != null and d.captain != null, "host has the AegisCaptain")
	if d == null or d.captain == null:
		return
	var c: AegisCaptain = d.captain
	c.set_physics_process(false)
	c.active = true
	c.in_position = true
	c.resistance = 0.35
	var snap: Dictionary = {}
	var t_end: int = Time.get_ticks_msec() + int(_budget(5.0) * 1000.0)
	while Time.get_ticks_msec() < t_end:
		snap = await _snapshot()
		if bool(snap.get("hud_captain_present", false)) \
				and absf(float(snap.get("hud_captain_resistance", -1.0)) - 0.35) < 0.001:
			break
		await wait_seconds(0.2)
	var cs: Dictionary = snap.get("captain", {}) as Dictionary
	assert_true(bool(cs.get("present", false)), "client net state: Brandt present (%s)" % cs)
	assert_near(float(cs.get("resistance", -1.0)), 0.35, 0.001, "client captain resistance = host value")
	assert_true(bool(snap.get("hud_captain_present", false)), "client HUD captain_present")
	assert_near(float(snap.get("hud_captain_resistance", -1.0)), 0.35, 0.001, "client HUD captain_resistance")
	c.active = false
	c.in_position = false
	c.resistance = 0.0
	t_end = Time.get_ticks_msec() + int(_budget(5.0) * 1000.0)
	while Time.get_ticks_msec() < t_end:
		snap = await _snapshot()
		if not bool(snap.get("hud_captain_present", true)):
			break
		await wait_seconds(0.2)
	assert_false(bool(snap.get("hud_captain_present", true)), "client HUD: Brandt gone")
	assert_near(float(snap.get("hud_captain_resistance", -1.0)), 0.0, 0.0001, "client HUD resistance 0")
	c.set_physics_process(true)


# --- Helpers -------------------------------------------------------------------------------------

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
