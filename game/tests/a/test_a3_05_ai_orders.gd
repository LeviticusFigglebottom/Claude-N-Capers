## A3-05 AI teammate orders (L6.1, D-014 P4 option): a human's CrewIntent order is routed on the
## server to one AI (CrewOrders.resolve_receiver): hold / follow / carry_bag / drop_bag / revive, the
## stealth follow option, the contextual order_menu mapping and the acknowledgement voice line.
extends TestCase

const TIME_SCALE: float = 3.0

var _rt: HeistRuntime = null
var _lines: Array[StringName] = []


func before_each() -> void:
	_lines.clear()
	EventBus.voice_line_requested.connect(_on_line)


func after_each() -> void:
	Engine.time_scale = 1.0
	if EventBus.voice_line_requested.is_connected(_on_line):
		EventBus.voice_line_requested.disconnect(_on_line)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _on_line(speaker: StringName, line: StringName, _ctx: Dictionary) -> void:
	if speaker == &"crew_ai":
		_lines.append(line)


func _launch_unit() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _brain(slot: int) -> CrewAiBrain:
	return CrewAiBrain.of(_crew(slot))


func _go_loud() -> void:
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)


## The human (slot 0, bot-driven) issues `o` for a few ticks (routed once), then stands still.
func _order(o: StringName, target: int = 0, pos: Vector3 = Vector3.ZERO) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = _crew(0).look_yaw
	i.look_pitch = _crew(0).look_pitch
	i.order = o
	i.order_target_net_id = target
	i.order_position = pos
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(3)
	var idle: CrewIntent = CrewIntent.new()
	idle.look_yaw = i.look_yaw
	idle.look_pitch = i.look_pitch
	_rt.set_bot_intent(0, idle)
	await wait_physics_frames(2)


func _walk_human(seconds: float) -> void:
	var walk: CrewIntent = CrewIntent.new()
	walk.look_yaw = 0.0  # -Z
	walk.move = Vector2(0.0, 1.0)
	_rt.set_bot_intent(0, walk)
	await wait_seconds(seconds)
	_rt.set_bot_intent(0, CrewIntent.new())


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_a3_05_hold_stays_put_then_follow_resumes() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	var ai: CrewController = _crew(1)
	var start: Vector3 = ai.global_position
	await _order(&"hold", ai.net_id)
	assert_eq(_brain(1).stance, &"hold", "slot 1 holds")
	assert_eq(_brain(2).stance, &"follow", "only the named AI received the order")
	assert_has(_lines, &"vo.crew.ack_hold", "acknowledged")
	await _walk_human(5.0)
	var human: CrewController = _crew(0)
	assert_true(_flat(human.global_position, start) > 10.0, "the human walked away")
	await wait_seconds(2.0)
	assert_true(_flat(ai.global_position, start) < 1.0, "the holding AI stayed put (%.2f m)" % _flat(ai.global_position, start))
	assert_eq(_brain(1).mode, CrewAiBrain.Mode.HOLD)
	assert_true(_flat(_crew(2).global_position, human.global_position) <= _brain(2).tweak.follow_max_m + 0.5,
		"a non-holding AI followed")
	await _order(&"follow", ai.net_id)
	assert_has(_lines, &"vo.crew.ack_follow")
	var tw: CrewAiTweak = _brain(1).tweak
	var ok: bool = await wait_until(func() -> bool:
		return _flat(ai.global_position, human.global_position) <= tw.follow_max_m + 0.5, 10.0)
	assert_true(ok, "follow resumes: the AI caught up with the human")
	assert_eq(_brain(1).mode, CrewAiBrain.Mode.FOLLOW)


func test_a3_05_hold_at_order_position() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	var spot: Vector3 = Vector3(-4.0, 0.05, 6.0)
	await _order(&"hold", _crew(2).net_id, spot)
	var ok: bool = await wait_until(func() -> bool: return _flat(_crew(2).global_position, spot) <= 0.8, 8.0)
	assert_true(ok, "the AI walked to the ordered hold point")


