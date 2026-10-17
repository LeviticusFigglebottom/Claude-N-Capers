## Shadow Ledger skyline (SL-1 polish, ENV C): the towers south, south-west and east of Calder Tower, generated from a
## fixed seed (a local RandomNumberGenerator, never the global one) so every build is byte-identical. Each lot gets a
## tower of its own footprint and height, sometimes a setback crown, a roof plant block or two, an antenna mast; aircraft
## warning lights (red emissive, no Light3D) on the tallest and on every mast; lit office windows on the faces turned
## towards Calder: each floor is dark, fully lit or partly lit, warm or cool per tower. Visual only (no collision, meta
## distant), one merged mesh per material: the whole skyline is ~8 draws. Design: shadow_ledger.md §Site ("a skyline of
## 30-40-storey towers 40-80 m away", "facades with lit floors and beacons"). Used by build_greybox._build_art.
extends RefCounted

const SEED: int = 41_0717
## Street level far below (the StreetGrid top) and Calder's centre (the faces turned towards it get windows).
const GRADE: float = -160.0
const CENTRE: Vector2 = Vector2(18.0, 12.0)
## Lot bands: [name, x0, z0, x1, z1, lowest top, highest top]. Streets 9-14 m wide between the lots; a lot is 14-34 m.
## South (beyond Calder Street), south-west (behind Arden's south end), east (beyond Vantage House). The near rows
## stay below the roof (~+12): the views over them stay open; the far rows rise above it.
const BANDS: Array = [
	["S", -70.0, 62.0, 124.0, 160.0, -58.0, 26.0],
	["SW", -130.0, 48.0, -36.0, 140.0, -50.0, 18.0],
	["E", 112.0, -70.0, 190.0, 54.0, -46.0, 30.0],
]
## Storey heights and window modules (m) a tower picks from.
const STOREYS: Array[float] = [3.5, 3.8, 4.2]
const MODULES: Array[float] = [1.6, 2.0, 2.4, 3.0]
## Windows below this depth under a tower's top are not drawn (the rain haze hides them; vertex budget).
const WINDOW_DEPTH: float = 84.0
## Windows stand this far off their face: 45-200 m away, a 2 cm offset z-fought with the facade (hatched windows).
const WINDOW_PROUD: float = 0.1
const BODY_MATS: Array[String] = ["tower", "tower_dark", "tower_stone"]

var b: Object
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## material id -> SurfaceTool (one merged mesh each), in first-use order.
var _st: Dictionary = {}
var _order: Array[String] = []
var _beacons: Array[Vector3] = []


func _init(builder: Object) -> void:
	b = builder


## Builds Geometry/Site/Skyline and returns [towers, lit windows, beacons].
func skyline(site: Node3D, root: Node) -> Array:
	_rng.seed = SEED
	var holder: Node3D = Node3D.new()
	holder.name = "Skyline"
	site.add_child(holder)
	holder.owner = root
	var towers: int = 0
	var lit: int = 0
	var tall: Array = []  # [top, roof centre] of every tower
	for band: Array in BANDS:
		var x: float = float(band[1])
		while x < float(band[3]) - 12.0:
			var w: float = _rng.randf_range(14.0, 34.0)
			var z: float = float(band[2])
			while z < float(band[4]) - 12.0:
				var d: float = _rng.randf_range(14.0, 30.0)
				if _rng.randf() < 0.82:  # some lots are low-rise or plazas: gaps in the wall of towers
					var depth: float = absf(z + d * 0.5 - CENTRE.y) + absf(x + w * 0.5 - CENTRE.x)
					var far: float = clampf((depth - 60.0) / 140.0, 0.0, 1.0)
					var top: float = lerpf(float(band[5]), float(band[6]), _rng.randf() * 0.6 + far * 0.4)
					var res: Array = _tower(Vector3(x, GRADE, z), Vector3(minf(w, float(band[3]) - x), 0.0,
						minf(d, float(band[4]) - z)), top)
					lit += int(res[0])
					tall.append([res[1], res[2]])
					towers += 1
				z += d + _rng.randf_range(9.0, 14.0)
			x += w + _rng.randf_range(9.0, 14.0)
	# aircraft warning lights: the tallest towers' roofs (the masts carry their own)
	tall.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) > float(c[0]))
	for i: int in range(mini(6, tall.size())):
		_beacons.append(tall[i][1])
	for p: Vector3 in _beacons:
		_box("beacon_red", p + Vector3(-0.35, 0.0, -0.35), p + Vector3(0.35, 0.5, 0.35))
	for id: String in _order:
		var st: SurfaceTool = _st[id]
		st.generate_tangents()
		st.set_material(b.call(&"lib_mat", id) as Material)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Skyline_" + id.to_pascal_case()
		mi.mesh = st.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta(&"distant", true)
		if id == "beacon_red":
			mi.set_meta(&"fixture", true)
		holder.add_child(mi)
		mi.owner = root
	return [towers, lit, _beacons.size()]


