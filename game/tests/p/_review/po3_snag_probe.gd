## PO-3 snag probe ("can't walk up a slight bump in the road"). Sweeps the walkable floor of a heist with the REAL
## CrewController (bot intents, no input device) and reports SNAG POINTS: places where the crew stops on a height
## change it should walk over (kerb, lip, threshold, ramp, stair, trimesh seam). Run as a SCENE (autoloads), headless,
## with --fixed-fps so game time runs as fast as the CPU allows (physics delta stays 1/60 s):
##   timeout 1200 /opt/godot/godot --headless --fixed-fps 60 --path game res://tests/p/_review/po3_snag_probe.tscn \
##     -- --heist=glasshouse [--spacing=1.0] [--max_trials=20000] [--max_samples=40000] [--out=/abs/dir]
##        [--stance=walk|sprint|crouch] [--masked] [--dirs=8|16] [--approach=run|touch] [--closed_doors]
##        [--offset=0.37] [--tag=name]   (doors are unlocked and opened unless --closed_doors)
##   --approach=touch starts each tier-1 trial from a standstill already touching the obstacle (no run-up).
##   --seed=N (default 1002) and --map=res://...tscn (a map scene not yet in the heist registry, e.g. a G1 greybox).
##   Ostrander Federal G1 (OF-P1, next_heist_ostrander.md §4 "PO-3 snag probe 0" before G2):
##     timeout 3600 /opt/godot/godot --headless --fixed-fps 60 --path game res://tests/p/_review/po3_snag_probe.tscn \
##       -- --heist=ostrander_federal --out=/abs/dir [--map=res://world/heists/ostrander_federal/ostrander_federal.tscn]
##     The bank has 5 levels and a large site: raise --max_samples / --max_trials (e.g. 120000 / 40000) if the summary
##     says it hit the cap. Pass = "[PO3] RESULT DONE ostrander_federal snags=0".
##   ... -- --selftest        synthetic check on ATestMaps.basic (0.2 m kerb climbs, 0.6 m box blocks)
## Output: <out>/<heist>.json + <heist>.txt (out = --out, else env PO3_OUT, else user://po3_snags/). Prints the text
## summary and "[PO3] RESULT ...". Method:
##  1. Floor samples: a grid of downward ray columns (crew collision mask; every walkable hit with 1.8 m headroom),
##     flood-filled from the map's player/guard/civilian spawns over "should be walkable" edges (8 neighbours).
##  2. An edge A->B "should be walkable" when the ground profile along it (0.1 m steps) never changes by more than
##     step_height_m - 3 cm, is never steeper than max_slope_deg - 1, and the body above step height (capsule
##     r 0.33 from +0.38 m to +1.78 m) is clear at every point: no wall / prop taller than a step in the way.
##  3. Trials: each crew (4 slots, all bot-driven, stealth_hidden) is teleported to A, settles, then walks toward B.
##     Edges with something to climb run first (tier 1), then flat trimesh floor (tier 2, seams), then a sparse
##     control sample of flat floor (tier 3). Not reaching B (0.4 m) = a snag; the stall is diagnosed by replaying
##     CrewController._step_up_rise's probes (read only; the controller is not modified).
## Owner: ENV P.
extends Node

const PROFILE_STEP_M: float = 0.1
const CLEAR_RADIUS_M: float = 0.33
const LIFT_BOTTOM_M: float = 0.38
const BODY_TOP_M: float = 1.78
const REACH_M: float = 0.4
const STALL_WINDOW: int = 15
const STALL_MIN_PROGRESS_M: float = 0.03
const MAX_WALK_TICKS: int = 90
const MAX_SETTLE_TICKS: int = 30
const MAX_HITS_PER_COLUMN: int = 12
const CLUSTER_M: float = 1.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
## --dirs=16 adds knight-move headings (2.2 m edges, ~27/63 deg to the grid) for shallow kerb approaches.
const DIRS16: Array[Vector2i] = [Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
	Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)]
const DY_BINS: PackedFloat32Array = [0.015, 0.05, 0.1, 0.2, 0.36]
const LAYER_NAMES: PackedStringArray = ["world_static", "world_dynamic", "players", "npcs", "hitboxes",
	"interactables", "loot", "vision_blockers", "bullet_penetrable", "triggers"]

var _args: Dictionary = {}
var _heist: StringName = &"glasshouse"
var _rt: HeistRuntime = null
var _tw: CrewTweak = null
var _space: PhysicsDirectSpaceState3D = null
var _mask: int = CrewController.COLLISION_MASK_WORLD
var _exclude: Array[RID] = []
var _spacing: float = 1.0
var _grid0: Vector2 = Vector2.ZERO
var _bounds: AABB = AABB()
var _max_slope: float = 0.0
var _q_lift: PhysicsShapeQueryParameters3D = null
var _q_full: PhysicsShapeQueryParameters3D = null
## Vector2i cell -> PackedFloat32Array of walkable floor heights (top first).
var _columns: Dictionary[Vector2i, PackedFloat32Array] = {}
var _clean: Dictionary[Vector3i, bool] = {}
var _edges: Array[Dictionary] = []
var _reject: Dictionary[String, int] = {}
var _ladder_pts: PackedVector3Array = PackedVector3Array()
var _ladders_cached: bool = false
var _samples: int = 0
var _seen: Dictionary[Vector3i, bool] = {}
var _seed_keys: Array[Vector3i] = []
var _trials: Array[Dictionary] = []
var _next: int = 0
var _results: Array[Dictionary] = []
var _workers_done: int = 0
var _visuals: Array[AABB] = []
var _t0: int = 0
var _stance: String = "walk"
var _not_normal_logged: int = 0
var _oob: Array[Node] = []
var _low_blockers: Dictionary[String, Dictionary] = {}
var _dirs: Array[Vector2i] = []
var _ticks: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_heist = StringName(String(_args.get("heist", "glasshouse")))
	_spacing = float(String(_args.get("spacing", "1.0")))
	_tw = Tweak.crew()
	_stance = String(_args.get("stance", "walk"))
	_dirs = DIRS.duplicate()
	if String(_args.get("dirs", "8")) == "16":
		_dirs.append_array(DIRS16)
	_max_slope = deg_to_rad(_tw.max_slope_deg)
	_t0 = Time.get_ticks_msec()
	await get_tree().process_frame
	var code: int = 0
	if _args.has("selftest"):
		code = await _selftest()
	else:
		code = await _probe_heist()
	get_tree().quit(code)