func test_a3_05_carry_bag_and_drop_bag() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag_pos: Vector3 = Vector3(-6.0, 0.3, 4.0)
	var bag: LootBag = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, bag_pos))
	await wait_physics_frames(2)
	# No bag id: the free bag nearest the aim point.
	await _order(&"carry_bag", 0, bag.global_position)
	assert_has(_lines, &"vo.crew.ack_carry_bag")
	var ok: bool = await wait_until(func() -> bool: return bag.is_carried(), 10.0)
	assert_true(ok, "an AI walked to the bag and picked it up")
	var carrier: CrewController = bag.carrier
	assert_true(carrier != null and carrier.is_ai, "carried by an AI")
	if carrier == null:
		return
	await _order(&"drop_bag", 0)
	assert_has(_lines, &"vo.crew.ack_drop_bag")
	ok = await wait_until(func() -> bool: return not carrier.is_carrying_bag(), 2.0)
	assert_true(ok, "drop_bag: the AI dropped the bag")
	assert_false(bag.is_carried(), "the bag is on the ground")
	await wait_seconds(1.0)
	assert_false(bag.is_carried(), "and the AI does not pick it up again")
	assert_eq(CrewAiBrain.of(carrier).task, &"", "carry task cleared")


func test_a3_05_drop_bag_without_bag_is_refused() -> void:
	await _launch_unit()
	await _go_loud()
	assert_false(_brain(1).receive_order(&"drop_bag"), "nothing to drop")
	assert_false(_lines.has(&"vo.crew.ack_drop_bag"), "no acknowledgement")


func test_a3_05_carry_bag_secured_at_dev_sandbox_van() -> void:
	_rt = await HeistLauncher.launch(&"dev_sandbox", 42, Enums.Difficulty.ROUTINE, self)
	await wait_physics_frames(2)
	Engine.time_scale = TIME_SCALE
	for role: StringName in [&"guard", &"civilian"]:
		for n: Node in _rt.npcs(role):
			(n as NpcBase).die({}, 0)
	await _go_loud()
	var secured: Array[int] = []
	var on_sec: Callable = func(id: int, _l: StringName, _v: int) -> void: secured.append(id)
	EventBus.loot_secured.connect(on_sec)
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, Vector3(8.0, 0.3, 4.0)))
	var bag_id: int = bag.net_id
	await wait_physics_frames(2)
	await _order(&"carry_bag", bag_id)
	var ok: bool = await wait_until(func() -> bool: return is_instance_valid(bag) and bag.is_carried(), 12.0)
	assert_true(ok, "an AI picked the ordered bag up")
	# The human walks over to the van; the carrier follows and secures the bag there.
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(12.0, 0.1, 11.0)))
	ok = await wait_until(func() -> bool: return secured.has(bag_id), 25.0)
	EventBus.loot_secured.disconnect(on_sec)
	assert_true(ok, "the AI secured the bag at the van (SECURE_LOOT)")


func test_a3_05_revive_order_targets_specific_downed() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	var revived: Array[int] = []
	var cb: Callable = func(slot: int, _by: int) -> void: revived.append(slot)
	EventBus.crew_revived.connect(cb)
	_crew(2).health.go_down()
	_crew(3).health.go_down()
	await wait_physics_frames(2)
	assert_true(_brain(1).revive_target == _crew(2), "automatic assignment: lower slot first")
	await _order(&"revive", _crew(3).net_id)
	assert_has(_lines, &"vo.crew.ack_revive")
	assert_true(_brain(1).revive_target == _crew(3), "the ordered AI goes to slot 3")
	var ok: bool = await wait_until(func() -> bool: return not revived.is_empty(), 20.0)
	EventBus.crew_revived.disconnect(cb)
	assert_true(ok, "a revive completed")
	if ok:
		assert_eq(revived[0], 3, "the ordered target was revived first")


func test_a3_05_revive_order_refused_for_standing_crew() -> void:
	await _launch_unit()
	await _go_loud()
	assert_false(_brain(1).receive_order(&"revive", _crew(2).net_id), "slot 2 is not downed")


