## slopes (all stages): no walkable slope < 50° outside the play mesh (next_heist.md §7.5, ENV P's
## traversal review, D-104). A player (capsule r 0.35, step 0.35, max floor angle 45°, jump apex
## 1.08 m) must not be able to climb onto a surface outside the intended play space: a roof, parapet
## coping, wall top, sill or ledge next to the navmesh. Such surfaces must be >= 50° steep, blocked,
## or out of reach.
## Algorithm: columns on a 0.25 m XZ grid over the navmesh bounds (+ reach) cast down through every
## collision surface. A surface sample is a hit when all of these hold:
##   * it is walkable: its normal is < 50° from vertical;
##   * it is not play mesh: no navmesh within 0.5 m (h) / 0.35 m (v);
##   * it is not play space: not inside an interior RoomVolume (furniture tops, counters and sills
##     in rooms are fine). In `exterior` / `roof` rooms only the building shell counts (props there
##     are dressing on the play area); outside every room all collision counts;
##   * it is reachable by a jump: navmesh lies within 1.0 m horizontally, between 0.35 m (step) and
##     1.18 m below it (jump apex 1.08 + 0.10: the capsule's rounded bottom rides a lip up to
##     r(1 - cos 45°) above the feet), with jump headroom above the take-off point and a clear line
##     across at the surface height; and that navmesh is on the players' play mesh (a navmesh path
##     from the first PLAYER spawn reaches it, so unreachable baked islands such as a police-only
##     roof do not count);
##   * a crouched player fits on it (cylinder r 0.2, 1.1 m high, nothing in it).
## One issue per collider (first sample by position). Severity: FAIL on every map (GN-C1: the
## pre-D-104 heists were fixed at the source, so the former LEGACY_WARN list is gone). Typical fixes:
## copings >= 50°, ridged guard tops (game/world/kits/ridge_top.gd), out of reach, or play space.
class_name LcCheckSlopes
extends LcCheck

const MIN_STEEP_DEG: float = 50.0
const STEP_H: float = 0.35
const JUMP_APEX: float = 1.08
## Rounded capsule bottom (r 0.35) still takes a lip as floor up to r * (1 - cos 45°) above the feet.
const JUMP_MARGIN: float = 0.10
const REACH_H: float = 1.0
const GRID: float = 0.25
const NAV_H_TOL: float = 0.5
const NAV_V_TOL: float = 0.35
const FIT_RADIUS: float = 0.2
const FIT_HEIGHT: float = 1.1
const MAX_HITS_PER_COLUMN: int = 48
## Coarse XZ cells (m) of the column mask: only columns near a navmesh polygon are cast.
const MASK_CELL: float = 1.0
const PATH_H_TOL: float = 0.3
const PATH_V_TOL: float = 0.5

## Rooms whose volume is open play area outdoors: shell surfaces in them still count.
const OUTDOOR_PURPOSES: Array[StringName] = [&"exterior", &"roof"]

var _spawn_nav: Variant = null
var _reach_cache: Dictionary = {}


func _init() -> void:
	id = &"slopes"
	title = "No walkable slope < 50° outside the play mesh"


