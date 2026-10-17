## Shadow Ledger generator base: shared constants, state and generic helpers. Owner: ENV C (C2).
## Chain: sl_builder_base.gd <- sl_gameplay.gd <- build_greybox.gd (the --script entry point).
extends SceneTree

const L: GDScript = preload("res://world/heists/shadow_ledger/greybox/shadow_ledger_layout.gd")
const R: GDScript = preload("res://world/heists/shadow_ledger/greybox/shadow_ledger_resources.gd")
const RT: GDScript = preload("res://world/kits/ridge_top.gd")  # not-standable guard tops (slopes, D-104)
const OUT_DIR: String = "res://world/heists/shadow_ledger/"
const SCENE_PATH: String = OUT_DIR + "shadow_ledger.tscn"
const DEF_PATH: String = OUT_DIR + "shadow_ledger_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "shadow_ledger_variants.tres"
const MISSION_PATH: String = OUT_DIR + "shadow_ledger_mission.gd"
const MAT_DIR: String = "res://world/materials/"
const KIT_DIR: String = "res://assets/arch/"
## Visual step boxes overlap their higher neighbour by this much (no ray-through seams).
const SEAM: float = 0.02
## Prefab id -> contract class_name (gameplay_prefabs.md). Scene = the class script's .tscn sibling.
const PREFAB_CLASSES: Dictionary = {
	"door": "Door", "window": "WindowPrefab", "safe": "Safe", "drill_point": "DrillPoint",
	"keycard_pickup": "KeycardPickup", "loot_spawn": "LootSpawn", "small_loot": "SmallLoot",
	"alarm_button": "AlarmButton", "phone": "Phone", "secure_zone": "SecureZone", "escape_zone": "EscapeZone",
	"body_container": "BodyContainer", "ladder": "Ladder", "camera_station": "CameraStation",
	"security_camera": "SecurityCamera", "code_note": "CodeNote", "keypad": "Keypad", "laser_grid": "LaserGrid",
	"bag_lift": "BagLift", "hack_terminal": "HackTerminal", "zipline": "Zipline", "keycard_reader": "KeycardReader",
}
## PO-13 surface pass: greybox class / room purpose -> library finish (sl_finishes.gd).
const F: GDScript = preload("res://world/heists/shadow_ledger/greybox/sl_finishes.gd")
## G2 dressing / art data (SL-1): catalog visuals of the map-built props and chairs.
const DD: GDScript = preload("res://world/heists/shadow_ledger/greybox/shadow_ledger_dressing.gd")
## Near-range (30 m) wrappers for the interior visuals (sl_dress.near_scene_path: the draw-call budget of the exterior
## views, as the kit props).
const DRS: GDScript = preload("res://world/heists/shadow_ledger/greybox/sl_dress.gd")
## Visual tile edge (m) for the big horizontal boxes (slabs, roofs, ceilings, grade): the Compatibility renderer
## lights a mesh instance with at most 8 omni / spot lights (rendering/limits/opengl/max_lights_per_object), so one
## floor-wide box overlapped by every room light keeps 8 arbitrary ones and whole rooms render black (Gallery Night
## GN-C1, 1639ea1c). The collider stays one box (navmesh, collision, LOS unchanged); only the mesh is tiled.
const SLAB_TILE: float = 6.0
## PO-13 slab skins: offset of a skin quad off its slab face (zfight treats < 2 mm as coplanar).
const SKIN_OFFSET: float = 0.004
## Emissive (fixtures, lamps, beacons, distant lit windows): untextured_ok.
const EMISSIVE_MATS: Dictionary = {
	"fixture": Color(1.0, 0.95, 0.88), "led_white": Color(0.85, 0.92, 1.0), "heli_green": Color(0.2, 1.0, 0.35),
	"beacon_red": Color(1.0, 0.1, 0.05), "city_lights": Color(1.0, 0.75, 0.45), "monitor": Color(0.55, 0.75, 1.0),
	"logo_teal": Color(0.36, 0.75, 0.78), "rack_led": Color(0.6, 0.8, 1.0),
}

