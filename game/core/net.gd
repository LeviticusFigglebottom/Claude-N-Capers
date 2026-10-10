## Session + crew registry + authority helpers + EventBus relay. Owner: LEAD (API).
## Contract: docs/contracts/net.md.
##
## Solo play = OfflineMultiplayerPeer (Godot default): multiplayer.is_server() == true,
## so solo runs the exact host code path. AI teammates occupy crew slots with peer_id 0.
extends Node

signal crew_changed()
signal session_started(is_host: bool)
signal session_ended()

const MAX_CREW: int = 4
const DEFAULT_PORT: int = 27655
const AI_PEER: int = 0

## crew_slot -> CrewSlotInfo dictionary: { "peer_id": int, "is_ai": bool, "display_name": String }
var crew: Dictionary[int, Dictionary] = {}


func is_authority() -> bool:
	return multiplayer.is_server()


func local_peer_id() -> int:
	return multiplayer.get_unique_id()


## Solo session: offline peer, local player in slot 0, AI fills the rest if requested.
func start_solo(display_name: String = "Player", ai_teammates: int = 3) -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	crew.clear()
	_assign_slot(local_peer_id(), false, display_name)
	for i: int in range(ai_teammates):
		_assign_slot(AI_PEER, true, "AI %d" % (i + 1))
	session_started.emit(true)


func host(port: int = DEFAULT_PORT, display_name: String = "Host") -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CREW - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	crew.clear()
	_assign_slot(1, false, display_name)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	session_started.emit(true)
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	session_started.emit(false)
	return OK


func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	crew.clear()
	session_ended.emit()


## Crew slot owned by a peer, or -1.
func slot_of_peer(peer_id: int) -> int:
	for slot: int in crew:
		if crew[slot]["peer_id"] == peer_id and not crew[slot]["is_ai"]:
			return slot
	return -1


func local_slot() -> int:
	return slot_of_peer(local_peer_id())


func human_slots() -> Array[int]:
	var out: Array[int] = []
	for slot: int in crew:
		if not crew[slot]["is_ai"]:
			out.append(slot)
	return out


func all_slots() -> Array[int]:
	var out: Array[int] = []
	out.assign(crew.keys())
	out.sort()
	return out


## Server: fill empty slots with AI (called when a heist starts).
func fill_with_ai() -> void:
	assert(is_authority())
	while crew.size() < MAX_CREW:
		_assign_slot(AI_PEER, true, "AI %d" % crew.size())
	_sync_crew()


## Server: relay an EventBus fact to all clients (they re-emit locally).
## Args must be network-serializable (no Node references; use net_ids).
func replicate_event(signal_name: StringName, args: Array) -> void:
	if not is_authority() or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_rpc_event.rpc(signal_name, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_event(signal_name: StringName, args: Array) -> void:
	if not EventBus.has_signal(signal_name):
		Log.warn(&"net", "unknown replicated event %s" % signal_name)
		return
	EventBus.emit_signal.callv([signal_name] + args)


func _assign_slot(peer_id: int, is_ai: bool, display_name: String) -> int:
	for slot: int in range(MAX_CREW):
		if not crew.has(slot):
			crew[slot] = {"peer_id": peer_id, "is_ai": is_ai, "display_name": display_name}
			crew_changed.emit()
			return slot
	return -1


func _on_peer_connected(peer_id: int) -> void:
	# Replace an AI slot if the crew is full of AI, else take a free slot.
	for slot: int in all_slots():
		if crew[slot]["is_ai"]:
			crew[slot] = {"peer_id": peer_id, "is_ai": false, "display_name": "Player %d" % peer_id}
			crew_changed.emit()
			_sync_crew()
			return
	_assign_slot(peer_id, false, "Player %d" % peer_id)
	_sync_crew()


func _on_peer_disconnected(peer_id: int) -> void:
	var slot: int = slot_of_peer(peer_id)
	if slot >= 0:
		crew[slot] = {"peer_id": AI_PEER, "is_ai": true, "display_name": "AI %d" % slot}
		crew_changed.emit()
		_sync_crew()


func _sync_crew() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_rpc_crew.rpc(crew)


@rpc("authority", "call_remote", "reliable")
func _rpc_crew(new_crew: Dictionary) -> void:
	crew.clear()
	for k: Variant in new_crew:
		crew[int(k)] = new_crew[k]
	crew_changed.emit()
