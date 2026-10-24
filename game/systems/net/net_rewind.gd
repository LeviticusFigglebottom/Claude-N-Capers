## Server: a short position history of the NPCs, so a remote shooter's hit claim is checked against where the target
## was on that client's screen (P6 co-op hardening, LEAD r313). Owner: ENV A.
## A client renders NPCs NetInterp.DELAY_S behind the newest server time it heard of, which itself is half a round trip
## old; it claims its hits there (CombatSystem). The claim-tolerance checks (body centre, head) also accept a match with
## any sampled position inside that window, so running targets are not rejected for being where the client saw them.
## Host shots and AI crew use the present only. Child `NetRewind` of HeistNetSync on the authority; samples only while
## a live session replicates (solo: nothing recorded, `offsets` returns [ZERO]).
class_name NetRewind
extends Node

const NODE_NAME: String = "NetRewind"
## Sample period (s): the transform rate.
const SAMPLE_S: float = 1.0 / 15.0
## Oldest sample kept (s), and the window cap for one claim.
const HISTORY_S: float = 0.6
## Slack on top of DELAY_S + RTT / 2 (one sample period and a bit of jitter).
const MARGIN_S: float = 0.1

## [[time_s, {net_id: Vector3 root position}], ...] oldest first.
var _hist: Array[Array] = []
var _acc: float = 0.0
var _clock: float = 0.0


func _physics_process(delta: float) -> void:
	_clock += delta
	var ns: HeistNetSync = get_parent() as HeistNetSync
	if ns == null or not Net.is_authority() or not ns.is_live():
		_hist.clear()
		return
	_acc += delta
	if _acc < SAMPLE_S:
		return
	_acc = 0.0
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null:
		return
	var snap: Dictionary = {}
	for n: Node in rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.alive:
			snap[npc.net_id] = npc.global_position
	_hist.append([_clock, snap])
	while not _hist.is_empty() and _clock - float(_hist[0][0]) > HISTORY_S:
		_hist.pop_front()


## Offsets (past position - present) of `target` over the window `shooter`'s screen lags by, ZERO first. Only ZERO for
## a host / AI shooter, a non-NPC target, or without history.
func offsets(target: Node3D, shooter: CrewController) -> Array[Vector3]:
	var out: Array[Vector3] = [Vector3.ZERO]
	var npc: NpcBase = target as NpcBase
	if npc == null or shooter == null or shooter.is_ai or shooter.peer_id == Net.local_peer_id() or _hist.is_empty():
		return out
	var window: float = minf(NetInterp.DELAY_S + rtt_s(shooter.peer_id) * 0.5 + MARGIN_S, HISTORY_S)
	for i: int in range(_hist.size() - 1, -1, -1):
		var s: Array = _hist[i]
		if _clock - float(s[0]) > window:
			break
		var p: Variant = (s[1] as Dictionary).get(npc.net_id)
		if p is Vector3:
			out.append((p as Vector3) - npc.global_position)
	return out


## Round-trip time to `peer_id` (s), 0 when unknown (no ENet peer).
func rtt_s(peer_id: int) -> float:
	var mp: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer if multiplayer != null else null
	if mp == null:
		return 0.0
	var pp: ENetPacketPeer = mp.get_peer(peer_id)
	return pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 1000.0 if pp != null else 0.0


## The `shooter`-relative offsets of `target` through the runtime's NetSync (ZERO only without one).
static func offsets_for(target: Node3D, shooter: CrewController) -> Array[Vector3]:
	var rt: HeistRuntime = HeistRuntime.of(target) if target != null else null
	var rw: NetRewind = rt.net_sync.get_node_or_null(NODE_NAME) as NetRewind if rt != null and rt.net_sync != null else null
	return rw.offsets(target, shooter) if rw != null else [Vector3.ZERO] as Array[Vector3]