var map_root: HeistMap = null
var errors: PackedStringArray = PackedStringArray()
## Projected nav obstructions for props and prefabs: [corners (PackedVector3Array), elevation, height].
var obstructions: Array[Array] = []
## Mesh tile edge for the pieces wall() builds (0 = whole); the builders set SLAB_TILE around building walls.
var wall_tile: float = 0.0
var _mat_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _scene_cache: Dictionary = {}


# --- Generic helpers (also used by shadow_ledger_gameplay.gd) ----------------------------------

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


## Material for a finish key (sl_finishes FINISHES) or a greybox class (its position-free default),
## the river and the emissives. Cached: one material per key.
func lib_mat(id: String) -> Material:
	if _mat_cache.has(id):
		return _mat_cache[id]
	var m: Material
	if id == "river":
		# PO-13: the Kestrel (160 m below, visual only) uses the library night water, duplicated per map.
		# No glints: the river sits in the fog far below every viewpoint; the sheen and sky reflection carry it.
		var w: ShaderMaterial = (load(MAT_DIR + "water_harbour_night.tres") as ShaderMaterial).duplicate() as ShaderMaterial
		w.resource_name = "sl_river_water"
		m = w
	elif EMISSIVE_MATS.has(id):
		m = _emissive_mat(id)
	else:
		var key: String = id if F.FINISHES.has(id) else F.resolve(id, "", AABB())
		if not F.FINISHES.has(key):
			errors.append("unknown material class `%s`" % id)
			key = "concrete"
		if not _mat_cache.has(key):
			_mat_cache[key] = _finish_mat(key)
		m = _mat_cache[key]
	_mat_cache[id] = m
	return m


## A library finish: the texgen material duplicated (textures shared) as world triplanar at the style
## guide density, optionally tinted (a tint alpha < 1: see-through, both faces). resource_name sl_<key>
## (surface_map.json gives its bullet surface).
func _finish_mat(key: String) -> Material:
	var row: Array = F.FINISHES[key]
	var lib: String = String(row[0])
	var base: BaseMaterial3D = load(MAT_DIR + lib + ".tres") as BaseMaterial3D
	var m: BaseMaterial3D = base.duplicate() as BaseMaterial3D
	m.resource_name = "sl_" + key
	if row[1] != null:
		var tint: Color = row[1]
		m.albedo_color = base.albedo_color * tint
		if tint.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var uv: float = F.uv_per_m(lib, float(base.albedo_texture.get_width()), float(base.get_meta(&"uv_tile_m", 2.0)))
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(uv, uv, uv)
	return m


func _emissive_mat(id: String) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.resource_name = "sl_" + id
	m.set_meta(&"untextured_ok", true)
	m.albedo_color = EMISSIVE_MATS[id]
	m.emission_enabled = true
	m.emission = EMISSIVE_MATS[id]
	# Distant lit windows stay dim (bright bands read as floating bars through the fog).
	m.emission_energy_multiplier = 0.35 if id == "city_lights" else 3.0
	return m


## Finish key for a box of class `cls` named `nm` with local corners mn / mx under `parent`.
func finish(parent: Node, cls: String, nm: String, mn: Vector3, mx: Vector3, kind: String = "") -> String:
	if cls == "river" or EMISSIVE_MATS.has(cls):
		return cls
	return F.resolve(cls, nm, _world_xf(parent) * AABB(mn, mx - mn), kind)


