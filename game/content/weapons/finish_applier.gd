## Puts a weapon finish on an assembled weapon model (B7-04). Owner: ENV B. Static; WeaponVisual.apply_finish
## calls it for the main gun and the akimbo offhand.
##
## Surfaces are matched by their STOCK material (the imported mesh's surface material, named `M_<library_id>`
## by the weapon build scripts and kept by ENV C's glb_post_import): SLOT_MATERIALS maps each finishable
## slot (the build scripts' `Mats.*` names) to that library id. A covered surface gets
## `MeshInstance3D.set_surface_override_material(i, finish material)`; everything else keeps (or gets back) no
## override. Nothing shared is changed: the mesh and its materials stay as imported, and finish materials are
## new resources (FinishMaterials). Only overrides tagged with FinishMaterials.META_FINISH are ever removed.
## Mod models attached by WeaponVisual (nodes named `Mod_*`) follow only when FinishDef.covers_mods.
class_name FinishApplier
extends RefCounted

## Finishable slot (build-script material name) -> library id of its stock material (`M_<id>`).
## Lenses, reticles, sight dots and cartridge brass are never finished.
const SLOT_MATERIALS: Dictionary = {
	&"polymer": &"polymer_black",
	&"stipple": &"polymer_stipple",
	&"steel": &"steel_blued",
	&"bare": &"steel_bare",
	&"matte": &"metal_matte",
	&"alu": &"alu_anodized_black",
	&"wood": &"wood_veneer_walnut",
	&"rubber": &"rubber_black",
	&"tan": &"polymer_tan",
	&"olive": &"polymer_olive",
}
const MATERIAL_PREFIX: String = "M_"


## Apply `def` to every mesh under `root` (null def = stock look). Returns how many surfaces now wear it.
static func apply(root: Node, def: FinishDef) -> int:
	if root == null:
		return 0
	var count: int = 0
	var skip_mods: bool = def != null and not def.covers_mods
	for mi: MeshInstance3D in _meshes(root, skip_mods):
		count += _apply_mesh(mi, def).x
	if skip_mods:
		clear_mods(root)
	return count


## Remove every finish override under `root` (stock look). Returns how many were removed.
static func clear(root: Node) -> int:
	if root == null:
		return 0
	var count: int = 0
	for mi: MeshInstance3D in _meshes(root, false):
		count += _apply_mesh(mi, null).y
	return count


## Remove finish overrides only inside attached mod models (`Mod_*` subtrees).
static func clear_mods(root: Node) -> void:
	for n: Node in root.find_children(WeaponVisual.MOD_NODE_PREFIX + "*", "Node3D", true, false):
		clear(n)


## The finishable slot of a stock material (&"" = not finishable / unknown).
static func slot_of(mat: Material) -> StringName:
	if mat == null or not mat.resource_name.begins_with(MATERIAL_PREFIX):
		return &""
	var lib: StringName = StringName(mat.resource_name.substr(MATERIAL_PREFIX.length()))
	for slot: StringName in SLOT_MATERIALS:
		if SLOT_MATERIALS[slot] == lib:
			return slot
	return &""


## The finish id a surface currently wears (&"" = stock).
static func worn(mi: MeshInstance3D, surface: int) -> StringName:
	var o: Material = mi.get_surface_override_material(surface)
	if o == null or not o.has_meta(FinishMaterials.META_FINISH):
		return &""
	return StringName(o.get_meta(FinishMaterials.META_FINISH))


## Sets / clears one mesh's surfaces: x = surfaces now wearing `def`, y = finish overrides removed.
static func _apply_mesh(mi: MeshInstance3D, def: FinishDef) -> Vector2i:
	var out: Vector2i = Vector2i.ZERO
	for i: int in range(mi.mesh.get_surface_count()):
		var current: Material = mi.get_surface_override_material(i)
		var ours: bool = current != null and current.has_meta(FinishMaterials.META_FINISH)
		if current != null and not ours:
			continue  # someone else's override (e.g. a gameplay effect): leave it alone
		var want: Material = null
		if def != null:
			var slot: StringName = slot_of(mi.mesh.surface_get_material(i))
			if slot != &"":
				want = _layer_material(def, slot)
		if want == null and ours:
			out.y += 1
		if want != current:
			mi.set_surface_override_material(i, want)
		if want != null:
			out.x += 1
	return out


static func _layer_material(def: FinishDef, slot: StringName) -> Material:
	for i: int in range(def.layers.size()):
		var l: FinishLayer = def.layers[i]
		if l != null and l.slots.has(slot):
			return FinishMaterials.material_for(def, i)
	return null


## MeshInstance3Ds with a mesh under `root` (root included), skipping `Mod_*` subtrees when asked.
static func _meshes(root: Node, skip_mods: bool) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_collect(root, skip_mods, out)
	return out


static func _collect(n: Node, skip_mods: bool, out: Array[MeshInstance3D]) -> void:
	if skip_mods and String(n.name).begins_with(WeaponVisual.MOD_NODE_PREFIX):
		return
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append(mi)
	for c: Node in n.get_children():
		_collect(c, skip_mods, out)