## One tower on the lot at `lo` (grade) of footprint `size` (x, z) up to `top`: its body, maybe a setback crown, roof
## plant, a mast; its lit windows. Returns [lit windows, top, roof centre for a beacon].
func _tower(lo: Vector3, size: Vector3, top: float) -> Array:
	var mat: String = BODY_MATS[_rng.randi_range(0, BODY_MATS.size() - 1)]
	var inset: float = _rng.randf_range(1.0, 3.0)
	var hi: Vector3 = Vector3(lo.x + size.x, top, lo.z + size.z)
	var body_lo: Vector3 = lo
	var crown: bool = _rng.randf() < 0.45 and size.x > 18.0 and size.z > 18.0
	var crown_h: float = _rng.randf_range(7.0, 16.0) if crown else 0.0
	var main_top: float = top - crown_h
	_box(mat, body_lo, Vector3(hi.x, main_top, hi.z))
	var storey: float = STOREYS[_rng.randi_range(0, STOREYS.size() - 1)]
	var module: float = MODULES[_rng.randi_range(0, MODULES.size() - 1)]
	var warm: bool = _rng.randf() < 0.7
	var occupancy: float = _rng.randf_range(0.15, 0.6)
	var lit: int = _windows(body_lo, Vector3(hi.x, main_top, hi.z), storey, module, warm, occupancy)
	var roof_lo: Vector3 = body_lo
	var roof_hi: Vector3 = Vector3(hi.x, main_top, hi.z)
	if crown:
		var c_lo: Vector3 = Vector3(body_lo.x + inset + 2.0, main_top, body_lo.z + inset + 2.0)
		var c_hi: Vector3 = Vector3(hi.x - inset - 2.0, top, hi.z - inset - 2.0)
		_box(mat, c_lo, c_hi)
		lit += _windows(c_lo, c_hi, storey, module, warm, occupancy * 0.6)
		roof_lo = c_lo
		roof_hi = c_hi
	var rs: Vector3 = roof_hi - roof_lo
	# roof plant: one or two concrete blocks off the parapet line
	for i: int in range(_rng.randi_range(1, 2)):
		var pw: float = _rng.randf_range(3.0, minf(9.0, rs.x * 0.45))
		var pd: float = _rng.randf_range(3.0, minf(8.0, rs.z * 0.45))
		var px: float = _rng.randf_range(roof_lo.x + 1.5, roof_hi.x - 1.5 - pw)
		var pz: float = _rng.randf_range(roof_lo.z + 1.5, roof_hi.z - 1.5 - pd)
		_box("concrete", Vector3(px, roof_hi.y, pz), Vector3(px + pw, roof_hi.y + _rng.randf_range(2.5, 4.5), pz + pd))
	var centre: Vector3 = Vector3((roof_lo.x + roof_hi.x) * 0.5, roof_hi.y, (roof_lo.z + roof_hi.z) * 0.5)
	if _rng.randf() < 0.35:  # an antenna mast at a roof corner, a warning light on its tip
		var mx: float = roof_lo.x + 1.2 if _rng.randf() < 0.5 else roof_hi.x - 1.6
		var mz: float = roof_lo.z + 1.2 if _rng.randf() < 0.5 else roof_hi.z - 1.6
		var mh: float = _rng.randf_range(8.0, 22.0)
		_box("tower_dark", Vector3(mx, roof_hi.y, mz), Vector3(mx + 0.4, roof_hi.y + mh, mz + 0.4))
		_beacons.append(Vector3(mx + 0.2, roof_hi.y + mh, mz + 0.2))
	return [lit, roof_hi.y, centre]


