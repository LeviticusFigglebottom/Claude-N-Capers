## AI teammate orders (A3-05, L6.1): who receives a human's order, and the contextual `order_menu`
## mapping used by PlayerInput. Owner: ENV A. Pure static helpers (no state), so every CrewAiBrain
## resolves the same receiver for the same intent on the server, and clients can preview the order.
##
## Receiver resolution (`resolve_receiver`, server):
##   eligible AI = an active CrewAiBrain whose crew is NORMAL / SWAN_SONG (drop_bag: also carrying a bag).
##   follow / hold / drop_bag: `order_target_net_id` names the AI crew member to command when it is
##     an eligible AI; else the eligible AI closest to the human's aim within order_aim_cone_deg and
##     order_range_m (smallest angle); else the eligible AI nearest the human.
##   carry_bag: `order_target_net_id` is the BAG (0 = the free bag nearest `order_position` within
##     bag_search_radius_m); receiver = the AI in the aim cone, else the eligible AI nearest the bag
##     (AI without a task first).
##   revive: `order_target_net_id` is the DOWNED crew member; receiver = the AI in the aim cone (not
##     the downed one), else the eligible AI nearest the downed member (AI without a task first).
##   `order_position` Vector3.ZERO means "here" (hold: the receiver's own spot).
##
## Contextual `order_menu` (T) tap (`contextual_order`), first match by smallest aim angle:
##   aimed AI teammate carrying a bag -> drop_bag (target = that AI)
##   aimed downed crew member         -> revive (target = the downed member)
##   aimed AI teammate                -> toggle: hold (here) <-> follow (target = that AI)
##   aimed free bag                   -> carry_bag (target = the bag)
##   aimed world point in range       -> hold at that point (receiver resolved as above)
##   nothing in range                 -> follow (nearest AI)
class_name CrewOrders
extends RefCounted

const ORDERS: Array[StringName] = [&"follow", &"hold", &"carry_bag", &"drop_bag", &"revive"]
const WORLD_MASK: int = (1 << 0) | (1 << 1)
const CHEST_UP: Vector3 = Vector3(0.0, 1.1, 0.0)
const BAG_UP: Vector3 = Vector3(0.0, 0.3, 0.0)


static func is_order(o: StringName) -> bool:
	return ORDERS.has(o)


## Server: the AI crew member that receives `order` from `human`, or null.
static func resolve_receiver(rt: HeistRuntime, human: CrewController, order: StringName,
		target_net_id: int, position: Vector3, tw: CrewAiTweak) -> CrewController:
	if rt == null or human == null or not is_order(order):
		return null
	var eligible: Array[CrewController] = []
	for c: CrewController in rt.crew_members():
		if c == human or not c.is_ai:
			continue
		var b: CrewAiBrain = CrewAiBrain.of(c)
		if b == null or not b.is_active():
			continue
		if c.crew_state != Enums.CrewState.NORMAL and c.crew_state != Enums.CrewState.SWAN_SONG:
			continue
		if order == &"drop_bag" and not c.is_carrying_bag():
			continue
		eligible.append(c)
	if eligible.is_empty():
		return null
	var target: Node = Ids.lookup(target_net_id) if target_net_id != 0 else null
	if order == &"follow" or order == &"hold" or order == &"drop_bag":
		var named: CrewController = target as CrewController
		if named != null and eligible.has(named):
			return named
		var aimed: CrewController = _aimed_ai(human, eligible, tw)
		return aimed if aimed != null else _nearest(eligible, human.global_position, false)
	var anchor: Node3D = null
	if order == &"carry_bag":
		anchor = target as LootBag
		if anchor == null:
			anchor = nearest_free_bag(rt, position, tw.bag_search_radius_m)
	elif order == &"revive":
		anchor = target as CrewController
		eligible.erase(anchor)
	if anchor == null or eligible.is_empty():
		return null
	var aimed2: CrewController = _aimed_ai(human, eligible, tw)
	return aimed2 if aimed2 != null else _nearest(eligible, anchor.global_position, true)


