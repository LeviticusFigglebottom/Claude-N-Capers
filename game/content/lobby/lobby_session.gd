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
## Chat (B6-03): send_chat() -> LobbyState.MSG_CHAT over Net.lobby_send; every accepted message emits
## chat_received (not `changed`). Net.lobby_send is the Net autoload's RPC, so it keeps working while a heist
## runs on the same session (MenuFlow keeps this node alive until Net.leave()): the in-heist chat uses it too.
## Kick (B6-04, D-072): kick(slot) -> Net.kick(peer_id) (host only). Net.peer_kicked (also for Net's own re-kick
## of a kicked name, or a kick from ENV A's drop-in service) puts the player on the session kick list
## (LobbyState.kicked) and sends LobbyState.MSG_KICK as a notice to the crew (kick_notice on every peer). The
## kicked client sees connection_failed(FAIL_KICKED) from Net.last_disconnect_reason == &"kicked" (set before
## host_lost). The host re-kicks any kicked peer id / profile name that comes back (crew change or profile
## summary), and join_decision() auto-denies its drop-in requests (DropInService.REASON_KICKED).
## Drop-in policy (B6-04): set_drop_in_policy() -> LobbyState.MSG_SETTINGS (host only, re-sent on crew changes).
class_name LobbySession
extends Node

signal changed()
signal contract_changed(contract: Dictionary)
## The host's MSG_START was accepted: {"heist": StringName, "difficulty", "is_pro", "last_breath", "seed"}.
signal started(info: Dictionary)
## A join could not connect (unreachable), never got a crew slot (timeout), or the host went away.
signal connection_failed(reason: StringName)
## The session ended (local Leave, or Net.leave() from anywhere).
signal session_left()
signal message_rejected(from_slot: int, kind: StringName, reason: StringName)
## A chat message was accepted (LobbyState.chat entry: id, slot, name, text, time).
signal chat_received(entry: Dictionary)
## The host kicked the human in `slot` (LobbyState.MSG_KICK notice; `player_name` as the crew knew them).
signal kick_notice(slot: int, player_name: String)

const FAIL_TIMEOUT: StringName = &"timeout"
const FAIL_HOST_LOST: StringName = &"host_lost"
const FAIL_UNREACHABLE: StringName = &"unreachable"
## The host kicked this peer (Net.last_disconnect_reason, D-072). UI text `ui.lobby.error.kicked`.
const FAIL_KICKED: StringName = &"kicked"
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
## Host: peers Net.kick was called for (no second kick while the drop is pending).
var _kick_pending: Dictionary = {}


func _ready() -> void:
	if net == null:
		net = get_node(^"/root/Net")
	if tweak == null:
		tweak = LobbyTweak.load_default()
	net.connect(&"crew_changed", _on_crew_changed)
	net.connect(&"lobby_message", _on_lobby_message)
	net.connect(&"session_ended", _on_session_ended)
	net.connect(&"connection_failed", _on_unreachable)  # D-052
	net.connect(&"host_lost", _on_host_lost)
	if net.has_signal(&"peer_kicked"):
		net.connect(&"peer_kicked", _on_peer_kicked)


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
	state.dropin_policy = _remembered_policy()  # lead ruling: the host's preference starts each session
	_kick_pending.clear()
	net.call(&"fill_with_ai")  # empty seats show as Crew AI; a joining peer takes an AI seat (Net)
	_on_crew_changed()
	return OK


func join(address: String, port: int) -> Error:
	var p: PlayerProfile = _profile()
	var err: Error = net.call(&"join", address, port, p.profile_name if p.profile_name != "" else "Player") as Error
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


## Send a chat line from the local slot. Returns LobbyState.OK (sent) or why not: R_BAD_SENDER (no
## session / no slot yet), R_EMPTY (nothing printable), R_RATE_LIMITED (this peer would reject it too).
func send_chat(text: String) -> StringName:
	if not _active or state.local_slot < 0:
		return LobbyState.R_BAD_SENDER
	var clean: String = ChatLog.clean_text(text, state.chat.max_length)
	if clean == "":
		return LobbyState.R_EMPTY
	if not state.chat.can_send(state.local_slot, now()):
		return LobbyState.R_RATE_LIMITED
	net.call(&"lobby_send", LobbyState.MSG_CHAT, ChatLog.message(clean))
	return LobbyState.OK


## Chat history so far (oldest first; copies).
func chat_history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in state.chat.entries:
		out.append(e.duplicate())
	return out


## Host: kick the human in `slot` with Net.kick (D-072); Net.peer_kicked then adds it to the kick list and
## notifies the crew. The lobby half of the DropInService kick(slot) interface (KickConfirmDialog calls it).
## False when not allowed (not the host, the host's own slot, an AI / empty seat) or when Net refuses.
func kick(slot: int) -> bool:
	if not _active or not state.is_host or slot == state.host_slot or not state.is_human(slot):
		return false
	return _net_kick(int((state.crew[slot] as Dictionary).get("peer_id", 0)))


## Host: set the lobby's drop-in policy (LobbyState.POLICY_ASK / AUTO / OFF). False for a client or a bad value.
func set_drop_in_policy(policy: StringName) -> bool:
	if not _active or not state.is_host or not LobbyState.POLICIES.has(policy):
		return false
	net.call(&"lobby_send", LobbyState.MSG_SETTINGS, LobbyState.settings_data(policy))
	var gs: GameSettings = GameSettings.current()
	if gs.dropin_policy() != policy:  # remember the host's choice for the next session
		gs.set_value(GameSettings.GAMEPLAY, &"dropin_policy", String(policy))
		gs.save()
	return true


