## Marked lines and D-128 detection sample points for the hide_los / bag_line checks (OF-C3). Owner: ENV C.
## A marked line is one of (world space, at the crew's feet):
##   * a Path3D: its curve's baked points;
##   * a Node3D with Node3D children (Marker3Ds): the children's origins in tree order (a polyline);
##   * any other Node3D: its own origin (a single spot).
## Detection points follow the runtime (StealthDirector._crew_visible): feet + min(h, eye) for each StealthTweak
## `los_heights` entry, eye = CrewTweak eye_standing / eye_crouched; the observer eye is an NPC's head_height.
class_name LcLines
extends RefCounted

## Tweaks via ENV A's static `Tweak` accessor (no hard paths into game/systems). Fallbacks = the shipped defaults
## (stealth_tweak.gd los_heights, crew_tweak.gd eye heights).
const DEFAULT_LOS_HEIGHTS: Array[float] = [1.6, 1.0]
const DEFAULT_EYE_STAND: float = 1.65
const DEFAULT_EYE_CROUCH: float = 1.05
## npc_base.gd head_height (guards, civilians): the observer's eye above its feet.
const NPC_EYE: float = 1.62
## StealthDirector.VISION_MASK: world_static, world_dynamic, vision_blockers.
const VISION_MASK: int = (1 << 0) | (1 << 1) | (1 << 7)
## Kinds whose colliders the vision check treats as transparent (glazing), plus nodes with meta see_through.
const SEE_THROUGH_KINDS: Array[StringName] = [&"window", &"glass", &"glazing"]


## Vertices of a marked line (see the header), world space.
static func vertices(n: Node3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var path: Path3D = n as Path3D
	if path != null and path.curve != null and path.curve.point_count > 0:
		for p: Vector3 in path.curve.get_baked_points():
			out.append(path.global_transform * p)
		return out
	for c: Node in n.get_children():
		if c is Node3D:
			out.append((c as Node3D).global_position)
	if out.is_empty():
		out.append(n.global_position)
	return out


## Points every `step` m along the polyline (both ends included); a single vertex gives itself.
static func samples(verts: PackedVector3Array, step: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if verts.is_empty():
		return out
	out.append(verts[0])
	for i: int in range(1, verts.size()):
		var a: Vector3 = verts[i - 1]
		var b: Vector3 = verts[i]
		var seg: float = a.distance_to(b)
		var n: int = maxi(1, ceili(seg / maxf(step, 0.05)))
		for k: int in range(1, n + 1):
			out.append(a.lerp(b, float(k) / float(n)))
	return out


static func los_heights() -> Array[float]:
	var out: Array[float] = []
	var tw: StealthTweak = Tweak.stealth()
	if tw != null:
		for h: float in tw.los_heights:
			out.append(h)
	if out.is_empty():
		out = DEFAULT_LOS_HEIGHTS.duplicate()
	return out


static func eye_height(crouched: bool) -> float:
	var tw: CrewTweak = Tweak.crew()
	if tw != null:
		return tw.eye_crouched if crouched else tw.eye_standing
	return DEFAULT_EYE_CROUCH if crouched else DEFAULT_EYE_STAND


## Heights above the feet that the runtime tests for LOS (sorted, unique).
static func detection_heights(crouched: bool) -> Array[float]:
	var top: float = eye_height(crouched)
	var out: Array[float] = []
	for h: float in los_heights():
		var v: float = minf(h, top)
		if not out.has(v):
			out.append(v)
	out.sort()
	return out


## Posture meta value: true unless the node says "stand" / "standing".
static func is_crouched(n: Node, key: StringName) -> bool:
	var p: String = String(LcUtil.meta_s(n, key)).to_lower()
	return not (p == "stand" or p == "standing")


static func meta_float(n: Node, key: StringName, fallback: float) -> float:
	if n != null and n.has_meta(key):
		var v: Variant = n.get_meta(key)
		if v is float or v is int:
			return float(v)
	return fallback


## A String ("a,b"), StringName, Array or PackedStringArray meta as a list of stripped strings.
static func meta_strings(n: Node, key: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if n == null or not n.has_meta(key):
		return out
	var v: Variant = n.get_meta(key)
	if v is String or v is StringName:
		for e: String in str(v).split(",", false):
			out.append(e.strip_edges())
	elif v is Array or v is PackedStringArray:
		for e2: Variant in v:
			out.append(str(e2).strip_edges())
	return out


## True when a collider is see-through for the vision check: in the `see_through` group (D-142, the runtime rule:
## StealthDirector passes such a collider), or meta see_through / a glazing kind on it or a parent.
static func see_through(obj: Object, map: Node) -> bool:
	var cur: Node = obj as Node
	if cur != null and cur.is_in_group(&"see_through"):
		return true
	while cur != null and cur != map:
		if LcUtil.meta_b(cur, &"see_through") or LcUtil.meta_s(cur, &"kind") in SEE_THROUGH_KINDS:
			return true
		cur = cur.get_parent()
	return false


## Vision ray filter: active, solid, not see-through.
static func vision_accept(ctx: LcContext) -> Callable:
	return func(hit: Dictionary) -> bool:
		var obj: Object = hit.get("collider")
		if obj == null:
			return true
		if obj is Area3D:
			return false
		return ctx.is_active(obj as Node) and not see_through(obj, ctx.map)
