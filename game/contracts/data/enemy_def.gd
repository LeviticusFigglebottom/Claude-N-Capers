## Enemy tweak data per type and difficulty. Schema LEAD; data ENV A (systems/ai/data) since
## enemy balance is tightly coupled to AI behaviour.
class_name EnemyDef
extends Resource

@export var id: StringName = &""           ## &"enemy.security_officer", &"enemy.phantom"
@export var display_name: String = ""
@export var is_special: bool = false
@export var health: PackedFloat32Array = PackedFloat32Array()        ## per Difficulty
@export var headshot_mult: PackedFloat32Array = PackedFloat32Array() ## per Difficulty
@export var damage: PackedFloat32Array = PackedFloat32Array()        ## per Difficulty (per shot)
@export var move_speed: float = 3.0
@export var weapon: StringName = &""
@export var detection_preset: StringName = &"guard"   ## see stealth tweak
@export var params: Dictionary = {}                    ## special-specific
@export var visual: PackedScene                        ## ENV C character visual (characters.md)
@export var voice: StringName = &""
