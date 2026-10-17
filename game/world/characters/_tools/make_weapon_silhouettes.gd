## LEAD (k), 2026-10-17: far weapon silhouettes for armed NPCs. ENV A culls an NPC's full held weapon (player-quality
## armory model, 4-13k tris, 11-20 parts, each its own draw + shadow draw) beyond the body's CrowdLod switch
## (UNIT_SWITCH_M, 25 m) and shows this instead: one MeshInstance3D, one surface, 70-210 tris, no shadow,
## visibility_range_begin = UNIT_SWITCH_M, so loud fights still read "armed" at range.
## The silhouette is the armory model's side profile: per 2 cm slice along the barrel axis (Z), the Y extent of the
## model's surface (points sampled over every triangle); runs of slices with near-equal extents merge into one box;
## each box is extruded to the model's core width (X). Same frame as the model (weapon origin = the firing-hand
## pivot, -Z muzzle, +Y up), so ENV A parents it at HandR/Socket next to the WeaponVisual. One per model mapped in
## NpcWeaponModels (B's npc_weapon_models.tres).
## Writes res://world/characters/_props/weapon_silhouettes/weapon_silhouette_<model>.tscn (+ _mesh.res) and
## weapon_silhouettes.json (NPC weapon id -> scene). Deterministic. Owner: ENV D.
##   /opt/godot/godot --headless --path game --script res://world/characters/_tools/make_weapon_silhouettes.gd
extends SceneTree

const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const MAP: String = "res://content/data/npc/npc_weapon_models.tres"
const DEFS: String = "res://content/data/weapons/%s.tres"
const OUT_DIR: String = "res://world/characters/_props/weapon_silhouettes/"
const MATERIAL: String = "res://world/materials/char_cartel_gunmetal.tres"
## slice length along Z (m) and the extent change (m) that starts a new box
const SLICE: float = 0.02
const MERGE_TOL: float = 0.012
## the silhouette's width: this share of the model's X extent (the receiver core, not the widest knob)
const WIDTH_SHARE: float = 0.7


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var models: Dictionary = load(MAP).get("models") as Dictionary
	var index: Dictionary = {}
	var done: Dictionary = {}
	var ids: Array = models.keys()
	ids.sort()
	for npc_id: Variant in ids:
		var model_id: String = String(models[npc_id]).trim_prefix("weapon.")
		var scene_path: String = OUT_DIR + "weapon_silhouette_%s.tscn" % model_id
		index[String(npc_id)] = scene_path
		if done.has(model_id):
			continue
		done[model_id] = true
		var def: Resource = load(DEFS % model_id)
		if def == null or def.get("model") == null:
			push_error("make_weapon_silhouettes: no model for %s" % model_id)
			continue
		var mesh: ArrayMesh = _silhouette((def.get("model") as PackedScene).instantiate() as Node3D)
		var mesh_path: String = OUT_DIR + "weapon_silhouette_%s_mesh.res" % model_id
		ResourceSaver.save(mesh, mesh_path)
		_write_scene(scene_path, mesh_path, model_id, mesh)
	var f: FileAccess = FileAccess.open(OUT_DIR + "weapon_silhouettes.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"_doc": "NPC weapon id -> far silhouette scene (make_weapon_silhouettes.gd); "
			+ "shown from visibility_range_begin = UNIT_SWITCH_M, where ENV A culls the full weapon.",
			"switch_m": CrowdLod.UNIT_SWITCH_M, "silhouettes": index}, "\t") + "\n")
	f.close()
	quit()


