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
## Ruling C11 (several heists on one kept Net session): HeistRuntime.teardown() tells the other side through
## Net.lobby_send, keyed by the heist's `token` (bring-up "token") so a notice never touches the next heist:
## the host sends KIND_CLOSED (the client replica freezes, `host_closed` fires, its local crew stops sending
## intents to the host's freed nodes); a client sends KIND_LEFT (the host stops replicating to that peer, so
## its state / transform RPCs do not hit the client's freed replica while the host is still on its payday).
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
## Client (C11): the host tore its heist down (payday Continue, session kept). The replica is frozen
## (process disabled): the app flow (ENV B) tears it down on its own Continue, like after heist_ended.
signal host_closed()

const SERVICE: StringName = &"net_sync"
const NODE_NAME: String = "NetSync"
## Discrete-state and transform rate (net.md: 10-20 Hz).
const SYNC_HZ: float = 15.0
## A4-03 soak (Dockside: two cowering civilians 5 m off on every client for the whole run): transforms go out
## unreliable and only when changed, so one lost packet, or one that reached a client still building its replica,
## leaves a now-still NPC stale for good. Every XFORM_KEYFRAME_S the full transform set is resent once.
const XFORM_KEYFRAME_S: float = 2.0
const SVC_INTERACTION: String = "isys"
const SVC_CODES: String = "codes"
const SVC_CUSTODY: String = "custody"
const SVC_RUNTIME: String = "rt"
## D-071 per-crew counters (CrewStatsService).
const SVC_STATS: String = "stats"
## ui_hud v1.3: {"present": bool, "resistance": float 0..1} of the director's AegisCaptain.
const SVC_CAPTAIN: String = "captain"
## D-103 §6: runtime MapZone kind changes (ZoneKinds).
const SVC_ZONES: String = "zones"
## PO6-08: PagerSystem HUD rows (window frozen while answering) for clients.
const SVC_PAGERS: String = "pagers"
## QC-63: variant groups revealed at runtime (PreplanAssets.runtime_reveals).
const SVC_REVEALS: String = "reveals"
## B1 skill keys: the live timed buffs (CrewBuffs: Inspire, Overkill, Swan Song) for client movement / HUD.
const SVC_BUFFS: String = "buffs"
## D-161: EcmSystem pocket ECM per holder slot.
const SVC_POCKET_ECM: String = "pocket_ecm"
## D-162: Maniac Hysteria stacks per holder slot (HUD).
const SVC_MANIAC: String = "maniac"
## D-163: TagPairs (Tag Team) per holder slot.
const SVC_TAG_PAIRS: String = "tag_pairs"
## C11 Net.lobby_message kinds, both {"token": int}: host -> clients / client -> host.
const KIND_CLOSED: StringName = &"heist_closed"
const KIND_LEFT: StringName = &"heist_left"

## Client: counters for tests and diagnostics.
var spawns_applied: int = 0
var despawns_applied: int = 0
var states_applied: int = 0
## Client: heist_time_s when host_lost fired (< 0 = never).
var host_lost_at_s: float = -1.0
## Client (C11): true once the host's KIND_CLOSED for this heist arrived (see host_closed).
var host_closed_heist: bool = false
## C11: this heist's id on the session, keying KIND_CLOSED / KIND_LEFT. Server: unique per runtime (set in
## _ready); client: the bring-up's "token" (HeistRuntime._start_replica). 0 = unknown.
var token: int = 0

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
var _keyframe_left: float = XFORM_KEYFRAME_S
## Client: last replicated captain state (see captain_state()).
var _captain: Dictionary = {"present": false, "resistance": 0.0}
## Server: peers holding a replica of this heist, the only ones replicated to: the peers connected at begin(),
## a drop-in once its late_bring_up() went out (QB-B6-DROPIN: nothing reaches it before its replica exists),
## minus a peer that tore its replica down (C11, KIND_LEFT).
var _members: Dictionary[int, bool] = {}


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
	if Net.is_authority():
		token = get_instance_id()
	if not Net.host_lost.is_connected(_on_server_disconnected):
		Net.host_lost.connect(_on_server_disconnected)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not Net.lobby_message.is_connected(_on_lobby_message):
		Net.lobby_message.connect(_on_lobby_message)


