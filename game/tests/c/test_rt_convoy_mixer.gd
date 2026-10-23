## Rolling Thunder phase 2: Reyes's mixer (D-149.8, the LEAD's ruling of 2026-10-22). On the generated map, per route
## slot: a `Mixer` ConvoyVehicle waits in the site; every convoy layout has a `MixerStop` and a `MixerPath` that starts
## at the mixer, ends on the stop and arrives along the stop's +Z (the mover's heading); at its stop the mixer's
## footprint is clear of every other vehicle stop in the layout; and its body swept along the path (from 0.25 m over
## the road, every 0.5 m) meets no static collider (the shell, the hoarding, the dressing): only the Tannery gate's
## leaf (SiteTanneryGate), which A opens at the mixer move, is left out. Owner: ENV C.
extends TestCase

const MAP: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"
## veh_mixer_truck: [length, height, width]; the sweep box stands this far over the road (kerbs, ramps).
const SIZE: Vector3 = Vector3(8.0, 3.5, 2.5)
const LIFT_M: float = 0.25
const STEP_M: float = 0.5
const GAP_M: float = 0.15
## The tightest turn the 8 m truck may follow (the LEAD's r283 capture review: a 5 m turn out of the gate pivoted it
## almost on the spot): heading change per STEP_M <= STEP_M / MIN_TURN_R_M.
const MIN_TURN_R_M: float = 5.5
## Vehicle stop footprints [length, width] (rt_gameplay CONVOY_LEN / CONVOY_WIDTH).
const STOP_SIZE: Dictionary = {"car": Vector2(5.0, 2.0), "cash": Vector2(7.5, 2.5), "bullion": Vector2(9.0, 2.5)}

var _map: Node3D = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null
	await wait_frames(2)


func test_mixer_drives_from_the_site_to_each_layout_stop() -> void:
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	add_child(_map)
	await wait_physics_frames(3)
	var exclude: Array[RID] = _gate_bodies()
	for m: Node in _map.find_children("Mixer", "ConvoyVehicle", true, false):   # every route slot's (one is live)
		exclude.append_array(_bodies_of(m))
	var n: int = 0
	for movers: Node in _map.find_children("Movers", "", true, false):
		var convoy: Node = movers.get_parent()
		var mixer: ConvoyVehicle = movers.get_node_or_null(^"Mixer") as ConvoyVehicle
		assert_true(mixer != null, "%s has the Mixer mover" % convoy.get_path())
		if mixer == null:
			continue
		for l: Node in convoy.get_children():
			if not l.has_meta(&"convoy_layout"):
				continue
			var lid: String = String(l.get_meta(&"convoy_layout"))
			var stop: Node3D = l.get_node_or_null(^"MixerStop") as Node3D
			var path: Path3D = l.get_node_or_null(^"MixerPath") as Path3D
			assert_true(stop != null and path != null, "%s has MixerStop and MixerPath" % lid)
			if stop == null or path == null:
				continue
			var curve: Curve3D = path.curve
			var len: float = curve.get_baked_length()
			var p0: Vector3 = path.global_transform * curve.sample_baked(0.0)
			var p1: Vector3 = path.global_transform * curve.sample_baked(len)
			assert_true(p0.distance_to(mixer.global_position) < 0.05, "%s path starts at the mixer" % lid)
			assert_true(p1.distance_to(stop.global_position) < 0.05, "%s path ends on MixerStop" % lid)
			var tail: Vector3 = (p1 - path.global_transform * curve.sample_baked(len - 0.5)).normalized()
			assert_true(tail.dot(stop.global_basis.z) > 0.98, "%s arrives along the stop's +Z" % lid)
			var tightest: float = _tightest_turn(path)
			assert_true(tightest >= MIN_TURN_R_M, "%s turns on a %.1f m radius (< %.1f m)" % [lid, tightest,
				MIN_TURN_R_M])
			_check_clear_of_stops(l, stop, lid)
			var hits: PackedStringArray = _sweep(path, exclude)
			assert_true(hits.is_empty(), "%s drive meets static colliders: %s" % [lid, ", ".join(hits)])
			n += 1
	assert_eq(n, 4, "the four layouts checked")


