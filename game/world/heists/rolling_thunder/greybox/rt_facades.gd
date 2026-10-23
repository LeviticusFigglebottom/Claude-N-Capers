## Rolling Thunder G3 near facades + the Skyway soffit (RT-C2, LEAD r305 punch list 2 / 4). Owner: ENV C. Visual only
## (no collision, no bake obstruction): the neighbour faces the player sees from play space get a facade rhythm (window
## bays on a 4 m x 3.6 m grid, ground-floor service doors with frames and canopies, a string course, a cornice,
## downpipes, a shop sign per face), and the Skyway's flat soffit gets its girder lines (longitudinal beams, diaphragms,
## two expansion joints). Everything stays within FACE_D of the face, so it never reaches into the walk space beside a
## neighbour (the sidewalks are >= 3 m).
extends RefCounted

const MAT_DIR: String = "res://world/materials/"
## [name, outward normal, the face plane (x for +-X faces, z for +-Z faces), along from, along to, height]
const FACES: Array = [
	["AshbyN", Vector3.FORWARD, 30.0, -60.0, -24.0, 14.4],      # the plaza's south side (rc_ext_plaza)
	["AshbyE", Vector3.RIGHT, -24.0, 30.0, 50.0, 14.4],         # Ashby's front on its forecourt
	["BlockNW", Vector3.RIGHT, -14.0, -100.0, -56.0, 10.0],     # Orchard north, under the Skyway
	["BlockNE", Vector3.LEFT, 14.0, -100.0, -56.0, 10.0],
	["BlockSW", Vector3.RIGHT, -14.0, 50.0, 80.0, 10.0],        # Orchard south, under the Skyway
	["BlockSE", Vector3.LEFT, 14.0, 40.0, 80.0, 10.0],
	["WarehousesSW", Vector3.RIGHT, -60.0, 11.0, 30.0, 9.0],    # the plaza's west end
]
const FACE_D: float = 0.2
const STOREY: float = 3.6
const FIRST_SILL: float = 4.9
const BAY: float = 4.0
const WIN: Vector2 = Vector2(1.5, 2.0)
const FRAME_T: float = 0.08
const DOOR_PITCH: float = 12.0
const DOOR: Vector2 = Vector2(1.2, 2.3)
const PIPE_PITCH: float = 16.0
const BAND_Y: Vector2 = Vector2(4.0, 4.3)
## Skyway soffit (rolling_thunder_geometry SKY_DECK: soffit 7.6) over Orchard (x -13..13, z -100..80).
const SOFFIT_Y: float = 7.6
const BEAM_X: Array[float] = [-10.5, -5.25, 0.0, 5.25, 10.5]
const BEAM: Vector2 = Vector2(0.5, 0.6)
const DIAPHRAGM_PITCH: float = 10.0
const SKY_Z: Vector2 = Vector2(-100.0, 80.0)
const SKY_X: Vector2 = Vector2(-13.0, 13.0)
const JOINT_Z: Array[float] = [-56.0, 14.0]
## material key -> [library material, albedo tint]
const MATS: Dictionary = {
	"frame": ["metal_painted", Color(0.17, 0.18, 0.19)],
	"door": ["metal_painted", Color(0.24, 0.27, 0.3)],
	"pipe": ["metal_painted", Color(0.32, 0.33, 0.34)],
	"band": ["concrete", Color(0.78, 0.76, 0.72)],
	"sign": ["plywood_painted", Color(0.45, 0.09, 0.07)],
	"girder": ["concrete", Color(0.62, 0.62, 0.6)],
	"joint": ["metal_matte", Color(0.2, 0.2, 0.2)],
}
const GLASS: Color = Color(0.1, 0.13, 0.16)

var b: Object
var counts: Dictionary = {}
var _st: Dictionary = {}


func _init(builder: Object) -> void:
	b = builder