func _physics_process(_delta: float) -> void:
	_ticks += 1


# --- Launch ------------------------------------------------------------------------------------------------

func _launch(heist: StringName, packed: PackedScene) -> bool:
	var opts: Dictionary = {"ai_teammates": 3, "crew_ai": false}
	if packed != null:
		opts["map_packed"] = packed
	elif _args.has("map"):
		opts["map_scene"] = String(_args["map"])
	_rt = await HeistLauncher.launch(heist, _seed(), Enums.Difficulty.ROUTINE, self, opts)
	if _rt == null:
		print("[PO3] RESULT FAIL launch %s" % heist)
		return false
	_rt.isolate_npc(null)
	# Stated shortcut: alarm devices off. A bot walking a laser sends the heist loud and the director parks assault
	# props (OF 2026-10-20: AssaultEvent_turret_van on Halloran Avenue, 62 of 134 "snags"); this probe tests geometry.
	var quiet: int = 0
	for cls: String in ["LaserGrid", "SecurityCamera"]:
		for n: Node in _rt.find_children("*", cls, true, false):
			if n.has_method(&"set_enabled"):
				n.call(&"set_enabled", false)
				quiet += 1
	print("[PO3] SHORTCUT %d lasers / cameras disabled (no alarm, no assault props)" % quiet)
	if not _args.has("closed_doors"):  # a player opens doors: open (and unlock) all so the sweep reaches inside
		for n: Node in _rt.find_children("*", "Door", true, false):
			(n as Door).unlock()
			(n as Door).set_open(true)
	await _physics(10)
	_space = get_viewport().world_3d.direct_space_state
	_exclude = []
	for c: CrewController in _rt.crew_members():
		_exclude.append(c.get_rid())
		c.stealth_hidden = true
		if _stance != "walk" or _args.has("masked"):
			c.set_masked()  # sprint / crouch are refused while casing (S1.1)
		_rt.set_bot_intent(c.slot, _intent(c.look_yaw, 0.0))
	_q_lift = _capsule_query(CLEAR_RADIUS_M, BODY_TOP_M - LIFT_BOTTOM_M)
	_q_full = _capsule_query(_tw.capsule_radius, _tw.height_standing - 0.04)
	return true


func _seed() -> int:
	return int(String(_args.get("seed", "1002")))


func _capsule_query(radius: float, height: float) -> PhysicsShapeQueryParameters3D:
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = _mask
	q.exclude = _exclude
	q.margin = 0.0
	return q


func _probe_heist() -> int:
	if not await _launch(_heist, null):
		return 1
	var t_launch: float = _elapsed()
	_compute_bounds()
	_collect_visuals()
	_flood(_seeds(), int(String(_args.get("max_samples", "40000"))))
	var t_flood: float = _elapsed()
	_pick_trials(int(String(_args.get("max_trials", "20000"))))
	await _run_trials()
	var t_trials: float = _elapsed()
	var rep: Dictionary = _report({"launch_s": t_launch, "flood_s": t_flood - t_launch, "trials_s": t_trials - t_flood})
	_write(String(_heist) + String(_args.get("tag", "")), rep)
	print("[PO3] RESULT DONE %s snags=%d clusters=%d trials=%d wall=%.0fs" % [_heist, (rep["snags"] as Array).size(),
		(rep["clusters"] as Array).size(), _results.size(), _elapsed()])
	_rt.teardown()
	return 0


# --- Floor sampling ----------------------------------------------------------------------------------------

func _compute_bounds() -> void:
	var first: bool = true
	for n: Node in _rt.find_children("*", "CollisionObject3D", true, false):
		var co: CollisionObject3D = n as CollisionObject3D
		if co is Area3D or co is CrewController or (co.collision_layer & _mask) == 0:
			continue
		for oid: int in co.get_shape_owners():
			var cs: Node3D = co.shape_owner_get_owner(oid) as Node3D
			if cs == null:
				continue
			for k: int in range(co.shape_owner_get_shape_count(oid)):
				var sh: Shape3D = co.shape_owner_get_shape(oid, k)
				if sh == null or sh is WorldBoundaryShape3D:
					continue
				var bb: AABB = cs.global_transform * sh.get_debug_mesh().get_aabb()
				if bb.size.x > 500.0 or bb.size.z > 500.0:
					continue
				_bounds = bb if first else _bounds.merge(bb)
				first = false
	_grid0 = Vector2(_bounds.position.x, _bounds.position.z) + Vector2.ONE * float(String(_args.get("offset", "0.37")))


func _collect_visuals() -> void:
	_visuals = []
	for n: Node in _rt.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		if gi is VisualInstance3D and gi.is_visible_in_tree() and not _is_crew_part(gi):
			_visuals.append(gi.global_transform * gi.get_aabb())


func _is_crew_part(n: Node) -> bool:
	var p: Node = n
	while p != null:
		if p is CrewController:
			return true
		p = p.get_parent()
	return false


func _cell_xz(cell: Vector2i) -> Vector2:
	return _grid0 + Vector2(cell) * _spacing


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x - _grid0.x) / _spacing), roundi((p.z - _grid0.y) / _spacing))


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, _mask, _exclude)
	return _space.intersect_ray(q)


func _walkable_normal(n: Vector3, slack_deg: float = 0.0) -> bool:
	return n.angle_to(Vector3.UP) <= _max_slope - deg_to_rad(slack_deg)


func _column(cell: Vector2i) -> PackedFloat32Array:
	if _columns.has(cell):
		return _columns[cell]
	var out: PackedFloat32Array = PackedFloat32Array()
	var xz: Vector2 = _cell_xz(cell)
	var y: float = _bounds.end.y + 1.0
	var bottom: float = _bounds.position.y - 1.0
	for _k: int in range(MAX_HITS_PER_COLUMN):
		var hit: Dictionary = _ray(Vector3(xz.x, y, xz.y), Vector3(xz.x, bottom, xz.y))
		if hit.is_empty():
			break
		var p: Vector3 = hit["position"]
		if _walkable_normal(hit["normal"]) and _ray(p + Vector3.UP * 0.05, p + Vector3.UP * 1.85).is_empty():
			out.append(p.y)
		y = p.y - 0.03
	_columns[cell] = out
	return out


## Index of the floor in `cell` within `tol` of `y`, or -1.
func _level(cell: Vector2i, y: float, tol: float) -> int:
	var col: PackedFloat32Array = _column(cell)
	var best: int = -1
	for k: int in range(col.size()):
		if absf(col[k] - y) <= tol and (best < 0 or absf(col[k] - y) < absf(col[best] - y)):
			best = k
	return best


