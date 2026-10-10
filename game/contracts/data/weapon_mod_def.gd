## A weapon modification part. Owner: LEAD (schema). Data: ENV B.
class_name WeaponModDef
extends Resource

@export var id: StringName = &""          ## &"mod.suppressor_short"
@export var display_name: String = ""
@export var mod_type: Enums.ModType = Enums.ModType.BARREL
@export var delta: WeaponStats            ## additive stat change
@export var price: int = 0
@export var unlock: StringName = &""      ## &"" = default unlocked; else drop/achievement id
@export var model: PackedScene            ## attaches to the marker named in visual_slots.md
## Mods that cannot be combined with this one (e.g. a sight blocking a rail gadget).
@export var conflicts: Array[StringName] = []
