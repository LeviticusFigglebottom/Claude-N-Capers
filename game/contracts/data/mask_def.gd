## Mask (base shape + colour/pattern/material customisation). Schema LEAD; data ENV B
## (content/data/masks/); mesh ENV C. ENV A attaches `model` to the crew Head attachment (characters.md).
class_name MaskDef
extends Resource

@export var id: StringName = &""           ## &"mask.porcelain_fox"
@export var display_name: String = ""
@export var model: PackedScene             ## pivot at the face centre, -Z forward (visual_slots.md)
@export var material_id: StringName = &""  ## mask material (world/materials library)
@export var color_a: Color = Color.WHITE
@export var color_b: Color = Color.BLACK
@export var pattern_id: StringName = &""
@export var unlock: StringName = &""