func _sample_pos(key: Vector3i) -> Vector3:
	var xz: Vector2 = _cell_xz(Vector2i(key.x, key.y))
	return Vector3(xz.x, _column(Vector2i(key.x, key.y))[key.z], xz.y)


func _body_free(q: PhysicsShapeQueryParameters3D, feet: Vector3, bottom: float) -> bool:
	var cap: CapsuleShape3D = q.shape as CapsuleShape3D
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (bottom + cap.height * 0.5))
	return _space.intersect_shape(q, 1).is_empty()


func _is_clean(key: Vector3i) -> bool:
	if not _clean.has(key):
		_clean[key] = _body_free(_q_full, _sample_pos(key), 0.04)
	return _clean[key]


func _seeds() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var pts: Array[Vector3] = []
	for c: CrewController in _rt.crew_members():
		pts.append(c.global_position)
	for n: Node in _rt.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n as SpawnPoint
		if sp.kind in [SpawnPoint.Kind.PLAYER, SpawnPoint.Kind.GUARD, SpawnPoint.Kind.CIVILIAN, SpawnPoint.Kind.CAMERA_OPERATOR]:
			pts.append(sp.global_position)
	for p: Vector3 in pts:
		var c0: Vector2i = _cell_of(p)
		var found: bool = false
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				if found:
					continue
				var cell: Vector2i = c0 + Vector2i(dx, dz)
				var lv: int = _level(cell, p.y - 0.05, 0.8)
				if lv >= 0:
					out.append(Vector3i(cell.x, cell.y, lv))
					found = true
	return out


## Ground profile from `a` (on the floor) toward `bxz`. {"ok", "reason", "end_y", "max_dy", "max_slope_deg",
## "collider_change", "trimesh", "low_touch"}.
func _profile(a: Vector3, bxz: Vector2) -> Dictionary:
	var axz: Vector2 = Vector2(a.x, a.z)
	var n: int = ceili(axz.distance_to(bxz) / PROFILE_STEP_M)
	var g: float = a.y
	var r: Dictionary = {"ok": false, "reason": "", "end_y": a.y, "max_dy": 0.0, "max_slope_deg": 0.0,
		"collider_change": false, "trimesh": false, "low_touch": false}
	var lim: float = _tw.step_height_m - 0.03
	var prev_id: String = ""
	for k: int in range(1, n + 1):
		var xz: Vector2 = axz.lerp(bxz, float(k) / float(n))
		var hit: Dictionary = _ray(Vector3(xz.x, g + _tw.step_height_m + 0.05, xz.y),
			Vector3(xz.x, g - _tw.step_height_m - 0.05, xz.y))
		if hit.is_empty():
			r["reason"] = "gap"
			return r
		var nrm: Vector3 = hit["normal"]
		if not _walkable_normal(nrm, 1.0):
			r["reason"] = "steep"
			return r
		var y: float = (hit["position"] as Vector3).y
		if absf(y - g) > lim:
			r["reason"] = "tall"
			return r
		r["max_dy"] = maxf(float(r["max_dy"]), absf(y - g))
		r["max_slope_deg"] = maxf(float(r["max_slope_deg"]), rad_to_deg(nrm.angle_to(Vector3.UP)))
		var gid: String = "%d:%d" % [int(hit["collider_id"]), int(hit["shape"])]
		if prev_id != "" and gid != prev_id:
			r["collider_change"] = true
		prev_id = gid
		if _shape_of(hit["collider"], int(hit["shape"])) is ConcavePolygonShape3D:
			r["trimesh"] = true
		g = y
		var feet: Vector3 = Vector3(xz.x, g, xz.y)
		if k % 2 == 0 or k == n:
			if not _body_free(_q_lift, feet, LIFT_BOTTOM_M):
				r["reason"] = "blocked"
				_note_low_blockers(feet)
				return r
			if not bool(r["low_touch"]) and not _body_free(_q_full, feet, 0.04):
				r["low_touch"] = true
	r["ok"] = true
	r["end_y"] = g
	return r


## Blockers of a "should be walkable" check whose collider top is only 0.32-0.75 m above the floor: things just
## too tall to step (kerb-like boxes, low walls, bench seats). They are excluded from trials, so list them: a
## collider much taller than its visual (a 0.15 m kerb with a 0.4 m box) would hide here.
func _note_low_blockers(feet: Vector3) -> void:
	var cap: CapsuleShape3D = _q_lift.shape as CapsuleShape3D
	_q_lift.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (LIFT_BOTTOM_M + cap.height * 0.5))
	for hit: Dictionary in _space.intersect_shape(_q_lift, 4):
		var co: CollisionObject3D = hit["collider"] as CollisionObject3D
		var sh: Shape3D = _shape_of(co, int(hit["shape"]))
		var oid: int = co.shape_find_owner(int(hit["shape"])) if co != null else -1
		if sh == null or oid < 0:
			continue
		var own: Node3D = co.shape_owner_get_owner(oid) as Node3D
		if own == null:
			continue
		var top: float = (own.global_transform * sh.get_debug_mesh().get_aabb()).end.y - feet.y
		if top < _tw.step_height_m - 0.03 or top > 0.75:
			continue
		var key: String = String(_rt.get_path_to(own))
		if not _low_blockers.has(key):
			var d: Dictionary = _describe(co, int(hit["shape"]))
			d["count"] = 0
			d["top_above_floor_m"] = top
			d["at"] = feet
			d["visible_mesh_top"] = _visual_top(own.global_position, feet.y)
			_low_blockers[key] = d
		_low_blockers[key]["count"] = int(_low_blockers[key]["count"]) + 1


## Highest visual AABB top (above `floor_y`) among visuals containing the xz of `p` and starting near the floor.
func _visual_top(p: Vector3, floor_y: float) -> float:
	var best: float = NAN
	for bb: AABB in _visuals:
		if p.x >= bb.position.x and p.x <= bb.end.x and p.z >= bb.position.z and p.z <= bb.end.z \
				and bb.position.y < floor_y + 0.3 and bb.end.y - floor_y < 3.0:
			best = bb.end.y - floor_y if is_nan(best) else maxf(best, bb.end.y - floor_y)
	return best


func _is_oob(p: Vector3) -> bool:
	for n: Node in _oob:
		if ZoneUtil.contains(n as Area3D, p + Vector3.UP * OutOfBoundsSystem.CREW_PROBE_UP_M):
			return true
	return false


