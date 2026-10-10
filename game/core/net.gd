## Session + crew registry + authority helpers + EventBus relay. Owner: LEAD (API).
## Contract: docs/contracts/net.md.
##
## Solo play = OfflineMultiplayerPeer (Godot default): multiplayer.is_server() == true,
## so solo runs the exact host code path. AI teammates occupy crew slots with peer_id 0.
extends Node

signal crew_changed()
signal session_started(is_host: bool)
signal session_ended()
## Lobby/menu messages between peers (pre-planning votes, ready states...). D-038.
signal lobby_message(from_peer: int, kind: StringName, data: Dictionary)
## Client: the connection to the host is up / could not be made / was lost (D-052).
signal connected_to_host()
signal connection_failed()
signal host_lost()

const MAX_CREW: int = 4
const DEFAULT_PORT: int = 27655
const AI_PEER: int = 0

## crew_slot -> CrewSlotInfo dictionary: { "peer_id": int, "is_ai": bool, "display_name": String }
var crew: Dictionary[int, Dictionary] = {}

var _join_name: String = "Player"


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
	_disconnect_handlers()
	multiplayer.multiplayer_peer = peer
	crew.clear()
	_assign_slot(1, false, display_name)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	session_started.emit(true)
	return OK


## Client: connect to a host. `display_name` is sent to the host once connected (it names our slot).
## Outcome arrives as connected_to_host / connection_failed; host_lost if the host goes away later.
func join(address: String, port: int = DEFAULT_PORT, display_name: String = "Player") -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	_disconnect_handlers()
	_join_name = display_name
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	session_started.emit(false)
	return OK


func leave() -> void:
	_disconnect_handlers()
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


## Send a lobby message to every peer (including self). Data must be network-serializable.
## Solo/offline: delivered locally only.
func lobby_send(kind: StringName, data: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		lobby_message.emit(local_peer_id(), kind, data)
		return
	_rpc_lobby.rpc(kind, data)


@rpc("any_peer", "call_local", "reliable")
func _rpc_lobby(kind: StringName, data: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = local_peer_id()
	lobby_message.emit(sender, kind, data)


## Host and client handlers are connected per session; leave()/host()/join() clear the previous ones
## so a second session never double-connects (D-052).
func _disconnect_handlers() -> void:
	var pairs: Array = [
		[multiplayer.peer_connected, _on_peer_connected],
		[multiplayer.peer_disconnected, _on_peer_disconnected],
		[multiplayer.connected_to_server, _on_connected_to_server],
		[multiplayer.connection_failed, _on_connection_failed],
		[multiplayer.server_disconnected, _on_server_disconnected],
	]
	for p: Array in pairs:
		var sig: Signal = p[0]
		if sig.is_connected(p[1]):
			sig.disconnect(p[1])


func _on_connected_to_server() -> void:
	_rpc_hello.rpc_id(1, _join_name)
	connected_to_host.emit()


func _on_connection_failed() -> void:
	connection_failed.emit()
	leave()


func _on_server_disconnected() -> void:
	host_lost.emit()
	leave()


## Server: a joining client names its slot.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(display_name: String) -> void:
	if not is_authority():
		return
	var slot: int = slot_of_peer(multiplayer.get_remote_sender_id())
	if slot < 0:
		return
	crew[slot]["display_name"] = display_name.strip_edges().left(24)
	crew_changed.emit()
	_sync_crew()
