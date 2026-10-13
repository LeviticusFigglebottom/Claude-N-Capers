## Host's drop-in request dialog (B6-04, PD2 drop-in). Owner: ENV B.
## "<name> (level, Notoriety badge) wants to join" with Accept / Deny and an auto-deny countdown
## (LobbyTweak.dropin_request_timeout_s). Requests queue up; answering one shows the next.
## Binds to any drop-in service by duck typing (bind(); signal join_requested(peer_id, summary), method
## answer_join(peer_id, accept); see DropInService). With `auto_find`, it looks the service up in
## DropInService.GROUP until one appears (ENV A's service is created with the heist).
## In the heist (`pause_gameplay`): while a request shows, the local crew member's input is paused
## (CrewInput holder &"dropin") and the mouse released, so the host can answer; both come back after.
## Player text (name) is shown as plain Label text.
## Policy (B6-04, D-072): before a request is shown, decision() asks `gate` (LobbySession.join_decision: the
## session kick list, then LobbyState.dropin_policy; without a gate the local `policy`): a kicked player is
## denied with DropInService.REASON_KICKED, policy `off` denies with REASON_OFF, `auto` accepts, all without a
## dialog; only `ask` shows the request. A timeout denies with REASON_TIMEOUT, Deny with REASON_DENIED.
## With ENV A's HeistDropIn (MenuFlow's heist dialog) there is no gate and `policy` stays ask: A already applied
## its own checks and the policy and emits join_requested only for `ask`, so A alone decides (DropInFlow).
class_name JoinRequestDialog
extends PanelContainer

## `auto` = answered without the host pressing a button (policy, kick list or timeout); last_reason says why.
signal answered(peer_id: int, accepted: bool, auto: bool)

const PAUSE_HOLDER: StringName = &"dropin"
const FIND_INTERVAL_S: float = 0.5
const MIN_SIZE: Vector2 = Vector2(640, 0)

## The drop-in service (duck-typed), or null.
var service: Object = null
var tweak: LobbyTweak = null
## Heist overlay: pause local input + show the mouse while a request is open.
var pause_gameplay: bool = false
## Look the service up in DropInService.GROUP while `service` is null.
var auto_find: bool = false
## Local crew slot for the input pause (MenuFlow passes Net.local_slot()).
var local_slot: int = -1
## Anything with join_decision(peer_id, summary) -> StringName (MenuFlow passes its LobbySession), or null.
var gate: Object = null
## Drop-in policy used without a gate (LobbyState.POLICY_*).
var policy: StringName = LobbyState.POLICY_ASK
## Reason of the last deny (&"" after an accept).
var last_reason: StringName = &""
var title_label: Label
var body_label: Label
var badge_label: Label
var timer_label: Label
var more_label: Label
var accept_button: Button
var deny_button: Button
## {"peer_id": int, "summary": Dictionary}, the shown request first.
var queue: Array[Dictionary] = []
## Seconds until the shown request is auto-denied.
var time_left: float = 0.0
var _find_left: float = 0.0


func _ready() -> void:
	if tweak == null:
		tweak = LobbyTweak.load_default()
	custom_minimum_size = MIN_SIZE
	var v: VBoxContainer = UiBuild.vbox(8)
	add_child(v)
	title_label = UiBuild.label(&"ui.dropin.request.title", UiBuild.SUBHEADER)
	body_label = UiBuild.label(&"")
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge_label = UiBuild.label(&"", UiBuild.DIM)
	timer_label = UiBuild.label(&"", UiBuild.DIM)
	more_label = UiBuild.label(&"", UiBuild.DIM)
	for l: Label in [title_label, body_label, badge_label, timer_label, more_label]:
		v.add_child(l)
	var row: HBoxContainer = UiBuild.hbox(16)
	accept_button = UiBuild.primary(UiBuild.button(&"ui.dropin.accept"))
	deny_button = UiBuild.button(&"ui.dropin.deny")
	for b: Button in [accept_button, deny_button]:
		b.custom_minimum_size = Vector2(240, 0)
		row.add_child(b)
	accept_button.pressed.connect(accept)
	deny_button.pressed.connect(deny)
	UiNav.chain_horizontal([accept_button, deny_button] as Array[Control])
	v.add_child(row)
	visible = false
	if service != null:
		bind(service)


## Bind to a drop-in service (its join_requested queues requests here; its join_failed for a queued peer, e.g.
## the joiner cancelled or left, drops that request without an answer).
func bind(p_service: Object) -> void:
	if service != null and service != p_service:
		_connect_service(false)
	service = p_service
	if service != null:
		_connect_service(true)


## A request from the service: answered at once unless decision() is JOIN_ASK, then queued (a peer already
## queued is ignored).
func show_request(peer_id: int, summary: Dictionary) -> void:
	var d: StringName = decision(peer_id, summary)
	if d != LobbyState.JOIN_ASK:
		_reply(peer_id, d == LobbyState.JOIN_ACCEPT, d, true)
		return
	for r: Dictionary in queue:
		if int(r["peer_id"]) == peer_id:
			return
	queue.append({"peer_id": peer_id, "summary": summary.duplicate(true)})
	if queue.size() == 1:
		_show_current()
	else:
		_refresh_more()