func _flood(seeds: Array[Vector3i], max_samples: int) -> void:
	_oob = []
	for n: Node in get_tree().get_nodes_in_group(OutOfBoundsSystem.ZONE_GROUP):
		if n is Area3D and _rt.is_ancestor_of(n):
			_oob.append(n)
	var seen: Dictionary[Vector3i, bool] = _seen
	_seed_keys = seeds
	var queue: Array[Vector3i] = []
	for s: Vector3i in seeds:
		if not seen.has(s):
			seen[s] = true
			queue.append(s)
	var head: int = 0
	while head < queue.size() and head < max_samples:
		var key: Vector3i = queue[head]
		head += 1
		var a: Vector3 = _sample_pos(key)
		for d: Vector2i in _dirs:
			var cell: Vector2i = Vector2i(key.x, key.y) + d
			var prof: Dictionary = _profile(a, _cell_xz(cell))
			if not bool(prof["ok"]):
				_reject[prof["reason"]] = _reject.get(prof["reason"], 0) + 1
				continue
			var lv: int = _level(cell, prof["end_y"], 0.12)
			if lv < 0:
				_reject["no_sample"] = _reject.get("no_sample", 0) + 1
				continue
			var tk: Vector3i = Vector3i(cell.x, cell.y, lv)
			if _is_oob(_sample_pos(tk)):
				_reject["out_of_bounds_zone"] = _reject.get("out_of_bounds_zone", 0) + 1
				continue
			if not seen.has(tk):
				seen[tk] = true
				queue.append(tk)
			var b: Vector3 = _sample_pos(tk)
			var interest: PackedStringArray = []
			if float(prof["max_dy"]) > 0.015:
				interest.append("dy%.2f" % float(prof["max_dy"]))
			if float(prof["max_slope_deg"]) > 3.0:
				interest.append("slope%d" % int(prof["max_slope_deg"]))
			if bool(prof["collider_change"]):
				interest.append("seam")
			if bool(prof["low_touch"]):
				interest.append("low_touch")
			if _near_ladder(a) or _near_ladder(b):  # a masked crew in a ladder's grab cone climbs it: not a snag (C)
				_reject["ladder_grab"] = _reject.get("ladder_grab", 0) + 1
				continue
			var tier: int = 1 if not interest.is_empty() else (2 if bool(prof["trimesh"]) else 3)
			_edges.append({"a": a, "b": b, "a_key": key, "tier": tier, "interest": interest, "max_dy": prof["max_dy"],
				"trimesh": bool(prof["trimesh"])})
	_samples = mini(queue.size(), max_samples)
	print("[PO3] %s: bounds %s, %d samples reached (%d queued), %d walkable edges, rejected %s, %.1fs" % [
		_heist, _bounds, _samples, queue.size(), _edges.size(), _reject, _elapsed()])


## Ladder grab points (Bottom / Top) in the heist, cached on first use.
func _ladder_points() -> PackedVector3Array:
	if _ladders_cached:
		return _ladder_pts
	_ladders_cached = true
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var l: Ladder = n as Ladder
		if l != null:
			_ladder_pts.append(l.bottom_position())
			_ladder_pts.append(l.top_position())
		stack.append_array(n.get_children())
	return _ladder_pts


## Within a ladder's grab radius (+ the capsule and a margin) of a grab point, at about its height.
func _near_ladder(p: Vector3) -> bool:
	var r: float = Tweak.interaction().ladder_grab_radius_m + 0.6
	for q: Vector3 in _ladder_points():
		if Vector2(p.x - q.x, p.z - q.z).length() <= r and absf(p.y - q.y) <= 1.0:
			return true
	return false


func _pick_trials(budget: int) -> void:
	var by_tier: Array[Array] = [[], [], [], []]
	for e: Dictionary in _edges:
		if _is_clean(e["a_key"]):
			by_tier[int(e["tier"])].append(e)
		else:
			_reject["start_not_clean"] = _reject.get("start_not_clean", 0) + 1
	_trials = []
	var tiers: Array[int] = [1, 2, 3]
	if _args.get("approach", "run") == "touch":
		tiers = [1]
	for t: int in tiers:
		var pool: Array = by_tier[t]
		var left: int = budget - _trials.size()
		if left <= 0 or pool.is_empty():
			continue
		var stride: float = float(pool.size()) / float(mini(pool.size(), left))
		var f: float = 0.0
		while int(f) < pool.size() and _trials.size() < budget:
			_trials.append(pool[int(f)])
			f += stride
	print("[PO3] trial edges by tier: t1 %d, t2 %d, t3 %d -> running %d" % [by_tier[1].size(), by_tier[2].size(),
		by_tier[3].size(), _trials.size()])


# --- Trials ------------------------------------------------------------------------------------------------

## Teleport `c` to `pos` facing `yaw` and wait until it stands (true) or MAX_SETTLE_TICKS pass.
func _place(c: CrewController, pos: Vector3, yaw: float) -> bool:
	_rt.teleport_crew(c.slot, Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * 0.05))
	for t: int in range(MAX_SETTLE_TICKS):
		await get_tree().physics_frame
		if t >= 3 and c.grounded:
			break
	return c.grounded


func _intent(yaw: float, fwd: float) -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0.0, fwd)
	i.look_yaw = yaw
	i.sprint = _stance == "sprint" and fwd > 0.0
	i.crouch = _stance == "crouch"
	return i


