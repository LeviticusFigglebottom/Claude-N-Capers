## One material recipe of a weapon finish (B7-04): the material slots it replaces and how the
## replacement looks. Lives inside a FinishDef (`layers`), never as a top-level file. Owner: ENV B.
##
## Slots are the weapon build scripts' material names (`tools/blender/weapons/_common.py` `Mats.*`):
## polymer, stipple, steel, bare, matte, alu, wood, rubber, tan, olive. WeaponFinishes.SLOT_MATERIALS maps
## each one to the library material it stands for (`M_<library_id>` on the imported surface). Glass,
## reticles, sight dots and cartridges are never finished (WeaponFinishes.FINISHABLE_SLOTS).
##
## Look: a fresh StandardMaterial3D (or a duplicate of ENV C's library material `base_material`, for its
## generated grain / normal map) with `albedo`, `metallic` and `roughness`; an optional procedural
## `pattern` (FinishMaterials.PATTERNS) tints it between `albedo` and `pattern_color`. No textures from
## outside the project: patterns are generated at runtime.
class_name FinishLayer
extends Resource

## Material slots this layer replaces (build-script names, see above).
@export var slots: Array[StringName] = []
@export var albedo: Color = Color(0.3, 0.3, 0.32, 1.0)
@export_range(0.0, 1.0) var metallic: float = 0.8
@export_range(0.0, 1.0) var roughness: float = 0.45
## Optional ENV C library material (a data reference, like MaskMaterialDef.library_material) whose
## textures this layer borrows: it is duplicated, the library resource is never changed. null = a plain
## StandardMaterial3D.
@export var base_material: Material
## Procedural pattern: &"" (none), &"mottle", &"camo", &"engrave", &"brushed", &"patina".
@export var pattern: StringName = &""
@export var pattern_color: Color = Color(0.1, 0.1, 0.1, 1.0)
## Pattern repeats per UV unit (weapon UVs are box-projected at first-person texel density).
@export var pattern_scale: float = 1.0
## Seed of the generated pattern (deterministic look; not gameplay RNG).
@export var pattern_seed: int = 1
## Optional clearcoat (0 = off) for lacquered / polished looks.
@export_range(0.0, 1.0) var clearcoat: float = 0.0
