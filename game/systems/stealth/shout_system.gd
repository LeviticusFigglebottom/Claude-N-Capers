## Crew shout handling (S7.1, S1.1, D-016). Owner: ENV A. Server only.
## A crew tick handler: on the rising edge of `intent.shout` (one shout per `shout_cooldown_s`)
## every civilian
##   - within shout_range_m x `stealth.civilian_intimidate_range_mult` inside the aim cone
##     (shout_cone_deg, full angle) with line of sight, or
##   - within shout_all_within_m in any direction, on the shouter's floor (|dy| <= shout_floor_dy_m) and
##     able to hear it: clear line of sight, or a navmesh path <= shout_all_within_m x shout_path_mult
##     (PO-5: walls and floors block the all-round shout; PD2 intimidates who can hear/see you)
## receives `CivilianBrain.on_shouted(crew)` (the brain applies the D-016 roll for panicked ones
## and emits civilian_intimidated [R]). Shouting is allowed while casing (S1.1) and is not a
## NoiseEvent (no make_noise), but PO-11 (S1.1): an unmasked (casing or civilian-mode) crew member's
## shout never reaches a civilian (PD2: civilians ignore you until you mask up); it can only mark.
## S2.9 (A2-05): a shout that affects no civilian marks the markable target (guard, special, camera:
## StealthDirector.mark_kind_of) nearest the aim line within mark_cone_half_deg / mark_range_m with
## line of sight, for the whole crew. Unmasked (casing) crew mark only with `stealth.casing_can_mark`.
## QB-61: `ability.shout_range_mult` scales the civilian shout range and the mark range (guards,
## specials, cameras) as well as the police surrender range (PoliceSurrender.shout_target).
## L5.1 (A3-04): the shout also addresses the police NPC nearest the aim line
## (PoliceSurrender.shout_target), which may surrender (PoliceSurrender.on_shouted); a cop that
## reacts counts as affected (no marking).
## Installation: until HeistRuntime creates it, the first CivilianBrain self-installs it with
## `ShoutSystem.ensure(runtime)` (service SERVICE + crew tick handler).
class_name ShoutSystem
extends Node

signal shouted(slot: int, affected: Array[Node])
## S2.9: a shout marked `target` (A2-05).
signal marked(slot: int, target: Node)

const SERVICE: StringName = &"shout"
## B6 stealth.noise_intimidates_civilians: the civilian shout range x this ◇.
const NOISE_INTIMIDATE_RANGE_MULT: float = 1.5

## slot -> intent.shout last tick
var _held: Dictionary[int, bool] = {}
## slot -> seconds until the next shout is allowed
var _cooldown: Dictionary[int, float] = {}
## B1 ability.inspire (Aced): slot -> seconds until the shout can revive again
var _inspire_cd: Dictionary[int, float] = {}
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
	_inspire_cd[slot] = maxf(_inspire_cd.get(slot, 0.0) - delta, 0.0)
	var pressed: bool = intent != null and intent.shout
	var rising: bool = pressed and not _held.get(slot, false)
	_held[slot] = pressed
	if not rising or cd > 0.0 or crew.crew_state != Enums.CrewState.NORMAL:
		return
	_cooldown[slot] = Tweak.stealth().shout_cooldown_s
	shout(crew)


## Server: resolve one shout from `crew`. Returns the NPCs that reacted (the teammate, for Inspire).
func shout(crew: CrewController) -> Array[Node]:
	var affected: Array[Node] = []
	var mate: CrewController = inspire(crew)  # B1: a shout at a teammate is Inspire, not an intimidation
	if mate != null:
		affected.append(mate)
		shouted.emit(crew.slot, affected)
		return affected
	for npc: NpcBase in targets_for(crew):
		var brain: Node = npc.get_node_or_null(^"Brain")
		if brain != null and brain.has_method(&"on_shouted") and bool(brain.call(&"on_shouted", crew)):
			affected.append(npc)
	var guard: NpcBase = guard_target_for(crew)  # S5.8
	if guard != null and (guard.get_node(^"Brain") as GuardBrain).on_shouted(crew):
		affected.append(guard)
	var rt0: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
	var cop: NpcBase = PoliceSurrender.shout_target(crew, rt0)  # L5.1 (A3-04)
	if cop != null and PoliceSurrender.on_shouted(cop, crew):
		affected.append(cop)
	shouted.emit(crew.slot, affected)
	if affected.is_empty():
		var t: Node3D = mark_target_for(crew)
		var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
		if t != null and rt != null and rt.stealth != null and rt.stealth.mark(t, crew.slot):
			marked.emit(crew.slot, t)
	return affected