func _physics(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _run_trials() -> void:
	_next = 0
	_results = []
	_workers_done = 0
	var crews: Array[CrewController] = _rt.crew_members()
	for c: CrewController in crews:
		_worker(c)
	var last: int = -1
	var tick: int = 0
	while _workers_done < crews.size():
		await get_tree().physics_frame
		tick += 1
		if tick % 30 == 0:
			_rt.isolate_npc(null)  # loud heists keep spawning police
		if floori(_results.size() / 500.0) != last:
			last = floori(_results.size() / 500.0)
			print("[PO3] trials %d/%d, %.0fs" % [_results.size(), _trials.size(), _elapsed()])


func _worker(c: CrewController) -> void:
	while _next < _trials.size():
		var e: Dictionary = _trials[_next]
		_next += 1
		var r: Dictionary = await _trial(c, e["a"], e["b"])
		r["tier"] = e["tier"]
		r["max_dy"] = e["max_dy"]
		r["interest"] = e["interest"]
		_results.append(r)
	_workers_done += 1


## Teleport `c` to `a`, settle, walk toward `b`. Returns the outcome; failures carry a diagnosis.
func _trial(c: CrewController, a: Vector3, b: Vector3) -> Dictionary:
	var d: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	var dist: float = d.length()
	var dir: Vector3 = d / dist
	var yaw: float = atan2(-dir.x, -dir.z)
	var r: Dictionary = {"a": a, "b": b, "heading_deg": fposmod(rad_to_deg(yaw), 360.0), "dh": b.y - a.y,
		"status": "ok"}
	c.stealth_hidden = true
	if c.crew_state != Enums.CrewState.NORMAL and c.health != null and c.crew_state != Enums.CrewState.CUSTODY:
		c.health.reset_full()  # loud heists (dockside_burn starts LOUD): police waves can down a crew between sweeps
		c.set_crew_state(Enums.CrewState.NORMAL)
	if c.crew_state != Enums.CrewState.NORMAL:
		r["status"] = "crew_not_normal"
		if _not_normal_logged < 5:
			_not_normal_logged += 1
			print("[PO3] slot %d state %s at %s, phase %s, ended %s" % [c.slot, Enums.CrewState.find_key(c.crew_state),
				_v3s(c.global_position), _rt.phase, _rt.get(&"_ended")])
		return r
	_rt.set_bot_intent(c.slot, _intent(yaw, 0.0))
	if not await _place(c, a, yaw):
		r["status"] = "start_not_grounded"
		return r
	if _args.get("approach", "run") == "touch":
		# Start from a standstill already touching whatever is in the way (walked up to the kerb and stopped).
		var tc: KinematicCollision3D = KinematicCollision3D.new()
		var lifted: Transform3D = c.global_transform.translated(Vector3.UP * 0.02)
		if not c.test_move(lifted, dir * dist, tc, c.safe_margin, false, 1):
			r["note"] = "no_contact"
			return r
		var tr: Vector3 = tc.get_travel()
		tr.y = 0.0
		if not await _place(c, c.global_position + tr - dir * 0.003, yaw):
			r["status"] = "start_not_grounded"
			return r
	var start: Vector3 = c.global_position
	_rt.set_bot_intent(c.slot, _intent(yaw, 1.0))
	var hist: PackedFloat32Array = PackedFloat32Array()
	var reached: bool = false
	var fell: bool = false
	for t: int in range(MAX_WALK_TICKS):
		await get_tree().physics_frame
		var p: Vector3 = c.global_position
		hist.append((p - start).dot(dir))
		if Vector2(p.x - b.x, p.z - b.z).length() <= REACH_M and absf(p.y - b.y) < 0.45:
			reached = true
			break
		if p.y < minf(a.y, b.y) - 1.0:
			fell = true
			break
		if t >= 20 and hist[t] - hist[t - STALL_WINDOW] < STALL_MIN_PROGRESS_M:
			break
	r["ticks"] = hist.size()
	if not reached and c.crew_state != Enums.CrewState.NORMAL:
		r["status"] = "crew_not_normal_midtrial"
	elif not reached:
		var p: Vector3 = c.global_position
		var lat: Vector3 = (p - start) - dir * (p - start).dot(dir)
		lat.y = 0.0
		r["status"] = "fell" if fell else ("deflected" if lat.length() > 0.4 else "stuck")
		r["stall"] = p
		r["progress_m"] = hist[hist.size() - 1] if not hist.is_empty() else 0.0
		r["dist_m"] = dist
		r["lateral_m"] = lat.length()
		r.merge(_diagnose(c, dir))
	_rt.set_bot_intent(c.slot, _intent(yaw, 0.0))
	return r


# --- Diagnosis ---------------------------------------------------------------------------------------------

func _shape_of(collider: Object, shape_idx: int) -> Shape3D:
	var co: CollisionObject3D = collider as CollisionObject3D
	if co == null:
		return null
	var oid: int = co.shape_find_owner(shape_idx)
	if oid < 0:
		return null
	var base: int = 0
	for o: int in co.get_shape_owners():
		if o == oid:
			break
		base += co.shape_owner_get_shape_count(o)
	var local: int = clampi(shape_idx - base, 0, maxi(co.shape_owner_get_shape_count(oid) - 1, 0))
	return co.shape_owner_get_shape(oid, local)


func _describe(collider: Object, shape_idx: int) -> Dictionary:
	var out: Dictionary = {"path": "", "class": "", "shape": "", "layer": "", "shape_node": ""}
	var co: CollisionObject3D = collider as CollisionObject3D
	if co == null:
		return out
	out["path"] = String(_rt.get_path_to(co))
	out["class"] = co.get_class()
	var sh: Shape3D = _shape_of(co, shape_idx)
	out["shape"] = sh.get_class() if sh != null else "?"
	if sh is BoxShape3D:
		out["shape"] = "BoxShape3D %s" % _v3s((sh as BoxShape3D).size)
	var oid: int = co.shape_find_owner(shape_idx)
	if oid >= 0:
		var own: Node = co.shape_owner_get_owner(oid) as Node
		out["shape_node"] = String(own.name) if own != null else ""
	var names: PackedStringArray = []
	for k: int in range(LAYER_NAMES.size()):
		if co.collision_layer & (1 << k):
			names.append(LAYER_NAMES[k])
	out["layer"] = "%d (%s)" % [co.collision_layer, ",".join(names)]
	return out


func _ground_like_controller(c: CrewController, feet: Vector3, depth: float) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.05,
		feet + Vector3.DOWN * (depth + 0.05), c.collision_mask, [c.get_rid()])
	var hit: Dictionary = _space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).angle_to(c.up_direction) > c.floor_max_angle + 0.01:
		return NAN
	return (hit["position"] as Vector3).y


