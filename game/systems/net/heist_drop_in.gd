## PD2 drop-in for a running heist (QB-B6-DROPIN, B6-04). Owner: ENV A. Implements ENV B's DropInService
## interface (content/lobby/drop_in_service.gd); one node `DropIn` under the tree root, group
## DropInService.GROUP, made by ensure() (the host's HeistRuntime ensures it at start; a joining client's
## UI calls `HeistDropIn.ensure(get_tree())` before asking).
##
## Client entry point (B): `Net.join(address, port, name)`, then on Net.connected_to_host call
## `HeistDropIn.ensure(get_tree()).request_join(LobbyState.summary_from(loadout, profile))`. The service
## waits for the host's answer and bring-up itself (HeistLauncher.launch_client) and emits join_progress /
## joined(slot) / join_failed(peer, reason) locally. While the heist does not run on the host, a request is
## denied (B's lobby flow covers that case).
##
## Host: a request (kind REQUEST) is checked in order:
##   no running heist / heist over -> denied; the peer has no crew slot (crew full of humans) -> full;
##   kicked this session -> kicked; LobbyState.validate_summary errors -> denied; then `policy`:
##   &"off" -> denied, &"auto" -> accept, &"ask" (default) -> join_requested(peer, summary), the host UI
##   answers with answer_join() (B's dialog auto-denies on its timeout).
## Accept: the AI crew member of the peer's slot (Net assigns a joining peer an AI slot) becomes the
## peer's: owner, name and the summary's loadout (modifiers pushed again), its CrewAiBrain removed; then a
## bring-up addressed to the peer (HeistNetSync.late_bring_up). joined(slot) [host] when the peer reports
## its replica is built; crew_member_joined [R].
## Deny: an ANSWER {accept false, reason} to the peer, then it is disconnected (its slot falls back to AI).
## kick(slot): Net.kick(peer) (D-072: the name stays on Net's kick list); kicked(slot). Any human leaving
## mid-heist (kick, drop, quit) turns its crew member back into an AI teammate (L6.1), crew_member_left [R].
## Messages travel as Net.lobby_send kinds `dropin.*` (never `lobby.chat` / `lobby.kick`); host -> client
## ones carry "to".
class_name HeistDropIn
extends DropInService

const NODE_NAME: String = "DropIn"
const KIND_REQUEST: StringName = &"dropin.request"
const KIND_ANSWER: StringName = &"dropin.answer"
const KIND_PROGRESS: StringName = &"dropin.progress"
const KIND_CANCEL: StringName = &"dropin.cancel"
const POLICY_ASK: StringName = &"ask"
const POLICY_AUTO: StringName = &"auto"
const POLICY_OFF: StringName = &"off"
## Host: delay before a denied peer is disconnected (lets the answer flush, like Net.KICK_FLUSH_S).
const DENY_FLUSH_S: float = 0.25

## Host drop-in policy (B's options / lobby): &"ask" | &"auto" | &"off".
var policy: StringName = POLICY_ASK
## Host: peer_id -> summary of requests waiting for answer_join().
var pending: Dictionary[int, Dictionary] = {}
## Client: a request is in flight / loading.
var joining: bool = false

## Host: display names kicked this session (auto-denied).
var _kicked: Dictionary[String, bool] = {}
var _cancel_gen: int = 0


## The service under the tree root (created on first use).
static func ensure(tree: SceneTree) -> HeistDropIn:
	var s: HeistDropIn = tree.root.get_node_or_null(NODE_NAME) as HeistDropIn
	if s == null:
		s = HeistDropIn.new()
		s.name = NODE_NAME
		tree.root.add_child(s)
	return s


func _ready() -> void:
	Net.lobby_message.connect(_on_lobby_message)
	Net.crew_changed.connect(_on_net_crew_changed)
	Net.peer_kicked.connect(_on_peer_kicked)
	Net.host_lost.connect(_on_host_lost)


func _exit_tree() -> void:
	for pair: Array in [
		[Net.lobby_message, _on_lobby_message], [Net.crew_changed, _on_net_crew_changed],
		[Net.peer_kicked, _on_peer_kicked], [Net.host_lost, _on_host_lost],
	]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