## Peer id of the request on screen (-1 = none).
func current_peer() -> int:
	return int(queue[0]["peer_id"]) if not queue.is_empty() else -1


func accept() -> void:
	_answer(true, DropInService.REASON_DENIED, false)


func deny() -> void:
	_answer(false, DropInService.REASON_DENIED, false)


## LobbyState.JOIN_ASK / JOIN_ACCEPT or a deny reason for a request: the gate's join_decision, else `policy`.
func decision(peer_id: int, summary: Dictionary) -> StringName:
	if gate != null and gate.has_method(&"join_decision"):
		return StringName(gate.call(&"join_decision", peer_id, summary))
	match policy:
		LobbyState.POLICY_OFF:
			return DropInService.REASON_OFF
		LobbyState.POLICY_AUTO:
			return LobbyState.JOIN_ACCEPT
	return LobbyState.JOIN_ASK


## "<name> (<level text>) wants to join." for a request summary (plain text; name cleaned and cut).
static func request_text(summary: Dictionary, tw: LobbyTweak = null) -> String:
	var t: LobbyTweak = tw if tw != null else LobbyTweak.load_default()
	var player: String = ChatLog.clean_text(String(summary.get("name", "")), t.max_name_length) \
			if summary.get("name") is String else ""
	if player == "":
		player = UiText.t(&"ui.dropin.unknown_player")
	# `level` first: the name is inserted last, so text inside it is never treated as a placeholder.
	var level: int = _int(summary, "level", 0, SkillPoints.tree_def().max_level)
	return UiText.t(&"ui.dropin.request.body", {"level": NotorietyScreen.level_text(level, _rank(summary)), "name": player})


static func _rank(summary: Dictionary) -> int:
	return _int(summary, "notoriety", 0, Notoriety.max_rank())


static func _int(summary: Dictionary, key: String, lo: int, hi: int) -> int:
	var v: Variant = summary.get(key, 0)
	return clampi(int(v), lo, hi) if v is int or v is float else 0


func _connect_service(on: bool) -> void:
	for pair: Array in [[&"join_requested", show_request], [&"join_failed", _on_service_failed]]:
		if not service.has_signal(pair[0]):
			continue
		if on and not service.is_connected(pair[0], pair[1]):
			service.connect(pair[0], pair[1])
		elif not on and service.is_connected(pair[0], pair[1]):
			service.disconnect(pair[0], pair[1])


## The service ended a request on its own (cancelled, peer gone): forget it; the next one shows.
func _on_service_failed(peer_id: int, _reason: StringName) -> void:
	for i: int in range(queue.size()):
		if int(queue[i]["peer_id"]) != peer_id:
			continue
		queue.remove_at(i)
		if i == 0:
			_show_current()
		else:
			_refresh_more()
		return


func _answer(accepted: bool, reason: StringName, auto: bool) -> void:
	if queue.is_empty():
		return
	var r: Dictionary = queue.pop_front()
	_reply(int(r["peer_id"]), accepted, reason, auto)
	_show_current()


## Tell the service (a deny carries `reason` when its answer_join takes a third argument).
func _reply(peer: int, accepted: bool, reason: StringName, auto: bool) -> void:
	last_reason = &"" if accepted else reason
	if service != null and service.has_method(&"answer_join"):
		if not accepted and service.get_method_argument_count(&"answer_join") >= 3:
			service.call(&"answer_join", peer, false, reason)
		else:
			service.call(&"answer_join", peer, accepted)
	answered.emit(peer, accepted, auto)


func _show_current() -> void:
	var showing: bool = not queue.is_empty()
	if showing:
		var s: Dictionary = queue[0]["summary"] as Dictionary
		body_label.text = request_text(s, tweak)
		badge_label.text = NotorietyScreen.badge_text(_rank(s))
		time_left = tweak.dropin_request_timeout_s
		_refresh_timer()
		_refresh_more()
	if showing != visible:
		visible = showing
		_set_paused(showing)
	if showing and is_inside_tree():
		accept_button.grab_focus.call_deferred()


func _refresh_timer() -> void:
	timer_label.text = UiText.t(&"ui.dropin.request.auto_deny", {"seconds": ceili(maxf(time_left, 0.0))})


func _refresh_more() -> void:
	more_label.text = UiText.t(&"ui.dropin.request.more", {"count": queue.size() - 1}) if queue.size() > 1 else ""


func _set_paused(on: bool) -> void:
	if not pause_gameplay:
		return
	CrewInput.set_paused(get_tree(), PAUSE_HOLDER, on, local_slot)
	# input_focus.md 1.1: the cursor through MouseCapture only.
	if on:
		MouseCapture.push_release(&"dropin")
	else:
		MouseCapture.pop_release(&"dropin")


func _process(delta: float) -> void:
	if service == null and auto_find:
		_find_left -= delta
		if _find_left <= 0.0:
			_find_left = FIND_INTERVAL_S
			var found: Node = DropInService.find(get_tree())
			if found != null:
				bind(found)
	if queue.is_empty():
		return
	time_left -= delta
	_refresh_timer()
	if time_left <= 0.0:
		_answer(false, DropInService.REASON_TIMEOUT, true)


func _exit_tree() -> void:
	if visible:
		_set_paused(false)
