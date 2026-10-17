## barred_doors (all stages, D-073): BARRED doorways are baked CLOSED in the navmesh; only the
## door's own NavLink (ENV A, enabled while the door is passable) may bridge them. For every active
## Door prefab with lock BARRED, every NavigationLink3D under a door is disabled, then a navmesh path
## is queried from 1.2 m in front of the door to 1.2 m behind it (and back). FAIL when a path
## segment crosses the doorway (the door line within the half width + 0.3 m, between 0.5 m below
## and 2.5 m above the door's floor). A detour through another opening passes. Doors the mission bars at runtime
## count too: `shutter` doors (GN lockdown) and DB fire shutters (meta `fire_shutter`). Doors inside a
## VariantSlot are skipped (noted): the navmesh is baked once for every variant, so a slot door that
## another slot leaves open cannot be baked closed.
class_name LcCheckBarredDoors
extends LcCheck

const PROBE_M: float = 1.2
const JAMB_TOL_M: float = 0.3


func _init() -> void:
	id = &"barred_doors"
	title = "BARRED doorways are closed in the navmesh"


func run(ctx: LcContext) -> void:
	if not ctx.has_navmesh():
		note("no navmesh; not checked")
		return
	var barred: Array[Door] = []
	var skipped: PackedStringArray = PackedStringArray()
	for n: Node in ctx.map.find_children("*", "", true, false):
		var d: Door = n as Door
		if d == null or not ctx.is_active(d):
			continue
		if d.lock != Door.Lock.BARRED and not d.shutter and not d.has_meta(&"fire_shutter"):
			continue
		if _in_slot(ctx, d):
			skipped.append("`%s`" % ctx.node_path(d))
			continue
		barred.append(d)
	var saved: Array[Array] = ctx.set_door_links(false)
	await ctx.await_sync(8)  # 3 frames was not always enough for the link disable to reach the map (flaky FAIL)
	for d2: Door in barred:
		_check_door(ctx, d2)
	ctx.restore_links(saved)
	await ctx.await_sync(3)
	note("%d BARRED door(s) checked" % barred.size())
	if not skipped.is_empty():
		note("variant-slot BARRED doors not checked (one bake for every variant): %s" % ", ".join(skipped))


static func _in_slot(ctx: LcContext, n: Node) -> bool:
	var cur: Node = n.get_parent()
	while cur != null and cur != ctx.map:
		if cur is VariantSlot:
			return true
		cur = cur.get_parent()
	return false


func _check_door(ctx: LcContext, d: Door) -> void:
	var xf: Transform3D = d.global_transform
	var front: Vector3 = xf * Vector3(0.0, 0.0, -PROBE_M)
	var back: Vector3 = xf * Vector3(0.0, 0.0, PROBE_M)
	var half: float = d.effective_width() * 0.5 + JAMB_TOL_M
	for pair: Array in [[front, back], [back, front]]:
		var path: PackedVector3Array = ctx.nav_path(pair[0], pair[1])
		var hit: Variant = crossing(xf, path, half)
		if hit != null:
			fail(ctx, d, hit, "navmesh path crosses the BARRED doorway (bake it closed; the door's NavLink bridges it)")
			return


## World point where `path` crosses the door plane (local z = 0) within |x| <= half and y in
## [-0.5, 2.5] of the door frame `xf`, or null.
static func crossing(xf: Transform3D, path: PackedVector3Array, half: float) -> Variant:
	var inv: Transform3D = xf.affine_inverse()
	for i: int in range(1, path.size()):
		var a: Vector3 = inv * path[i - 1]
		var b: Vector3 = inv * path[i]
		if (a.z < 0.0) == (b.z < 0.0) or is_equal_approx(a.z, b.z):
			continue
		var t: float = a.z / (a.z - b.z)
		var c: Vector3 = a.lerp(b, t)
		if absf(c.x) <= half and c.y >= -0.5 and c.y <= 2.5:
			return xf * c
	return null