## B1 `ability.inspire` (PD2 Inspire, Rally Cry): a shout at the teammate nearest the aim line (mark cone, line of
## sight). Basic: a standing teammate within the shout range gets movement / reload x buff_move_mult / buff_reload_mult
## for buff_duration s (CrewBuffs source "inspire", refreshed by another shout). Aced (`range` > 0): a DOWNED teammate
## within `range` m is revived at once, then not again for `cooldown` s from this shouter. Returns the teammate it
## reached (null: the shout goes on to civilians, guards, police and marks).
func inspire(crew: CrewController) -> CrewController:
	var p: Dictionary = Modifiers.params(crew.slot, &"ability.inspire")
	if p.is_empty():
		return null
	var mate: CrewController = ally_target_for(crew, maxf(Tweak.stealth().shout_range_m, float(p.get("range", 0.0))))
	if mate == null or mate.health == null:
		return null
	var ok: bool = _inspire_revive(crew, mate, p) if mate.crew_state == Enums.CrewState.DOWNED \
		else _inspire_buff(crew, mate, p)
	return mate if ok else null


## Aced: revive the DOWNED `mate` within `range` m, off cooldown.
func _inspire_revive(crew: CrewController, mate: CrewController, p: Dictionary) -> bool:
	var revive_m: float = float(p.get("range", 0.0))
	if revive_m <= 0.0 or mate.global_position.distance_to(crew.global_position) > revive_m \
			or _inspire_cd.get(crew.slot, 0.0) > 0.0:
		return false
	mate.health.revive(crew.slot)
	_inspire_cd[crew.slot] = float(p.get("cooldown", 0.0))
	return true


## Basic: the standing `mate` within the shout range gets the move / reload buff.
func _inspire_buff(crew: CrewController, mate: CrewController, p: Dictionary) -> bool:
	var dur: float = float(p.get("buff_duration", 0.0))
	var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
	var buffs: CrewBuffs = CrewBuffs.of(rt)
	if buffs == null or mate.crew_state != Enums.CrewState.NORMAL or dur <= 0.0 \
			or mate.global_position.distance_to(crew.global_position) > Tweak.stealth().shout_range_m:
		return false
	buffs.grant(mate.slot, &"inspire", {
		&"movement.speed_mult": float(p.get("buff_move_mult", 1.0)),
		&"weapon.reload_speed_mult": float(p.get("buff_reload_mult", 1.0))}, dur)
	return true


## The teammate (any other crew member) nearest `crew`'s aim line within the mark cone and `max_m`, in sight.
func ally_target_for(crew: CrewController, max_m: float) -> CrewController:
	var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
	if rt == null:
		return null
	var eye: Vector3 = crew.eye_position()
	var aim: Vector3 = crew.aim_direction()
	var half: float = deg_to_rad(Tweak.stealth().mark_cone_half_deg)
	var best: CrewController = null
	var best_ang: float = INF
	for c: CrewController in rt.crew_members():
		if c == crew or c.crew_state == Enums.CrewState.CUSTODY:
			continue
		var point: Vector3 = c.global_position + Vector3(0.0, 0.4 if c.crew_state == Enums.CrewState.DOWNED else 1.2, 0.0)
		var to: Vector3 = point - eye
		var ang: float = aim.angle_to(to)
		if to.length() > max_m or ang > half or ang >= best_ang or not _clear_to(crew, eye, point, c):
			continue
		best = c
		best_ang = ang
	return best


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
	var mark_range: float = tw.mark_range_m * Modifiers.mult(crew.slot, &"ability.shout_range_mult")  # QB-61
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
		if to.length() > mark_range or ang > half or ang >= best_ang:
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