## Transform of `nd` relative to the map root (nodes are built before the map enters a tree).
func _world_xf(nd: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = nd
	while cur != null and cur != map_root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func box_mesh(size: Vector3, mat_id: String) -> BoxMesh:
	var key: String = "%s|%.3f|%.3f|%.3f" % [mat_id, size.x, size.y, size.z]
	if not _box_mesh_cache.has(key):
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		bm.material = lib_mat(mat_id)
		_box_mesh_cache[key] = bm
	return _box_mesh_cache[key]


func box_shape(size: Vector3) -> BoxShape3D:
	var key: String = "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if not _box_shape_cache.has(key):
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		_box_shape_cache[key] = bs
	return _box_shape_cache[key]


## Box mesh of `size` without the faces flagged open: [-x, +x, -z, +z(, -y, +y)] (seamless wall tiles; G2: capless
## wall pieces). An open side reaches 1 mm into its neighbour tile (same material: coplanar overlap is not a zfight)
## so no ray slips through the seam; an open cap simply has no face (it stands on / under a slab). Cached.
func _tile_mesh(size: Vector3, mat_id: String, open: Array) -> Mesh:
	var key: String = "tile|%s|%.3f|%.3f|%.3f|%s" % [mat_id, size.x, size.y, size.z, str(open)]
	if _box_mesh_cache.has(key):
		return _box_mesh_cache[key]
	var lo: Vector3 = -size * 0.5
	var hi: Vector3 = size * 0.5
	# a seam side (true / 1) reaches 1 mm into its neighbour tile; a hidden side (2, G2 caps) does not (its top face
	# would overlap the next box's, which may carry another finish: zfight)
	lo.x -= 0.001 if int(open[0]) == 1 else 0.0
	hi.x += 0.001 if int(open[1]) == 1 else 0.0
	lo.z -= 0.001 if int(open[2]) == 1 else 0.0
	hi.z += 0.001 if int(open[3]) == 1 else 0.0
	var mid: Vector3 = (lo + hi) * 0.5
	var h: Vector3 = (hi - lo) * 0.5
	# [normal, u, v] with u x v = -normal (Godot front faces wind clockwise).
	var faces: Array = [[Vector3.LEFT, Vector3.UP, Vector3.BACK], [Vector3.RIGHT, Vector3.BACK, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP], [Vector3.BACK, Vector3.UP, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.BACK, Vector3.RIGHT], [Vector3.UP, Vector3.RIGHT, Vector3.BACK]]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fi: int in range(faces.size()):
		if fi < open.size() and bool(open[fi]):
			continue
		var n: Vector3 = faces[fi][0]
		var u: Vector3 = faces[fi][1]
		var v: Vector3 = faces[fi][2]
		var c: Vector3 = mid + n * h
		var hu: Vector3 = u * absf(u.dot(h))
		var hv: Vector3 = v * absf(v.dot(h))
		var q: Array = [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
		for k: int in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = q[k]
			st.set_normal(n)
			st.set_uv(Vector2(p.dot(u), p.dot(v)))
			st.add_vertex(p)
	st.generate_tangents()
	st.set_material(lib_mat(mat_id))
	var m: ArrayMesh = st.commit()
	_box_mesh_cache[key] = m
	return m


## Static box (world_static) from min/max corners: StaticBody3D + CollisionShape3D + MeshInstance3D.
## mat_id "" or "none" = collision only.
## tile > 0: the visual is an even grid of mesh tiles no wider than `tile` in x / z (SLAB_TILE) under the one
## unchanged collider; one tile keeps the single `Mesh` child.
## seamless: the tiles leave out their faces on the internal seams (walls: a seam face on a crossing wall's face
## line would be a coplanar pair).
func box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat_id: String, collide: bool = true,
		tile: float = 0.0, seamless: bool = false, caps: int = 0) -> Node3D:
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
	if mat_id == "" or mat_id == "none":
		return body
	var key: String = finish(parent, mat_id, nm, mn, mx)
	var nx: int = maxi(1, ceili(size.x / tile - 0.001)) if tile > 0.0 else 1
	var nz: int = maxi(1, ceili(size.z / tile - 0.001)) if tile > 0.0 else 1
	var ts: Vector3 = Vector3(size.x / nx, size.y, size.z / nz)
	for ix: int in range(nx):
		for iz: int in range(nz):
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "Mesh" if nx * nz == 1 else "Mesh%02d_%02d" % [ix, iz]
			if caps != 0:  # G2: hidden faces left out (zfight): bottom 1, top 2, -x 4, +x 8, -z 16, +z 32 (+ 64)
				var sm: bool = seamless and nx * nz > 1
				var sv: int = 2 if caps & 64 != 0 else 1  # 64: seams without the 1 mm reach (slabs: tiles cover the collider)
				mi.mesh = _tile_mesh(ts, key, [sv if sm and ix > 0 else (2 if ix == 0 and caps & 4 != 0 else 0),
					sv if sm and ix < nx - 1 else (2 if ix == nx - 1 and caps & 8 != 0 else 0),
					sv if sm and iz > 0 else (2 if iz == 0 and caps & 16 != 0 else 0),
					sv if sm and iz < nz - 1 else (2 if iz == nz - 1 and caps & 32 != 0 else 0), caps & 1 != 0, caps & 2 != 0])
			elif seamless and nx * nz > 1:
				mi.mesh = _tile_mesh(ts, key, [ix > 0, ix < nx - 1, iz > 0, iz < nz - 1])
			else:
				mi.mesh = box_mesh(ts, key)
			if nx * nz > 1:
				mi.position = Vector3(-size.x * 0.5 + ts.x * (ix + 0.5), 0.0, -size.z * 0.5 + ts.z * (iz + 0.5))
			add(body, mi)
	return body


func box_a(parent: Node3D, nm: String, b: Array, mat_id: String, collide: bool = true, tile: float = 0.0) -> Node3D:
	return box(parent, nm, v3(b, 0), v3(b, 3), mat_id, collide, tile)


## Visual-only box mesh child (no collision) at local min/max corners.
func mesh_box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat_id: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = box_mesh(mx - mn, finish(parent, mat_id, nm, mn, mx))
	mi.position = (mn + mx) * 0.5
	add(parent, mi)
	return mi


## PO-13 slab skins: a slab box spans several rooms and carries one finish, so where a room's floor
## (ceiling) finish differs from the slab box it stands on (sits under), a single upward (downward) quad
## of the room's finish covers that part, SKIN_OFFSET off the slab face (zfight tolerance 2 mm). Visual
## only: MeshInstance3D, no body (no collision, nav bake, vision ray or surface tag sees it), no shadow
## casting. One mesh per room under `parent` (Skin<room>; room-sized so per-object light limits of the
## Compatibility renderer pick that room's lights), one surface per finish. Returns the surfaces (draw calls).
## rooms: [room id, x0, z0, x1, z1, floor y, ceiling y, floor key, ceiling key] ("" key: no skin); a room
## with several rectangles has several rows.
## sources: box bodies or groups of them (axis-aligned slabs / ceilings; finish = material name).
func slab_skins(parent: Node3D, sources: Array, rooms: Array, prefix: String) -> int:
	var boxes: Array = []
	for src: Node in sources:
		var bodies: Array[Node] = src.find_children("*", "StaticBody3D", true, false)
		if src is StaticBody3D:
			bodies.push_front(src)
		for c: Node in bodies:
			var cs: CollisionShape3D = c.get_node_or_null("Collision") as CollisionShape3D
			var meshes: Array[Node] = c.find_children("Mesh*", "MeshInstance3D", false, false)
			var xf: Transform3D = _world_xf(c)
			if cs == null or not (cs.shape is BoxShape3D) or meshes.is_empty() or not xf.basis.is_equal_approx(Basis.IDENTITY):
				continue
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			var mat: Material = (meshes[0] as MeshInstance3D).mesh.surface_get_material(0)  # box or flat (ceilings) mesh
			boxes.append([xf * AABB(cs.position - sz * 0.5, sz), String(mat.resource_name).trim_prefix(prefix)])
	var per_room: Dictionary = {}  # room id -> {finish key -> [[x0, z0, x1, z1, y, up], ...]} (insertion order)
	for r: Array in rooms:
		for face: int in [0, 1]:
			var key: String = String(r[7 + face])
			if key == "":
				continue
			for b: Array in boxes:
				var ab: AABB = b[0]
				var fy: float = ab.end.y if face == 0 else ab.position.y
				if absf(fy - float(r[5 + face])) > 0.005 or String(b[1]) == key:
					continue
				var q: Array = [maxf(float(r[1]), ab.position.x), maxf(float(r[2]), ab.position.z),
					minf(float(r[3]), ab.end.x), minf(float(r[4]), ab.end.z)]
				if float(q[2]) - float(q[0]) < 0.01 or float(q[3]) - float(q[1]) < 0.01:
					continue
				var fl: Dictionary = per_room.get(String(r[0]), {})
				per_room[String(r[0])] = fl
				if not fl.has(key):
					fl[key] = []
				q.append_array([fy + (SKIN_OFFSET if face == 0 else -SKIN_OFFSET), face == 0])
				(fl[key] as Array).append(q)
	var surfaces: int = 0
	for room: String in per_room:
		var fl2: Dictionary = per_room[room]
		var keys: Array = fl2.keys()
		keys.sort()
		var mesh: ArrayMesh = ArrayMesh.new()
		for k: String in keys:
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for q2: Array in fl2[k]:
				_skin_quad(st, q2)
			st.generate_tangents()
			st.set_material(lib_mat(k))
			st.commit(mesh)
			surfaces += 1
		var mi2: MeshInstance3D = MeshInstance3D.new()
		mi2.name = "Skin" + room
		mi2.mesh = mesh
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi2.set_meta(&"slab_skin", true)
		add(parent, mi2)
	return surfaces


## One skin rectangle [x0, z0, x1, z1, y, up]: two triangles, clockwise seen from the side it faces.
static func _skin_quad(st: SurfaceTool, q: Array) -> void:
	var y: float = float(q[4])
	var a: Vector3 = Vector3(float(q[0]), y, float(q[1]))
	var b: Vector3 = Vector3(float(q[2]), y, float(q[1]))
	var c: Vector3 = Vector3(float(q[2]), y, float(q[3]))
	var d: Vector3 = Vector3(float(q[0]), y, float(q[3]))
	var up: bool = bool(q[5])
	var order: Array = [a, b, c, a, c, d] if up else [a, c, b, a, d, c]
	for v: Vector3 in order:
		st.set_normal(Vector3.UP if up else Vector3.DOWN)
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)


