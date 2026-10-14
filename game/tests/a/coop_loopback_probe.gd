## A3-07 loopback probe: the same node at /root/LoopbackProbe on the host (test) and on the client
## process (coop_loopback_client.gd). The host sends commands; the client answers with snapshots of
## its replica. Test-only RPCs, validated like gameplay RPCs (net.md): commands only from the
## authority, reports only from a connected client.
extends Node

signal reported(kind: String, data: Dictionary)

const NODE_NAME: String = "LoopbackProbe"

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


func _on_explosion_fx(pos: Vector3, radius: float, kind: StringName) -> void:
	fx_blasts.append({"pos": pos, "radius": radius, "kind": kind})


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
		"quit":
			get_tree().quit(0)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report(kind: String, data: Dictionary) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
		return
	reported.emit(kind, data)


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
	var codes: CodeRegistry = rt.service(CodeRegistry.SERVICE) as CodeRegistry
	return {
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
		"captain": rt.net_sync.captain_state(),
		"hud_captain_present": rt.hud_model.captain_present if rt.hud_model != null else false,
		"hud_captain_resistance": rt.hud_model.captain_resistance if rt.hud_model != null else -1.0,
		"shot_fx": fx_shots.duplicate(), "explosion_fx": fx_blasts.duplicate(),
		"vfx_shots": rt.vfx.shots - vfx_base if rt.vfx != null else -1,
	}


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