# --- Host -----------------------------------------------------------------------------------------

# LEAD: matches B's DropInService v2 signature (f46b038: reason argument; REASON_KICKED now inherited).
func answer_join(peer_id: int, accept: bool, reason: StringName = REASON_DENIED) -> void:
	if not Net.is_authority() or not pending.has(peer_id):
		return
	var summary: Dictionary = pending[peer_id]
	pending.erase(peer_id)
	if accept:
		_accept(peer_id, summary)
	else:
		_deny(peer_id, reason)


func kick(slot: int) -> bool:
	if not Net.is_authority() or not Net.crew.has(slot):
		return false
	var info: Dictionary = Net.crew[slot]
	if bool(info.get("is_ai", true)):
		return false
	_kicked[String(info.get("display_name", ""))] = true
	return Net.kick(int(info.get("peer_id", Net.AI_PEER)))


func _on_request(peer_id: int, summary: Dictionary) -> void:
	var rt: HeistRuntime = HeistRuntime.current()
	if rt == null or rt.is_replica or rt.phase == Enums.HeistPhase.ENDED:
		_deny(peer_id, REASON_DENIED)
		return
	var slot: int = Net.slot_of_peer(peer_id)
	if slot < 0 or rt.crew_controller(slot) == null:
		_deny(peer_id, REASON_FULL)
		return
	if _kicked.has(String(summary.get("name", ""))):
		_deny(peer_id, REASON_KICKED)
		return
	var errors: Array[String] = LobbyState.validate_summary(summary)
	if not errors.is_empty():
		Log.warn(LOG_CHANNEL, "drop-in from %d rejected: %s" % [peer_id, ", ".join(errors)])
		_deny(peer_id, REASON_DENIED)
		return
	match policy:
		POLICY_OFF:
			_deny(peer_id, REASON_DENIED)
		POLICY_AUTO:
			_accept(peer_id, summary)
		_:
			pending[peer_id] = summary
			join_requested.emit(peer_id, summary)


func _accept(peer_id: int, summary: Dictionary) -> void:
	var rt: HeistRuntime = HeistRuntime.current()
	var slot: int = Net.slot_of_peer(peer_id)
	var c: CrewController = rt.crew_controller(slot) as CrewController if rt != null and slot >= 0 else null
	if c == null:
		_deny(peer_id, REASON_FULL)
		return
	var l: Loadout = LobbyState.loadout_from_dict(summary.get("loadout", {}) as Dictionary)
	var eff: Loadout = LoadoutModifiers.effective_loadouts({slot: l}, [slot])[slot]
	rt.crew_loadouts[slot] = eff
	LoadoutModifiers.push(rt.crew_loadouts)  # QB-L2: the newcomer's skills + perk deck
	var brain: Node = c.get_node_or_null(CrewAiBrain.NODE_NAME)
	if brain != null:
		c.remove_child(brain)
		brain.queue_free()
	c.peer_id = peer_id
	c.is_ai = false
	c.display_name = String(summary.get("name", c.display_name)).left(24)
	c.set_loadout(eff)
	_send(KIND_ANSWER, {"to": peer_id, "accept": true, "slot": slot})
	Net.lobby_send(HeistLauncher.BRING_UP_KIND, rt.net_sync.late_bring_up(peer_id))
	join_progress.emit(peer_id, 0.0)
	EventBus.crew_member_joined.emit(slot, peer_id, false)
	Net.replicate_event(&"crew_member_joined", [slot, peer_id, false])


func _deny(peer_id: int, reason: StringName) -> void:
	pending.erase(peer_id)
	_send(KIND_ANSWER, {"to": peer_id, "accept": false, "reason": String(reason)})
	join_failed.emit(peer_id, reason)
	get_tree().create_timer(DENY_FLUSH_S, true, false, true).timeout.connect(_drop.bind(peer_id))


func _drop(peer_id: int) -> void:
	var mp: MultiplayerPeer = multiplayer.multiplayer_peer
	if mp != null and not (mp is OfflineMultiplayerPeer) and multiplayer.get_peers().has(peer_id):
		mp.disconnect_peer(peer_id)


