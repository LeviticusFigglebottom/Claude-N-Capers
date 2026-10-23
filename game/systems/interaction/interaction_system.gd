## Server-side hold-interaction sessions, one per crew slot (S9.1). Owner: ENV A.
## CrewController calls `tick()` every physics tick on the authority. Progress is server state;
## clients read it through LocalHudModel (replicated per crew member).
## Events: interaction_started / cancelled / completed [R] (events.md).
class_name InteractionSystem
extends Node

signal session_changed(slot: int)

## C4-03: a LOCAL system (the safehouse crew's HubInteraction): no server behind it, so it runs its own sessions on
## any peer, also on a client connected to a session (Net.is_authority() false). Heist systems leave it false.
var local: bool = false


## slot -> { "comp": InteractableComponent, "progress": float, "duration": float,
##           "start_pos": Vector3, "aimed": bool }
var _sessions: Dictionary[int, Dictionary] = {}
## slot -> true once an interaction completed or was refused: the crew must release first.
var _needs_release: Dictionary[int, bool] = {}
## slot -> last blocked reason (HUD).
var _blocked: Dictionary[int, StringName] = {}
## Client mirror (A3-07): slot -> [owner_net_id, component name, progress 0..1, blocked reason].
var _remote: Dictionary[int, Array] = {}


func tick(crew: CrewController, intent: CrewIntent, delta: float) -> void:
	if not _authority():
		return
	var slot: int = crew.slot
	if intent == null or not intent.interact:
		_needs_release.erase(slot)
		_blocked.erase(slot)
		if _sessions.has(slot):
			cancel(slot)
		return
	if _sessions.has(slot):
		_advance(crew, delta)
		return
	if _needs_release.get(slot, false):
		return
	var comp: InteractableComponent = resolve_target(crew, intent)
	if comp == null:
		return
	var reason: StringName = comp.availability(crew)
	if reason == InteractableComponent.BLOCK_NONE and not comp.allow_multiple and is_busy(comp, slot):
		reason = InteractableComponent.BLOCK_BUSY
	if reason != InteractableComponent.BLOCK_NONE:
		_blocked[slot] = reason
		_needs_release[slot] = true
		session_changed.emit(slot)
		return
	_start(crew, comp, intent.interact_target_net_id == 0)


## Target for `crew`: explicit net_id (bots/AI) or aim (2 m ray + 10° assist cone).
func resolve_target(crew: CrewController, intent: CrewIntent) -> InteractableComponent:
	if intent.interact_target_net_id != 0:
		return best_component_on(Ids.lookup(intent.interact_target_net_id), crew)
	return aimed_component(crew)


## Highest-priority available component on `target` (or the first one if none is available).
func best_component_on(target: Node, crew: CrewController) -> InteractableComponent:
	if target == null:
		return null
	var comps: Array[InteractableComponent] = components_of(target)
	var best: InteractableComponent = null
	var fallback: InteractableComponent = null
	var reach: float = Tweak.interaction().explicit_reach_m
	for c: InteractableComponent in comps:
		if crew != null and crew.eye_position().distance_to(c.global_position) > reach + 1.0:
			if crew.global_position.distance_to(c.global_position) > reach + 1.0:
				continue
		if fallback == null or c.priority > fallback.priority:
			fallback = c
		if c.availability(crew) == InteractableComponent.BLOCK_NONE:
			if best == null or c.priority > best.priority:
				best = c
	return best if best != null else fallback


static func components_of(target: Node) -> Array[InteractableComponent]:
	var out: Array[InteractableComponent] = []
	for ch: Node in target.get_children():
		var c: InteractableComponent = ch as InteractableComponent
		if c != null:
			out.append(c)
	return out


## Aim resolution (crew_intent.md): nearest-angle component within reach and the assist cone, with LOS.
func aimed_component(crew: CrewController) -> InteractableComponent:
	var tw: InteractionTweak = Tweak.interaction()
	var eye: Vector3 = crew.eye_position()
	var fwd: Vector3 = crew.aim_direction()
	var best: InteractableComponent = null
	var best_score: float = INF
	var cone: float = deg_to_rad(tw.assist_cone_deg)
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not c.is_visible_in_tree() or (c.aim_filter.is_valid() and not c.aim_filter.call(crew)):
			continue
		var to: Vector3 = c.global_position - eye
		var d: float = to.length()
		if d - c.aim_radius_m > tw.reach_m + 0.35 or d < 0.001:
			continue
		var ang: float = fwd.angle_to(to)
		# Close targets get a wider effective cone (the object fills more of the view); PO6-20 aim_radius_m
		# widens it to the whole extent (a pager body is answerable from anywhere around it).
		var eff_cone: float = maxf(cone, atan2(0.3 + c.aim_radius_m, d))
		if ang > eff_cone:
			continue
		var score: float = ang + d * 0.05
		if c.aim_radius_m > 0.0:  # PO6-20: anywhere inside the extent counts as dead-on
			score = maxf(ang - atan2(c.aim_radius_m, d), 0.0) + d * 0.05
		if score < best_score and _has_los(crew, eye, c):
			best = c
			best_score = score
	return best


