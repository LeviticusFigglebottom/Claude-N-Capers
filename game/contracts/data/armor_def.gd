## Body armor tier (Two-piece suit .. heaviest vest analog). Data: ENV B.
class_name ArmorDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var armor: float = 0.0
@export var dodge: float = 0.0             ## 0..1 base dodge contribution
@export var move_speed_mult: float = 1.0
@export var concealment: int = 0
@export var stamina_mult: float = 1.0
@export var unlock_level: int = 0
