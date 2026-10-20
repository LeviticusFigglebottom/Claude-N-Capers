## NPC third-person weapons baked to one draw (LEAD r244 (b), D's OF perf audit: a stock gun is 11-20 MeshInstances /
## 13-23 surfaces, so a loud OF fight drew ~1600 weapon surfaces). bake(def) merges every visible part of the stock
## model into ONE surface: each part's library material becomes per-vertex values (COLOR = the albedo texture's
## linear mean x albedo_color, UV2 = the ORM texture's mean metallic / roughness x the scalars), drawn by one shared
## ShaderMaterial (npc_weapon_merged.tres), with auto LODs. The contract markers (Muzzle, LeftHandIK, AimPoint, ...)
## are copied flat at their model-space transforms, so WeaponVisual.get_marker() works unchanged.
## Players keep the full first/third-person model (WeaponVisual.setup); NPCs use WeaponVisual.setup_npc().
## Regenerate after a weapon model change (the tests compare markers and bounds with the source):
##   godot --headless --path game -s res://content/weapons/tools/npc_weapon_bake_cli.gd
## Owner: ENV B.
class_name NpcWeaponBake
extends RefCounted

const DIR: String = "res://assets/weapons/npc/"
const MATERIAL_PATH: String = "res://content/weapons/npc_weapon_merged.tres"
const MERGED_NODE: StringName = &"Merged"
## Fallback when a part's material is not a BaseMaterial3D (none today).
const FALLBACK: Array = [Color(0.2, 0.2, 0.2), 0.0, 0.6]


## The baked scene path for armory weapon `weapon_id` (weapon.corsair_ar -> res://assets/weapons/npc/corsair_ar_npc3p.tscn).
static func scene_path(weapon_id: StringName) -> String:
	return DIR + String(weapon_id).trim_prefix("weapon.") + "_npc3p.tscn"


## The baked scene for `def`, or null when it has none (the caller falls back to the full model).
static func scene(def: WeaponDef) -> PackedScene:
	if def == null:
		return null
	var p: String = scene_path(def.id)
	return load(p) as PackedScene if ResourceLoader.exists(p) else null


## Build the merged node tree for `def`'s stock model: root Node3D, `Merged` MeshInstance3D (one surface, LODs),
## and the model's marker nodes. Every node is owned by the root (ready to pack). Null when `def` has no model.
static func bake(def: WeaponDef) -> Node3D:
	if def == null or def.model == null:
		return null
	var src: Node3D = def.model.instantiate() as Node3D
	var arrays: Dictionary = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(),
			"uv2": PackedVector2Array(), "i": PackedInt32Array()}
	var looks: Dictionary = {}
	for n: Node in src.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh != null and _shown(src, mi):
			_append(arrays, mi, WeaponVisual._transform_to(src, mi), looks)
	var root: Node3D = Node3D.new()
	root.name = StringName(String(def.id).trim_prefix("weapon.") + "_npc3p")
	var mi_out: MeshInstance3D = MeshInstance3D.new()
	mi_out.name = MERGED_NODE
	mi_out.mesh = _mesh(arrays)
	root.add_child(mi_out)
	mi_out.owner = root
	for m: Node3D in markers(src):
		var copy: Node3D = Node3D.new()
		copy.name = m.name
		copy.transform = WeaponVisual._transform_to(src, m)
		root.add_child(copy)
		copy.owner = root
	src.free()
	return root


