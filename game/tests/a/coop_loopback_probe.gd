## A3-07 loopback probe: the same node at /root/LoopbackProbe on the host (test) and on the client
## process (coop_loopback_client.gd). The host sends commands; the client answers with snapshots of
## its replica. Test-only RPCs, validated like gameplay RPCs (net.md): commands only from the
## authority, reports only from a connected client.
extends Node

signal reported(kind: String, data: Dictionary)
## A4-03 soak (several clients): the same report with the sending peer.
signal reported_by(peer: int, kind: String, data: Dictionary)

const NODE_NAME: String = "LoopbackProbe"
## Newest shot / blast FX facts kept (the tests read the last few).
const FX_KEEP: int = 256

## Client: highest LocalHudModel interaction progress seen, and its prompt key.
var hud_max_progress: float = 0.0
var hud_prompt: StringName = &""
## Client: the HeistRuntime returned by `await HeistLauncher.launch_client()` (null with --join=auto).
var launched_rt: HeistRuntime = null
## D-105: VfxDirector.shots on this peer at the last "clear_fx" (snapshot reports the difference).
var vfx_base: int = 0
## PO-8: shot_fx / explosion_fx seen on this peer since the last "clear_fx" (compact dicts).
var fx_shots: Array = []
var fx_blasts: Array = []


func _ready() -> void:
	EventBus.shot_fx.connect(_on_shot_fx)
	EventBus.explosion_fx.connect(_on_explosion_fx)


func _on_shot_fx(origin: Vector3, end: Vector3, normal: Vector3, surface: StringName, weapon_class: StringName,
		shooter: int, flags: int) -> void:
	fx_shots.append({"origin": origin, "end": end, "normal": normal, "surface": surface, "class": weapon_class,
		"shooter": shooter, "flags": flags})
	if fx_shots.size() > FX_KEEP:
		fx_shots = fx_shots.slice(fx_shots.size() - FX_KEEP)  # A4-03: a long soak must not grow the probe itself


func _on_explosion_fx(pos: Vector3, radius: float, kind: StringName) -> void:
	fx_blasts.append({"pos": pos, "radius": radius, "kind": kind})
	if fx_blasts.size() > FX_KEEP:
		fx_blasts = fx_blasts.slice(fx_blasts.size() - FX_KEEP)


func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		return
	var rt: HeistRuntime = HeistRuntime.current()
	if rt == null or rt.hud_model == null:
		return
	var inter: Dictionary = rt.hud_model.interaction
	var p: float = float(inter.get("progress", 0.0))
	if p > hud_max_progress:
		hud_max_progress = p
		hud_prompt = StringName(inter.get("text_key", &""))