## Replays CrewController._step_up_rise's probes at the stall (read only) and says which condition refused.
func _why_no_step(c: CrewController, h_motion: Vector3) -> String:
	var col: KinematicCollision3D = KinematicCollision3D.new()
	if not c.test_move(c.global_transform, h_motion, col, c.safe_margin, false, 4):
		return "no_contact_ahead"
	var wall: bool = false
	for k: int in range(col.get_collision_count()):
		if col.get_angle(k, c.up_direction) > c.floor_max_angle + 0.01:
			wall = true
	if not wall:
		return "contact_not_wall (all contacts <= max slope: step-up never tried)"
	var xf: Transform3D = c.global_transform
	var up: Vector3 = Vector3.UP * _tw.step_height_m
	if c.test_move(xf, up, col, c.safe_margin, false, 1):
		up = col.get_travel()
	xf.origin += up
	var fwd: Vector3 = h_motion
	if c.test_move(xf, h_motion, col, c.safe_margin, false, 1):
		fwd = col.get_travel()
	xf.origin += fwd
	var res: String = ""
	if up.y < 0.01:
		res = "no_headroom (up %.3f)" % up.y
	elif fwd.length() < h_motion.length() * 0.25:
		res = "blocked_at_step_height (fwd %.3f of %.3f)" % [fwd.length(), h_motion.length()]
	elif not c.test_move(xf, Vector3.DOWN * up.y, col, c.safe_margin, false, 1):
		res = "nothing_to_stand_on"
	else:
		var rise: float = xf.origin.y + col.get_travel().y - c.global_position.y
		var top: float = _ground_like_controller(c, col.get_position() + h_motion.normalized() * 0.03, 0.06)
		if rise <= 0.002:
			res = "rise_le_0 (%.4f)" % rise
		elif is_nan(top):
			res = "top_nan (no walkable ground 3 cm past the landing contact %s)" % _v3s(col.get_position())
		elif top - c.global_position.y > _tw.step_height_m + 0.005:
			res = "top_too_high (%.3f)" % (top - c.global_position.y)
		else:
			res = "step_ok (rise %.3f): step-up would succeed now" % rise
	return res


func _diagnose(c: CrewController, dir: Vector3) -> Dictionary:
	var out: Dictionary = {}
	var feet: Vector3 = c.global_position
	var h_motion: Vector3 = dir * _tw.walk_speed / float(Engine.physics_ticks_per_second)
	out["grounded"] = c.grounded
	out["why_no_step"] = _why_no_step(c, h_motion)
	var col: KinematicCollision3D = KinematicCollision3D.new()
	var contacts: Array[Dictionary] = []
	if c.test_move(c.global_transform, h_motion * 2.0, col, c.safe_margin, false, 4):
		for k: int in range(col.get_collision_count()):
			var info: Dictionary = _describe(col.get_collider(k), col.get_collider_shape_index(k))
			var cp: Vector3 = col.get_position(k)
			info["contact"] = cp
			info["contact_h"] = cp.y - feet.y
			info["normal"] = col.get_normal(k)
			info["angle_deg"] = rad_to_deg(col.get_angle(k, Vector3.UP))
			info["visible_mesh"] = _visible_at(cp)
			contacts.append(info)
	out["contacts"] = contacts
	# Floor height just ahead of the capsule (lip height) and under the feet.
	var ahead: Vector3 = feet + dir * (_tw.capsule_radius + 0.05)
	var hit: Dictionary = _ray(ahead + Vector3.UP * 0.7, ahead + Vector3.DOWN * 0.7)
	out["lip_h"] = (hit["position"] as Vector3).y - feet.y if not hit.is_empty() else NAN
	if not hit.is_empty():
		out["lip_collider"] = _describe(hit["collider"], int(hit["shape"]))
		out["lip_normal_deg"] = rad_to_deg((hit["normal"] as Vector3).angle_to(Vector3.UP))
	var under: Dictionary = _ray(feet + Vector3.UP * 0.05, feet + Vector3.DOWN * 0.5)
	if not under.is_empty():
		out["floor_collider"] = _describe(under["collider"], int(under["shape"]))
	out["verdict"] = _verdict(out)
	return out


func _visible_at(p: Vector3) -> bool:
	for bb: AABB in _visuals:
		if bb.grow(0.06).has_point(p):
			return true
	return false


func _verdict(d: Dictionary) -> String:
	var contacts: Array[Dictionary] = d["contacts"]
	var why: String = d["why_no_step"]
	var lip: float = d["lip_h"]
	var c0: Dictionary = contacts[0] if not contacts.is_empty() else {}
	var trimesh: bool = String(c0.get("shape", "")).begins_with("ConcavePolygon")
	var res: String = "unclear (%s)" % why.get_slice(" ", 0)
	if trimesh and absf(float(c0["contact_h"])) < 0.06 and (is_nan(lip) or absf(lip) < 0.03):
		res = "bad collision: trimesh seam / internal edge on a flat floor"
	elif not is_nan(lip) and lip > _tw.step_height_m + 0.005:
		res = "geometry: obstacle taller than a step just ahead (thin/offset collider the centre-line probe missed)"
	elif why.begins_with("blocked_at_step_height") or why.begins_with("no_headroom"):
		res = "geometry: blocked above step height (overhang / sill / narrow gap), not a step problem"
	elif not is_nan(lip) and lip > 0.02:
		res = "controller: did not climb a %.2f m lip (%s)" % [lip, why.get_slice(" ", 0)]
	elif why.begins_with("contact_not_wall"):
		res = "controller: stopped by a walkable-angle contact (slope/edge) without stepping"
	if not c0.is_empty() and not bool(c0["visible_mesh"]):
		res += " [no visible mesh at the contact: invisible collider?]"
	return res


# --- Report ------------------------------------------------------------------------------------------------

func _report(times: Dictionary) -> Dictionary:
	var snags: Array[Dictionary] = []
	var counts: Dictionary[String, int] = {}
	for r: Dictionary in _results:
		var st: String = r["status"]
		counts[st] = counts.get(st, 0) + 1
		if st in ["stuck", "deflected", "fell"]:
			snags.append(r)
	var clusters: Array[Dictionary] = []
	for s: Dictionary in snags:
		var p: Vector3 = s["stall"]
		var home: Dictionary = {}
		for cl: Dictionary in clusters:
			var cp: Vector3 = cl["center"]
			if Vector2(cp.x - p.x, cp.z - p.z).length() <= CLUSTER_M and absf(cp.y - p.y) < 0.5:
				home = cl
				break
		if home.is_empty():
			home = {"center": p, "members": []}
			clusters.append(home)
		var mem: Array = home["members"]
		mem.append(s)
		var cc: Vector3 = Vector3.ZERO
		for m: Dictionary in mem:
			cc += m["stall"] as Vector3
		home["center"] = cc / float(mem.size())
	clusters.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return (x["members"] as Array).size() > (y["members"] as Array).size())
	var cl_out: Array[Dictionary] = []
	for cl: Dictionary in clusters:
		cl_out.append(_cluster_summary(cl))
	var bins: Dictionary[String, String] = {}
	for bi: int in range(DY_BINS.size() - 1):
		var n_all: int = 0
		var n_ok: int = 0
		for r: Dictionary in _results:
			var dy: float = r["max_dy"]
			if dy >= DY_BINS[bi] and dy < DY_BINS[bi + 1]:
				n_all += 1
				n_ok += 1 if r["status"] == "ok" else 0
		bins["%.2f-%.2f m" % [DY_BINS[bi], DY_BINS[bi + 1]]] = "%d/%d ok" % [n_ok, n_all]
	var tiers: Dictionary[int, int] = {}
	for r: Dictionary in _results:
		tiers[int(r["tier"])] = tiers.get(int(r["tier"]), 0) + 1
	return {"heist": String(_heist), "seed": _seed(), "spacing_m": _spacing, "step_height_m": _tw.step_height_m,
		"max_slope_deg": _tw.max_slope_deg, "capsule_radius": _tw.capsule_radius, "walk_speed": _tw.walk_speed,
		"bounds": _bounds, "samples": _samples, "walkable_edges": _edges.size(), "rejected": _reject,
		"trials": _results.size(), "trials_by_tier": tiers, "outcomes": counts, "times_s": times,
		"stance": _stance, "dirs": _dirs.size(), "approach": String(_args.get("approach", "run")), "trials_by_max_step": bins,
		"sim_ticks": _ticks, "snags": snags, "clusters": cl_out, "low_blockers": _low_blockers.values()}