func _exit_tree() -> void:
	if Net.host_lost.is_connected(_on_server_disconnected):
		Net.host_lost.disconnect(_on_server_disconnected)
	if Net.lobby_message.is_connected(_on_lobby_message):
		Net.lobby_message.disconnect(_on_lobby_message)
	if multiplayer != null and multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)


func _on_server_disconnected() -> void:
	if host_lost_at_s >= 0.0:
		return
	host_lost_at_s = _runtime.heist_time_s if _runtime != null else 0.0
	Log.warn(&"net", "connection to the host lost")
	host_lost.emit()


## Server: true while `peer_id` gets this heist's replication (see _members).
func replicates_to(peer_id: int) -> bool:
	return _members.has(peer_id)


## C11 (HeistRuntime.teardown, before the runtime leaves the tree): tell the other side this heist is gone
## here. Server: KIND_CLOSED to the clients (once begin() ran, live session). Client: KIND_LEFT to the host
## (while connected). No-op offline.
func notify_teardown() -> void:
	if not is_inside_tree() or token == 0:
		return
	if Net.is_authority():
		if _begun and is_live():
			Net.lobby_send(KIND_CLOSED, {"token": token})
	elif host_lost_at_s < 0.0 and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(1):
		Net.lobby_send(KIND_LEFT, {"token": token})


func _on_lobby_message(from_peer: int, kind: StringName, data: Dictionary) -> void:
	if kind != KIND_CLOSED and kind != KIND_LEFT:
		return
	if token == 0 or int(data.get("token", 0)) != token or from_peer == Net.local_peer_id():
		return
	if kind == KIND_LEFT and Net.is_authority():
		_members.erase(from_peer)
	elif kind == KIND_CLOSED and not Net.is_authority() and from_peer == 1 and not host_closed_heist:
		host_closed_heist = true
		if _runtime != null and is_instance_valid(_runtime):
			_runtime.process_mode = Node.PROCESS_MODE_DISABLED  # nothing of it may RPC the host's freed nodes
		Log.info(&"net", "the host closed heist %s" % (_runtime.heist_id if _runtime != null else &"?"))
		host_closed.emit()


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
	for p: int in multiplayer.get_peers():
		_members[p] = true
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
		"objectives": objectives_state(), "token": token,
	}


## Server (QB-B6-DROPIN): the bring-up for one peer dropping into the running heist. Same shape as
## bring_up() plus "for_peer" (other clients ignore it), built from the current state WITHOUT moving the
## diff baselines of the clients already in (their later diffs re-apply harmlessly on the newcomer).
func late_bring_up(peer_id: int) -> Dictionary:
	var rt: HeistRuntime = _runtime
	_members[peer_id] = true  # its bring-up goes out right after: later RPCs are ordered behind it
	var states: Dictionary = {}
	var map_ids: Dictionary = map_id_table()
	var spawns: Array = describe_dynamic()
	for id: int in _tracked:
		var n: Node = Ids.lookup(id)
		if n != null:
			states[id] = NetEntityCodec.state_of(n)
	var crew_ids: Dictionary = {}
	for c: CrewController in rt.crew_members():
		crew_ids[c.slot] = NetIds.of(c)
	return {
		"version": HeistLauncher.BRING_UP_VERSION, "heist_id": rt.heist_id, "seed": rt.run_seed,
		"difficulty": rt.difficulty, "map_scene": rt.map.scene_file_path, "variants": rt.variants.duplicate(true),
		"map_ids": map_ids, "crew_ids": crew_ids, "phase": int(rt.phase), "went_loud": rt.went_loud,
		"heist_time_s": rt.heist_time_s, "preplan": rt.preplan.result.duplicate(true) if rt.preplan.is_active() else {},
		"runtime_path": String(rt.get_path()), "launch_options": public_options(rt.launch_options),
		"objectives": objectives_state(), "token": token,
		"snapshot": {"spawns": spawns, "states": states, "services": services_state()}, "for_peer": peer_id,
	}


