## perk.rogue_dodge_stack (Slipper, PD2 Rogue). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## Enemy target-selection weight x aggro_near_crew_mult while a teammate is within near_crew_m. Dodge,
## swap speed and armor pierce come from the generic keys (defense.dodge_add, weapon.swap_speed_mult,
## weapon.armor_pierce_add), which ENV B grants next to this key.
class_name PerkRogue
extends PerkComponent

const KEY: StringName = &"perk.rogue_dodge_stack"


func aggro_mult(_from: Node3D) -> float:
	if PerkUtil.near_teammate(crew, num("near_crew_m")):
		return float(param("aggro_near_crew_mult", 1.0))
	return 1.0
