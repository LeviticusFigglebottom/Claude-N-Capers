## secure_zones (all stages, D-066): a bag resting on the ground must be able to sit inside every
## active SECURE_LOOT MapZone. For each zone box, 3 x 3 footprint samples (0.3 m in from the edges)
## cast down from the box top to 2 m below its bottom, ignoring the zone's own SecureZone vehicle
## collision; a sample is good when the hit + 0.05 m (a resting bag's probe) lies inside the box.
## FAIL when no sample is good (e.g. the zone floor sits above the ground under it).
class_name LcCheckSecureZones
extends LcCheck

const PROBE_UP: float = 0.05
const EDGE_IN: float = 0.3
const BELOW: float = 2.0


func _init() -> void:
	id = &"secure_zones"
	title = "Secure zones reach the ground"


func run(ctx: LcContext) -> void:
	var n: int = 0
	for node: Node in ctx.map.find_children("*", "MapZone", true, false):
		var z: MapZone = node as MapZone
		if z.kind != MapZone.Kind.SECURE_LOOT or not ctx.is_active(z):
			continue
		for cs_node: Node in z.get_children():
			var cs: CollisionShape3D = cs_node as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			n += 1
			_check_box(ctx, z, cs)
	note("%d SECURE_LOOT box(es) checked" % n)


func _check_box(ctx: LcContext, z: MapZone, cs: CollisionShape3D) -> void:
	var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
	var xf: Transform3D = cs.global_transform
	var inv: Transform3D = xf.affine_inverse()
	var owner_prefab: Node = z.get_parent() as SecureZone
	var accept: Callable = func(hit: Dictionary) -> bool:
		var obj: Node = hit.get("collider") as Node
		if obj != null and owner_prefab != null and owner_prefab.is_ancestor_of(obj):
			return false
		return ctx.accept_any_active(hit)
	var good: int = 0
	var lowest_gap: float = INF
	for fx: float in [-1.0, 0.0, 1.0]:
		for fz: float in [-1.0, 0.0, 1.0]:
			var lx: float = fx * maxf(half.x - EDGE_IN, 0.0)
			var lz: float = fz * maxf(half.z - EDGE_IN, 0.0)
			var top: Vector3 = xf * Vector3(lx, half.y, lz)
			var bottom: Vector3 = xf * Vector3(lx, -half.y - BELOW, lz)
			var hit: Dictionary = ctx.ray(top, bottom, accept)
			if hit.is_empty():
				continue
			var probe: Vector3 = (hit["position"] as Vector3) + Vector3.UP * PROBE_UP
			var lp: Vector3 = inv * probe
			if absf(lp.x) <= half.x and absf(lp.z) <= half.z and lp.y >= -half.y and lp.y <= half.y:
				good += 1
			else:
				lowest_gap = minf(lowest_gap, -half.y - lp.y)
	if good == 0:
		var why: String = ("the ground is %.2f m below the zone floor" % (lowest_gap + PROBE_UP)) \
			if lowest_gap < INF else "no ground under it"
		fail(ctx, z, xf.origin, "SECURE_LOOT zone holds no resting-bag point (ground + %.2f m): %s"
			% [PROBE_UP, why])