## The free (not carried, not secured) bag nearest `pos` within `radius` m, or null.
static func nearest_free_bag(rt: HeistRuntime, pos: Vector3, radius: float) -> LootBag:
	var best: LootBag = null
	var best_d: float = radius
	for n: Node in rt.get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b == null or b.secured or b.is_carried() or b.is_queued_for_deletion() or not rt.is_ancestor_of(b):
			continue
		var d: float = b.global_position.distance_to(pos)
		if d <= best_d:
			best = b
			best_d = d
	return best


## Contextual `order_menu` tap for `human` (see the header). `stances` maps an AI net id to the
## last follow/hold order this human gave it (PlayerInput's local memory; default follow).
## Returns {order, target, position}.
static func contextual_order(rt: HeistRuntime, human: CrewController, stances: Dictionary, tw: CrewAiTweak) -> Dictionary:
	var eye: Vector3 = human.eye_position()
	var dir: Vector3 = human.aim_direction().normalized()
	var best: Node3D = null
	var best_a: float = deg_to_rad(tw.order_aim_cone_deg)
	for c: CrewController in rt.crew_members():
		if c == human or c.crew_state == Enums.CrewState.CUSTODY:
			continue
		if not c.is_ai and c.crew_state != Enums.CrewState.DOWNED:
			continue
		var a: float = _aim_angle(human, eye, dir, c.global_position + CHEST_UP, tw.order_range_m)
		if a < best_a:
			best = c
			best_a = a
	for n: Node in rt.get_tree().get_nodes_in_group(G.LOOT_BAG):
		var b: LootBag = n as LootBag
		if b == null or b.secured or b.is_carried() or not rt.is_ancestor_of(b):
			continue
		var a2: float = _aim_angle(human, eye, dir, b.global_position + BAG_UP, tw.order_range_m)
		if a2 < best_a:
			best = b
			best_a = a2
	var crew: CrewController = best as CrewController
	if crew != null:
		if crew.crew_state == Enums.CrewState.DOWNED:
			return _o(&"revive", crew.net_id)
		if crew.is_carrying_bag():
			return _o(&"drop_bag", crew.net_id)
		var held: bool = StringName(stances.get(crew.net_id, &"follow")) == &"hold"
		return _o(&"follow" if held else &"hold", crew.net_id)
	var bag: LootBag = best as LootBag
	if bag != null:
		return _o(&"carry_bag", bag.net_id, bag.global_position)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + dir * tw.order_range_m, WORLD_MASK)
	q.exclude = [human.get_rid()]
	var hit: Dictionary = human.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return _o(&"hold", 0, hit["position"] as Vector3)
	return _o(&"follow", 0)


static func _o(order: StringName, target: int, position: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"order": order, "target": target, "position": position}


## Angle (rad) between the aim and `point`, INF beyond `range_m` or without line of sight.
static func _aim_angle(human: CrewController, eye: Vector3, dir: Vector3, point: Vector3, range_m: float) -> float:
	var to: Vector3 = point - eye
	if to.length() > range_m or to.length() < 0.01:
		return INF
	var a: float = dir.angle_to(to)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, point, WORLD_MASK)
	q.exclude = [human.get_rid()]
	if not human.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return INF
	return a


static func _aimed_ai(human: CrewController, eligible: Array[CrewController], tw: CrewAiTweak) -> CrewController:
	var eye: Vector3 = human.eye_position()
	var dir: Vector3 = human.aim_direction().normalized()
	var best: CrewController = null
	var best_a: float = deg_to_rad(tw.order_aim_cone_deg)
	for c: CrewController in eligible:
		var a: float = _aim_angle(human, eye, dir, c.global_position + CHEST_UP, tw.order_range_m)
		if a < best_a:
			best = c
			best_a = a
	return best


## Nearest crew member of `list` to `pos` (ties: lower slot). `prefer_idle`: AI without a task first.
static func _nearest(list: Array[CrewController], pos: Vector3, prefer_idle: bool) -> CrewController:
	var best: CrewController = null
	var best_key: Vector2 = Vector2(INF, INF)
	for c: CrewController in list:
		var busy: float = 0.0
		if prefer_idle:
			var b: CrewAiBrain = CrewAiBrain.of(c)
			busy = 1.0 if b != null and b.task != &"" else 0.0
		var key: Vector2 = Vector2(busy, c.global_position.distance_to(pos))
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y - 0.001):
			best = c
			best_key = key
	return best
