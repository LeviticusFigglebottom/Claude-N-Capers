## Mask base shape (pd2_fidelity P8). Owner: ENV B (data); the mesh is ENV D's (D-027).
## `model_path` is ENV D's glb (`res://assets/masks/mask_base_<name>/mask_base_<name>.glb`); while it
## does not exist MaskComposer builds an original procedural placeholder from the shape numbers below,
## unless `requires_model` is set: then the base is HIDDEN (MaskCatalog.is_available) until the glb
## exists (B4-15: slots requested from ENV D light up when the mesh lands; masks.md "Requested bases").
## Placeholder space: u = -1..1 across the face, v = -1..1 chin to forehead; sizes in meters.
class_name MaskBaseDef
extends MaskPartDef

@export_file("*.glb", "*.tscn") var model_path: String = ""
## Hidden from pickers, payday card pools and compositions until `model_path` exists (no placeholder).
@export var requires_model: bool = false
@export_group("Placeholder shape")
@export var width_m: float = 0.18
@export var height_m: float = 0.23
## Forward bulge of the face centre (toward -Z).
@export var depth_m: float = 0.05
## Outline superellipse exponent: 2 = oval, higher = squarer.
@export var roundness: float = 2.2
## 0..0.9: how much the lower half narrows toward the chin.
@export var chin_taper: float = 0.3
## Eye holes: centre (±eye_x, eye_y) and half extents in normalized units.
@export var eye_x: float = 0.38
@export var eye_y: float = 0.22
@export var eye_w: float = 0.2
@export var eye_h: float = 0.11
## Nose/beak/snout bump: forward size (m), centre v, half extents in u/v.
@export var snout_m: float = 0.02
@export var snout_y: float = -0.1
@export var snout_w: float = 0.18
@export var snout_h: float = 0.35
## Brow ridge forward size (m), just above the eyes.
@export var brow_m: float = 0.008
## Ears/tufts above the forehead (normalized height, 0 = none) at u = ±ear_x with half width ear_w.
@export var ear_h: float = 0.0
@export var ear_x: float = 0.6
@export var ear_w: float = 0.22