## Side-profile boxes of `model` (freed here) as one ArrayMesh surface with the shared gunmetal material.
func _silhouette(model: Node3D) -> ArrayMesh:
	var pts: PackedVector3Array = []
	var x_min: float = INF
	var x_max: float = -INF
	for m: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = _rel(mi, model)
		for s: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ia: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if ia.is_empty():
				ia.resize(vs.size())
				for k: int in vs.size():
					ia[k] = k
			for t: int in range(0, ia.size() - 2, 3):
				var a: Vector3 = xf * vs[ia[t]]
				var b: Vector3 = xf * vs[ia[t + 1]]
				var c: Vector3 = xf * vs[ia[t + 2]]
				for p: Vector3 in [a, b, c]:
					x_min = minf(x_min, p.x)
					x_max = maxf(x_max, p.x)
				_sample_tri(pts, a, b, c)
	model.free()
	var z_min: float = INF
	var z_max: float = -INF
	for p: Vector3 in pts:
		z_min = minf(z_min, p.z)
		z_max = maxf(z_max, p.z)
	var n: int = maxi(1, ceili((z_max - z_min) / SLICE))
	var lo: PackedFloat32Array = []
	var hi: PackedFloat32Array = []
	lo.resize(n)
	hi.resize(n)
	lo.fill(INF)
	hi.fill(-INF)
	for p: Vector3 in pts:
		var i: int = clampi(int((p.z - z_min) / SLICE), 0, n - 1)
		lo[i] = minf(lo[i], p.y)
		hi[i] = maxf(hi[i], p.y)
	var half_w: float = maxf(0.006, (x_max - x_min) * WIDTH_SHARE * 0.5)
	var cx: float = (x_max + x_min) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # flat faces: no streaks across neighbouring boxes
	var start: int = 0
	for i: int in range(1, n + 1):
		if i < n and lo[start] != INF and lo[i] != INF and absf(lo[i] - lo[start]) <= MERGE_TOL \
				and absf(hi[i] - hi[start]) <= MERGE_TOL:
			continue
		if lo[start] == INF:  # an empty slice (a real gap between parts): no box
			start = i
			continue
		var y0: float = lo[start]
		var y1: float = hi[start]
		for k: int in range(start, i):
			y0 = minf(y0, lo[k])
			y1 = maxf(y1, hi[k])
		_box(st, Vector3(cx - half_w, y0, z_min + start * SLICE), Vector3(cx + half_w, y1, z_min + i * SLICE))
		start = i
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, load(MATERIAL) as Material)
	return mesh


## Points over triangle abc, at most SLICE / 2 apart, so a long low-poly face covers every slice it spans.
func _sample_tri(pts: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var edge: float = maxf(maxf(a.distance_to(b), b.distance_to(c)), c.distance_to(a))
	var k: int = clampi(ceili(edge / (SLICE * 0.5)), 1, 200)
	for i: int in k + 1:
		for j: int in k + 1 - i:
			var u: float = float(i) / k
			var v: float = float(j) / k
			pts.append(a + (b - a) * u + (c - a) * v)


## `node`'s transform in `top`'s space (parent chain; works outside the scene tree).
func _rel(node: Node3D, top: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != top:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _box(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var c: Array[Vector3] = [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z),
		Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	var centre: Vector3 = (a + b) * 0.5
	for q: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 4, 7, 3], [1, 5, 6, 2]]:
		var out: Vector3 = (c[q[0]] + c[q[1]] + c[q[2]] + c[q[3]]) * 0.25 - centre
		for t: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			var p0: Vector3 = c[t[0]]
			var p1: Vector3 = c[t[1]]
			var p2: Vector3 = c[t[2]]
			# Godot front faces wind clockwise as seen from outside: (p1 - p0) x (p2 - p0) points inward
			if (p1 - p0).cross(p2 - p0).dot(out) > 0.0:
				var tmp: Vector3 = p1
				p1 = p2
				p2 = tmp
			st.add_vertex(p0)
			st.add_vertex(p1)
			st.add_vertex(p2)


func _write_scene(path: String, mesh_path: String, model_id: String, mesh: ArrayMesh) -> void:
	var tris: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	var mi := MeshInstance3D.new()
	mi.name = "WeaponSilhouette"
	mi.mesh = load(mesh_path) as Mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_begin = CrowdLod.UNIT_SWITCH_M
	mi.set_meta(&"model", model_id)
	mi.set_meta(&"tris", tris)
	var ps := PackedScene.new()
	ps.pack(mi)
	ResourceSaver.save(ps, path)
	mi.free()
	print("make_weapon_silhouettes: %s %d tris" % [path, tris])
