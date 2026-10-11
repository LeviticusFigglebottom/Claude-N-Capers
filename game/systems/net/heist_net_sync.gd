## Heist replication between the host and its clients (A3-07, docs/contracts/net.md). Owner: ENV A.
## HeistRuntime creates one child `NetSync` (service SERVICE) on every peer. It is idle in solo
## (OfflineMultiplayerPeer) and while no client is connected, so solo behaviour is unchanged.
##
## Server (authority), once `begin()` ran (HeistLauncher, after the bring-up was sent):
## * every physics frame: new children of `dynamic_root` with a net_id -> `_rpc_spawn` (reliable),
##   replicated ids whose node left the tree (bag secured, small loot taken, NPC despawned) ->
##   `_rpc_despawn` (reliable);
## * at SYNC_HZ: discrete state diffs per entity (NetEntityCodec.state_of) plus service state
##   (interaction sessions per crew slot, known codes, custody timers, phase, captain) -> `_rpc_state`
##   (reliable, only what changed), and transforms of NPCs, crew and loose bags -> `_rpc_xforms`
##   (unreliable_ordered, only what moved).
## Client: applies the above (`HeistRuntime.start(..., {"bring_up": ...})` builds the map and adopts map ids first).
## The bring-up message itself (map ids, variants, initial spawns) travels through
## `Net.lobby_send(HeistLauncher.BRING_UP_KIND, ...)` because the client has no runtime yet.
## RPC paths: the client's HeistRuntime must sit at the same node path as the host's
## (`bring_up.runtime_path`; launch both under the tree root, the default).
class_name HeistNetSync
extends Node

## Client: a replicated dynamic entity entered the tree (HeistRuntime keeps its crew table).
signal replica_spawned(node: Node)
## Client: the host's phase / went_loud (HeistRuntime mirrors them).
signal phase_replicated(phase: int, went_loud: bool)
## Client: the host's Commander Brandt state changed (ui_hud v1.3, D-049; LocalHudModel reads
## captain_state()).
signal captain_replicated(present: bool, resistance: float)
## Client: the connection to the host dropped while this replica runs (multiplayer.server_disconnected).
## Nothing is torn down here: the app flow (ENV B) shows its "host left" result, then calls
## HeistRuntime.teardown() and Net.leave(). `host_lost_at_s` keeps the heist time it happened.
## Driven by `Net.host_lost` (D-052), with multiplayer.server_disconnected as a fallback.
signal host_lost()

const SERVICE: StringName = &"net_sync"
const NODE_NAME: String = "NetSync"
## Discrete-state and transform rate (net.md: 10-20 Hz).
const SYNC_HZ: float = 15.0
const SVC_INTERACTION: String = "isys"
const SVC_CODES: String = "codes"
const SVC_CUSTODY: String = "custody"
const SVC_RUNTIME: String = "rt"
## D-071 per-crew counters (CrewStats).
const SVC_STATS: String = "stats"
## ui_hud v1.3: {"present": bool, "resistance": float 0..1} of the director's AegisCaptain.
const SVC_CAPTAIN: String = "captain"

## Client: counters for tests and diagnostics.
var spawns_applied: int = 0
var despawns_applied: int = 0
var states_applied: int = 0
## Client: heist_time_s when host_lost fired (< 0 = never).
var host_lost_at_s: float = -1.0

var _runtime: HeistRuntime = null
var _begun: bool = false
## Server: replicated net ids (map + announced dynamic entities).
var _tracked: Dictionary[int, bool] = {}
## Server: instance ids of dynamic children already announced.
var _announced: Dictionary[int, bool] = {}
var _last_state: Dictionary[int, Dictionary] = {}
var _last_xform: Dictionary[int, Variant] = {}
var _last_services: Dictionary = {}
var _accum: float = 0.0
## Client: last replicated captain state (see captain_state()).
var _captain: Dictionary = {"present": false, "resistance": 0.0}


## False while `node`'s networked heist has not sent its bring-up yet: clients have no replica of
## the heist nodes, so an RPC on them would fail (the state travels with the bring-up snapshot).
## True in solo, without a heist, and once replication runs.
static func can_rpc(node: Node) -> bool:
	var rt: HeistRuntime = HeistRuntime.of(node)
	if rt == null or rt.net_sync == null:
		return true
	return rt.net_sync.is_begun() or not rt.net_sync.is_live()


