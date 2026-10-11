## perk.crook (Hustler, PD2 Crook). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## While wearing one of vest_armor_ids: dodge + vest_dodge_add and max armor x vest_armor_mult.
class_name PerkCrook
extends PerkComponent

const KEY: StringName = &"perk.crook"


func in_vest() -> bool:
	return PerkUtil.id_in(param("vest_armor_ids", []), PerkUtil.armor_id(crew))


func adjust_max_armor(value: float, _raw_health: float) -> float:
	return value * float(param("vest_armor_mult", 1.0)) if in_vest() else value


func dodge_add() -> float:
	return num("vest_dodge_add") if in_vest() else 0.0