func is_busy(comp: InteractableComponent, except_slot: int) -> bool:
	for s: int in _sessions:
		if s != except_slot and _sessions[s]["comp"] == comp:
			return true
	return false


## Slots currently holding `comp` (pager juggling, S5.4).
func holders_of(comp: InteractableComponent) -> Array[int]:
	var out: Array[int] = []
	for s: int in _sessions:
		if _sessions[s]["comp"] == comp:
			out.append(s)
	return out


## Active session of `slot` ({} = none). On a client: the replicated mirror
## {"comp", "progress" (0..1), "duration": 1.0, "remote": true} (A3-07).
func session(slot: int) -> Dictionary:
	if not _authority():
		return _remote_session(slot)
	return _sessions.get(slot, {})


func blocked_reason(slot: int) -> StringName:
	if not _authority():
		return StringName((_remote[slot] as Array)[3]) if _remote.has(slot) else &""
	return _blocked.get(slot, &"")


## Progress 0..1 of slot's active interaction (0 if none).
func progress(slot: int) -> float:
	if not _authority():
		return float((_remote[slot] as Array)[2]) if _remote.has(slot) and int((_remote[slot] as Array)[0]) != 0 else 0.0
	if not _sessions.has(slot):
		return 0.0
	var s: Dictionary = _sessions[slot]
	var dur: float = s["duration"]
	return 1.0 if dur <= 0.0 else clampf(float(s["progress"]) / dur, 0.0, 1.0)


## Server (A3-07): per-slot session state for clients' HUD models:
## {slot: [owner_net_id (0 = none), component node name, progress 0..1, blocked reason]}.
func net_sessions() -> Dictionary:
	var out: Dictionary = {}
	for slot: int in _sessions:
		var comp: InteractableComponent = _sessions[slot]["comp"]
		if is_instance_valid(comp):
			out[slot] = [comp.owner_net_id(), String(comp.name), snappedf(progress(slot), 0.001), _blocked.get(slot, &"")]
	for slot: int in _blocked:
		if not out.has(slot):
			out[slot] = [0, "", 0.0, _blocked[slot]]
	return out


## Client (A3-07): replace the mirror with the server's net_sessions().
func apply_net_sessions(d: Dictionary) -> void:
	var changed: Array[int] = []
	for k: Variant in d:
		changed.append(int(k))
	for slot: int in _remote:
		if not changed.has(slot):
			changed.append(slot)
	_remote.clear()
	for k: Variant in d:
		_remote[int(k)] = d[k] as Array
	for slot: int in changed:
		session_changed.emit(slot)


func _remote_session(slot: int) -> Dictionary:
	if not _remote.has(slot):
		return {}
	var a: Array = _remote[slot]
	var owner: Node = Ids.lookup(int(a[0]))
	if owner == null:
		return {}
	var comp: InteractableComponent = owner.get_node_or_null(NodePath(String(a[1]))) as InteractableComponent
	if comp == null:
		comp = owner.find_child(String(a[1]), true, false) as InteractableComponent
	if comp == null:
		return {}
	return {"comp": comp, "progress": float(a[2]), "duration": 1.0, "remote": true}


## Cancel slot's interaction (release, movement, damage S9.1, state change).
func cancel(slot: int) -> void:
	if not _sessions.has(slot):
		return
	var s: Dictionary = _sessions[slot]
	_sessions.erase(slot)
	var comp: InteractableComponent = s["comp"]
	var crew: Node = s.get("crew")
	if is_instance_valid(comp):
		comp.cancelled.emit(crew)
		_emit(&"interaction_cancelled", [comp.owner_net_id(), slot])
	else:  # PO6-07: the object was freed mid-hold; the fact still stops its hold cues
		_emit(&"interaction_cancelled", [int(s.get("owner_id", 0)), slot])
	session_changed.emit(slot)