func run(ctx: LcContext) -> void:
	if not ctx.has_navmesh():
		skipped_reason = "no navmesh"
		return
	# Door NavLinks were just enabled by LcContext.setup(): let the navigation map sync so the
	# play-mesh paths below see them whether or not another check ran first.
	await ctx.await_sync(8)
	var bounds: AABB = _nav_bounds(ctx)
	var mask: Dictionary = _column_mask(ctx)
	var spawns: Array[SpawnPoint] = LcTargets.player_spawns(ctx)
	if not spawns.is_empty():
		_spawn_nav = ctx.nav_closest(spawns[0].global_position)
	var grow: float = REACH_H + GRID
	var x0: float = bounds.position.x - grow
	var z0: float = bounds.position.z - grow
	var nx: int = int(ceil((bounds.size.x + 2.0 * grow) / GRID)) + 1
	var nz: int = int(ceil((bounds.size.z + 2.0 * grow) / GRID)) + 1
	var y_top: float = bounds.end.y + JUMP_APEX + JUMP_MARGIN + 0.2
	var y_bot: float = bounds.position.y + STEP_H - 0.05
	var min_ny: float = cos(deg_to_rad(MIN_STEEP_DEG))
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = FIT_RADIUS
	cyl.height = FIT_HEIGHT
	var fit_q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	fit_q.shape = cyl
	fit_q.collision_mask = LcContext.QUERY_MASK
	var by_node: Dictionary = {}  # node path -> {node, pos, nav, dy, deg, n}
	var samples: int = 0
	for i: int in range(nx):
		for j: int in range(nz):
			var x: float = x0 + float(i) * GRID
			var z: float = z0 + float(j) * GRID
			if not mask.has(Vector2i(floori(x / MASK_CELL), floori(z / MASK_CELL))):
				continue
			for hit: Dictionary in _column(ctx, x, z, y_top, y_bot):
				samples += 1
				var n: Vector3 = hit["normal"]
				if n.y < min_ny:
					continue
				var info: Dictionary = _judge(ctx, hit, fit_q)
				if info.is_empty():
					continue
				var node: Node = hit["collider"] as Node
				var key: String = ctx.node_path(node)
				if by_node.has(key):
					by_node[key]["n"] = int(by_node[key]["n"]) + 1
					continue
				info["node"] = node
				info["deg"] = rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
				info["n"] = 1
				by_node[key] = info
	var keys: Array = by_node.keys()
	keys.sort()
	for k: String in keys:
		var d: Dictionary = by_node[k]
		var msg: String = ("walkable %.0f° surface outside the play mesh, %.2f m above the play-mesh floor at %s (%d sample(s)); "
			+ "make it >= %.0f° steep, block it, or bring it into play space") % [d["deg"], d["dy"],
			LcCheck.fmt_v(d["nav"]), d["n"], MIN_STEEP_DEG]
		fail(ctx, d["node"], d["pos"], msg)
	note("%d x %d columns (%.2f m), %d surface samples, %d collider(s) with reachable walkable surfaces outside play"
		% [nx, nz, GRID, samples, by_node.size()])


## Bounds of every enabled, active navmesh region (world space).
func _nav_bounds(ctx: LcContext) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for nd: Node in ctx.map.find_children("*", "NavigationRegion3D", true, false):
		var r: NavigationRegion3D = nd
		if r.navigation_mesh == null or not r.enabled or not ctx.is_active(r):
			continue
		var xf: Transform3D = r.global_transform
		for v: Vector3 in r.navigation_mesh.get_vertices():
			var w: Vector3 = xf * v
			out = AABB(w, Vector3.ZERO) if first else out.expand(w)
			first = false
	return out


## Coarse XZ cells within reach of any navmesh polygon: {Vector2i: true}.
func _column_mask(ctx: LcContext) -> Dictionary:
	var out: Dictionary = {}
	var grow: float = REACH_H + GRID
	for nd: Node in ctx.map.find_children("*", "NavigationRegion3D", true, false):
		var r: NavigationRegion3D = nd
		if r.navigation_mesh == null or not r.enabled or not ctx.is_active(r):
			continue
		var nm: NavigationMesh = r.navigation_mesh
		var verts: PackedVector3Array = nm.get_vertices()
		var xf: Transform3D = r.global_transform
		for i: int in range(nm.get_polygon_count()):
			var lo: Vector2 = Vector2(INF, INF)
			var hi: Vector2 = Vector2(-INF, -INF)
			for vi: int in nm.get_polygon(i):
				var w: Vector3 = xf * verts[vi]
				lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.z))
				hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.z))
			for cx: int in range(floori((lo.x - grow) / MASK_CELL), floori((hi.x + grow) / MASK_CELL) + 1):
				for cz: int in range(floori((lo.y - grow) / MASK_CELL), floori((hi.y + grow) / MASK_CELL) + 1):
					out[Vector2i(cx, cz)] = true
	return out


## Every active surface hit straight down from y_top to y_bot at (x, z), top first.
func _column(ctx: LcContext, x: float, z: float, y_top: float, y_bot: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var y: float = y_top
	var ex: Array[RID] = []
	var sp: PhysicsDirectSpaceState3D = ctx.space()
	for k: int in range(MAX_HITS_PER_COLUMN):
		if y <= y_bot:
			break
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, y, z), Vector3(x, y_bot, z),
			LcContext.QUERY_MASK, ex)
		q.hit_back_faces = false
		var hit: Dictionary = sp.intersect_ray(q)
		if hit.is_empty():
			break
		var obj: Node = hit.get("collider") as Node
		if obj != null and not ctx.is_active(obj):
			ex.append(hit["rid"])
			continue
		out.append(hit)
		y = (hit["position"] as Vector3).y - 0.02
	return out