## PO-B-C7: the mission's objectives as [id, state, data (with "text_key")] in creation order, for the
## bring-up: objective_updated [R] facts sent during the host's mission start reach no replica yet.
func objectives_state() -> Array:
	var out: Array = []
	var m: HeistMission = _runtime.mission if _runtime != null else null
	if m == null:
		return out
	for o: Dictionary in m.objectives():
		var data: Dictionary = (o.get("data", {}) as Dictionary).duplicate(true)
		data["text_key"] = o["text_key"]
		out.append([StringName(o["id"]), int(o["state"]), data])
	return out


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
	out[SVC_RUNTIME] = {"phase": int(_runtime.phase), "loud": _runtime.went_loud, "layouts": _runtime.layouts.duplicate()}
	if _runtime.stats != null:
		out[SVC_STATS] = _runtime.stats.net_state()
	out[SVC_CAPTAIN] = captain_state()
	var zones: ZoneKinds = _runtime.service(ZoneKinds.SERVICE) as ZoneKinds
	if zones != null and not zones.overrides.is_empty():
		out[SVC_ZONES] = zones.net_state()
	var pagers: PagerSystem = _runtime.service(G.SVC_PAGERS) as PagerSystem
	if pagers != null:
		out[SVC_PAGERS] = pagers.net_state()
	var buffs: CrewBuffs = _runtime.service(CrewBuffs.SERVICE) as CrewBuffs
	if buffs != null:
		out[SVC_BUFFS] = buffs.net_state()
	if not _runtime.preplan.runtime_reveals.is_empty():
		out[SVC_REVEALS] = _runtime.preplan.reveals_net_state()
	var ecm: EcmSystem = _runtime.service(EcmSystem.SERVICE) as EcmSystem
	if ecm != null and not ecm.pocket.is_empty():
		out[SVC_POCKET_ECM] = ecm.net_state()
	var maniac: Dictionary = {}
	for c: CrewController in _runtime.crew_members():
		if c.has_meta(PerkManiac.META):
			maniac[c.slot] = snappedf(PerkManiac.stacks_of(c), 1.0)
	if not maniac.is_empty():
		out[SVC_MANIAC] = maniac
	var tags: TagPairs = _runtime.service(TagPairs.SERVICE) as TagPairs
	if tags != null and not tags.pairs.is_empty():
		out[SVC_TAG_PAIRS] = tags.net_state()
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
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"heist_net_sync", fp)


func _physics_step(delta: float) -> void:
	if not _begun or _runtime == null or not Net.is_authority() or not is_live():
		return
	_scan_spawns()
	_scan_despawns()
	_accum += delta
	_keyframe_left -= delta
	if _accum < 1.0 / SYNC_HZ:
		return
	_accum = 0.0
	_send_state()
	if _keyframe_left <= 0.0:
		_keyframe_left = XFORM_KEYFRAME_S
		_last_xform.clear()  # this send carries every transform
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
		_send(&"_rpc_spawn", [batch])


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
	_send(&"_rpc_despawn", [gone])


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
		_send(&"_rpc_state", [diffs, svc_diff])


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
		_send(&"_rpc_xforms", [out])


## Server: an RPC of this node to every peer holding the replica (_members; a broadcast when that is everyone).
func _send(method: StringName, args: Array) -> void:
	var peers: PackedInt32Array = multiplayer.get_peers()
	var targets: Array[int] = []
	for p: int in peers:
		if _members.has(p):
			targets.append(p)
	if targets.size() == peers.size():
		callv(&"rpc", [method] + args)
		return
	for p: int in targets:
		callv(&"rpc_id", [p, method] + args)


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
	if svc.has(SVC_ZONES):
		ZoneKinds.ensure(_runtime).apply_net_state(svc[SVC_ZONES] as Dictionary)
	var pagers: PagerSystem = _runtime.service(G.SVC_PAGERS) as PagerSystem
	if svc.has(SVC_PAGERS) and pagers != null:
		pagers.apply_net_state(svc[SVC_PAGERS] as Dictionary)
	if svc.has(SVC_BUFFS):
		CrewBuffs.of(_runtime).apply_net_state(svc[SVC_BUFFS] as Dictionary)
	if svc.has(SVC_REVEALS):
		_runtime.preplan.apply_reveals_net_state(svc[SVC_REVEALS] as Array)
	var ecm: EcmSystem = _runtime.service(EcmSystem.SERVICE) as EcmSystem
	if svc.has(SVC_POCKET_ECM) and ecm != null:
		ecm.apply_net_state(svc[SVC_POCKET_ECM] as Dictionary)
	if svc.has(SVC_TAG_PAIRS):
		TagPairs.of(_runtime).apply_net_state(svc[SVC_TAG_PAIRS] as Dictionary)
	var maniac: Dictionary = svc.get(SVC_MANIAC, {}) as Dictionary
	for k: Variant in maniac:
		var mc: Node = _runtime.crew_controller(int(k))
		if mc != null:
			mc.set_meta(PerkManiac.META, float(maniac[k]))
	if svc.has(SVC_RUNTIME):
		var r: Dictionary = svc[SVC_RUNTIME] as Dictionary
		phase_replicated.emit(int(r.get("phase", _runtime.phase)), bool(r.get("loud", _runtime.went_loud)))
		if not Net.is_authority():
			_runtime.apply_replicated_layouts(r.get("layouts", {}) as Dictionary)  # A5-02
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