## Host: send a command to every client.
func command(cmd: String, args: Dictionary = {}) -> void:
	_rpc_command.rpc(cmd, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_command(cmd: String, args: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var rt: HeistRuntime = HeistRuntime.current()
	var slot: int = Net.local_slot()
	match cmd:
		"snapshot":
			_rpc_report.rpc_id(1, "snapshot", snapshot(args))
		"intent":
			if rt != null:
				rt.set_bot_intent(slot, CrewIntent.from_dict(args.get("intent", {}) as Dictionary))
			_rpc_report.rpc_id(1, "ack", {"cmd": cmd})
		"clear_intent":
			if rt != null:
				rt.clear_bot_intent(slot)
			_rpc_report.rpc_id(1, "ack", {"cmd": cmd})
		"clear_fx":
			fx_shots.clear()
			fx_blasts.clear()
			var crt: HeistRuntime = HeistRuntime.current()
			vfx_base = crt.vfx.shots if crt != null and crt.vfx != null else 0
			_rpc_report.rpc_id(1, "ack", {"cmd": cmd})
		"teardown":  # C11: payday Continue on the client (the Net session stays up)
			var had: bool = rt != null
			if rt != null:
				rt.teardown()
			_rpc_report.rpc_id(1, "ack", {"cmd": cmd, "had_rt": had, "session": multiplayer.get_peers().has(1)})
		"launch_client":  # C11: wait for the host's next bring-up (back in the lobby, same session)
			_relaunch(float(args.get("timeout", 30.0)))
			_rpc_report.rpc_id(1, "ack", {"cmd": cmd})
		"soak_drive":  # A4-03: drive this client's crew member with varied intents for `seconds`
			_soak_drive(float(args.get("seconds", 60.0)), int(args.get("seed", 1)))
			_rpc_report.rpc_id(1, "ack", {"cmd": cmd})
		"hub_check":  # C4-03: the real safehouse on this client while the session is up
			_hub_check(String(args.get("root_dir", "user://a_hub_client")))
		"motion_start":  # P6: the rubber-banding metric on this client (MotionStats)
			var old: Node = get_node_or_null(^"MotionStats")
			if old != null:
				old.free()
			var ms: MotionStats = MotionStats.new()
			ms.name = "MotionStats"
			add_child(ms)
			_rpc_report.rpc_id(1, "ack", {"cmd": cmd, "interp": NetInterp.enabled})
		"npc_info":  # P6 churn diagnostics: what this replica holds for the given net ids
			var info: Dictionary = {}
			for id: Variant in args.get("ids", []):
				var nid: int = int(id)
				var look: Node = Ids.lookup(nid)
				var holders: Array = []
				if rt != null:
					for n: Node in rt.npcs():
						if NetIds.of(n) == nid:
							var npc: NpcBase = n as NpcBase
							holders.append({"path": String(n.get_path()), "pos": npc.global_position, "alive": npc.alive,
								"pm": int(npc.process_mode), "ragdoll": NpcRagdoll.owns_pose(npc), "vis": npc.visible})
				info[nid] = {"lookup": String(look.get_path()) if look != null else "", "lookup_cls": look.get_class() if look != null else "",
					"holders": holders, "interp": NetInterp.enabled}
			_rpc_report.rpc_id(1, "npc_info", info)
		"motion_report":
			var m: MotionStats = get_node_or_null(^"MotionStats") as MotionStats
			_rpc_report.rpc_id(1, "motion", m.report() if m != null else {})
		"quit":
			get_tree().quit(0)


## Client (C4-03): HubCheck on this peer, reported as "hub_check".
func _hub_check(root_dir: String) -> void:
	var res: Dictionary = await HubCheck.run(get_tree().root, root_dir)
	_rpc_report.rpc_id(1, "hub_check", res)


## Client (C11): `await HeistLauncher.launch_client()` again. Its listener is connected before the first
## await, so the "launch_client" ack the host waits for always precedes the bring-up.
func _relaunch(timeout_s: float) -> void:
	launched_rt = null
	var rt: HeistRuntime = await HeistLauncher.launch_client(null, {}, timeout_s)
	launched_rt = rt
	Log.info(&"loopback", "client: launch_client() again -> %s" % ("replica" if rt != null else "null"))


## Client, A4-03 soak: every 0.5 s a new intent for this client's crew member (walk / sprint in a random direction,
## turn toward the nearest enemy, fire in bursts, reload now and then), sent like player input, for `seconds`.
## Test code: a local RNG seeded per client (D-051).
func _soak_drive(seconds: float, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var end_ms: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_ms and is_inside_tree():
		var rt: HeistRuntime = HeistRuntime.current()
		var me: CrewController = rt.crew_controller(Net.local_slot()) as CrewController if rt != null else null
		if me != null:
			var i: CrewIntent = CrewIntent.new()
			i.move = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 1.0)).limit_length(1.0)
			i.sprint = rng.randf() < 0.3
			i.look_yaw = me.look_yaw + rng.randf_range(-0.6, 0.6)
			var best: Node3D = null
			for n: Node in rt.npcs():
				var npc: NpcBase = n as NpcBase
				if npc != null and npc.alive and npc.is_in_group(G.ENEMY) and (best == null
						or npc.global_position.distance_to(me.global_position) < best.global_position.distance_to(me.global_position)):
					best = npc
			if best != null:
				var to: Vector3 = best.global_position - me.global_position
				i.look_yaw = atan2(-to.x, -to.z)
				i.fire = rng.randf() < 0.6
			i.reload = rng.randf() < 0.05
			rt.set_bot_intent(Net.local_slot(), i)
		await get_tree().create_timer(0.5).timeout
	var rt2: HeistRuntime = HeistRuntime.current()
	if rt2 != null:
		rt2.clear_bot_intent(Net.local_slot())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report(kind: String, data: Dictionary) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
		return
	reported.emit(kind, data)
	reported_by.emit(multiplayer.get_remote_sender_id(), kind, data)


## Client: state of the local replica (`args.probe_ids`: net ids whose existence to report).
func snapshot(args: Dictionary = {}) -> Dictionary:
	var rt: HeistRuntime = HeistRuntime.current()
	if rt == null:
		return {"has_rt": false}
	var npc_ids: Array[int] = []
	for n: Node in rt.npcs():
		npc_ids.append(NetIds.of(n))
	npc_ids.sort()
	var crew_ids: Dictionary = {}
	var crew_pos: Dictionary = {}
	for c: CrewController in rt.crew_members():
		crew_ids[c.slot] = c.net_id
		crew_pos[c.slot] = c.global_position
	var doors: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var d: Door = n as Door
		if d != null and rt.is_ancestor_of(d):
			doors[d.net_id] = d.is_open
	var present: Dictionary = {}
	for id: Variant in args.get("probe_ids", []):
		present[int(id)] = Ids.lookup(int(id)) != null
	var anim: Dictionary = {}
	for id: Variant in args.get("anim_ids", []):  # D-116 npc_oneshot: what this peer's AnimDriver got / shows
		var d: AnimDriver = AnimDriver.of(Ids.lookup(int(id)))
		if d != null:
			anim[int(id)] = {"net": d.last_net_oneshot.duplicate(), "clip": d.clip, "oneshot": d._oneshot,
				"hint": d._hint(), "panic_left": d.civ_panic.left if d.civ_panic != null else 0.0}
	var codes: CodeRegistry = rt.service(CodeRegistry.SERVICE) as CodeRegistry
	return {
		"anim": anim,
		"has_rt": true, "replica": rt.is_replica, "seed": rt.run_seed, "variants": rt.variants,
		"music_track": StringName(rt.launch_options.get("music_track", &"")),
		"phase": int(rt.phase), "went_loud": rt.went_loud, "local_slot": Net.local_slot(),
		"npc_ids": npc_ids, "crew_ids": crew_ids, "crew_pos": crew_pos, "doors": doors,
		"map_ids": rt.net_sync.map_id_table(), "missing": rt.replica_missing_ids.size(),
		"active_slots": active_variant_slots(rt), "present": present,
		"codes": codes.known_codes() if codes != null else {},
		"hud_max_progress": hud_max_progress, "hud_prompt": hud_prompt,
		"stealth_alarm": rt.stealth != null and rt.stealth.alarm_raised,
		"launch_client": is_instance_valid(launched_rt) and launched_rt == rt,
		"captain": rt.net_sync.captain_state(), "host_closed": rt.net_sync.host_closed_heist,
		"hud_captain_present": rt.hud_model.captain_present if rt.hud_model != null else false,
		"hud_captain_resistance": rt.hud_model.captain_resistance if rt.hud_model != null else -1.0,
		"shot_fx": fx_shots.duplicate(), "explosion_fx": fx_blasts.duplicate(),
		"vfx_shots": rt.vfx.shots - vfx_base if rt.vfx != null else -1,
		"hud_objectives": rt.hud_model.objectives.map(func(o: Dictionary) -> String:
			return "%s:%d" % [o["id"], int(o["state"])]) if rt.hud_model != null else [],
		"of_state": of_state(rt) if bool(args.get("of_state", false)) else {},
		"mem": OS.get_static_memory_usage(),  # A4-03 soak: memory growth on this peer
		"counts": counts(),
	}


## OF co-op parity (test_of_coop_loopback.gd): the replicated state of a heist, computed the same way on both peers.
## Discrete values compare exactly; positions (rounded to 0.1 m) with a tolerance in the test.
## A4-03 soak: engine object counts of this process (where memory growth comes from).
static func counts() -> Dictionary:
	return {"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}


static func of_state(rt: HeistRuntime) -> Dictionary:
	var prefabs: Dictionary = {}
	var lifts: Dictionary = {}
	var doors: Dictionary = {}
	for n: Node in rt.map.find_children("*", "", true, false):
		var gp: GameplayPrefab = n as GameplayPrefab
		if gp == null or gp.net_id == 0:
			continue
		var row: Array = [gp.prefab_enabled, gp.is_visible_in_tree()]
		if gp is Ladder:
			row.append((gp as Ladder).usable)
		prefabs[gp.net_id] = row
		if gp is BagLift:
			var car: Node3D = (gp as BagLift).visual_node("Car") as Node3D
			lifts[gp.net_id] = _r(car.global_position) if car != null else Vector3.INF
		if gp is Door:
			doors[gp.net_id] = [(gp as Door).is_open, (gp as Door).locked]
	var bags: Dictionary = {}
	for n: Node in rt.get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b != null and rt.is_ancestor_of(b) and not b.is_queued_for_deletion():
			bags[NetIds.of(b)] = [b.loot_id, _r(b.global_position)]
	var npcs: Dictionary = {}
	for n: Node in rt.npcs():
		npcs[NetIds.of(n)] = _r((n as Node3D).global_position)
	var items: Dictionary = {}
	var civ: Dictionary = {}
	for c: CrewController in rt.crew_members():
		items[c.slot] = c.items.duplicate()
		civ[c.slot] = c.civilian  # S1.3 per-crew gear (AH civilian start, A4-03)
	var reveals: Array = Array(rt.preplan.reveals()).map(func(g: StringName) -> String: return String(g))
	reveals.sort()
	return {"phase": int(rt.phase), "went_loud": rt.went_loud, "prefabs": prefabs, "lifts": lifts, "doors": doors,
		"bags": bags, "npcs": npcs, "items": items, "civ": civ, "reveals": reveals,
		"objectives": rt.hud_model.objectives.map(func(o: Dictionary) -> String:
			return "%s:%d" % [o["id"], int(o["state"])]) if rt.hud_model != null else []}


static func _r(v: Vector3) -> Vector3:
	return (v * 10.0).round() / 10.0


## Paths of the visible VariantSlots in the runtime's map (both peers).
static func active_variant_slots(rt: HeistRuntime) -> Array[String]:
	var out: Array[String] = []
	var slots: Dictionary = VariantResolver.collect_slots(rt.map)
	for g: Variant in slots:
		for s: VariantSlot in slots[g]:
			if s.visible:
				out.append(String(rt.map.get_path_to(s)))
	out.sort()
	return out
