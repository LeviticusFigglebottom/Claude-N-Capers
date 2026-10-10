## navmesh: baked navmesh exists, covers walkable floors in rooms, carries no polygons on
## furniture, and every contract marker sits on it (heist_map.md §3, level_standards §4).
class_name LcCheckNavmesh
extends LcCheck

const MARKER_H_TOL: float = 0.25
const MARKER_V_TOL: float = 0.5
const COVER_STEP: float = 0.5
const MAX_SAMPLES_PER_ROOM: int = 900
const COVER_MIN: float = 0.95
## Clearance probe: a walkable sample must fit this cylinder (agent radius 0.35 + margin).
const CLEAR_RADIUS: float = 0.5
const CLEAR_HEIGHT: float = 1.6
const MAX_SLOPE_DEG: float = 40.0
const COVER_H_TOL: float = 0.3


func _init() -> void:
	id = &"navmesh"
	title = "Navmesh"


func run(ctx: LcContext) -> void:
	if not ctx.has_navmesh():
		fail(ctx, ctx.map, null, "no baked navmesh in `Navigation` (bake and commit it)")
		return
	_check_settings(ctx)
	_check_markers(ctx)
	_check_coverage(ctx)
	_check_furniture(ctx)


## heist_map.md §3: agent radius 0.35, height 1.8, climb 0.3, slope 40; layer `walkable` (bit 1).
func _check_settings(ctx: LcContext) -> void:
	var nm: NavigationMesh = ctx.nav_region.navigation_mesh
	var want: Dictionary = {"agent_radius": 0.35, "agent_height": 1.8, "agent_max_climb": 0.3, "agent_max_slope": 40.0}
	for k: String in want.keys():
		if absf(float(nm.get(k)) - float(want[k])) > 0.001:
			fail(ctx, ctx.nav_region, null, "navmesh %s = %.2f, contract says %.2f" % [k, nm.get(k), want[k]])
	if (ctx.nav_region.navigation_layers & 1) == 0:
		fail(ctx, ctx.nav_region, null, "Navigation region is not on navigation layer 1 (`walkable`)")
	note("navmesh: %d polygons, cell %.2f/%.2f m" % [nm.get_polygon_count(), nm.cell_size, nm.cell_height])


func _check_markers(ctx: LcContext) -> void:
	var markers: Array[Node3D] = LcTargets.nav_markers(ctx)
	for m: Node3D in markers:
		var p: Vector3 = m.global_position
		var c: Vector3 = ctx.nav_closest(p)
		var dh: float = Vector2(c.x - p.x, c.z - p.z).length()
		var dv: float = absf(c.y - p.y)
		if dh > MARKER_H_TOL or dv > MARKER_V_TOL:
			fail(ctx, m, p, "%.2f m (h) / %.2f m (v) from navmesh; markers must be within %.2f m (h), %.2f m (v)"
				% [dh, dv, MARKER_H_TOL, MARKER_V_TOL])
	note("%d markers checked" % markers.size())


func _check_coverage(ctx: LcContext) -> void:
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = CLEAR_RADIUS
	cyl.height = CLEAR_HEIGHT
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.collision_mask = LcContext.QUERY_MASK
	var min_ny: float = cos(deg_to_rad(MAX_SLOPE_DEG))
	note("| room | walkable samples | covered | coverage |")
	note("|---|---|---|---|")
	for r: RoomVolume in ctx.rooms:
		var step: float = COVER_STEP
		var area: float = LcAreas.footprint(r)
		if area / (step * step) > MAX_SAMPLES_PER_ROOM:
			step = sqrt(area / MAX_SAMPLES_PER_ROOM)
		var walk: int = 0
		var covered: int = 0
		var missing: PackedVector3Array = PackedVector3Array()
		for s: Vector3 in LcAreas.floor_grid(r, step, CLEAR_RADIUS):
			var fl: Dictionary = ctx.shell_floor(s, 1.0, 0.6)
			if fl.is_empty() or (fl["normal"] as Vector3).y < min_ny:
				continue
			var fp: Vector3 = fl["position"]
			q.transform = Transform3D(Basis(), fp + Vector3.UP * (0.35 + CLEAR_HEIGHT * 0.5))
			var hits: Array[Dictionary] = ctx.space().intersect_shape(q, 4)
			var blocked: bool = false
			for h: Dictionary in hits:
				if ctx.accept_any_active(h):
					blocked = true
					break
			if blocked:
				continue
			walk += 1
			var c: Vector3 = ctx.nav_closest(fp)
			if Vector2(c.x - fp.x, c.z - fp.z).length() <= COVER_H_TOL and absf(c.y - fp.y) <= 0.5:
				covered += 1
			else:
				missing.append(fp)
		var frac: float = float(covered) / float(walk) if walk > 0 else 1.0
		note("| `%s` | %d | %d | %.0f%% |" % [ctx.node_path(r), walk, covered, frac * 100.0])
		if frac < COVER_MIN:
			fail(ctx, r, null, "navmesh covers %.0f%% of walkable floor samples (need >= %.0f%%)"
				% [frac * 100.0, COVER_MIN * 100.0])
			for mp: Vector3 in missing.slice(0, 5):
				fail(ctx, r, mp, "walkable floor not on navmesh")


## No navmesh on counters/tables: polygons whose supporting surface is a prop (unless meta walkable).
func _check_furniture(ctx: LcContext) -> void:
	var bad: Dictionary = {}
	for c: Vector3 in ctx.navmesh_centroids():
		var hit: Dictionary = ctx.ray(c + Vector3.UP * 0.4, c + Vector3.DOWN * 0.6, ctx.accept_any_active)
		if hit.is_empty():
			continue
		var p: LcProp = ctx.prop_of(hit.get("collider"))
		if p != null and not p.is_door and p.kind != &"stairs" and not LcUtil.meta_b(p.node, &"walkable"):
			if not bad.has(p):
				bad[p] = c
	for p2: LcProp in bad.keys():
		fail(ctx, p2.node, bad[p2], "navmesh polygon on top of a prop (counter/table); bake with props as obstacles or mark meta walkable")