func _cluster_summary(cl: Dictionary) -> Dictionary:
	var mem: Array = cl["members"]
	var heads: PackedStringArray = []
	var dh_min: float = INF
	var dh_max: float = -INF
	var verdicts: Dictionary[String, int] = {}
	var whys: Dictionary[String, int] = {}
	var colliders: Dictionary[String, int] = {}
	var lips: PackedFloat32Array = []
	var cheights: PackedFloat32Array = []
	var statuses: Dictionary[String, int] = {}
	for m: Dictionary in mem:
		heads.append("%d" % roundi(float(m["heading_deg"])))
		dh_min = minf(dh_min, float(m["dh"]))
		dh_max = maxf(dh_max, float(m["dh"]))
		var v: String = m["verdict"]
		verdicts[v] = verdicts.get(v, 0) + 1
		var w: String = String(m["why_no_step"]).get_slice(" ", 0)
		whys[w] = whys.get(w, 0) + 1
		statuses[String(m["status"])] = statuses.get(String(m["status"]), 0) + 1
		if not is_nan(float(m["lip_h"])):
			lips.append(float(m["lip_h"]))
		for ct: Dictionary in m["contacts"]:
			var key: String = "%s [%s, %s, layer %s%s]" % [ct["path"], ct["class"], ct["shape"], ct["layer"],
				"" if bool(ct["visible_mesh"]) else ", NO MESH"]
			colliders[key] = colliders.get(key, 0) + 1
			cheights.append(float(ct["contact_h"]))
	var top_c: Array[String] = []
	for k: String in colliders:
		top_c.append(k)
	top_c.sort_custom(func(x: String, y: String) -> bool: return colliders[x] > colliders[y])
	return {"center": cl["center"], "count": mem.size(), "headings_deg": heads, "dh_range": [dh_min, dh_max],
		"lip_h_range": [_minf(lips), _maxf(lips)], "contact_h_range": [_minf(cheights), _maxf(cheights)],
		"status": statuses, "why_no_step": whys, "verdicts": verdicts, "colliders": top_c.slice(0, 4),
		"interest": (mem[0] as Dictionary)["interest"],
		"floor": ((mem[0] as Dictionary).get("floor_collider", {}) as Dictionary).get("path", "")}


func _minf(a: PackedFloat32Array) -> float:
	var m: float = INF
	for v: float in a:
		m = minf(m, v)
	return m if a.size() > 0 else NAN


func _maxf(a: PackedFloat32Array) -> float:
	var m: float = -INF
	for v: float in a:
		m = maxf(m, v)
	return m if a.size() > 0 else NAN


func _v3s(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _text(rep: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("PO-3 snag probe: %s  (step %.2f m, slope %.0f deg, r %.2f m, walk %.1f m/s)" % [rep["heist"],
		rep["step_height_m"], rep["max_slope_deg"], rep["capsule_radius"], rep["walk_speed"]])
	lines.append("samples %d, walkable edges %d, trials %d %s, outcomes %s, rejected edges %s" % [rep["samples"],
		rep["walkable_edges"], rep["trials"], rep["trials_by_tier"], rep["outcomes"], rep["rejected"]])
	lines.append("stance %s, approach %s, %d headings; trials by largest single step on the edge: %s" % [
		rep["stance"], rep["approach"], rep["dirs"], rep["trials_by_max_step"]])
	lines.append("times %s, sim ticks %d" % [rep["times_s"], rep["sim_ticks"]])
	var lb: Array = rep["low_blockers"]
	lb.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["count"]) > int(y["count"]))
	lines.append("%d low blockers (collider top 0.32-0.75 m above the floor, stops a walkable-looking path):" % lb.size())
	for b: Dictionary in lb.slice(0, 40):
		lines.append("    %s  top %.2f m (visual top %.2f) x%d at %s [%s, %s, layer %s]" % [b["path"], b["top_above_floor_m"],
			b["visible_mesh_top"], b["count"], _v3s(b["at"]), b["class"], b["shape"], b["layer"]])
	lines.append_array(_coverage(rep["clusters"]))
	var cls: Array = rep["clusters"]
	lines.append("%d snag clusters (%d snag trials):" % [cls.size(), (rep["snags"] as Array).size()])
	var i: int = 0
	for cl: Dictionary in cls:
		i += 1
		var dr: Array = cl["dh_range"]
		var lr: Array = cl["lip_h_range"]
		var cr: Array = cl["contact_h_range"]
		lines.append("#%d at %s  x%d  status %s  headings %s" % [i, _v3s(cl["center"]), cl["count"], cl["status"],
			",".join(cl["headings_deg"] as PackedStringArray)])
		lines.append("    dh A->B %.2f..%.2f m, lip ahead %.2f..%.2f m, contact h %.2f..%.2f m, edge %s, floor %s" % [
			dr[0], dr[1], lr[0], lr[1], cr[0], cr[1], cl["interest"], cl["floor"]])
		lines.append("    why_no_step %s" % cl["why_no_step"])
		lines.append("    verdict %s" % cl["verdicts"])
		for cs: String in cl["colliders"]:
			lines.append("    hit %s" % cs)
	return "\n".join(lines)