# --- PO-8 presentation facts (impact_fx.md 1.0, D-105): one per shot / strike / blast, never per pellet --
# Reliable like the [R] EventBus facts: ENet throttles unreliable packets under load (the loopback test
# lost whole shots on a busy machine), and a shot nobody sees (an enemy firing at you) is worse than the
# few bytes of one ordered message per shot. They ride this node, whose RPC path every client caches early.

## Server: may presentation facts go out now (a live session whose clients have the heist replica)?
func _can_relay_fx() -> bool:
	return _begun and _runtime != null and Net.is_authority() and is_live()


## Server: an accepted crew gun shot (CrewWeapons.server_commit_shot) to every client except
## `exclude_peer` (the owning client that already presented it). Clients replay the seeded pellets.
func relay_crew_shot(crew_net_id: int, origin: Vector3, dir: Vector3, spread_deg: float, pellet_seed: int,
		weapon_slot: int, exclude_peer: int = 0) -> void:
	if not _can_relay_fx():
		return
	for p: int in multiplayer.get_peers():
		if p != exclude_peer and _members.has(p):
			_rpc_crew_shot.rpc_id(p, crew_net_id, origin, dir, spread_deg, pellet_seed, weapon_slot)


## Server: an NPC shot or a crew melee strike (ShotFx.MODE_*).
func relay_impact_fx(shooter_id: int, from: Vector3, to: Vector3, target_id: int, mode: int) -> void:
	if _can_relay_fx():
		_send(&"_rpc_impact_fx", [shooter_id, from, to, target_id, mode])


## Server: a blast (Explosion.apply, concussion grenades).
func relay_explosion_fx(pos: Vector3, radius: float, kind: StringName) -> void:
	if _can_relay_fx():
		_send(&"_rpc_explosion_fx", [pos, radius, kind])


## Server (D-116, net.md npc_oneshot): NPC `net_id` started presentation one-shot `clip` at clip time `start_s` (s)
## with speed_scale `speed` (NetOneshot: door breach door_kick_<fam> / shield_bang, civilian panic_start).
func relay_npc_oneshot(net_id: int, clip: StringName, start_s: float, speed: float) -> void:
	if _can_relay_fx():
		_send(&"_rpc_npc_oneshot", [net_id, clip, start_s, speed])


@rpc("authority", "call_remote", "reliable")
func _rpc_crew_shot(crew_net_id: int, origin: Vector3, dir: Vector3, spread_deg: float, pellet_seed: int,
		weapon_slot: int) -> void:
	if Net.is_authority():
		return
	var crew: CrewController = Ids.lookup(crew_net_id) as CrewController
	if crew != null and crew.weapons != null:  # net hook, like NetEntityCodec's _apply_net_state
		crew.weapons.call(&"_fx_replay", origin, dir, spread_deg, pellet_seed, weapon_slot)


@rpc("authority", "call_remote", "reliable")
func _rpc_impact_fx(shooter_id: int, from: Vector3, to: Vector3, target_id: int, mode: int) -> void:
	if Net.is_authority():
		return
	ShotFx.play_impact(Ids.lookup(shooter_id), from, to, target_id, mode)


@rpc("authority", "call_remote", "reliable")
func _rpc_explosion_fx(pos: Vector3, radius: float, kind: StringName) -> void:
	if Net.is_authority():
		return
	EventBus.explosion_fx.emit(pos, radius, kind)


@rpc("authority", "call_remote", "reliable")
func _rpc_npc_oneshot(net_id: int, clip: StringName, start_s: float, speed: float) -> void:
	if Net.is_authority():
		return
	var d: AnimDriver = AnimDriver.of(Ids.lookup(net_id))
	if d != null:
		NetOneshot.apply(d, clip, start_s, speed)