## {pos, nav, dy} when the walkable surface hit is reachable and outside play, else {}.
func _judge(ctx: LcContext, hit: Dictionary, fit_q: PhysicsShapeQueryParameters3D) -> Dictionary:
	var p: Vector3 = hit["position"]
	var on: Vector3 = _floor_under(ctx, ctx.nav_closest(p))
	if Vector2(on.x - p.x, on.z - p.z).length() <= NAV_H_TOL and absf(on.y - p.y) <= NAV_V_TOL:
		return {}
	if _in_play_space(ctx, hit):
		return {}
	var take: Variant = _take_off(ctx, p)
	if take == null:
		return {}
	var c: Vector3 = take
	if not _fits_and_clear(ctx, hit, c, fit_q):
		return {}
	return {"pos": p, "nav": c, "dy": p.y - c.y}


## A crouched player fits on the surface, and the jump from floor point c gets there: headroom above c,
## then a clear line across at the surface height.
func _fits_and_clear(ctx: LcContext, hit: Dictionary, c: Vector3, fit_q: PhysicsShapeQueryParameters3D) -> bool:
	var p: Vector3 = hit["position"]
	# A crouched player fits on the surface (lifted clear of the surface's own slope).
	var n: Vector3 = hit["normal"]
	var lift: float = 0.05 + FIT_RADIUS * sqrt(maxf(0.0, 1.0 - n.y * n.y)) / maxf(n.y, 0.01)
	fit_q.transform = Transform3D(Basis(), p + Vector3.UP * (lift + FIT_HEIGHT * 0.5))
	for r: Dictionary in ctx.space().intersect_shape(fit_q, 8):
		var o: Node = r.get("collider") as Node
		if o == null or ctx.is_active(o):
			return false
	# Jump headroom above the take-off point, then a clear line across at the surface height.
	var over: float = p.y + 0.25
	if not ctx.ray(c + Vector3.UP * 0.3, Vector3(c.x, over, c.z), ctx.accept_any_active).is_empty():
		return false
	if not ctx.ray(Vector3(c.x, over, c.z), Vector3(p.x, over, p.z), ctx.accept_any_active).is_empty():
		return false
	return true


## The floor under a player-reachable navmesh point the player can jump from onto p (within REACH_H,
## STEP_H < rise <= apex + margin), or null.
func _take_off(ctx: LcContext, p: Vector3) -> Variant:
	for q: Vector3 in [p + Vector3.DOWN * 0.7, p]:
		var nav: Vector3 = ctx.nav_closest(q)
		var c: Vector3 = _floor_under(ctx, nav)
		var dy: float = p.y - c.y
		if dy > STEP_H and dy <= JUMP_APEX + JUMP_MARGIN and Vector2(c.x - p.x, c.z - p.z).length() <= REACH_H \
				and _player_reachable(ctx, nav):
			return c
	return null


## A navmesh path from the first PLAYER spawn ends at `nav` (cached on a 0.5 m grid). No spawn: true.
func _player_reachable(ctx: LcContext, nav: Vector3) -> bool:
	if _spawn_nav == null:
		return true
	var key: Vector3i = Vector3i((nav * 2.0).round())
	if _reach_cache.has(key):
		return _reach_cache[key]
	var path: PackedVector3Array = ctx.nav_path(_spawn_nav, nav)
	var ok: bool = false
	if not path.is_empty():
		var e: Vector3 = path[path.size() - 1]
		ok = Vector2(e.x - nav.x, e.z - nav.z).length() <= PATH_H_TOL and absf(e.y - nav.y) <= PATH_V_TOL
	_reach_cache[key] = ok
	return ok


## The collision floor under a navmesh point (navmesh polygons float up to ~0.2 m above it).
func _floor_under(ctx: LcContext, c: Vector3) -> Vector3:
	var hit: Dictionary = ctx.ray(c + Vector3.UP * 0.05, c + Vector3.DOWN * 0.5, ctx.accept_any_active)
	return c if hit.is_empty() else (hit["position"] as Vector3)


func _in_play_space(ctx: LcContext, hit: Dictionary) -> bool:
	var room: RoomVolume = ctx.room_at((hit["position"] as Vector3) + Vector3.UP * 0.1)
	if room == null:
		return false
	if not (room.purpose in OUTDOOR_PURPOSES):
		return true
	var pr: LcProp = ctx.prop_of(hit.get("collider"))
	return pr != null and not (pr.kind in LcContext.SHELL_KINDS or pr.is_door)