func test_a3_05_hold_limits_auto_revive_radius() -> void:
	await _launch_unit()
	await _go_loud()
	for s: int in [1, 2]:
		assert_true(_brain(s).receive_order(&"hold"), "slot %d holds" % s)
	_rt.teleport_crew(3, Transform3D(Basis.IDENTITY, Vector3(10.0, 0.05, -10.0)))
	await wait_physics_frames(2)
	_crew(3).health.go_down()
	await wait_physics_frames(2)
	assert_true(_brain(1).revive_target == null and _brain(2).revive_target == null,
		"holding AI ignore a downed crew member far from their hold point")
	_rt.teleport_crew(3, Transform3D(Basis.IDENTITY, Vector3(-8.0, 0.05, 7.0)))
	await wait_physics_frames(2)
	assert_true(_brain(1).revive_target == _crew(3) or _brain(2).revive_target == _crew(3),
		"but revive one within hold_revive_radius_m")


func test_a3_05_stealth_follow_makes_ai_detectable() -> void:
	await _launch_unit()
	var ai: CrewController = _crew(1)
	assert_true(ai.stealth_hidden, "waiting at the van: hidden")
	await _order(&"follow", ai.net_id)
	assert_false(_rt.went_loud)
	assert_true(_brain(1).stealth_engaged, "D-014 P4 option: ordered out of the van")
	assert_false(ai.stealth_hidden, "a following AI is detectable like a player")
	assert_true(_crew(2).stealth_hidden and _crew(3).stealth_hidden, "the others keep waiting hidden")
	assert_has(_lines, &"vo.crew.ack_follow")
	Engine.time_scale = TIME_SCALE
	var p0: Vector3 = ai.global_position
	await _walk_human(4.0)
	await wait_seconds(2.0)
	assert_true(_flat(ai.global_position, p0) > 3.0, "it follows the human in stealth")
	assert_true(_crew(2).global_position.distance_to(Vector3(-8.0, 0.05, 10.0)) < 0.2, "slot 2 did not move")
	Engine.time_scale = 1.0
	# Seen by a guard like a player (masked, in view).
	ai.set_masked()
	_rt.teleport_crew(1, Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), Vector3(0, 0.05, -6)))
	await _order(&"hold", ai.net_id)
	assert_eq(_brain(1).stance, &"hold")
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3.ZERO, Vector3.FORWARD)
	var seen: bool = await wait_until(func() -> bool: return _rt.detection_value(g, 1) > 0.0, 2.0)
	assert_true(seen, "a guard detects the ordered AI")
	assert_false(ai.stealth_hidden, "still detectable while holding in stealth")


func test_a3_05_stealth_follow_disabled_keeps_ai_hidden() -> void:
	await _launch_unit()
	var b: CrewAiBrain = _brain(1)
	b.tweak = b.tweak.duplicate() as CrewAiTweak
	b.tweak.stealth_follow_enabled = false
	await _order(&"follow", _crew(1).net_id)
	assert_false(b.stealth_engaged, "flag off: the order is ignored in stealth")
	assert_true(_crew(1).stealth_hidden, "still hidden at the van")
	assert_eq(b.mode, CrewAiBrain.Mode.STEALTH_WAIT)
	assert_false(_lines.has(&"vo.crew.ack_follow"), "no acknowledgement")