func _ready() -> void:
	_runtime = HeistRuntime.of(self)
	if not Net.host_lost.is_connected(_on_server_disconnected):
		Net.host_lost.connect(_on_server_disconnected)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	if Net.host_lost.is_connected(_on_server_disconnected):
		Net.host_lost.disconnect(_on_server_disconnected)
	if multiplayer != null and multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)


func _on_server_disconnected() -> void:
	if host_lost_at_s >= 0.0:
		return
	host_lost_at_s = _runtime.heist_time_s if _runtime != null else 0.0
	Log.warn(&"net", "connection to the host lost")
	host_lost.emit()


## Server: true once begin() ran (clients have the heist replica).
func is_begun() -> bool:
	return _begun


## True when a real network session with at least one remote peer is running.
func is_live() -> bool:
	if not is_inside_tree() or not multiplayer.has_multiplayer_peer():
		return false
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return false
	return not multiplayer.get_peers().is_empty()


## Server: start replicating. Returns the snapshot the bring-up carries: {"map_ids": {path: id},
## "spawns": [descriptor], "states": {id: state}, "services": services_state()}. Later changes are
## sent as diffs against it.
func begin() -> Dictionary:
	var snap: Dictionary = {"map_ids": {}, "spawns": [], "states": {}, "services": {}}
	if not Net.is_authority() or _runtime == null:
		return snap
	snap["map_ids"] = map_id_table()
	snap["spawns"] = describe_dynamic()
	for id: int in (snap["map_ids"] as Dictionary).values():
		_tracked[id] = true
	for c: Node in _runtime.dynamic_root.get_children():
		var id: int = NetIds.of(c)
		_announced[c.get_instance_id()] = true
		if id != Ids.INVALID:
			_tracked[id] = true
	var states: Dictionary = {}
	for id: int in _tracked:
		var n: Node = Ids.lookup(id)
		if n != null:
			_last_state[id] = NetEntityCodec.state_of(n)
			states[id] = _last_state[id]
	snap["states"] = states
	_last_services = services_state()
	snap["services"] = _last_services
	_begun = true
	return snap


## Server: the bring-up message for clients (HeistLauncher sends it right after HeistRuntime.start()).
## Starts replicating: later changes are diffs against the snapshot inside.
func bring_up() -> Dictionary:
	var rt: HeistRuntime = _runtime
	var snap: Dictionary = begin()
	var map_ids: Dictionary = snap["map_ids"]
	snap.erase("map_ids")
	var crew_ids: Dictionary = {}
	for c: CrewController in rt.crew_members():
		crew_ids[c.slot] = NetIds.of(c)
	return {
		"version": HeistLauncher.BRING_UP_VERSION, "heist_id": rt.heist_id, "seed": rt.run_seed,
		"difficulty": rt.difficulty, "map_scene": rt.map.scene_file_path, "variants": rt.variants.duplicate(true),
		"map_ids": map_ids, "crew_ids": crew_ids, "phase": int(rt.phase), "went_loud": rt.went_loud,
		"heist_time_s": rt.heist_time_s, "preplan": rt.preplan.result.duplicate(true) if rt.preplan.is_active() else {},
		"runtime_path": String(rt.get_path()), "snapshot": snap, "launch_options": public_options(rt.launch_options),
	}