## Top-down coverage map, one char per grid cell (+X right, +Z down): '#' reached floor, 'o' floor never reached,
## 'S' seed, '1'-'9' snag cluster rank, ' ' no standable floor.
func _coverage(clusters: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var c0: Vector2i = _cell_of(_bounds.position)
	var c1: Vector2i = _cell_of(_bounds.end)
	var marks: Dictionary[Vector2i, String] = {}
	for k: Vector3i in _seen:
		marks[Vector2i(k.x, k.y)] = "#"
	for k: Vector3i in _seed_keys:
		marks[Vector2i(k.x, k.y)] = "S"
	for i: int in range(mini(clusters.size(), 9)):
		marks[_cell_of((clusters[i] as Dictionary)["center"])] = str(i + 1)
	out.append("coverage map: x %.0f..%.0f (1 char = %.1f m), z %.0f..%.0f top to bottom" % [_cell_xz(c0).x,
		_cell_xz(c1).x, _spacing, _cell_xz(c0).y, _cell_xz(c1).y])
	for z: int in range(c0.y, c1.y + 1):
		var row: String = ""
		for x: int in range(c0.x, c1.x + 1):
			var cell: Vector2i = Vector2i(x, z)
			if marks.has(cell):
				row += marks[cell]
			else:
				row += "o" if not _column(cell).is_empty() else " "
		out.append("  |" + row.rstrip(" "))
	return out


func _out_dir() -> String:
	var d: String = String(_args.get("out", OS.get_environment("PO3_OUT")))
	if d == "":
		d = "user://po3_snags"
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _jsonable(v: Variant) -> Variant:
	if v is Vector3:
		var p: Vector3 = v
		return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]
	if v is float:
		var f: float = v
		return null if is_nan(f) or is_inf(f) else snappedf(f, 0.0001)
	if v is AABB:
		var bb: AABB = v
		return {"position": _jsonable(bb.position), "size": _jsonable(bb.size)}
	if v is Dictionary:
		var o: Dictionary = {}
		for k: Variant in (v as Dictionary):
			o[str(k)] = _jsonable((v as Dictionary)[k])
		return o
	if v is Array or v is PackedStringArray or v is PackedFloat32Array:
		var arr: Array = []
		for x: Variant in v:
			arr.append(_jsonable(x))
		return arr
	return v


func _write(name: String, rep: Dictionary) -> void:
	var d: String = _out_dir()
	var txt: String = _text(rep)
	print(txt)
	var fj: FileAccess = FileAccess.open(d.path_join(name + ".json"), FileAccess.WRITE)
	if fj != null:
		fj.store_string(JSON.stringify(_jsonable(rep), " "))
		fj.close()
	var ft: FileAccess = FileAccess.open(d.path_join(name + ".txt"), FileAccess.WRITE)
	if ft != null:
		ft.store_string(txt + "\n")
		ft.close()
	print("[PO3] wrote %s" % ProjectSettings.globalize_path(d.path_join(name + ".json")))


func _elapsed() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


# --- Self-check --------------------------------------------------------------------------------------------

## ATestMaps.basic + a 0.2 m kerb (x=0), a 0.6 m box (x=12) and a 0.15 m trimesh kerb (x=-12), all with their
## near face at z=-2.5. Forced trials across each, then the full sweep: the 0.6 m box must stop the crew (and be
## excluded from the sweep as a wall), the 0.2 m kerb must be climbed and never reported.
func _selftest() -> int:
	_heist = &"selftest"
	if not await _launch(&"unit_map", ATestMaps.basic(0, 0)):
		return 1
	ATestMaps.add_wall(_rt.map, Vector3(0.0, 0.1, -4.0), Vector3(6.0, 0.2, 3.0))
	ATestMaps.add_wall(_rt.map, Vector3(12.0, 0.3, -4.0), Vector3(6.0, 0.6, 3.0))
	var tri: StaticBody3D = StaticBody3D.new()
	tri.name = "TrimeshKerb"
	tri.collision_layer = 1
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(6.0, 0.15, 3.0)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = bm.create_trimesh_shape()
	tri.add_child(cs)
	_rt.map.add_child(tri)
	tri.global_position = Vector3(-12.0, 0.075, -4.0)
	await _physics(3)
	_compute_bounds()
	_collect_visuals()
	var fails: PackedStringArray = []
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	var tall: Dictionary = await _trial(crew, Vector3(12.0, 0.0, -1.0), Vector3(12.0, 0.6, -4.0))
	print("[PO3] selftest 0.6 m box: status %s %s" % [tall["status"], tall.get("verdict", "")])
	if tall["status"] == "ok":
		fails.append("0.6 m box was walked over (not flagged)")
	var kerb: Dictionary = await _trial(crew, Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.2, -4.0))
	print("[PO3] selftest 0.2 m kerb: status %s %s" % [kerb["status"], kerb.get("verdict", "")])
	if kerb["status"] != "ok":
		fails.append("0.2 m kerb flagged: %s" % kerb.get("verdict", kerb["status"]))
	var trik: Dictionary = await _trial(crew, Vector3(-12.0, 0.0, -1.0), Vector3(-12.0, 0.15, -4.0))
	print("[PO3] selftest 0.15 m trimesh kerb (informative): status %s %s" % [trik["status"], trik.get("verdict", "")])
	_flood(_seeds(), 40000)
	_pick_trials(int(String(_args.get("max_trials", "2500"))))
	if _reject.get("tall", 0) + _reject.get("blocked", 0) == 0:
		fails.append("sweep did not reject any edge as too tall / blocked (0.6 m box)")
	await _run_trials()
	var rep: Dictionary = _report({"total_s": _elapsed()})
	_write("selftest", rep)
	for s: Dictionary in rep["snags"]:
		var p: Vector3 = s["stall"]
		if absf(p.x) < 3.6 and p.z < -1.5 and p.z > -6.0:
			fails.append("snag at the 0.2 m kerb %s" % _v3s(p))
			break
	var kerb_trials: int = 0
	for r: Dictionary in _results:
		var a: Vector3 = r["a"]
		var b: Vector3 = r["b"]
		if absf(a.x) < 3.0 and (a.z > -2.5) != (b.z > -2.5):
			kerb_trials += 1
	if kerb_trials == 0:
		fails.append("the sweep ran no trial across the 0.2 m kerb")
	print("[PO3] selftest: %d sweep trials crossed the 0.2 m kerb face" % kerb_trials)
	print("[PO3] RESULT %s %s" % ["PASS" if fails.is_empty() else "FAIL", "; ".join(fails)])
	_rt.teardown()
	return 0 if fails.is_empty() else 1
