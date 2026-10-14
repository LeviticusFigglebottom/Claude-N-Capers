## Not-standable tops for thin guards and edge furniture (next_heist §7.5, D-104 `slopes`): a railing,
## balustrade, handrail, gunwale, barrier or bollard keeps its visual, but its collider's top is a
## ridge whose two faces are ANGLE_DEG steep, so a player (max floor angle 45°) slides off instead of
## standing on it. The collider keeps the box's AABB (sides, base and peak height unchanged), so it
## still blocks players, bags and the navmesh exactly as the box did; only the top edges are chamfered
## up to the ridge. Used by the map generators (`preload`ed as `RT`). Owner: ENV C.
extends RefCounted

## Steepness of both ridge faces (the slopes check flags anything under 50°).
const ANGLE_DEG: float = 55.0

## Shapes shared by size + axis (one sub-resource per distinct rail, like the builders' box_shape cache).
static var _cache: Dictionary = {}


## Convex prism with the AABB of a box of `size` centred on the origin: vertical sides, the top a ridge
## along local X (`axis` 0) or Z (`axis` 2); -1 picks the longer horizontal side. The chamfer rise is
## half the cross width * tan(ANGLE_DEG), clamped to the box height.
static func shape(size: Vector3, axis: int = -1) -> ConvexPolygonShape3D:
	var key: String = "%.4f|%.4f|%.4f|%d" % [size.x, size.y, size.z, axis]
	if _cache.has(key):
		return _cache[key]
	var along_x: bool = size.x >= size.z if axis < 0 else axis == 0
	var h: Vector3 = size * 0.5
	var hw: float = h.z if along_x else h.x
	var rise: float = minf(hw * tan(deg_to_rad(ANGLE_DEG)), size.y)
	var y_sh: float = h.y - rise
	var pts: PackedVector3Array = PackedVector3Array()
	var ends: Array[float] = [-(h.x if along_x else h.z), h.x if along_x else h.z]
	for a: float in ends:
		var cs: Array[Vector2] = [Vector2(-hw, -h.y), Vector2(hw, -h.y), Vector2(0.0, h.y)]
		if y_sh > -h.y + 0.001:  # else a low slab: the chamfer starts at the base (triangular prism)
			cs.append_array([Vector2(hw, y_sh), Vector2(-hw, y_sh)])
		for c: Vector2 in cs:
			pts.append(Vector3(a, c.y, c.x) if along_x else Vector3(c.x, c.y, a))
	var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shp.points = pts
	_cache[key] = shp
	return shp


## Replace the BoxShape3D of `body`'s CollisionShape3D child `col_name` with shape(size, axis).
## Returns false (and changes nothing) when there is no such box collider.
static func apply(body: Node, axis: int = -1, col_name: String = "Collision") -> bool:
	if body == null:
		return false
	var col: CollisionShape3D = body.get_node_or_null(col_name) as CollisionShape3D
	if col == null or not (col.shape is BoxShape3D):
		return false
	col.shape = shape((col.shape as BoxShape3D).size, axis)
	return true
