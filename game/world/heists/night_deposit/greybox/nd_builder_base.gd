## Night Deposit generator base: shared constants, state and generic helpers. Owner: ENV C (C2).
## Chain: nd_builder_base.gd <- nd_gameplay.gd <- build_greybox.gd (the --script entry point).
## G2 (art pass): box visuals go to the art accumulator (nd_art.gd: library materials per surface
## class and room finish, merged per visual group, world-scaled UVs); the greybox flat materials are
## gone.
extends SceneTree

const L: GDScript = preload("res://world/heists/night_deposit/greybox/night_deposit_layout.gd")
const R: GDScript = preload("res://world/heists/night_deposit/greybox/night_deposit_resources.gd")
const A: GDScript = preload("res://world/heists/night_deposit/greybox/nd_art.gd")
const DR: GDScript = preload("res://world/heists/night_deposit/greybox/nd_dress.gd")
const DD: GDScript = preload("res://world/heists/night_deposit/greybox/night_deposit_dressing.gd")
const RT: GDScript = preload("res://world/kits/ridge_top.gd")  # not-standable guard tops (slopes, D-104)
const ART_DIR: String = "res://world/heists/night_deposit/art/"
const OUT_DIR: String = "res://world/heists/night_deposit/"
const SCENE_PATH: String = OUT_DIR + "night_deposit.tscn"
const DEF_PATH: String = OUT_DIR + "night_deposit_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "night_deposit_variants.tres"
const MISSION_PATH: String = OUT_DIR + "night_deposit_mission.gd"
const MAT_DIR: String = "res://world/materials/"
## Visual step boxes overlap their higher neighbour by this much (no ray-through seams).
const SEAM: float = 0.02
## Map-built prop material classes -> art material keys.
const PROP_MATS: Dictionary = {"partition": "plastic_matte", "vehicle": "van_white", "rack": "rubber_black"}
## Prefab id -> contract class_name (gameplay_prefabs.md). Scene = the class script's .tscn sibling.
const PREFAB_CLASSES: Dictionary = {
	"door": "Door", "window": "WindowPrefab", "safe": "Safe", "drill_point": "DrillPoint",
	"keycard_pickup": "KeycardPickup", "loot_spawn": "LootSpawn", "small_loot": "SmallLoot",
	"alarm_button": "AlarmButton", "phone": "Phone", "secure_zone": "SecureZone", "escape_zone": "EscapeZone",
	"body_container": "BodyContainer", "ladder": "Ladder", "camera_station": "CameraStation",
	"security_camera": "SecurityCamera", "code_note": "CodeNote", "keypad": "Keypad", "laser_grid": "LaserGrid",
	"bag_lift": "BagLift", "hack_terminal": "HackTerminal", "deposit_box": "DepositBox", "padlock": "Padlock",
}
var map_root: HeistMap = null
var errors: PackedStringArray = PackedStringArray()
## Art pass (materials, accumulated visuals) and the dressing pass.
var art: RefCounted = null
var dress: RefCounted = null
## Visual group the next box() / mesh_box() faces go to (one merged MeshInstance3D per group).
var vis_group: String = "Shell"
## Projected nav obstructions for props and prefabs: [corners (PackedVector3Array), elevation, height].
var obstructions: Array[Array] = []
var _box_shape_cache: Dictionary = {}
var _scene_cache: Dictionary = {}


# --- Generic helpers (also used by night_deposit_gameplay.gd) ----------------------------------

func add(parent: Node, c: Node) -> Node:
	parent.add_child(c)
	c.owner = map_root
	return c


func node3d(nm: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var c: Node3D = Node3D.new()
	c.name = nm
	c.position = pos
	return c


static func yaw_basis(yaw_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg))


static func v3(a: Array, i: int) -> Vector3:
	return Vector3(float(a[i]), float(a[i + 1]), float(a[i + 2]))


func box_shape(size: Vector3) -> BoxShape3D:
	var key: String = "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if not _box_shape_cache.has(key):
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		_box_shape_cache[key] = bs
	return _box_shape_cache[key]