## D-062: the network-safe part of launch options (String/StringName/number/bool values; no resources,
## callables or loadouts) that every peer shares, e.g. "music_track".
static func public_options(opts: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in opts:
		if k == "bring_up":
			continue
		var v: Variant = opts[k]
		if v is String or v is StringName or v is int or v is float or v is bool:
			out[k] = v
	return out


## Client: apply the bring-up snapshot (after the map ids were adopted).
func apply_snapshot(snap: Dictionary) -> void:
	apply_spawns(snap.get("spawns", []) as Array)
	var states: Dictionary = snap.get("states", {}) as Dictionary
	for k: Variant in states:
		var n: Node = Ids.lookup(int(k))
		if n != null:
			NetEntityCodec.apply_state(n, states[k] as Dictionary)
	apply_services(snap.get("services", {}) as Dictionary)


## Server: {path relative to the map: net_id} of every map-placed entity (tree order).
func map_id_table() -> Dictionary:
	var out: Dictionary = {}
	if _runtime == null or _runtime.map == null:
		return out
	var stack: Array[Node] = [_runtime.map]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		var id: int = NetIds.of(n)
		if id != Ids.INVALID and n != _runtime.map:
			out[String(_runtime.map.get_path_to(n))] = id
		for c: Node in n.get_children():
			stack.append(c)
	return out


## Server: spawn descriptors of the current dynamic entities (claims missing ids first).
func describe_dynamic() -> Array:
	var out: Array = []
	if _runtime == null or _runtime.dynamic_root == null:
		return out
	for c: Node in _runtime.dynamic_root.get_children():
		if c.is_queued_for_deletion():
			continue
		if NetIds.of(c) == Ids.INVALID and &"net_id" in c:
			NetIds.claim(c)
		if NetIds.of(c) != Ids.INVALID:
			out.append(NetEntityCodec.describe(c))
	return out


## Server: service-level state mirrored to clients.
func services_state() -> Dictionary:
	var out: Dictionary = {}
	if _runtime == null:
		return out
	if _runtime.interaction != null:
		out[SVC_INTERACTION] = _runtime.interaction.net_sessions()
	var codes: CodeRegistry = _runtime.service(CodeRegistry.SERVICE) as CodeRegistry
	if codes != null:
		out[SVC_CODES] = codes.net_state()
	var custody: CustodySystem = _runtime.service(CustodySystem.SERVICE) as CustodySystem
	if custody != null:
		out[SVC_CUSTODY] = custody.net_state()
	out[SVC_RUNTIME] = {"phase": int(_runtime.phase), "loud": _runtime.went_loud}
	if _runtime.stats != null:
		out[SVC_STATS] = _runtime.stats.net_state()
	out[SVC_CAPTAIN] = captain_state()
	return out


## Commander Brandt for the HUD (ui_hud v1.3): {"present": bool, "resistance": float 0..1 (damage
## reduction of every enemy; 0 when absent / not yet in position)}. Server: read from the director's
## AegisCaptain. Client: the last value replicated by the host (services diff, SYNC_HZ).
func captain_state() -> Dictionary:
	if not Net.is_authority():
		return _captain.duplicate()
	var dir: AssaultDirector = _runtime.service(G.SVC_DIRECTOR) as AssaultDirector if _runtime != null else null
	if dir == null or dir.captain == null:
		return {"present": false, "resistance": 0.0}
	var present: bool = dir.captain.active
	return {"present": present, "resistance": clampf(dir.captain.resistance, 0.0, 1.0) if present else 0.0}


func _physics_process(delta: float) -> void:
	if not _begun or _runtime == null or not Net.is_authority() or not is_live():
		return
	_scan_spawns()
	_scan_despawns()
	_accum += delta
	if _accum < 1.0 / SYNC_HZ:
		return
	_accum = 0.0
	_send_state()
	_send_xforms()


func _scan_spawns() -> void:
	var batch: Array = []
	for c: Node in _runtime.dynamic_root.get_children():
		var iid: int = c.get_instance_id()
		if _announced.has(iid) or c.is_queued_for_deletion():
			continue
		if NetIds.of(c) == Ids.INVALID:
			if not &"net_id" in c:
				_announced[iid] = true  # not a networked entity
				continue
			NetIds.claim(c)
		_announced[iid] = true
		var id: int = NetIds.of(c)
		_tracked[id] = true
		batch.append(NetEntityCodec.describe(c))
		_last_state[id] = NetEntityCodec.state_of(c)
	if not batch.is_empty():
		_rpc_spawn.rpc(batch)


func _scan_despawns() -> void:
	var gone: PackedInt32Array = PackedInt32Array()
	for id: int in _tracked:
		var n: Node = Ids.lookup(id)
		if n == null or not n.is_inside_tree():
			gone.append(id)
	if gone.is_empty():
		return
	for id: int in gone:
		_tracked.erase(id)
		_last_state.erase(id)
		_last_xform.erase(id)
	_rpc_despawn.rpc(gone)


func _send_state() -> void:
	var diffs: Dictionary = {}
	for id: int in _tracked:
		var n: Node = Ids.lookup(id)
		if n == null:
			continue
		var cur: Dictionary = NetEntityCodec.state_of(n)
		var prev: Dictionary = _last_state.get(id, {})
		var d: Dictionary = {}
		for k: Variant in cur:
			if not prev.has(k) or typeof(prev[k]) != typeof(cur[k]) or prev[k] != cur[k]:
				d[k] = cur[k]
		if not d.is_empty():
			diffs[id] = d
			_last_state[id] = cur
	var svc: Dictionary = services_state()
	var svc_diff: Dictionary = {}
	for k: Variant in svc:
		if not _last_services.has(k) or _last_services[k] != svc[k]:
			svc_diff[k] = svc[k]
	_last_services = svc
	if not diffs.is_empty() or not svc_diff.is_empty():
		_rpc_state.rpc(diffs, svc_diff)


func _send_xforms() -> void:
	var out: Dictionary = {}
	for id: int in _tracked:
		var n: Node = Ids.lookup(id)
		if n == null:
			continue
		var x: Variant = NetEntityCodec.xform_of(n)
		if x == null:
			continue
		if _last_xform.has(id) and _last_xform[id] == x:
			continue
		_last_xform[id] = x
		out[id] = x
	if not out.is_empty():
		_rpc_xforms.rpc(out)


# --- Client --------------------------------------------------------------------------------------

## Client: build every entity of a spawn batch (bring-up or `_rpc_spawn`).
func apply_spawns(batch: Array) -> void:
	if _runtime == null or _runtime.dynamic_root == null:
		return
	for v: Variant in batch:
		var d: Dictionary = v as Dictionary
		var id: int = int(d.get("net_id", Ids.INVALID))
		var existing: Node = Ids.lookup(id)
		if existing != null:
			continue
		var node: Node = NetEntityCodec.instantiate(d)
		if node == null:
			continue
		var stale: Node = _runtime.dynamic_root.get_node_or_null(NodePath(String(node.name)))
		if stale != null:  # a despawned node still waiting for its free
			_runtime.dynamic_root.remove_child(stale)
			stale.queue_free()
		_runtime.dynamic_root.add_child(node)
		NetEntityCodec.finish_spawn(node, d)
		replica_spawned.emit(node)
		spawns_applied += 1


## Client: apply service-level state (see services_state()).
func apply_services(svc: Dictionary) -> void:
	if _runtime == null:
		return
	if svc.has(SVC_INTERACTION) and _runtime.interaction != null:
		_runtime.interaction.apply_net_sessions(svc[SVC_INTERACTION] as Dictionary)
	var codes: CodeRegistry = _runtime.service(CodeRegistry.SERVICE) as CodeRegistry
	if svc.has(SVC_CODES) and codes != null:
		codes.apply_net_state(svc[SVC_CODES] as Dictionary)
	var custody: CustodySystem = _runtime.service(CustodySystem.SERVICE) as CustodySystem
	if svc.has(SVC_CUSTODY) and custody != null:
		custody.apply_net_state(svc[SVC_CUSTODY] as Dictionary)
	if svc.has(SVC_STATS) and _runtime.stats != null:
		_runtime.stats.apply_net_state(svc[SVC_STATS] as Dictionary)
	if svc.has(SVC_RUNTIME):
		var r: Dictionary = svc[SVC_RUNTIME] as Dictionary
		phase_replicated.emit(int(r.get("phase", _runtime.phase)), bool(r.get("loud", _runtime.went_loud)))
	if svc.has(SVC_CAPTAIN) and not Net.is_authority():
		var cs: Dictionary = svc[SVC_CAPTAIN] as Dictionary
		var next: Dictionary = {"present": bool(cs.get("present", false)),
			"resistance": clampf(float(cs.get("resistance", 0.0)), 0.0, 1.0)}
		if next != _captain:
			_captain = next
			captain_replicated.emit(bool(next["present"]), float(next["resistance"]))


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn(batch: Array) -> void:
	if Net.is_authority():
		return
	apply_spawns(batch)


@rpc("authority", "call_remote", "reliable")
func _rpc_despawn(ids: PackedInt32Array) -> void:
	if Net.is_authority():
		return
	for id: int in ids:
		var n: Node = Ids.lookup(id)
		if n == null:
			continue
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.queue_free()
		despawns_applied += 1


@rpc("authority", "call_remote", "reliable")
func _rpc_state(diffs: Dictionary, svc: Dictionary) -> void:
	if Net.is_authority():
		return
	for k: Variant in diffs:
		var n: Node = Ids.lookup(int(k))
		if n != null:
			NetEntityCodec.apply_state(n, diffs[k] as Dictionary)
			states_applied += 1
	apply_services(svc)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_xforms(xforms: Dictionary) -> void:
	if Net.is_authority():
		return
	for k: Variant in xforms:
		var n: Node = Ids.lookup(int(k))
		if n != null:
			NetEntityCodec.apply_xform(n, xforms[k])
