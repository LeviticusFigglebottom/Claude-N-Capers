## P3 gate loopback probe (test_coop_loopback.gd). Owner: LEAD. The same node at /root/P3LoopbackProbe on
## the host (the test) and on the client process (coop_client.gd). The host sends commands; the client
## answers with snapshots of its replica plus the EventBus facts it received (relayed [R] events).
## Test-only RPCs, validated like gameplay RPCs (net.md): commands only from the authority, reports only
## from a connected peer.
extends Node

signal reported(kind: String, data: Dictionary)

const NODE_NAME: String = "P3LoopbackProbe"
## EventBus facts the client records (all relayed with Net.replicate_event by the host).
const FACTS: Array[StringName] = [&"alarm_raised", &"loot_secured", &"heist_ended", &"assault_phase_changed"]

## Client: the HeistRuntime returned by `await HeistLauncher.launch_client()`.
var launched_rt: HeistRuntime = null

var _facts: Array[Array] = []


func _ready() -> void:
	for f: StringName in FACTS:
		var tag: StringName = f
		Signal(EventBus, f).connect(func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			if not multiplayer.is_server():
				_facts.append([tag, a, b, c]))


## Host: send a command to every client.
func command(cmd: String, args: Dictionary = {}) -> void:
	_rpc_command.rpc(cmd, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_command(cmd: String, args: Dictionary) -> void:
	if multiplayer.is_server():
		return
	match cmd:
		"snapshot":
			_rpc_report.rpc_id(1, "snapshot", snapshot(args))
		"quit":
			get_tree().quit(0)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report(kind: String, data: Dictionary) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
		return
	reported.emit(kind, data)


## Client: state of the local replica. `args.probe_ids`: net ids whose existence to report.
func snapshot(args: Dictionary = {}) -> Dictionary:
	var rt: HeistRuntime = HeistRuntime.current()
	if rt == null:
		return {"has_rt": false}
	var npc_ids: Array[int] = []
	for n: Node in rt.npcs():
		npc_ids.append(NetIds.of(n))
	npc_ids.sort()
	var crew_ids: Dictionary = {}
	for c: CrewController in rt.crew_members():
		crew_ids[c.slot] = c.net_id
	var doors: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var d: Door = n as Door
		if d != null and rt.is_ancestor_of(d):
			doors[d.net_id] = d.is_open
	var present: Dictionary = {}
	for id: Variant in args.get("probe_ids", []):
		present[int(id)] = Ids.lookup(int(id)) != null
	var facts: Array = []
	for f: Array in _facts:
		var row: Array = [String(f[0])]
		for v: Variant in f.slice(1):
			row.append(v)
		facts.append(row)
	return {
		"has_rt": true, "replica": rt.is_replica, "seed": rt.run_seed, "variants": rt.variants,
		"heist_id": String(rt.heist_id), "phase": int(rt.phase), "went_loud": rt.went_loud,
		"local_slot": Net.local_slot(), "npc_ids": npc_ids, "crew_ids": crew_ids, "doors": doors,
		"present": present, "missing": rt.replica_missing_ids.size(), "facts": facts,
		"launch_client": is_instance_valid(launched_rt) and launched_rt == rt,
	}
