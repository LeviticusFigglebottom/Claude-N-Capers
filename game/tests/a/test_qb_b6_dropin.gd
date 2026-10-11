## QB-B6-DROPIN: HeistDropIn (B's DropInService) on the host, driven in-process with a fake joining peer in an
## AI slot: policy ask / auto / off, summary validation, accept turns the slot's AI crew member into the peer's
## (loadout, name, no CrewAiBrain), a kicked name is auto-denied, a human leaving turns back into an AI
## teammate; the drop-in bring-up is addressed to its peer. Client: a denial answer fails the join.
extends TestCase

const PEER: int = 99

var _rt: HeistRuntime = null
var _svc: HeistDropIn = null
var _saved_crew: Dictionary = {}


func after_each() -> void:
	if _svc != null and is_instance_valid(_svc):
		_svc.policy = HeistDropIn.POLICY_ASK
		_svc.pending.clear()
		_svc._kicked.clear()
		_svc.joining = false
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 6301, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "skip_casing": true})
	await wait_physics_frames(2)
	_svc = DropInService.find(get_tree()) as HeistDropIn
	# Net gave the joining peer the AI slot 1 (Net._on_peer_connected).
	Net.crew[1] = {"peer_id": PEER, "is_ai": false, "display_name": "Player %d" % PEER}


func _summary(name: String = "Joiner") -> Dictionary:
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.corsair_ar"
	l.secondary = &"weapon.kestrel_p9"
	return {"name": name, "level": 10, "notoriety": 0, "loadout": LobbyState.loadout_to_dict(l)}


func _request(summary: Dictionary) -> void:
	_svc._on_lobby_message(PEER, HeistDropIn.KIND_REQUEST, {"summary": summary})


func test_ask_then_accept_takes_the_ai_slot() -> void:
	await _launch()
	assert_true(_svc != null and _svc.is_in_group(G.DROP_IN_SERVICE), "service in G.DROP_IN_SERVICE")
	var asked: Array = []
	_svc.join_requested.connect(func(p: int, s: Dictionary) -> void: asked.append([p, s]))
	var joined_ev: Array = []
	var cb: Callable = func(slot: int, pid: int, ai: bool) -> void: joined_ev.append([slot, pid, ai])
	EventBus.crew_member_joined.connect(cb)
	var bring: Array[Dictionary] = []
	var on_msg: Callable = func(_f: int, kind: StringName, d: Dictionary) -> void:
		if kind == HeistLauncher.BRING_UP_KIND:
			bring.append(d)
	Net.lobby_message.connect(on_msg)
	_request(_summary())
	assert_eq(asked.size(), 1, "ask: join_requested(peer, summary)")
	assert_true(_svc.pending.has(PEER), "pending")
	_svc.answer_join(PEER, true, &"")
	Net.lobby_message.disconnect(on_msg)
	EventBus.crew_member_joined.disconnect(cb)
	var c: CrewController = _rt.crew_controller(1) as CrewController
	assert_false(c.is_ai, "the AI crew member is the peer's now")
	assert_eq(c.peer_id, PEER)
	assert_eq(c.display_name, "Joiner")
	assert_true(c.get_node_or_null(CrewAiBrain.NODE_NAME) == null, "no AI brain")
	assert_eq(c.loadout.primary, &"weapon.corsair_ar", "the summary's loadout")
	assert_eq(joined_ev, [[1, PEER, false]], "crew_member_joined [R]")
	assert_eq(bring.size(), 1, "a drop-in bring-up")
	if bring.size() == 1:
		assert_eq(int(bring[0]["for_peer"]), PEER, "addressed to the joiner")
		assert_true((bring[0]["snapshot"] as Dictionary).has("spawns"), "full snapshot")
		assert_false(HeistLauncher.for_me(bring[0]), "other peers ignore it")
	assert_true(HeistLauncher.for_me({}), "a normal bring-up is for everyone")
	var prog: Array = []
	_svc.joined.connect(func(slot: int) -> void: prog.append(slot))
	_svc._on_lobby_message(PEER, HeistDropIn.KIND_PROGRESS, {"frac": 1.0})
	assert_eq(prog, [1], "joined(slot) once the joiner reports its replica")


func test_policies_validation_and_kicked() -> void:
	await _launch()
	var failed: Array = []
	_svc.join_failed.connect(func(p: int, r: StringName) -> void: failed.append([p, r]))
	var bad: Dictionary = _summary()
	bad["level"] = -5
	_request(bad)
	assert_eq(failed.back(), [PEER, DropInService.REASON_DENIED], "invalid summary: denied")
	_svc.policy = HeistDropIn.POLICY_OFF
	_request(_summary())
	assert_eq(failed.back(), [PEER, DropInService.REASON_OFF], "policy off")
	_svc.policy = HeistDropIn.POLICY_ASK
	_svc._kicked["Joiner"] = true
	_request(_summary())
	assert_eq(failed.back(), [PEER, DropInService.REASON_KICKED], "kicked this session: auto-denied")
	_svc._kicked.clear()
	Net.crew[1] = {"peer_id": Net.AI_PEER, "is_ai": true, "display_name": "AI 1"}
	_request(_summary())
	assert_eq(failed.back(), [PEER, DropInService.REASON_FULL], "no slot for the peer: full")
	Net.crew[1] = {"peer_id": PEER, "is_ai": false, "display_name": "Player %d" % PEER}
	_svc.policy = HeistDropIn.POLICY_AUTO
	_request(_summary())
	assert_false((_rt.crew_controller(1) as CrewController).is_ai, "auto: accepted at once")


func test_drop_out_returns_the_slot_to_ai() -> void:
	await _launch()
	_svc.policy = HeistDropIn.POLICY_AUTO
	_request(_summary())
	var c: CrewController = _rt.crew_controller(1) as CrewController
	assert_false(c.is_ai)
	var left: Array[int] = []
	var cb: Callable = func(slot: int) -> void: left.append(slot)
	EventBus.crew_member_left.connect(cb)
	Net.crew[1] = {"peer_id": Net.AI_PEER, "is_ai": true, "display_name": "AI 1"}  # Net._on_peer_disconnected
	Net.crew_changed.emit()
	EventBus.crew_member_left.disconnect(cb)
	assert_true(c.is_ai and c.peer_id == Net.AI_PEER, "an AI teammate again")
	assert_true(c.get_node_or_null(CrewAiBrain.NODE_NAME) != null, "with its brain")
	assert_eq(left, [1] as Array[int], "crew_member_left [R]")
	assert_false(_svc.kick(1), "kick: not a human slot any more")


func test_client_denial_fails_the_join() -> void:
	await _launch()
	var failed: Array = []
	_svc.join_failed.connect(func(p: int, r: StringName) -> void: failed.append(r))
	_svc.joining = true
	_svc._on_answer({"to": Net.local_peer_id(), "accept": false, "reason": "full"})
	assert_eq(failed, [DropInService.REASON_FULL], "join_failed(reason) on the client")
	assert_false(_svc.joining)