func build() -> Dictionary:
	var root: Node = b.get(&"map_root")
	var site: Node3D = root.get_node_or_null("Geometry/Site") as Node3D
	if site == null:
		site = root.get_node("Geometry") as Node3D
	for f: Array in FACES:
		_face(f)
	_soffit()
	var keys: Array = _st.keys()
	keys.sort()
	var mesh: ArrayMesh = ArrayMesh.new()
	for key: String in keys:
		var st: SurfaceTool = _st[key]
		st.index()
		st.generate_tangents()
		st.set_material(_mat(key))
		st.commit(mesh)
	mesh.resource_name = "rt_near_facades"
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "NearFacades"
	mi.mesh = mesh
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.set_meta(&"facade", true)
	b.call(&"add", site, mi)
	return counts


# --- Facades -------------------------------------------------------------------------------------

func _face(f: Array) -> void:
	var n: Vector3 = f[1]
	var fixed: float = float(f[2])
	var a0: float = float(f[3])
	var a1: float = float(f[4])
	var h: float = float(f[5])
	var along_x: bool = absf(n.z) > 0.5

	var at: Callable = func(a: float, y: float, out: float) -> Vector3:
		return (Vector3(a, y, fixed) if along_x else Vector3(fixed, y, a)) + n * out

	# string course and cornice: full-length bands
	_slab("band", at.call(a0, BAND_Y.x, 0.0), at.call(a1, BAND_Y.y, 0.12))
	_slab("band", at.call(a0, h - 0.5, 0.0), at.call(a1, h, FACE_D))
	# ground floor: service doors on a 12 m pitch (frame, leaf, canopy), the sign over the middle one
	var nd: int = maxi(1, int(floor((a1 - a0 - 4.0) / DOOR_PITCH)))
	var d0: float = (a0 + a1) * 0.5 - float(nd - 1) * DOOR_PITCH * 0.5
	for k: int in range(nd):
		var c: float = d0 + float(k) * DOOR_PITCH
		_framed(c, 0.0, DOOR.x, DOOR.y, at, "door")
		_slab("frame", at.call(c - 0.9, DOOR.y + 0.25, 0.0), at.call(c + 0.9, DOOR.y + 0.35, 0.6))
		if k == int(nd / 2.0):
			_slab("sign", at.call(c - 1.6, DOOR.y + 0.6, 0.0), at.call(c + 1.6, DOOR.y + 1.2, 0.1))
		counts["doors"] = int(counts.get("doors", 0)) + 1
	# ground-floor windows between the doors, upper floors on the bay grid
	var cols: int = int(floor((a1 - a0 - 2.0) / BAY))
	var c0: float = (a0 + a1) * 0.5 - float(cols - 1) * BAY * 0.5
	for k2: int in range(cols):
		var c2: float = c0 + float(k2) * BAY
		var near_door: bool = false
		for k3: int in range(nd):
			if absf(c2 - (d0 + float(k3) * DOOR_PITCH)) < 2.2:
				near_door = true
		if not near_door:
			_framed(c2, 0.9, WIN.x, WIN.y + 0.4, at, "glass")
		var y: float = FIRST_SILL
		while y + WIN.y < h - 0.9:
			_framed(c2, y, WIN.x, WIN.y, at, "glass")
			counts["windows"] = int(counts.get("windows", 0)) + 1
			y += STOREY
	# downpipes on a 16 m pitch, off the bay grid
	var p: float = a0 + 2.0
	while p < a1 - 1.0:
		_slab("pipe", at.call(p - 0.06, 0.0, 0.04), at.call(p + 0.06, h - 0.5, 0.16))
		p += PIPE_PITCH


## A frame (FRAME_T border, 0.06 proud) around a panel (`kind`: glass / door, 0.03 proud) centred on `c`, from `y0`.
func _framed(c: float, y0: float, w: float, hh: float, at: Callable, kind: String) -> void:
	var hw: float = w * 0.5
	_slab("frame", at.call(c - hw - FRAME_T, y0 - FRAME_T, 0.0), at.call(c + hw + FRAME_T, y0, 0.06))
	_slab("frame", at.call(c - hw - FRAME_T, y0 + hh, 0.0), at.call(c + hw + FRAME_T, y0 + hh + FRAME_T, 0.06))
	_slab("frame", at.call(c - hw - FRAME_T, y0, 0.0), at.call(c - hw, y0 + hh, 0.06))
	_slab("frame", at.call(c + hw, y0, 0.0), at.call(c + hw + FRAME_T, y0 + hh, 0.06))
	_slab(kind, at.call(c - hw, y0, 0.0), at.call(c + hw, y0 + hh, 0.03))