## Bake and save every NPC-carried weapon (NpcWeaponModels' mapped armory models): <weapon>_npc3p.tscn plus its
## mesh as <weapon>_npc3p_mesh.res. Returns one report line per weapon.
static func bake_all() -> Array[String]:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var out: Array[String] = []
	var done: Dictionary = {}
	for npc_id: StringName in NpcWeaponModels.data().models:
		var def: WeaponDef = NpcWeaponModels.weapon_def(npc_id)
		if def == null or done.has(def.id):
			continue
		done[def.id] = true
		var root: Node3D = bake(def)
		var path: String = scene_path(def.id)
		var mi: MeshInstance3D = root.get_node(NodePath(String(MERGED_NODE))) as MeshInstance3D
		var mesh_path: String = path.trim_suffix(".tscn") + "_mesh.res"
		ResourceSaver.save(mi.mesh, mesh_path)
		mi.mesh.take_over_path(mesh_path)
		var ps: PackedScene = PackedScene.new()
		ps.pack(root)
		var err: Error = ResourceSaver.save(ps, path)
		var tris: int = (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		out.append("NPCBAKE %s -> %s: %d tris, err %d" % [def.id, path, tris, err])
		root.free()
	return out


## The non-mesh Node3Ds of a model (contract markers and helpers), first of each name, excluding the root.
static func markers(model: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var seen: Dictionary = {}
	for n: Node in model.find_children("*", "Node3D", true, false):
		if n is MeshInstance3D or seen.has(n.name):
			continue
		seen[n.name] = true
		out.append(n as Node3D)
	return out


## A part shows at rest: visible up to the root and not a reload prop (WeaponVisual.HIDDEN_AT_REST).
static func _shown(root: Node3D, node: Node3D) -> bool:
	var n: Node = node
	while n != null and n != root:
		if (n is Node3D and not (n as Node3D).visible) or WeaponVisual.HIDDEN_AT_REST.has(n.name):
			return false
		n = n.get_parent()
	return true


static func _append(out: Dictionary, mi: MeshInstance3D, xf: Transform3D, looks: Dictionary) -> void:
	# Packed arrays are values: work on locals and store them back.
	var v: PackedVector3Array = out["v"]
	var nn: PackedVector3Array = out["n"]
	var c: PackedColorArray = out["c"]
	var u2: PackedVector2Array = out["uv2"]
	var ii: PackedInt32Array = out["i"]
	var nb: Basis = xf.basis.inverse().transposed()
	var flip: bool = xf.basis.determinant() < 0.0
	for s: int in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var mat: Material = mi.get_active_material(s)
		if not looks.has(mat):
			looks[mat] = look(mat)
		var lk: Array = looks[mat]
		var uv2: Vector2 = Vector2(lk[1], lk[2])
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var base: int = v.size()
		for k: int in verts.size():
			v.append(xf * verts[k])
			nn.append((nb * norms[k]).normalized() if k < norms.size() else Vector3.UP)
			c.append(lk[0])
			u2.append(uv2)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for k: int in verts.size():
				idx.append(k)
		for t: int in range(0, idx.size(), 3):
			ii.append(base + idx[t])
			ii.append(base + idx[t + (2 if flip else 1)])
			ii.append(base + idx[t + (1 if flip else 2)])
	out["v"] = v
	out["n"] = nn
	out["c"] = c
	out["uv2"] = u2
	out["i"] = ii


## A part material's flat look: [linear albedo Color, metallic, roughness] (texture means x the material scalars).
static func look(mat: Material) -> Array:
	var bm: BaseMaterial3D = mat as BaseMaterial3D
	if bm == null:
		return FALLBACK
	var alb: Color = bm.albedo_color.srgb_to_linear()
	var albedo_tex: Texture2D = bm.albedo_texture
	if albedo_tex != null:
		var m: Color = _mean(albedo_tex, true)
		alb = Color(alb.r * m.r, alb.g * m.g, alb.b * m.b)
	var metal: float = bm.metallic
	var rough: float = bm.roughness
	var orm: ORMMaterial3D = bm as ORMMaterial3D
	if orm != null and orm.orm_texture != null:
		var o: Color = _mean(orm.orm_texture, false)
		rough *= o.g
		metal *= o.b
	else:
		if bm.metallic_texture != null:
			metal *= _mean(bm.metallic_texture, false).r
		if bm.roughness_texture != null:
			rough *= _mean(bm.roughness_texture, false).r
	return [alb, clampf(metal, 0.0, 1.0), clampf(rough, 0.0, 1.0)]


## Mean of a texture (linear; an sRGB texture is decoded per texel before averaging).
static func _mean(tex: Texture2D, srgb: bool) -> Color:
	var img: Image = tex.get_image()
	if img == null:
		return Color(0.5, 0.5, 0.5)
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	img.resize(32, 32, Image.INTERPOLATE_LANCZOS)
	var sum: Color = Color(0, 0, 0)
	for y: int in 32:
		for x: int in 32:
			var c: Color = img.get_pixel(x, y)
			sum += c.srgb_to_linear() if srgb else c
	return Color(sum.r / 1024.0, sum.g / 1024.0, sum.b / 1024.0)


static func _mesh(a: Dictionary) -> ArrayMesh:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = a["v"]
	arr[Mesh.ARRAY_NORMAL] = a["n"]
	arr[Mesh.ARRAY_COLOR] = a["c"]
	arr[Mesh.ARRAY_TEX_UV2] = a["uv2"]
	arr[Mesh.ARRAY_INDEX] = a["i"]
	var im: ImporterMesh = ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, load(MATERIAL_PATH) as Material, "merged")
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()