func test_a3_05_receiver_resolution() -> void:
	await _launch_unit()
	await _go_loud()
	var human: CrewController = _crew(0)
	var tw: CrewAiTweak = _brain(1).tweak
	# Named AI wins.
	assert_true(CrewOrders.resolve_receiver(_rt, human, &"hold", _crew(3).net_id, Vector3.ZERO, tw) == _crew(3))
	# Aimed AI: put slot 2 straight ahead of the human (facing -Z).
	_rt.teleport_crew(2, Transform3D(Basis.IDENTITY, human.global_position + Vector3(0, 0, -6)))
	await wait_physics_frames(2)
	assert_true(CrewOrders.resolve_receiver(_rt, human, &"follow", 0, Vector3.ZERO, tw) == _crew(2), "aimed AI")
	# Nothing aimed: nearest AI to the human.
	_rt.teleport_crew(2, Transform3D(Basis.IDENTITY, Vector3(10, 0.05, -10)))
	await wait_physics_frames(2)
	assert_true(CrewOrders.resolve_receiver(_rt, human, &"follow", 0, Vector3.ZERO, tw) == _crew(1), "nearest AI")
	# Revive: nearest AI to the downed member (never the downed one itself).
	_crew(3).health.go_down()
	await wait_physics_frames(1)
	_rt.teleport_crew(3, Transform3D(Basis.IDENTITY, Vector3(9, 0.05, -9)))
	await wait_physics_frames(1)
	assert_true(CrewOrders.resolve_receiver(_rt, human, &"revive", _crew(3).net_id, Vector3.ZERO, tw) == _crew(2),
		"revive: nearest AI to the downed member")
	assert_true(CrewOrders.resolve_receiver(_rt, human, &"drop_bag", 0, Vector3.ZERO, tw) == null,
		"drop_bag: nobody carries a bag")
	assert_true(CrewOrders.resolve_receiver(_rt, human, &"dance", 0, Vector3.ZERO, tw) == null, "unknown order")


func test_a3_05_contextual_order_mapping() -> void:
	await _launch_unit()
	await _go_loud()
	var human: CrewController = _crew(0)
	var tw: CrewAiTweak = _brain(1).tweak
	var look: CrewIntent = CrewIntent.new()
	_rt.set_bot_intent(0, look)
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, human.global_position + Vector3(0, 0, -6)))
	_rt.teleport_crew(2, Transform3D(Basis.IDENTITY, Vector3(10, 0.05, -10)))
	_rt.teleport_crew(3, Transform3D(Basis.IDENTITY, Vector3(12, 0.05, -10)))
	for s: int in [1, 2, 3]:
		_brain(s).receive_order(&"hold")  # keep them where the test puts them
	await wait_physics_frames(2)
	var o: Dictionary = CrewOrders.contextual_order(_rt, human, {}, tw)
	assert_eq(o["order"], &"hold", "aimed AI -> hold")
	assert_eq(o["target"], _crew(1).net_id)
	o = CrewOrders.contextual_order(_rt, human, {_crew(1).net_id: &"hold"}, tw)
	assert_eq(o["order"], &"follow", "aimed holding AI -> follow (toggle)")
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, Vector3(-10, 0.3, 7)))
	await wait_physics_frames(1)
	loot.carry(bag, _crew(1))
	await wait_physics_frames(1)
	o = CrewOrders.contextual_order(_rt, human, {}, tw)
	assert_eq(o["order"], &"drop_bag", "aimed AI carrying a bag -> drop_bag")
	loot.drop_bag(_crew(1), false)
	_crew(1).health.go_down()
	await wait_physics_frames(2)
	o = CrewOrders.contextual_order(_rt, human, {}, tw)
	assert_eq(o["order"], &"revive", "aimed downed crew -> revive")
	assert_eq(o["target"], _crew(1).net_id)
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(14, 0.05, -10)))
	await wait_physics_frames(3)
	# Look down at the bag (dropped ~0.7 m in front of slot 1's old spot).
	var to: Vector3 = bag.global_position + CrewOrders.BAG_UP - human.eye_position()
	look.look_yaw = atan2(-to.x, -to.z)
	look.look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await wait_physics_frames(2)
	o = CrewOrders.contextual_order(_rt, human, {}, tw)
	assert_eq(o["order"], &"carry_bag", "aimed bag -> carry_bag")
	assert_eq(o["target"], bag.net_id)
	# Aim at the floor away from everything -> hold there; at the sky -> follow.
	look.look_yaw = PI * 0.5
	look.look_pitch = -0.6
	await wait_physics_frames(2)
	o = CrewOrders.contextual_order(_rt, human, {}, tw)
	assert_eq(o["order"], &"hold", "aimed point -> hold there")
	assert_eq(o["target"], 0)
	assert_true((o["position"] as Vector3).y < 0.1, "the hit point on the floor")
	look.look_pitch = 1.2
	await wait_physics_frames(2)
	o = CrewOrders.contextual_order(_rt, human, {}, tw)
	assert_eq(o["order"], &"follow", "nothing aimed -> follow")
