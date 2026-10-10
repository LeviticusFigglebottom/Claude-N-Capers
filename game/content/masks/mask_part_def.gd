## One mask customisation part (pd2_fidelity P8): a base shape, a material, a colour pair or a pattern.
## Owner: ENV B. Parts live in `content/data/masks/parts/<kind>.tres` (MaskPartList), never as
## top-level files, so ContentDB's `masks` index only holds MaskDef presets. Ids:
## `mask_base.<name>`, `mask_material.<name>`, `mask_colors.<name>`, `mask_pattern.<name>`.
## UI text: strings.csv `item.<id>.name` (display_name is a debug fallback).
class_name MaskPartDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## Owned by every profile from the start (P9 stub: later parts come from payday card drops and are
## stored in PlayerProfile.owned_mask_parts).
@export var default_owned: bool = false
