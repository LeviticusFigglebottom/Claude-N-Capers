## Glue between the Net API (core/net.gd, contract net.md) and the pure LobbyState (B4-11). Owner: ENV B.
## Uses ONLY the Net API: host / join / leave, the crew registry, lobby_send / lobby_message. No RPCs.
## `net` is the autoload Net by default; tests give it a Net instance living in its own
## SceneMultiplayer branch (host + client in one process).
##
## Flow: host(port) or join(address, port). Whenever the crew changes, every peer (re)sends its own
## profile summary and ready flag, and the host re-sends the contract, so a late joiner gets the whole
## picture. A lobby message is attributed to the SENDER'S crew slot (Net.slot_of_peer) and applied by
## LobbyState.receive (which rejects bad senders / payloads). MSG_START emits `started` on every peer,
## the host included (its own message comes back through Net), which is where MenuFlow launches.
class_name LobbySession
extends Node

signal changed()
signal contract_changed(contract: Dictionary)
## The host's MSG_START was accepted: {"heist": StringName, "difficulty", "is_pro", "seed"}.
signal started(info: Dictionary)
## A join never got a crew slot (timeout), or the host went away.
signal connection_failed(reason: StringName)
## The session ended (local Leave, or Net.leave() from anywhere).
signal session_left()
signal message_rejected(from_slot: int, kind: StringName, reason: StringName)

const FAIL_TIMEOUT: StringName = &"timeout"
const FAIL_HOST_LOST: StringName = &"host_lost"
const LOG_CHANNEL: StringName = &"lobby"

## The Net API node (autoload `Net` when left null before _ready).
var net: Node = null
var state: LobbyState = LobbyState.new()
var tweak: LobbyTweak
## Profile whose name / level / loadout this peer advertises.
var profile: PlayerProfile = null
## Loadout advertised in MSG_PROFILE (null = profile.loadout).
var loadout: Loadout = null
var _active: bool = false
var _join_left_s: float = -1.0
var _resend_queued: bool = false


func _ready() -> void:
	if net == null:
		net = get_node(^"/root/Net")
	if tweak == null:
		tweak = LobbyTweak.load_default()
	net.connect(&"crew_changed", _on_crew_changed)
	net.connect(&"lobby_message", _on_lobby_message)
	net.connect(&"session_ended", _on_session_ended)
	# Not part of the Net API yet (asked: QB-L1): a client learns that the host vanished only here.
	if not net.multiplayer.server_disconnected.is_connected(_on_host_lost):
		net.multiplayer.server_disconnected.connect(_on_host_lost)


func _exit_tree() -> void:
	if net != null and is_instance_valid(net) and net.multiplayer != null \
			and net.multiplayer.server_disconnected.is_connected(_on_host_lost):
		net.multiplayer.server_disconnected.disconnect(_on_host_lost)


## True from host()/join() until the session ends.
func is_active() -> bool:
	return _active


## True while a join waits for its crew slot.
func is_joining() -> bool:
	return _join_left_s >= 0.0


func host(port: int) -> Error:
	var p: PlayerProfile = _profile()
	var err: Error = net.call(&"host", port, p.profile_name if p.profile_name != "" else "Host") as Error
	if err != OK:
		Log.warn(LOG_CHANNEL, "host on port %d failed: %s" % [port, error_string(err)])
		return err
	_active = true
	state.reset(true)
	net.call(&"fill_with_ai")  # empty seats show as Crew AI; a joining peer takes an AI seat (Net)
	_on_crew_changed()
	return OK


func join(address: String, port: int) -> Error:
	var err: Error = net.call(&"join", address, port) as Error
	if err != OK:
		Log.warn(LOG_CHANNEL, "join %s:%d failed: %s" % [address, port, error_string(err)])
		return err
	_active = true
	state.reset(false)
	_join_left_s = tweak.join_timeout_s
	changed.emit()
	return OK


func leave() -> void:
	if not _active:
		return
	net.call(&"leave")  # session_ended -> _on_session_ended


func set_ready(on: bool) -> void:
	if _active and state.local_slot >= 0:
		net.call(&"lobby_send", LobbyState.MSG_READY, {"ready": on})