## Straight wall with rectangular openings. axis "x": runs along x at z = fixed; "z": along z at x = fixed.
## openings: [[along0, along1, sill_y, head_y], ...] (absolute heights). One box per storey (split
## at every floor level) so the per-floor plan render cuts every wall.
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
	var part: int = 0
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
		var split: Array[Vector2] = []
		for sp: Vector2 in spans:
			var lo: float = sp.x
			for fh: float in L.FLOOR_HEIGHTS:
				if fh > lo + 0.0001 and fh < sp.y - 0.0001:
					split.append(Vector2(lo, fh))
					lo = fh
			split.append(Vector2(lo, sp.y))
		for s: Vector2 in split:
			var mn: Vector3
			var mx: Vector3
			if axis == "x":
				mn = Vector3(p, s.x, fixed - thick * 0.5)
				mx = Vector3(q, s.y, fixed + thick * 0.5)
			else:
				mn = Vector3(fixed - thick * 0.5, s.x, p)
				mx = Vector3(fixed + thick * 0.5, s.y, q)
			# G2: a piece's bottom / top on a storey line (the wall base, its top, a floor level) stands on / under a slab
			# and draws no cap there (its caps were coplanar with the slab's and the crossing walls' faces: zfight)
			var caps: int = (1 if _on_level(s.x, yr) else 0) | (2 if _on_level(s.y, yr) else 0)
			box(parent, "%s_%02d" % [nm, part], mn, mx, mat_id, true, wall_tile, true, caps)
			part += 1


