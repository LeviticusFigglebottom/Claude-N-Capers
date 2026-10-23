## Rolling Thunder road markings (RT-C2 G3, LEAD r305 punch list 1). Owner: ENV C. One visual-only mesh
## (Geometry/Site/RoadMarkings) from the layout's MARKINGS quads (tools/levelcheck/plans/rolling_thunder_markings.py):
## lane and edge lines, the double centre line, stop lines, crosswalks and lane arrows in the library road paint
## (paint_white), MARK_LIFT above the asphalt. No collision, no navmesh obstruction, no shadow; it takes the GI like
## the grade under it.
extends RefCounted

const L: GDScript = preload("res://world/heists/rolling_thunder/greybox/rolling_thunder_layout.gd")
const MAT_DIR: String = "res://world/materials/"
const PAINT: String = "paint_white"
## Planar UVs (m per texture repeat) so the paint's grain reads at the asphalt's scale.
const UV_M: float = 2.0

var b: Object


func _init(builder: Object) -> void:
	b = builder


func build() -> int:
	var root: Node = b.get(&"map_root")
	var site: Node3D = root.get_node_or_null("Geometry/Site") as Node3D
	if site == null:
		site = root.get_node("Geometry") as Node3D
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads: int = 0
	for row: Array in L.MARKINGS:
		for q: Array in row[1]:
			_quad(st, q)
			quads += 1
	st.index()
	st.generate_tangents()
	var mat: Material = load(MAT_DIR + PAINT + ".tres") as Material
	if mat == null:
		var errs: PackedStringArray = b.get(&"errors")
		errs.append("rt_markings: missing material %s" % PAINT)
		b.set(&"errors", errs)
	st.set_material(mat)
	var mesh: ArrayMesh = st.commit()
	mesh.resource_name = "rt_road_markings"
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "RoadMarkings"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta(&"decal", true)
	b.call(&"add", site, mi)
	return quads


## Two triangles, face up: Godot's front faces wind clockwise as seen, so from above (the corners' winding is fixed
## here, whichever way the data lists them).
static func _quad(st: SurfaceTool, q: Array) -> void:
	var p: Array[Vector3] = []
	for i: int in range(4):
		p.append(Vector3(float(q[i * 3]), float(q[i * 3 + 1]), float(q[i * 3 + 2])))
	if (p[1] - p[0]).cross(p[2] - p[0]).y > 0.0:
		p.reverse()
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(p[idx].x, p[idx].z) / UV_M)
		st.add_vertex(p[idx])