func _on_peer_kicked(_peer_id: int, slot: int) -> void:
	kicked.emit(slot)


## Host: a human left (kick, drop, quit): Net put an AI back in its slot; make its crew member an AI teammate.
func _on_net_crew_changed() -> void:
	var rt: HeistRuntime = HeistRuntime.current()
	if not Net.is_authority() or rt == null or rt.is_replica:
		return
	for peer_id: int in pending.keys():
		if Net.slot_of_peer(peer_id) < 0:
			pending.erase(peer_id)
			join_failed.emit(peer_id, REASON_CANCELLED)
	for c: CrewController in rt.crew_members():
		var info: Dictionary = Net.crew.get(c.slot, {})
		if c.is_ai or not bool(info.get("is_ai", false)) or c.peer_id == Net.local_peer_id():
			continue
		c.peer_id = Net.AI_PEER
		c.is_ai = true
		c.display_name = String(info.get("display_name", c.display_name))
		if c.get_node_or_null(CrewAiBrain.NODE_NAME) == null:
			c.add_child(CrewAiBrain.new())  # A1-10 AI teammate (L6.1)
		EventBus.crew_member_left.emit(c.slot)
		Net.replicate_event(&"crew_member_left", [c.slot])


# --- Client ---------------------------------------------------------------------------------------

func request_join(summary: Dictionary) -> void:
	if Net.is_authority() or joining:
		return
	joining = true
	_cancel_gen += 1
	var gen: int = _cancel_gen
	join_progress.emit(Net.local_peer_id(), 0.0)
	_send(KIND_REQUEST, {"summary": summary})
	var rt: HeistRuntime = await HeistLauncher.launch_client()
	if gen != _cancel_gen or not joining:
		return
	joining = false
	if rt == null:
		if Net.last_disconnect_reason == REASON_KICKED:
			join_failed.emit(Net.local_peer_id(), REASON_KICKED)
		return  # denied / cancelled / host lost: join_failed already emitted
	join_progress.emit(Net.local_peer_id(), 1.0)
	_send(KIND_PROGRESS, {"frac": 1.0})
	joined.emit(Net.local_slot())


func cancel_join() -> void:
	if not joining:
		return
	joining = false
	_cancel_gen += 1
	_send(KIND_CANCEL, {})
	HeistLauncher.cancel_launch_client()
	join_failed.emit(Net.local_peer_id(), REASON_CANCELLED)


func _on_answer(data: Dictionary) -> void:
	if not joining:
		return
	if bool(data.get("accept", false)):
		join_progress.emit(Net.local_peer_id(), 0.5)  # the bring-up follows
		return
	joining = false
	_cancel_gen += 1
	HeistLauncher.cancel_launch_client()
	join_failed.emit(Net.local_peer_id(), StringName(String(data.get("reason", REASON_DENIED))))


func _on_host_lost() -> void:
	if joining:
		joining = false
		_cancel_gen += 1
		join_failed.emit(Net.local_peer_id(), REASON_HOST_LOST)


# --- Messages -------------------------------------------------------------------------------------

func _send(kind: StringName, data: Dictionary) -> void:
	Net.lobby_send(kind, data)


func _on_lobby_message(from_peer: int, kind: StringName, data: Dictionary) -> void:
	if Net.is_authority():
		if from_peer == Net.local_peer_id():
			return
		match kind:
			KIND_REQUEST:
				_on_request(from_peer, data.get("summary", {}) as Dictionary)
			KIND_CANCEL:
				if pending.has(from_peer):
					pending.erase(from_peer)
				join_failed.emit(from_peer, REASON_CANCELLED)
				_drop(from_peer)
			KIND_PROGRESS:
				var frac: float = clampf(float(data.get("frac", 0.0)), 0.0, 1.0)
				join_progress.emit(from_peer, frac)
				if frac >= 1.0:
					joined.emit(Net.slot_of_peer(from_peer))
		return
	if kind == KIND_ANSWER and int(data.get("to", -1)) == Net.local_peer_id():
		_on_answer(data)
