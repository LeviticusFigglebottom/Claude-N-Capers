## Mask material (pd2_fidelity P8). Owner: ENV B. Wraps a shared library material (world/materials,
## ENV C; `char_*` ENV D): its textures give the grain, the numbers here give the mask finish.
## MaskDef.material_id holds `material_id` (the library id), so each library id is used once.
class_name MaskMaterialDef
extends MaskPartDef

## Library id, e.g. &"brass" (file `world/materials/<id>.tres`).
@export var material_id: StringName = &""
## The library material itself (a data reference; the preview reads its textures).
@export var library_material: Material
@export_range(0.0, 1.0) var metallic: float = 0.0
@export_range(0.0, 1.0) var roughness: float = 0.5
## 0 = flat colour, 1 = full library grain (albedo luminance, ORM roughness/AO, normal).
@export_range(0.0, 1.0) var detail_strength: float = 0.5
## Mean albedo luminance of the library texture (keeps the colour pair's brightness).
@export_range(0.05, 1.0) var detail_mean: float = 0.5
## Library texture tiles per mask UV unit.
@export var uv_tile: float = 1.5