# --- Skyway soffit -------------------------------------------------------------------------------

func _soffit() -> void:
	for x: float in BEAM_X:
		_box("girder", Vector3(x - BEAM.x * 0.5, SOFFIT_Y - BEAM.y, SKY_Z.x), Vector3(x + BEAM.x * 0.5, SOFFIT_Y, SKY_Z.y))
		counts["beams"] = int(counts.get("beams", 0)) + 1
	var z: float = SKY_Z.x + DIAPHRAGM_PITCH
	while z < SKY_Z.y - 1.0:
		_box("girder", Vector3(SKY_X.x, SOFFIT_Y - 0.45, z - 0.15), Vector3(SKY_X.y, SOFFIT_Y, z + 0.15))
		counts["diaphragms"] = int(counts.get("diaphragms", 0)) + 1
		z += DIAPHRAGM_PITCH
	for jz: float in JOINT_Z:
		_box("joint", Vector3(SKY_X.x, SOFFIT_Y - 0.02, jz - 0.1), Vector3(SKY_X.y, SOFFIT_Y, jz + 0.1))


# --- Mesh helpers --------------------------------------------------------------------------------

## A slab between two points given in face space (any corner order).
func _slab(key: String, p: Vector3, q: Vector3) -> void:
	_box(key, Vector3(minf(p.x, q.x), minf(p.y, q.y), minf(p.z, q.z)), Vector3(maxf(p.x, q.x), maxf(p.y, q.y), maxf(p.z, q.z)))


## An axis-aligned box (all six faces, outward normals, planar UVs at 1 m).
func _box(key: String, lo: Vector3, hi: Vector3) -> void:
	if not _st.has(key):
		var s: SurfaceTool = SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = s
	var st: SurfaceTool = _st[key]
	var c: Array[Vector3] = [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	# [corner indices CCW seen from outside, normal]; emitted reversed (Godot's front faces wind clockwise as seen)
	var faces: Array = [
		[[4, 5, 6, 7], Vector3.BACK], [[1, 0, 3, 2], Vector3.FORWARD], [[5, 1, 2, 6], Vector3.RIGHT],
		[[0, 4, 7, 3], Vector3.LEFT], [[7, 6, 2, 3], Vector3.UP], [[0, 1, 5, 4], Vector3.DOWN],
	]
	for fc: Array in faces:
		var idx: Array = fc[0]
		var nn: Vector3 = fc[1]
		for i: int in [0, 2, 1, 0, 3, 2]:
			var v: Vector3 = c[int(idx[i])]
			st.set_normal(nn)
			st.set_uv(_uv(v, nn))
			st.add_vertex(v)


static func _uv(v: Vector3, n: Vector3) -> Vector2:
	if absf(n.y) > 0.5:
		return Vector2(v.x, v.z)
	if absf(n.x) > 0.5:
		return Vector2(v.z, -v.y)
	return Vector2(v.x, -v.y)


func _mat(key: String) -> Material:
	if key == "glass":
		var g: StandardMaterial3D = StandardMaterial3D.new()
		g.albedo_color = GLASS
		g.metallic = 0.6
		g.roughness = 0.12
		g.set_meta(&"untextured_ok", true)
		g.resource_name = "rt_near_glass"
		return g
	var spec: Array = MATS[key]
	var base: BaseMaterial3D = load(MAT_DIR + String(spec[0]) + ".tres") as BaseMaterial3D
	if base == null:
		var errs: PackedStringArray = b.get(&"errors")
		errs.append("rt_facades: missing material %s" % spec[0])
		b.set(&"errors", errs)
		base = StandardMaterial3D.new()
	var m: BaseMaterial3D = base.duplicate() as BaseMaterial3D
	m.albedo_color = spec[1]
	m.resource_name = "rt_near_" + key
	return m