## The tightest turning radius along `path` (top view; the heading change between 0.5 m chords).
func _tightest_turn(path: Path3D) -> float:
	var curve: Curve3D = path.curve
	var len: float = curve.get_baked_length()
	var best: float = INF
	var d: float = STEP_M
	while d + STEP_M <= len:
		var a: Vector3 = curve.sample_baked(d - STEP_M) - curve.sample_baked(d - 2.0 * STEP_M if d >= 2.0 * STEP_M
			else 0.0)
		var b: Vector3 = curve.sample_baked(d + STEP_M) - curve.sample_baked(d)
		var turn: float = absf(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))
		if turn > 0.0001:
			best = minf(best, 2.0 * STEP_M / turn)   # the two chords' centres are 2 STEP_M apart
		d += STEP_M
	return best


func _check_clear_of_stops(l: Node, stop: Node3D, lid: String) -> void:
	var mine: PackedVector2Array = _rect(stop.global_transform, Vector2(SIZE.x, SIZE.z), GAP_M)
	for c: Node in l.get_children():
		var kind: String = String(c.get_meta(&"vehicle_kind", ""))
		if c == stop or not STOP_SIZE.has(kind) or String(c.name) == "RearStop2":
			continue
		var other: PackedVector2Array = _rect((c as Node3D).global_transform, STOP_SIZE[kind], 0.0)
		assert_true(Geometry2D.intersect_polygons(mine, other).is_empty(),
			"%s: MixerStop overlaps %s" % [lid, c.name])


## A footprint (top view): [length along +Z, width along X] grown by `grow`.
static func _rect(xf: Transform3D, size: Vector2, grow: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var hl: float = size.x * 0.5 + grow
	var hw: float = size.y * 0.5 + grow
	for k: Vector2 in [Vector2(-hw, -hl), Vector2(hw, -hl), Vector2(hw, hl), Vector2(-hw, hl)]:
		var p: Vector3 = xf * Vector3(k.x, 0.0, k.y)
		out.append(Vector2(p.x, p.z))
	return out


## Names of the static bodies the mixer's box meets along `path`.
func _sweep(path: Path3D, exclude: Array[RID]) -> PackedStringArray:
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(SIZE.z, SIZE.y - LIFT_M, SIZE.x)
	q.shape = box
	q.collide_with_areas = false
	q.exclude = exclude
	var hits: Dictionary = {}
	var curve: Curve3D = path.curve
	var len: float = curve.get_baked_length()
	var d: float = 0.0
	while d <= len:
		var xf: Transform3D = path.global_transform * curve.sample_baked_with_rotation(d, false, true)
		# Curve3D's frame looks down -Z along the path; the mover's cab is +Z
		var basis: Basis = Basis.looking_at(xf.basis.z, Vector3.UP)
		q.transform = Transform3D(basis, xf.origin + Vector3.UP * (LIFT_M + (SIZE.y - LIFT_M) * 0.5))
		for h: Dictionary in space.intersect_shape(q, 8):
			var col: Object = h.get("collider")
			if col is StaticBody3D or col is AnimatableBody3D:
				hits[String(_map.get_path_to(col as Node))] = true
		d += STEP_M
	return PackedStringArray(hits.keys())


## The Tannery gates' bodies (A opens them before the mixer moves).
func _gate_bodies() -> Array[RID]:
	var out: Array[RID] = []
	for nm: String in ["SiteTanneryGate"]:
		var g: Node = _map.find_child(nm, true, false)
		if g != null:
			out.append_array(_bodies_of(g))
	return out


static func _bodies_of(n: Node) -> Array[RID]:
	var out: Array[RID] = []
	for c: Node in n.find_children("*", "CollisionObject3D", true, false):
		out.append((c as CollisionObject3D).get_rid())
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	return out