## The host's remembered drop-in policy (GameSettings gameplay/dropin_policy), else the data default.
static func _remembered_policy() -> StringName:
	var p: StringName = GameSettings.current().dropin_policy()
	return p if LobbyState.POLICIES.has(p) else LobbyState.default_policy()


## Host: how to answer a join / drop-in request (LobbyState.join_decision: kick list, then the drop-in policy).
## JoinRequestDialog asks this before it shows a request.
func join_decision(peer_id: int, summary: Dictionary) -> StringName:
	return state.join_decision(peer_id, summary)


## Session clock for the chat rate limit (seconds since start-up).
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Host: set the lobby's contract (from the host's Board or planning table).
func set_contract(heist_id: StringName, difficulty: int, is_pro: bool, last_breath: bool = false) -> bool:
	if not _active or not state.is_host:
		return false
	net.call(&"lobby_send", LobbyState.MSG_CONTRACT, LobbyState.contract_data(heist_id, difficulty, is_pro, last_breath))
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
	_rekick_crew()
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
	if state.is_host:
		set_drop_in_policy(state.dropin_policy)
	if state.is_host and not state.contract.is_empty():
		var c: Dictionary = state.contract
		set_contract(c["heist"], int(c["difficulty"]), bool(c["is_pro"]), bool(c.get("last_breath", false)))


func _on_lobby_message(from_peer: int, kind: StringName, data: Dictionary) -> void:
	if not _active or not LobbyState.KINDS.has(kind):
		return
	var slot: int = int(net.call(&"slot_of_peer", from_peer))
	if slot < 0 and from_peer == int(net.call(&"local_peer_id")):
		slot = state.local_slot
	if state.kicked.has(from_peer) or _rekick_summary(from_peer, kind, data):
		return  # a kicked peer's last messages (until Net drops it) are ignored
	var before: Dictionary = state.contract
	var kick_name: String = _kick_target_name(kind, data)
	state.now_s = now()
	var r: StringName = state.receive(slot, kind, data)
	if r != LobbyState.OK:
		Log.warn(LOG_CHANNEL, "lobby message %s from slot %d rejected: %s" % [kind, slot, r])
		message_rejected.emit(slot, kind, r)
		return
	if kind == LobbyState.MSG_CHAT:
		chat_received.emit(state.chat.last())
		return
	if kind == LobbyState.MSG_KICK:
		kick_notice.emit(int(data["slot"]), kick_name)
		changed.emit()
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


func _on_unreachable() -> void:
	if _active and not state.is_host:
		_fail(FAIL_UNREACHABLE, false)  # Net leaves by itself


func _on_host_lost() -> void:
	if _active and not state.is_host:
		var why: Variant = net.get(&"last_disconnect_reason")
		_fail(FAIL_KICKED if why != null and StringName(why) == FAIL_KICKED else FAIL_HOST_LOST, false)


## Net.peer_kicked (host): kick list + the crew notice. Covers kick(), Net's re-kick and other callers.
func _on_peer_kicked(peer_id: int, slot: int) -> void:
	if not _active or not state.is_host:
		return
	_kick_pending[peer_id] = true
	state.kicked.add(peer_id, "")
	if state.is_human(slot) and int((state.crew[slot] as Dictionary).get("peer_id", 0)) == peer_id:
		net.call(&"lobby_send", LobbyState.MSG_KICK, {"slot": slot})  # every peer: remember_kick + kick_notice
	changed.emit()


func _net_kick(peer_id: int) -> bool:
	if peer_id <= 0 or _kick_pending.has(peer_id):
		return false
	return bool(net.call(&"kick", peer_id))


## Host: a crew member whose peer id or Net display name is on the kick list is kicked again.
func _rekick_crew() -> void:
	if not state.is_host:
		return
	for slot: int in state.human_slots():
		var c: Dictionary = state.crew[slot] as Dictionary
		var peer: int = int(c.get("peer_id", 0))
		if slot != state.host_slot and state.kicked.has(peer, String(c.get("display_name", ""))):
			_net_kick(peer)


## Host: a profile summary under a kicked profile name re-kicks its sender. True = drop the message.
func _rekick_summary(from_peer: int, kind: StringName, data: Dictionary) -> bool:
	if not state.is_host or kind != LobbyState.MSG_PROFILE or from_peer == int(net.call(&"local_peer_id")):
		return false
	var player: Variant = data.get("name")
	if not (player is String) or not state.kicked.has(0, String(player)):
		return false
	_net_kick(from_peer)
	return true


## The name of a MSG_KICK target, read before the message is applied ("" for other kinds).
func _kick_target_name(kind: StringName, data: Dictionary) -> String:
	var target: Variant = data.get("slot")
	if kind != LobbyState.MSG_KICK or not (target is int or target is float):
		return ""
	return String(state.slot_view(int(target))["name"])


func _fail(reason: StringName, leave_net: bool = true) -> void:
	_join_left_s = -1.0
	Log.warn(LOG_CHANNEL, "co-op session failed: %s" % reason)
	connection_failed.emit(reason)
	if leave_net:
		net.call(&"leave")


func _profile() -> PlayerProfile:
	if profile == null:
		profile = PlayerProfile.new_default()
	return profile
