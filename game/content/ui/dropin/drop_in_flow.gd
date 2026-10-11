## Drop-in wiring between B's UI and ENV A's HeistDropIn (B6-04, PD2 drop-in). Owner: ENV B.
## MenuFlow keeps one of these (`MenuFlow.drop_in`); it holds the drop-in logic so MenuFlow stays under the
## gdlint public-method cap.
## Host: apply_host_policy(tree, policy) copies the lobby's drop-in policy into A's service when MenuFlow
## launches a co-op heist. A's HeistDropIn then decides every request (running heist, crew slot, kicked,
## LobbyState.validate_summary, then `policy`); it emits join_requested only for `ask`, and B's JoinRequestDialog
## only shows those (no B gate in the heist), so exactly one side (A) decides.
## Joining client: open(address, port) builds a DropInJoinScreen whose service is THIS node (it acts as the
## DropInService for the screen by duck typing; it is not in G.DROP_IN_SERVICE). Flow, as A's header asks:
##   loadout picked -> request_join(summary) -> `lobby.join(address, port)` (Net.join) -> on the lobby Net's
##   connected_to_host: `service_provider` (default HeistDropIn.ensure(tree)) -> its request_join(summary).
## A's join_progress / joined(slot) / join_failed(peer, reason) are passed on to the screen. A's service runs
## HeistLauncher.launch_client itself, so MenuFlow only switches to its in-heist UI on joined (heist_info()).
## A failure before the request (unreachable, no slot in time, host lost, kicked: LobbySession.connection_failed)
## or any join_failed ends the attempt; the lobby session is left (Net.leave) and last_failure keeps the reason.
class_name DropInFlow
extends Node

signal join_progress(peer_id: int, frac: float)
signal joined(slot: int)
signal join_failed(peer_id: int, reason: StringName)

enum Phase { IDLE, CONNECTING, REQUESTED, DONE }

const JOIN_SCENE: PackedScene = preload("res://content/ui/dropin/drop_in_join_screen.tscn")
## LobbySession.connection_failed reason -> DropInService reason.
const LOBBY_FAIL_REASONS: Dictionary = {
	LobbySession.FAIL_UNREACHABLE: DropInService.REASON_UNREACHABLE,
	LobbySession.FAIL_TIMEOUT: DropInService.REASON_TIMEOUT,
	LobbySession.FAIL_HOST_LOST: DropInService.REASON_HOST_LOST,
	LobbySession.FAIL_KICKED: DropInService.REASON_KICKED,
}

## The co-op session the join runs on (MenuFlow's; its `net` is the Net autoload in the game).
var lobby: LobbySession = null
## Returns the drop-in service to ask once connected (default: ENV A's HeistDropIn.ensure(tree)). Tests: a mock.
var service_provider: Callable = Callable()
## The service asked (set on connect), or null.
var service: Object = null
var phase: Phase = Phase.IDLE
var address: String = ""
var port: int = 0
## Why the last attempt failed (&"" = none / joined).
var last_failure: StringName = &""
var _summary: Dictionary = {}


## Host: copy the lobby's drop-in policy into A's service (created here if the heist has not made it yet).
static func apply_host_policy(tree: SceneTree, policy: StringName) -> void:
	HeistDropIn.ensure(tree).policy = policy if LobbyState.POLICIES.has(policy) else LobbyState.POLICY_ASK


## Client: a DropInJoinScreen for `p_address`:`p_port` bound to this node (not added to the tree).
func open(p_address: String, p_port: int, p: PlayerProfile, profile_slot: int) -> DropInJoinScreen:
	_reset()
	address = p_address
	port = p_port
	var screen: DropInJoinScreen = JOIN_SCENE.instantiate() as DropInJoinScreen
	screen.profile_slot = profile_slot
	screen.setup(self, p)
	return screen


## DropInJoinScreen: the loadout was picked. Connects (lobby.join), then asks the service on connected_to_host.
func request_join(summary: Dictionary) -> void:
	if phase != Phase.IDLE or lobby == null:
		return
	phase = Phase.CONNECTING
	_summary = summary.duplicate(true)
	lobby.loadout = LobbyState.loadout_from_dict(_summary.get("loadout", {}) as Dictionary)  # the lobby advertises it too
	_connect_lobby(true)
	var err: Error = lobby.join(address, port) if not lobby.is_active() else ERR_ALREADY_IN_USE
	if err != OK:
		_fail.call_deferred(DropInService.REASON_UNREACHABLE)  # after the screen switched to its progress view


