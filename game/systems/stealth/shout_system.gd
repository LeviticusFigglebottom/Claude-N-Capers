## Crew shout handling (S7.1, S1.1, D-016). Owner: ENV A. Server only.
## A crew tick handler: on the rising edge of `intent.shout` (one shout per `shout_cooldown_s`)
## every civilian
##   - within shout_range_m x `stealth.civilian_intimidate_range_mult` inside the aim cone
##     (shout_cone_deg, full angle) with line of sight, or
##   - within shout_all_within_m in any direction
## receives `CivilianBrain.on_shouted(crew)` (the brain applies the D-016 roll for panicked ones
## and emits civilian_intimidated [R]). Shouting is allowed while casing (S1.1) and is not a
## NoiseEvent (no make_noise).
## S2.9 (A2-05): a shout that affects no civilian marks the markable target (guard, special, camera:
## StealthDirector.mark_kind_of) nearest the aim line within mark_cone_half_deg / mark_range_m with
## line of sight, for the whole crew. Unmasked (casing) crew mark only with `stealth.casing_can_mark`.
## Installation: until HeistRuntime creates it, the first CivilianBrain self-installs it with
## `ShoutSystem.ensure(runtime)` (service SERVICE + crew tick handler).
class_name ShoutSystem
extends Node

signal shouted(slot: int, affected: Array[Node])
## S2.9: a shout marked `target` (A2-05).
signal marked(slot: int, target: Node)

const SERVICE: StringName = &"shout"

## slot -> intent.shout last tick
var _held: Dictionary[int, bool] = {}
## slot -> seconds until the next shout is allowed
var _cooldown: Dictionary[int, float] = {}
var _runtime: HeistRuntime = null


## The runtime's ShoutSystem, created and hooked into the crew tick on first use.
static func ensure(rt: HeistRuntime) -> ShoutSystem:
	if rt == null:
		return null
	var s: ShoutSystem = rt.service(SERVICE) as ShoutSystem
	if s == null:
		s = ShoutSystem.new()
		s.name = "ShoutSystem"
		s._runtime = rt
		rt.register_service(SERVICE, s)
		rt.add_crew_tick_handler(s.tick)
	return s


func tick(crew: CrewController, intent: CrewIntent, delta: float) -> void:
	if not Net.is_authority() or crew == null:
		return
	var slot: int = crew.slot
	var cd: float = maxf(_cooldown.get(slot, 0.0) - delta, 0.0)
	_cooldown[slot] = cd
	var pressed: bool = intent != null and intent.shout
	var rising: bool = pressed and not _held.get(slot, false)
	_held[slot] = pressed
	if not rising or cd > 0.0 or crew.crew_state != Enums.CrewState.NORMAL:
		return
	_cooldown[slot] = Tweak.stealth().shout_cooldown_s
	shout(crew)


## Server: resolve one shout from `crew`. Returns the NPCs that reacted.
func shout(crew: CrewController) -> Array[Node]:
	var affected: Array[Node] = []
	for npc: NpcBase in targets_for(crew):
		var brain: Node = npc.get_node_or_null(^"Brain")
		if brain != null and brain.has_method(&"on_shouted") and bool(brain.call(&"on_shouted", crew)):
			affected.append(npc)
	shouted.emit(crew.slot, affected)
	if affected.is_empty():
		var t: Node3D = mark_target_for(crew)
		var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
		if t != null and rt != null and rt.stealth != null and rt.stealth.mark(t, crew.slot):
			marked.emit(crew.slot, t)
	return affected


## S2.9: the markable target a shout from `crew` would mark now (null when none).
func mark_target_for(crew: CrewController) -> Node3D:
	var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
	if rt == null or rt.stealth == null:
		return null
	if not crew.masked and not Modifiers.flag(crew.slot, &"stealth.casing_can_mark"):
		return null
	var tw: StealthTweak = Tweak.stealth()
	var eye: Vector3 = crew.eye_position()
	var aim: Vector3 = crew.aim_direction()
	var half: float = deg_to_rad(tw.mark_cone_half_deg)
	var cands: Array[Node3D] = []
	for n: Node in rt.npcs():
		cands.append(n as Node3D)
	for cam: SecurityCamera in SecurityCamera.cameras_in(rt):
		cands.append(cam)
	var best: Node3D = null
	var best_ang: float = INF
	for c: Node3D in cands:
		if c == null or StealthDirector.mark_kind_of(c) == &"":
			continue
		var point: Vector3 = _mark_point(c)
		var to: Vector3 = point - eye
		var ang: float = aim.angle_to(to)
		if to.length() > tw.mark_range_m or ang > half or ang >= best_ang:
			continue
		if not _clear_to(crew, eye, point, c):
			continue
		best = c
		best_ang = ang
	return best


## Vision ray from `eye` to `point` hits nothing, or only `target` (its own bodies).
static func _clear_to(crew: CrewController, eye: Vector3, point: Vector3, target: Node3D) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, point, StealthDirector.VISION_MASK)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Node = hit.get("collider") as Node
	return col != null and (col == target or target.is_ancestor_of(col))


static func _mark_point(n: Node3D) -> Vector3:
	if n.has_method(&"eye_position"):
		var npc: NpcBase = n as NpcBase
		return npc.global_position + Vector3(0.0, 1.2, 0.0) if npc != null else n.call(&"eye_position")
	return n.global_position


## Civilians a shout from `crew` reaches right now (before the D-016 roll).
func targets_for(crew: CrewController) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
	if rt == null:
		return out
	var tw: StealthTweak = Tweak.stealth()
	var range_m: float = tw.shout_range_m * Modifiers.mult(crew.slot, &"stealth.civilian_intimidate_range_mult")
	var half_cone: float = deg_to_rad(tw.shout_cone_deg) * 0.5
	var eye: Vector3 = crew.eye_position()
	var aim: Vector3 = crew.aim_direction()
	var st: StealthDirector = rt.stealth
	for n: Node in rt.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		if npc == null:
			continue
		var point: Vector3 = _aim_point(npc)
		var flat: float = Vector2(npc.global_position.x - crew.global_position.x,
				npc.global_position.z - crew.global_position.z).length()
		if flat <= tw.shout_all_within_m:
			out.append(npc)
			continue
		var to: Vector3 = point - eye
		if to.length() > range_m or aim.angle_to(to) > half_cone:
			continue
		if st != null and st.is_inside_tree() and not st.has_los(eye, point, [crew.get_rid(), npc.get_rid()]):
			continue
		out.append(npc)
	return out


static func _aim_point(npc: NpcBase) -> Vector3:
	var brain: Node = npc.get_node_or_null(^"Brain")
	if brain != null and brain.has_method(&"shout_target_point"):
		return brain.call(&"shout_target_point")
	return npc.global_position + Vector3(0.0, 1.0, 0.0)