## S5.8: the guard a shout from `crew` would dominate now (nearest the aim line within
## guard_dominate_range_m / guard_dominate_cone_half_deg with LOS, inside his window), or null.
func guard_target_for(crew: CrewController) -> NpcBase:
	var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
	if rt == null or not Modifiers.flag(crew.slot, &"stealth.can_dominate_guards"):
		return null
	var tw: StealthTweak = Tweak.stealth()
	var range_m: float = guard_dominate_range_for(crew)
	var eye: Vector3 = crew.eye_position()
	var aim: Vector3 = crew.aim_direction()
	var st: StealthDirector = rt.stealth
	var best: NpcBase = null
	var best_ang: float = INF
	for n: Node in rt.npcs(&"guard"):
		var npc: NpcBase = n as NpcBase
		var brain: GuardBrain = npc.get_node_or_null(^"Brain") as GuardBrain if npc != null else null
		if brain == null or not brain.can_be_dominated_by(crew):
			continue
		var point: Vector3 = npc.global_position + Vector3(0.0, 1.2, 0.0)
		var to: Vector3 = point - eye
		var ang: float = aim.angle_to(to)
		if to.length() > range_m or ang > deg_to_rad(guard_dominate_cone_half_deg(to.length())) or ang >= best_ang:
			continue
		if st != null and st.is_inside_tree() and not st.has_los(eye, point, [crew.get_rid(), npc.get_rid()]):
			continue
		best = npc
		best_ang = ang
	return best


## D-079: guard domination range for `crew` (m): base x skill x Crew Chief (shout range), multiplicative.
static func guard_dominate_range_for(crew: CrewController) -> float:
	var tw: StealthTweak = Tweak.stealth()
	var r: float = tw.guard_dominate_range_m * Modifiers.mult(crew.slot, &"ability.shout_range_mult")
	if Modifiers.flag(crew.slot, &"ability.intimidate_cops"):
		r *= tw.guard_dominate_skill_range_mult
	return r


## D-079: aim cone half-angle (deg) at distance `d` m: max(8, 90 -> 30 linear over 0..12 m, extrapolated).
static func guard_dominate_cone_half_deg(d: float) -> float:
	var tw: StealthTweak = Tweak.stealth()
	var t: float = d / maxf(tw.guard_dominate_cone_far_m, 0.001)
	return maxf(tw.guard_dominate_cone_min_deg, lerpf(tw.guard_dominate_cone_near_deg, tw.guard_dominate_cone_far_deg, t))


## Civilians a shout from `crew` reaches right now (before the D-016 roll).
func targets_for(crew: CrewController) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(crew)
	if rt == null or crew.is_casing():  # PO-11 (S1.1): an unmasked shout intimidates no civilian
		return out
	var tw: StealthTweak = Tweak.stealth()
	var range_m: float = tw.shout_range_m * Modifiers.mult(crew.slot, &"stealth.civilian_intimidate_range_mult") \
		* Modifiers.mult(crew.slot, &"ability.shout_range_mult")  # QB-61: every shout target
	if Modifiers.flag(crew.slot, &"stealth.noise_intimidates_civilians"):
		range_m *= NOISE_INTIMIDATE_RANGE_MULT  # B6 Captive Audience: a wider intimidation
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
		if flat <= tw.shout_all_within_m and _hears_nearby(crew, npc, eye, point, st, rt):
			out.append(npc)
			continue
		var to: Vector3 = point - eye
		if to.length() > range_m or aim.angle_to(to) > half_cone:
			continue
		if st != null and st.is_inside_tree() and not st.has_los(eye, point, [crew.get_rid(), npc.get_rid()]):
			continue
		out.append(npc)
	return out


## PO-5 (S7.1): the all-round shout reaches a nearby civilian on the same floor that has line of sight
## to the shouter or a short walk to them (around a counter, through an open doorway).
static func _hears_nearby(crew: CrewController, npc: NpcBase, eye: Vector3, point: Vector3,
		st: StealthDirector, rt: HeistRuntime) -> bool:
	var tw: StealthTweak = Tweak.stealth()
	if absf(npc.global_position.y - crew.global_position.y) > tw.shout_floor_dy_m:
		return false
	if st == null or not st.is_inside_tree() or st.has_los(eye, point, [crew.get_rid(), npc.get_rid()]):
		return true
	var targets: CivilianTargets = CivilianTargets.ensure(rt)
	if targets == null or not targets.is_inside_tree():
		return false
	return targets.nav_path_length(crew.global_position, npc.global_position) <= tw.shout_all_within_m * tw.shout_path_mult


static func _aim_point(npc: NpcBase) -> Vector3:
	var brain: Node = npc.get_node_or_null(^"Brain")
	if brain != null and brain.has_method(&"shout_target_point"):
		return brain.call(&"shout_target_point")
	return npc.global_position + Vector3(0.0, 1.0, 0.0)
