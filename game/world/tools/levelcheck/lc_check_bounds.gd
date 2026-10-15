## bounds (final): no reachable point sees the void or through a back face. From navmesh
## samples at eye height (1.65 m), rays in 16 yaw x 5 pitch directions (+ straight up) are cast
## against single-sided proxies of the *visual* meshes (LcContext.build_proxies). A ray must hit
## a front face within 500 m; rays pitched upward may instead escape to the sky when the map's
## WorldEnvironment has a sky background. Only navmesh a player can reach from a player spawn is sampled (police-only
## islands such as a roof reached by one-way rappel links are never stood on by the crew; PO6-17).
class_name LcCheckBounds
extends LcCheck

const EYE: float = 1.65
const RANGE: float = 500.0
const MAX_SAMPLES: int = 300
const YAWS: int = 16
const PITCHES: Array[float] = [-30.0, -10.0, 0.0, 15.0, 45.0]
const MAX_REPORTS: int = 25
## A sample counts as player-reachable when the path from a player spawn ends this close to it.
const REACH_TOL_M: float = 0.6


var _skipped: int = 0


func _init() -> void:
	id = &"bounds"
	title = "No void / back faces"
	stages = PackedStringArray(["final"])


func run(ctx: LcContext) -> void:
	if not ctx.has_navmesh():
		fail(ctx, ctx.map, null, "no navmesh; bounds not checked")
		return
	var sky: bool = _has_sky(ctx)
	await LcVisual.build_proxies(ctx)
	var pts: PackedVector3Array = _player_reachable(ctx, ctx.navmesh_centroids())
	var stride: int = maxi(1, int(ceil(float(pts.size()) / float(MAX_SAMPLES))))
	var dirs: Array[Vector3] = []
	for yi: int in range(YAWS):
		var yaw: float = TAU * float(yi) / float(YAWS)
		for pd: float in PITCHES:
			var pr: float = deg_to_rad(pd)
			dirs.append(Vector3(sin(yaw) * cos(pr), sin(pr), cos(yaw) * cos(pr)))
	dirs.append(Vector3.UP)
	var rays: int = 0
	var bad: int = 0
	for i: int in range(0, pts.size(), stride):
		var eye: Vector3 = pts[i] + Vector3.UP * EYE
		for d: Vector3 in dirs:
			rays += 1
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + d * RANGE, LcContext.PROXY_LAYER)
			var hit: Dictionary = ctx.space().intersect_ray(q)
			if not hit.is_empty():
				continue
			if d.y > 0.01 and sky:
				continue
			bad += 1
			if bad <= MAX_REPORTS:
				fail(ctx, ctx.map, eye, "eye ray toward %s sees the void or a back face (nothing front-facing within %.0f m)"
					% [LcCheck.fmt_v(d), RANGE])
	LcVisual.free_proxies(ctx)
	if _skipped > 0:
		note("%d navmesh sample(s) skipped: not reachable from a player spawn (police-only)" % _skipped)
	if bad > MAX_REPORTS:
		fail(ctx, ctx.map, null, "%d more void rays not listed" % (bad - MAX_REPORTS))
	note("%d eye samples, %d rays, sky %s, %d void ray(s)" % [ceili(float(pts.size()) / float(stride)), rays,
		"yes" if sky else "no", bad])


static func _has_sky(ctx: LcContext) -> bool:
	for n: Node in ctx.map.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env != null and env.background_mode == Environment.BG_SKY and env.sky != null:
			return true
	return false


## Samples reachable from the first player spawn (doors open, every nav layer: the crew's reach). No spawn: all.
func _player_reachable(ctx: LcContext, pts: PackedVector3Array) -> PackedVector3Array:
	_skipped = 0
	var spawns: Array[SpawnPoint] = LcTargets.player_spawns(ctx)
	if spawns.is_empty():
		return pts
	var from: Vector3 = spawns[0].global_position
	var out: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in pts:
		var path: PackedVector3Array = ctx.nav_path(from, p)
		if not path.is_empty() and path[path.size() - 1].distance_to(p) <= REACH_TOL_M:
			out.append(p)
		else:
			_skipped += 1
	return out