## Static box (world_static) from min/max corners: StaticBody3D + CollisionShape3D; its visible faces
## (by surface class `mat_id`, nd_art.face_key) go to the merged visual of `vis_group`.
## mat_id "" or "none" = collision only.
func box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat_id: String, collide: bool = true,
		skip: Array[int] = []) -> Node3D:
	var size: Vector3 = mx - mn
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return null
	var body: Node3D
	if collide:
		var sb: StaticBody3D = StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		body = sb
	else:
		body = Node3D.new()
	body.name = nm
	body.position = (mn + mx) * 0.5
	add(parent, body)
	if collide:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Collision"
		col.shape = box_shape(size)
		add(body, col)
		SurfaceTags.tag(body, SurfaceTags.from_faces(mn, mx, surface_face.bind(mat_id), mat_id))
	if mat_id != "" and mat_id != "none":
		art.vis_box(vis_group, mn, mx, mat_id, skip)
	return body


## PO-8: material key a bullet meets on face f of a class `cls` box: the art pass's face, or the
## room's floor finish on a floor's top (drawn separately by nd_art.room_surfaces).
func surface_face(f: int, n: Vector3, c: Vector3, cls: String) -> String:
	if cls == "" or cls == "none":
		return ""
	if f == 3 and cls == "floor":
		var r: String = A.room_at(c + n * 0.3)
		return String((A.FINISH[r] as Array)[0]) if A.FINISH.has(r) else "concrete"
	return String(art.face_key(cls, f, n, c))


func box_a(parent: Node3D, nm: String, b: Array, mat_id: String, collide: bool = true) -> Node3D:
	return box(parent, nm, v3(b, 0), v3(b, 3), mat_id, collide)


## Visual-only box (no collision) in world coordinates, accumulated into `vis_group`.
func mesh_box(mn: Vector3, mx: Vector3, mat_id: String) -> void:
	art.vis_box(vis_group, mn, mx, mat_id)


## Straight wall with rectangular openings. axis "x": runs along x at z = fixed; "z": along z at x = fixed.
## openings: [[along0, along1, sill_y, head_y], ...] (absolute heights). One box per storey (split
## at the ground FFL) so the per-floor plan render cuts every wall.
func wall(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, thick: float,
		yr: Vector2, openings: Array, mat_id: String) -> void:
	var y0: float = yr.x
	var y1: float = yr.y
	var cuts: Array[float] = [a0, a1]
	for o: Array in openings:
		for v: float in [float(o[0]), float(o[1])]:
			if v > a0 and v < a1 and not cuts.has(v):
				cuts.append(v)
	cuts.sort()
	# solid height spans of every segment between cuts (openings removed)
	var segs: Array = []
	for i: int in range(cuts.size() - 1):
		var p: float = cuts[i]
		var q: float = cuts[i + 1]
		if q - p < 0.001:
			continue
		var holes: Array[Vector2] = []
		for o2: Array in openings:
			if float(o2[0]) <= p + 0.0001 and float(o2[1]) >= q - 0.0001:
				holes.append(Vector2(maxf(float(o2[2]), y0), minf(float(o2[3]), y1)))
		holes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cur: float = y0
		var spans: Array[Vector2] = []
		for h: Vector2 in holes:
			if h.x > cur + 0.0001:
				spans.append(Vector2(cur, h.x))
			cur = maxf(cur, h.y)
		if y1 > cur + 0.0001:
			spans.append(Vector2(cur, y1))
		segs.append([p, q, spans])
	var lo_face: int = 0 if axis == "x" else 4
	var hi_face: int = 1 if axis == "x" else 5
	var part: int = 0
	for si: int in range(segs.size()):
		var p2: float = float(segs[si][0])
		var q2: float = float(segs[si][1])
		var split: Array[Vector2] = []
		for sp: Vector2 in segs[si][2]:
			if sp.x < -0.0001 and sp.y > 0.0001:
				split.append(Vector2(sp.x, 0.0))
				split.append(Vector2(0.0, sp.y))
			else:
				split.append(sp)
		for s: Vector2 in split:
			# an end face is buried when the neighbouring segment (touching it) is solid over this span
			var skip: Array[int] = []
			if si > 0 and absf(float(segs[si - 1][1]) - p2) < 0.0001 and _covers(segs[si - 1][2], s):
				skip.append(lo_face)
			if si < segs.size() - 1 and absf(float(segs[si + 1][0]) - q2) < 0.0001 and _covers(segs[si + 1][2], s):
				skip.append(hi_face)
			var mn: Vector3
			var mx: Vector3
			if axis == "x":
				mn = Vector3(p2, s.x, fixed - thick * 0.5)
				mx = Vector3(q2, s.y, fixed + thick * 0.5)
			else:
				mn = Vector3(fixed - thick * 0.5, s.x, p2)
				mx = Vector3(fixed + thick * 0.5, s.y, q2)
			box(parent, "%s_%02d" % [nm, part], mn, mx, mat_id, true, skip)
			part += 1


