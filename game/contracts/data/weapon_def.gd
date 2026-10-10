## A weapon in the armory. Owner: LEAD (schema). Data: ENV B (content/data/weapons/*.tres).
class_name WeaponDef
extends Resource

@export var id: StringName = &""                ## &"weapon.kestrel_p9"
@export var display_name: String = ""
@export var manufacturer: String = ""
@export var weapon_class: Enums.WeaponClass = Enums.WeaponClass.PISTOL
@export var slot: Enums.WeaponSlot = Enums.WeaponSlot.SECONDARY
@export var fire_modes: Array[StringName] = [&"semi"]  ## &"semi", &"auto", &"burst3", &"pump", &"bolt"
@export var base: WeaponStats
@export var price: int = 0
@export var unlock_level: int = 0
## Mod slots this weapon exposes and the mods allowed in each: ModType -> Array[StringName mod ids]
@export var mod_slots: Dictionary = {}
## Default mod per slot (stock parts) ModType -> StringName
@export var default_mods: Dictionary = {}
## Generated model (assets/weapons/...glb) with attachment markers per contract visual_slots.md
@export var model: PackedScene
@export var fire_cue: StringName = &""            ## audio cue id
@export var fire_cue_suppressed: StringName = &""
## Animation set id for first-person viewmodel (contracts/characters.md)
@export var anim_set: StringName = &"pistol"