## True when height `y` is a wall run's base / top or a floor level (a slab face, not an opening's sill or head).
static func _on_level(y: float, yr: Vector2) -> bool:
	if absf(y - yr.x) < 0.0005 or absf(y - yr.y) < 0.0005:
		return true
	for fh: float in L.FLOOR_HEIGHTS:
		if absf(y - fh) < 0.0005:
			return true
	return false


func kit_scene(piece: String) -> PackedScene:
	var path: String = "%s%s/%s.glb" % [KIT_DIR, piece, piece]
	if not _scene_cache.has(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			errors.append("missing kit piece %s" % path)
		_scene_cache[path] = ps
	return _scene_cache[path]


## Catalog prop scene by asset id (PropCatalog `scene`, tools/blender/props), cached; null + error if absent.
func _catalog_scene(asset: String) -> PackedScene:
	var path: String = String(PropCatalog.entry(StringName(asset)).get("scene", ""))
	if path == "":
		errors.append("catalog asset %s not found" % asset)
		return null
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) as PackedScene
	return _scene_cache[path]


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
	obstruct(body.transform, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size))
	var art: Array = DD.PROP_ART.get(nm, [])
	if not art.is_empty():  # G2 (SL-1): the catalog visual over the unchanged collider
		body.set_meta(&"art_asset", String(art[0]))
		if String(art[2]) != "":
			body.set_meta(&"kind", String(art[2]))
		_art_visual(body, "Visual", String(art[0]), float(art[1]), Vector3.ZERO, not (String(parent.name) in ["Terrace", "Roof"]))
		return body
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = box_mesh(size, finish(parent, mat_id, nm, base - Vector3(size.x, 0.0, size.z) * 0.5,
		base + Vector3(size.x, size.y * 2.0, size.z) * 0.5, kind))
	mi.position = col.position
	add(body, mi)
	return body