## Lit windows on the faces of the box lo..hi turned towards Calder (and its sides), from WINDOW_DEPTH under the top
## up, WINDOW_PROUD off the face. Per floor: dark (30 %), fully lit (12 %), else each window lit at `occupancy`.
func _windows(lo: Vector3, hi: Vector3, storey: float, module: float, warm: bool, occupancy: float) -> int:
	var id: String = "city_lights" if warm else "city_lights_cool"
	var c: Vector2 = Vector2((lo.x + hi.x) * 0.5, (lo.z + hi.z) * 0.5)
	var to: Vector2 = (CENTRE - c).normalized()
	var n: int = 0
	# [outward normal, fixed coordinate of the face, along x?]
	for f: Array in [[Vector3.FORWARD, lo.z, true], [Vector3.BACK, hi.z, true], [Vector3.LEFT, lo.x, false],
			[Vector3.RIGHT, hi.x, false]]:
		var nrm: Vector3 = f[0]
		if Vector2(nrm.x, nrm.z).dot(to) < -0.3:
			continue
		var a0: float = lo.x if bool(f[2]) else lo.z
		var a1: float = hi.x if bool(f[2]) else hi.z
		var cols: int = int(floor((a1 - a0 - 1.2) / module))
		if cols < 1:
			continue
		var margin: float = (a1 - a0 - float(cols) * module) * 0.5
		var win_w: float = module * _rng.randf_range(0.55, 0.8)
		var win_h: float = storey * _rng.randf_range(0.45, 0.62)
		var face: float = float(f[1]) + (nrm.z if bool(f[2]) else nrm.x) * WINDOW_PROUD
		var y: float = hi.y - storey * 0.85
		var floor_y: float = maxf(lo.y + 2.0, hi.y - WINDOW_DEPTH)
		while y > floor_y:
			var roll: float = _rng.randf()
			var p: float = 0.0 if roll < 0.3 else (1.0 if roll < 0.42 else occupancy)
			for i: int in range(cols):
				if _rng.randf() >= p:
					continue
				var u: float = a0 + margin + (float(i) + 0.5) * module
				var wl: Vector3 = Vector3(u - win_w * 0.5, y, face) if bool(f[2]) else Vector3(face, y, u - win_w * 0.5)
				var wh: Vector3 = Vector3(u + win_w * 0.5, y + win_h, face) if bool(f[2]) \
					else Vector3(face, y + win_h, u + win_w * 0.5)
				_quad(id, wl, wh, nrm)
				n += 1
			y -= storey
	return n


func _tool(id: String) -> SurfaceTool:
	if not _st.has(id):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[id] = st
		_order.append(id)
	return _st[id]


## A closed box's outward faces but the bottom (it stands on the street or a roof), world UVs, clockwise front faces.
func _box(id: String, lo: Vector3, hi: Vector3) -> void:
	var st: SurfaceTool = _tool(id)
	var mid: Vector3 = (lo + hi) * 0.5
	var h: Vector3 = (hi - lo) * 0.5
	var faces: Array = [[Vector3.LEFT, Vector3.UP, Vector3.BACK], [Vector3.RIGHT, Vector3.BACK, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP], [Vector3.BACK, Vector3.UP, Vector3.RIGHT],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK]]
	for f: Array in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c: Vector3 = mid + nrm * h
		var hu: Vector3 = u * absf(u.dot(h))
		var hv: Vector3 = v * absf(v.dot(h))
		var q: Array = [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
		for k: int in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = q[k]
			st.set_normal(nrm)
			st.set_uv(Vector2(p.dot(u), p.dot(v)))
			st.add_vertex(p)


## One flat window rectangle lo..hi on a face (constant x or z) facing `nrm`, clockwise seen from that side.
func _quad(id: String, lo: Vector3, hi: Vector3, nrm: Vector3) -> void:
	var st: SurfaceTool = _tool(id)
	var along_x: bool = absf(nrm.z) > 0.5
	var a: Vector3 = lo
	var c: Vector3 = hi
	var bb: Vector3 = Vector3(hi.x, lo.y, lo.z) if along_x else Vector3(lo.x, lo.y, hi.z)
	var d: Vector3 = Vector3(lo.x, hi.y, lo.z)
	var pts: Array = [a, d, c, a, c, bb]
	if (d - a).cross(c - a).dot(nrm) > 0.0:
		pts = [a, c, d, a, bb, c]
	for p: Vector3 in pts:
		st.set_normal(nrm)
		st.set_uv(Vector2(p.x + p.z, p.y))
		st.add_vertex(p)
