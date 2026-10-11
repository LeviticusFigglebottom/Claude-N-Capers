## B-side mock of the drop-in service (B6-04) until ENV A's lands. Owner: ENV B. Implements the DropInService
## interface and records what the UI did; tests and dev scenes drive the other side.
## * Host side: simulate_request(peer_id, summary) emits join_requested; answer_join() records the answer and
##   emits join_progress(peer, 0) on accept or join_failed(peer, REASON_DENIED) on deny; kick() records the slot.
## * Client side: request_join() records the summary and starts a fake load; advance(delta) (or _process
##   when `auto_progress`) emits join_progress until 1.0, then joined(assign_slot); deny_local() / cancel_join()
##   emit join_failed for the local peer.
class_name MockDropInService
extends DropInService

## {"peer_id": int, "accept": bool} per answer_join() call.
var answers: Array[Dictionary] = []
## Slots passed to kick().
var kicks: Array[int] = []
## Host side: peer_id -> summary of requests not answered yet.
var pending: Dictionary = {}
## Client side: the summary of the last request_join() ({} = none).
var requested: Dictionary = {}
## Peer id the client side reports for itself, and the slot it is given.
var local_peer: int = 2
var assign_slot: int = 1
## Client side fake load speed (fraction per second) and whether _process drives it.
var progress_per_s: float = 0.5
var auto_progress: bool = false
var joining: bool = false
var frac: float = 0.0


func simulate_request(peer_id: int, summary: Dictionary) -> void:
	pending[peer_id] = summary.duplicate(true)
	join_requested.emit(peer_id, summary)


func answer_join(peer_id: int, accept: bool) -> void:
	answers.append({"peer_id": peer_id, "accept": accept})
	pending.erase(peer_id)
	if accept:
		join_progress.emit(peer_id, 0.0)
	else:
		join_failed.emit(peer_id, REASON_DENIED)


func kick(slot: int) -> bool:
	kicks.append(slot)
	kicked.emit(slot)
	return true


func request_join(summary: Dictionary) -> void:
	requested = summary.duplicate(true)
	joining = true
	frac = 0.0


func cancel_join() -> void:
	if not joining:
		return
	joining = false
	join_failed.emit(local_peer, REASON_CANCELLED)


## Client side: the host said no (or timed out, was full...).
func deny_local(reason: StringName = REASON_DENIED) -> void:
	joining = false
	join_failed.emit(local_peer, reason)


## Client side: fake load progress; joined(assign_slot) at 1.0.
func advance(delta: float) -> void:
	if not joining:
		return
	frac = minf(frac + progress_per_s * delta, 1.0)
	join_progress.emit(local_peer, frac)
	if frac >= 1.0:
		joining = false
		joined.emit(assign_slot)


func _process(delta: float) -> void:
	if auto_progress:
		advance(delta)
