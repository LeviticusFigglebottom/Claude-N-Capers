## door_access (all stages; G3, P r315: a door turned round put its interactable behind the wall and cut a stealth
## route): every active Door prefab's Interactable must be usable from each side it is meant to be used from, as the
## game resolves it (interaction_system.gd aimed_component / _has_los). Sides: the front (-Z, the UsePoint side)
## always; the back (+Z) too unless the door is a push-bar fire exit (it opens only from the inside, the front).
## Skipped: BARRED doors and shutters (the crew never operates them; barred_doors covers them), doors without an
## Interactable. Per side: a stand point on the navmesh 0.5 / 0.8 / 1.1 m out along the door's normal (the nearest
## navmesh point within NAV_TOL horizontally of the probe and at least 0.2 m out from the door's plane); from its eye
## (+EYE_H) the Interactable must lie within reach (InteractionTweak.reach_m + 0.35) and a ray on layer 1 to it may
## hit only the door's own colliders (its leaf, its frame). FAIL names the side and what blocked it.
class_name LcCheckDoorAccess
extends LcCheck

const EYE_H: float = 1.6
const PROBES: Array[float] = [0.5, 0.8, 1.1]
const NAV_TOL: float = 0.35
const MIN_OUT: float = 0.2
const REACH_SLACK: float = 0.35


func _init() -> void:
	id = &"door_access"
	title = "door interactables usable from the sides they open from"


func run(ctx: LcContext) -> void:
	if not ctx.has_navmesh():
		note("no navmesh; not checked")
		return
	var reach: float = Tweak.interaction().reach_m + REACH_SLACK
	var n_doors: int = 0
	for n: Node in ctx.map.find_children("*", "", true, false):
		var d: Door = n as Door
		if d == null or not ctx.is_active(d) or d.lock == Door.Lock.BARRED or d.shutter:
			continue
		var comp: InteractableComponent = d.interactable
		if comp == null:
			continue
		n_doors += 1
		var normal: Vector3 = d.global_basis.z
		normal.y = 0.0
		normal = normal.normalized()
		_check_side(ctx, d, comp, -normal, "front", reach)
		if not d.push_bar:
			_check_side(ctx, d, comp, normal, "back", reach)
	note("%d door(s) checked (reach %.2f m, eye %.1f m)" % [n_doors, reach, EYE_H])


func _check_side(ctx: LcContext, d: Door, comp: InteractableComponent, out: Vector3, side: String, reach: float) -> void:
	var o: Vector3 = d.global_position
	var target: Vector3 = comp.global_position
	var why: String = "no navmesh within %.2f m of the probes %s m out" % [NAV_TOL, PROBES]
	for dist: float in PROBES:
		var probe: Vector3 = o + out * dist
		var nav: Vector3 = ctx.nav_closest(probe)
		var flat: Vector3 = nav - probe
		flat.y = 0.0
		if flat.length() > NAV_TOL or absf(nav.y - o.y) > 0.6 or (nav - o).dot(out) < MIN_OUT:
			continue
		var eye: Vector3 = nav + Vector3.UP * EYE_H
		var dd: float = eye.distance_to(target)
		if dd > reach:
			why = "the interactable is %.2f m from the eye at %s (reach %.2f m)" % [dd, nav.snapped(Vector3.ONE * 0.01), reach]
			continue
		var hit: Dictionary = ctx.ray(eye, target, Callable(), 1)
		var col: Node = hit.get("collider") as Node if not hit.is_empty() else null
		if hit.is_empty() or col == d or d.is_ancestor_of(col):
			return
		why = "the aim ray from %s hits `%s` at %s" % [nav.snapped(Vector3.ONE * 0.01), ctx.node_path(col),
			(hit["position"] as Vector3).snapped(Vector3.ONE * 0.01)]
	fail(ctx, d, target, "door can't be used from its %s: %s" % [side, why])
