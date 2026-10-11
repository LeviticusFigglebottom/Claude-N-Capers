## Drop-in service interface (B6-04, PD2 drop-in: a player joins a heist that is already running). Owner: ENV B
## (interface + UI); ENV A owns the real implementation (QB to A). Until it lands, B's UI runs on
## MockDropInService (lobby/mock/).
##
## The UI never needs this class: it finds the service in group GROUP (`drop_in_service`; find()) or gets it
## passed, and binds by duck typing (has_signal / has_method). A's service may extend this class or just
## provide the same signals and methods.
##
## Host side (authority):
## * signal join_requested(peer_id, summary): a peer asks to drop in. `summary` = LobbyState.summary_from()
##   shape ({"name", "level", "notoriety", "loadout", ...}); the host UI shows it (JoinRequestDialog).
## * answer_join(peer_id, accept): the host's decision (also sent on the dialog's auto-deny timeout).
## * kick(slot) -> bool: remove the human in crew slot `slot` (KickConfirmDialog); false when refused.
## Joining client:
## * request_join(summary): ask the host, with the loadout picked on DropInJoinScreen.
## * cancel_join(): give up (join_failed(.., REASON_CANCELLED) follows).
## Both sides:
## * signal join_progress(peer_id, frac): the joiner's load progress 0..1 (the client sees its own).
## * signal joined(slot): the joiner took crew slot `slot` (host: the new crew member; client: its own slot).
## * signal join_failed(peer_id, reason): REASON_* below.
## * signal kicked(slot): crew slot `slot` was removed by the host.
class_name DropInService
extends Node

signal join_requested(peer_id: int, summary: Dictionary)
signal join_progress(peer_id: int, frac: float)
signal joined(slot: int)
signal join_failed(peer_id: int, reason: StringName)
signal kicked(slot: int)

## Scene-tree group the UI looks the service up in (ask the lead for G.DROP_IN_SERVICE, contracts/groups.md).
const GROUP: StringName = &"drop_in_service"
const REASON_DENIED: StringName = &"denied"
const REASON_TIMEOUT: StringName = &"timeout"
const REASON_FULL: StringName = &"full"
const REASON_CANCELLED: StringName = &"cancelled"
const REASON_HOST_LOST: StringName = &"host_lost"
const REASONS: Array[StringName] = [REASON_DENIED, REASON_TIMEOUT, REASON_FULL, REASON_CANCELLED, REASON_HOST_LOST]
const LOG_CHANNEL: StringName = &"dropin"


func _enter_tree() -> void:
	add_to_group(GROUP)


## Host: accept or deny a pending join request.
func answer_join(peer_id: int, accept: bool) -> void:
	Log.warn(LOG_CHANNEL, "answer_join(%d, %s): no drop-in service implementation" % [peer_id, accept])


## Host: remove the human in `slot`. False when refused / not implemented.
func kick(slot: int) -> bool:
	Log.warn(LOG_CHANNEL, "kick(%d): no drop-in service implementation" % slot)
	return false


## Client: ask the host to drop in with `summary` (LobbyState.summary_from).
func request_join(summary: Dictionary) -> void:
	Log.warn(LOG_CHANNEL, "request_join(%s): no drop-in service implementation" % summary.get("name", ""))


## Client: cancel a pending request / load.
func cancel_join() -> void:
	Log.warn(LOG_CHANNEL, "cancel_join: no drop-in service implementation")


## The first node in GROUP (A's service or a mock), or null.
static func find(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP)