## D-134 addendum (S9.1 amended, PD2 playerdamage.lua damage_bullet never interrupts; interupt_interact only on a
## state change): taking damage cancels NO held interaction, for any kind, humans and bots. Kept as the hook CrewHealth
## calls; it does nothing (the old "no interrupt on damage" skill modifier is retired with it).
func interrupt_on_damage(_slot: int) -> void:
	pass


## A stun / flash (PO6-17b) interrupts any hold interaction, a revive included (D-134 ◇: PD2 has no such rule).
func interrupt_on_stun(slot: int) -> void:
	cancel(slot)


## Cancel every session on `comp` (e.g. the object was destroyed or disabled).
func cancel_all_on(comp: InteractableComponent) -> void:
	for s: int in holders_of(comp):
		cancel(s)


func _start(crew: CrewController, comp: InteractableComponent, aimed: bool) -> void:
	var slot: int = crew.slot
	var dur: float = comp.duration_for(crew)
	_sessions[slot] = {
		"comp": comp, "crew": crew, "progress": 0.0, "duration": dur,
		"start_pos": crew.global_position, "aimed": aimed, "owner_id": comp.owner_net_id(),
	}
	_blocked.erase(slot)
	comp.started.emit(crew)
	_emit(&"interaction_started", [comp.owner_net_id(), slot, comp.kind])
	if comp.noise != &"silent":
		var radius: float = float(Tweak.interaction().noise_profiles.get(comp.noise, 0.0))
		var rt: HeistRuntime = HeistRuntime.of(self)
		if rt != null and radius > 0.0:
			rt.make_noise(comp.global_position, radius, comp.noise, comp.owner_net_id())
	session_changed.emit(slot)
	if dur <= 0.0:
		_complete(slot)


func _advance(crew: CrewController, delta: float) -> void:
	var slot: int = crew.slot
	var s: Dictionary = _sessions[slot]
	var comp: InteractableComponent = s["comp"]
	var tw: InteractionTweak = Tweak.interaction()
	if not is_instance_valid(comp) or comp.availability(crew) != InteractableComponent.BLOCK_NONE:
		cancel(slot)
		_needs_release[slot] = true
		return
	var start_pos: Vector3 = s["start_pos"]
	if crew.global_position.distance_to(start_pos) > tw.cancel_move_m:
		cancel(slot)
		_needs_release[slot] = true
		return
	if bool(s["aimed"]):
		var to: Vector3 = comp.global_position - crew.eye_position()
		if crew.aim_direction().angle_to(to) > deg_to_rad(tw.cancel_look_deg):
			cancel(slot)
			_needs_release[slot] = true
			return
	s["progress"] = float(s["progress"]) + delta
	if float(s["progress"]) >= float(s["duration"]):
		_complete(slot)


func _complete(slot: int) -> void:
	var s: Dictionary = _sessions[slot]
	_sessions.erase(slot)
	_needs_release[slot] = true
	var comp: InteractableComponent = s["comp"]
	var crew: CrewController = s["crew"]
	if comp.consumes_item and comp.requires_item != &"":
		crew.remove_item(comp.requires_item, 1)
	var owner_id: int = comp.owner_net_id()
	var kind: StringName = comp.kind
	comp.completed.emit(crew)
	_emit(&"interaction_completed", [owner_id, slot, kind])
	session_changed.emit(slot)


func _has_los(crew: CrewController, eye: Vector3, comp: InteractableComponent) -> bool:
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, comp.global_position, 1)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Node = hit.get("collider")
	var owner: Node = comp.owner_node()
	return col != null and owner != null and (col == owner or owner.is_ancestor_of(col) or _container_hit(col, owner))


## PO6-05: the hit belongs to the prefab that holds the target (an open safe's body around the loot
## inside it), so it does not block the target. Closed safes hide their contents, so this never reaches
## through a shut door.
static func _container_hit(col: Node, owner: Node) -> bool:
	var n: Node = col
	while n != null:
		if n is GameplayPrefab:
			return n.is_ancestor_of(owner)
		n = n.get_parent()
	return false


func _emit(sig: StringName, args: Array) -> void:
	EventBus.emit_signal.callv([sig] + args)
	if not local:
		Net.replicate_event(sig, args)  # a local (hub) interaction is this peer's own


func _authority() -> bool:
	return local or Net.is_authority()