static func _covers(spans: Array, s: Vector2) -> bool:
	for sp: Vector2 in spans:
		if sp.x <= s.x + 0.0001 and sp.y >= s.y - 0.0001:
			return true
	return false


## Catalog scene (world/props, prop_catalog.json) of an asset id.
func catalog_scene(asset: String) -> PackedScene:
	return dress.scene(asset)


## Gameplay prefab scene by contract id, or null (no error) when `optional` and not on trunk.
func prefab_scene(prefab: String, optional: bool = false) -> PackedScene:
	if _scene_cache.has(prefab):
		return _scene_cache[prefab]
	var cls: String = String(PREFAB_CLASSES.get(prefab, ""))
	var ps: PackedScene = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c["class"]) == cls:
			var path: String = String(c["path"]).get_basename() + ".tscn"
			if ResourceLoader.exists(path):
				ps = load(path) as PackedScene
	if ps == null and not optional:
		errors.append("gameplay prefab `%s` (class %s) not found" % [prefab, cls])
	_scene_cache[prefab] = ps
	return ps


## Records a projected navmesh obstruction for a box (local AABB under xform).
func obstruct(xform: Transform3D, aabb: AABB) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var lo: float = INF
	var hi: float = -INF
	for corner: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
		var lp: Vector3 = aabb.position + aabb.size * corner
		pts.append(xform * lp)
	for cy: float in [aabb.position.y, aabb.end.y]:
		var w: Vector3 = xform * Vector3(aabb.position.x, cy, aabb.position.z)
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
	obstructions.append([pts, lo, hi - lo])


## Box prop: StaticBody3D map_root at the bottom-centre (meta kind / support), collision + mesh.
func prop_box(parent: Node3D, nm: String, base: Vector3, size: Vector3, yaw: float, kind: String,
		support: bool, mat_id: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = yaw_basis(yaw)
	body.set_meta(&"kind", kind)
	if support:
		body.set_meta(&"support", true)
	add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = box_shape(size)
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = art.local_box_mesh([[size, Vector3.ZERO, String(PROP_MATS.get(mat_id, mat_id))]])
	mi.position = col.position
	add(body, mi)
	obstruct(body.transform, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size))
	return body


func area_boxes(area: Area3D, boxes: Array) -> void:
	for i: int in range(boxes.size()):
		var b: Array = boxes[i]
		var mn: Vector3 = v3(b, 0)
		var mx: Vector3 = v3(b, 3)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Shape" if i == 0 else "Shape%d" % i
		col.shape = box_shape(mx - mn)
		col.position = (mn + mx) * 0.5
		add(area, col)


func zone(parent: Node3D, nm: String, kind: String, zone_id: String, boxes: Array) -> MapZone:
	var z: MapZone = MapZone.new()
	z.name = nm
	z.kind = MapZone.Kind[kind]
	z.zone_id = StringName(zone_id)
	z.collision_layer = 1 << 9
	z.collision_mask = 0
	add(parent, z)
	area_boxes(z, boxes)
	return z


func spawn(parent: Node3D, nm: String, kind: String, pos: Vector3, yaw: float, tags: Array, idle: String,
		graph: String) -> SpawnPoint:
	var sp: SpawnPoint = SpawnPoint.new()
	sp.name = nm
	sp.kind = SpawnPoint.Kind[kind]
	var tg: Array[StringName] = []
	for t: Variant in tags:
		tg.append(StringName(String(t)))
	sp.tags = tg
	sp.idle_activity = StringName(idle)
	sp.position = pos
	sp.basis = yaw_basis(yaw)
	add(parent, sp)
	if graph != "":
		sp.patrol_graph = sp.get_path_to(map_root.get_node("Patrols/" + graph))
	return sp


func n(path: String) -> Node3D:
	return map_root.get_node(path) as Node3D
