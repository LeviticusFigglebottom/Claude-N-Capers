## glTF post-import: maps Blender material slots onto the shared material library. Owner: ENV C.
##
## Wired per file through `import_script/path` in each `<asset>.glb.import` (tools/blender/build.py
## writes it). For every MeshInstance3D surface whose material is named `M_<library_id>`, assigns
## `res://world/materials/<library_id>.tres` on the mesh resource itself (mesh.surface_set_material),
## so it is saved with the imported scene. If that library material does not exist yet the
## embedded flat-colour placeholder is kept and a warning is pushed. A surface never ends up with a
## null material: if one has none, the greybox prop material (or a fresh flat material) is used.
##
## Collision is produced by Godot's own name suffixes before this script runs (style guide §5):
## a mesh node `Collision-colonly` becomes StaticBody3D `Collision` with a trimesh shape
## (architecture), `Collision-convcolonly` becomes StaticBody3D `Collision` with a convex shape
## (props). Their meshes are removed by the importer. `-col` keeps the mesh and adds a trimesh body.
@tool
extends EditorScenePostImport

const LIBRARY_DIR: String = "res://world/materials/"
## Prop materials (tinted library surfaces, emissives; tools/blender/props/_make_materials.py).
const PROP_LIBRARY_DIR: String = "res://world/props/materials/"
const MATERIAL_PREFIX: String = "M_"
const FALLBACK_MATERIAL: String = "res://world/materials/grey_prop.tres"


func _post_import(scene: Node) -> Object:
	var source: String = get_source_file()
	_visit(scene, source)
	return scene


func _visit(node: Node, source: String) -> void:
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null and mi.mesh != null:
		_map_mesh(mi, source)
	for child: Node in node.get_children():
		_visit(child, source)


func _map_mesh(mi: MeshInstance3D, source: String) -> void:
	var mesh: Mesh = mi.mesh
	for i: int in range(mesh.get_surface_count()):
		var current: Material = mesh.surface_get_material(i)
		var mapped: Material = resolve(current, "%s:%s/%d" % [source, mi.name, i])
		if mapped != current:
			mesh.surface_set_material(i, mapped)


## Library material for `current` (by `M_<id>` name), or `current` itself, never null.
static func resolve(current: Material, where: String) -> Material:
	if current == null:
		push_warning("glb_post_import: %s has no material; using fallback" % where)
		return _fallback()
	var mat_name: String = current.resource_name
	if not mat_name.begins_with(MATERIAL_PREFIX):
		push_warning("glb_post_import: %s material '%s' is not named M_<library_id>" % [where, mat_name])
		return current
	var lib_id: String = mat_name.substr(MATERIAL_PREFIX.length())
	var path: String = library_path(lib_id)
	if not ResourceLoader.exists(path):
		push_warning("glb_post_import: %s library material %s missing; keeping placeholder" % [where, path])
		return current
	var lib: Material = load(path) as Material
	if lib == null:
		push_warning("glb_post_import: %s could not load %s; keeping placeholder" % [where, path])
		return current
	return lib


## Library material path for `lib_id`: world/materials first, then world/props/materials.
static func library_path(lib_id: String) -> String:
	var main: String = LIBRARY_DIR + lib_id + ".tres"
	if ResourceLoader.exists(main):
		return main
	var prop: String = PROP_LIBRARY_DIR + lib_id + ".tres"
	if ResourceLoader.exists(prop):
		return prop
	return main


static func _fallback() -> Material:
	if ResourceLoader.exists(FALLBACK_MATERIAL):
		var fb: Material = load(FALLBACK_MATERIAL) as Material
		if fb != null:
			return fb
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = "M_missing"
	mat.albedo_color = Color(0.6, 0.3, 0.5)
	return mat