## G2 (SL-1): a catalog prop's wrapper scene as the visual child `nm` of a map-built body (yaw / offset in the body's
## frame). Any collision the model ships with is switched off: the body's layout collider stays the gameplay shape.
func _art_visual(body: Node3D, nm: String, asset: String, yaw: float, offset: Vector3, near: bool = false) -> Node3D:
	var ps: PackedScene = _catalog_scene(asset)
	if ps == null:
		return null
	if near:
		ps = load(DRS.near_scene_path(asset, ps.resource_path)) as PackedScene
	var vis: Node3D = ps.instantiate() as Node3D
	vis.name = nm
	vis.transform = Transform3D(yaw_basis(yaw), offset)
	add(body, vis)  # inside the body's prop (levelcheck: the body is the prop root and carries the metas)
	var shapes: Array[Node] = vis.find_children("*", "CollisionShape3D", true, false)
	if not shapes.is_empty():
		map_root.set_editable_instance(vis, true)
		for m: Node in vis.find_children("*", "", true, false):
			if m.scene_file_path != "":
				map_root.set_editable_instance(m, true)
		for c: Node in vis.find_children("*", "CollisionObject3D", true, false):
			(c as CollisionObject3D).collision_layer = 0
		for s: Node in shapes:
			(s as CollisionShape3D).disabled = true
	return vis


func chair(parent: Node3D, nm: String, base: Vector3, yaw: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = yaw_basis(yaw)
	body.set_meta(&"kind", "chair")
	add(parent, body)
	var size: Vector3 = Vector3(0.45, 0.85, 0.45)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = box_shape(size)
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	add(body, col)
	var m: Marker3D = Marker3D.new()
	m.name = "Seat"
	m.position = Vector3(0.0, 0.45, 0.0)
	add(body, m)
	if DD.CHAIR_ART.has(nm):  # G2 (SL-1): the catalog chair over the unchanged 0.45 m collider / seat
		body.set_meta(&"art_asset", String(DD.CHAIR_ART[nm]))
		_art_visual(body, "Visual", String(DD.CHAIR_ART[nm]), 0.0, Vector3.ZERO, true)
	else:
		mesh_box(body, "SeatMesh", Vector3(-0.225, 0.0, -0.225), Vector3(0.225, 0.45, 0.225), "chair")
		mesh_box(body, "BackMesh", Vector3(-0.225, 0.45, 0.165), Vector3(0.225, 0.85, 0.225), "chair")
	obstruct(body.transform, AABB(Vector3(-0.225, 0.0, -0.225), size))


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
