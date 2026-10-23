class_name MeleeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var damage: float = 0.0
@export var charged_damage: float = 0.0
@export var charge_time_s: float = 1.0
@export var range_m: float = 1.8
@export var knockdown: float = 0.0
@export var concealment: int = 30
@export var silent: bool = true
## D-155: the player level that unlocks this melee (PD2: melee is never sold; free once unlocked). 0 = from the start.
@export var unlock_level: int = 0
@export var model: PackedScene
## D-069: first-person AnimationLibrary (characters.md v1.7): &"melee_knife" | &"melee_blunt" | &"melee_blade".
@export var anim_set: StringName = &"melee_knife"
## D-069 optional timings; 0 = use the clip's own length / hit@ event.
@export var swing_time_s: float = 0.0
@export var hit_delay_s: float = 0.0
@export var equip_time_s: float = 0.0