## Advertise `l` (default: the current advertised loadout / the profile's) to every peer.
func send_profile(l: Loadout = null) -> void:
	if l != null:
		loadout = l
	if not _active or state.local_slot < 0:
		return
	var p: PlayerProfile = _profile()
	net.call(&"lobby_send", LobbyState.MSG_PROFILE, LobbyState.summary_from(loadout if loadout != null else p.loadout, p))


## Host: set the lobby's contract (from the host's Board or planning table).
func set_contract(heist_id: StringName, difficulty: int, is_pro: bool) -> bool:
	if not _active or not state.is_host:
		return false
	net.call(&"lobby_send", LobbyState.MSG_CONTRACT, LobbyState.contract_data(heist_id, difficulty, is_pro))
	return true


## Host: send the launch order. Returns LobbyState.OK or the start_block() reason (nothing sent).
func start(run_seed: int) -> StringName:
	var block: StringName = state.start_block()
	if block != LobbyState.OK:
		return block
	net.call(&"lobby_send", LobbyState.MSG_START, LobbyState.start_data(state.contract, run_seed))
	return LobbyState.OK


func _process(delta: float) -> void:
	if _join_left_s < 0.0:
		return
	if state.local_slot >= 0:
		_join_left_s = -1.0
		return
	_join_left_s -= delta
	if _join_left_s < 0.0:
		_fail(FAIL_TIMEOUT)


func _on_crew_changed() -> void:
	if not _active:
		return
	var crew: Dictionary = net.get(&"crew") as Dictionary
	var host: int = int(net.call(&"slot_of_peer", 1))
	state.set_crew(crew, int(net.call(&"local_slot")), host)
	if state.local_slot >= 0:
		_join_left_s = -1.0
		# Deferred: Net emits crew_changed on the host BEFORE it syncs the crew to the new peer, and a
		# message that overtakes the crew would come from an unknown slot there.
		if not _resend_queued:
			_resend_queued = true
			_resend.call_deferred()
	changed.emit()


## Re-advertise this peer's summary + ready flag (and the host's contract) after a crew change.
func _resend() -> void:
	_resend_queued = false
	if not _active or state.local_slot < 0:
		return
	send_profile()
	if state.is_ready(state.local_slot):
		set_ready(true)
	if state.is_host and not state.contract.is_empty():
		var c: Dictionary = state.contract
		set_contract(c["heist"], int(c["difficulty"]), bool(c["is_pro"]))


func _on_lobby_message(from_peer: int, kind: StringName, data: Dictionary) -> void:
	if not _active or not LobbyState.KINDS.has(kind):
		return
	var slot: int = int(net.call(&"slot_of_peer", from_peer))
	if slot < 0 and from_peer == int(net.call(&"local_peer_id")):
		slot = state.local_slot
	var before: Dictionary = state.contract
	var r: StringName = state.receive(slot, kind, data)
	if r != LobbyState.OK:
		Log.warn(LOG_CHANNEL, "lobby message %s from slot %d rejected: %s" % [kind, slot, r])
		message_rejected.emit(slot, kind, r)
		return
	if kind == LobbyState.MSG_PROFILE and not state.is_legal(slot):
		Log.warn(LOG_CHANNEL, "slot %d loadout flagged illegal: %s" % [slot, ", ".join(state.errors.get(slot, []) as Array)])
	if kind == LobbyState.MSG_CONTRACT and state.contract != before:
		contract_changed.emit(state.contract)
	changed.emit()
	if kind == LobbyState.MSG_START:
		started.emit(state.started.duplicate())


func _on_session_ended() -> void:
	if not _active:
		return
	_active = false
	_join_left_s = -1.0
	state.reset(false)
	session_left.emit()
	changed.emit()


func _on_host_lost() -> void:
	if _active and not state.is_host:
		_fail(FAIL_HOST_LOST)


func _fail(reason: StringName) -> void:
	_join_left_s = -1.0
	Log.warn(LOG_CHANNEL, "co-op session failed: %s" % reason)
	connection_failed.emit(reason)
	net.call(&"leave")


func _profile() -> PlayerProfile:
	if profile == null:
		profile = PlayerProfile.new_default()
	return profile