## DropInJoinScreen Cancel: while connecting, give up here; once asked, the service's cancel_join (its
## join_failed(cancelled) ends the attempt).
func cancel_join() -> void:
	match phase:
		Phase.CONNECTING:
			_fail(DropInService.REASON_CANCELLED)
		Phase.REQUESTED:
			if service != null and service.has_method(&"cancel_join"):
				service.call(&"cancel_join")
			if phase == Phase.REQUESTED:  # a service that did not answer with join_failed
				_fail(DropInService.REASON_CANCELLED)


## True while connecting or waiting for the host / the bring-up.
func is_joining() -> bool:
	return phase == Phase.CONNECTING or phase == Phase.REQUESTED


## What MenuFlow needs to enter the running heist: {"heist", "difficulty", "is_pro", "runtime"} from the replica
## (HeistRuntime.current()) and the lobby's contract (is_pro; heist / difficulty when there is no replica).
func heist_info() -> Dictionary:
	var c: Dictionary = lobby.state.contract if lobby != null else {}
	var rt: HeistRuntime = HeistRuntime.current()
	var info: Dictionary = {"heist": StringName(c.get("heist", &"")), "difficulty": int(c.get("difficulty", 0)),
		"is_pro": bool(c.get("is_pro", false)), "runtime": rt}
	if rt != null:
		info["heist"] = rt.heist_id
		info["difficulty"] = rt.difficulty
	return info


func _reset() -> void:
	_bind_service(false)
	_connect_lobby(false)
	service = null
	phase = Phase.IDLE
	last_failure = &""
	_summary = {}


func _connect_lobby(on: bool) -> void:
	if lobby == null:
		return
	var pairs: Array = [[lobby.connection_failed, _on_lobby_failed]]
	if lobby.net != null and lobby.net.has_signal(&"connected_to_host"):
		pairs.append([Signal(lobby.net, &"connected_to_host"), _on_connected])
	for pair: Array in pairs:
		var s: Signal = pair[0]
		if on and not s.is_connected(pair[1]):
			s.connect(pair[1])
		elif not on and s.is_connected(pair[1]):
			s.disconnect(pair[1])


func _bind_service(on: bool) -> void:
	if service == null:
		return
	var pairs: Array = [[&"join_progress", _on_progress], [&"joined", _on_joined], [&"join_failed", _on_failed]]
	for pair: Array in pairs:
		if not service.has_signal(pair[0]):
			continue
		if on and not service.is_connected(pair[0], pair[1]):
			service.connect(pair[0], pair[1])
		elif not on and service.is_connected(pair[0], pair[1]):
			service.disconnect(pair[0], pair[1])


## Net.connected_to_host (the lobby's Net): A's header order: ensure the service, then request_join.
func _on_connected() -> void:
	if phase != Phase.CONNECTING:
		return
	phase = Phase.REQUESTED
	service = service_provider.call() if service_provider.is_valid() else HeistDropIn.ensure(get_tree())
	if service == null or not service.has_method(&"request_join"):
		_fail(DropInService.REASON_DENIED)
		return
	_bind_service(true)
	service.call(&"request_join", _summary)


func _on_progress(peer_id: int, frac: float) -> void:
	if phase == Phase.REQUESTED:
		join_progress.emit(peer_id, frac)


func _on_joined(slot: int) -> void:
	if phase != Phase.REQUESTED:
		return
	phase = Phase.DONE
	_bind_service(false)
	_connect_lobby(false)
	joined.emit(slot)


func _on_failed(_peer_id: int, reason: StringName) -> void:
	if is_joining():
		_fail(reason)


func _on_lobby_failed(reason: StringName) -> void:
	if is_joining():
		_fail(StringName(LOBBY_FAIL_REASONS.get(reason, DropInService.REASON_HOST_LOST)))


## End the attempt: tell the screen, then leave the session (A's client side does not call Net.leave).
func _fail(reason: StringName) -> void:
	if not is_joining():
		return
	phase = Phase.DONE
	last_failure = reason
	_bind_service(false)
	_connect_lobby(false)
	var peer: int = int(lobby.net.call(&"local_peer_id")) if lobby != null and lobby.net != null else 0
	join_failed.emit(peer, reason)
	if lobby != null and lobby.is_active():
		lobby.leave()
