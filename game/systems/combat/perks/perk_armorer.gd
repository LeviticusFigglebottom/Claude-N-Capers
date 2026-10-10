## perk.armorer (Ironclad, PD2 Armorer). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## break_immunity_s of health-damage immunity (CrewHealth.invuln_left) when armor breaks, at most
## once per break_immunity_cooldown_s. The armor bonus and regen delay are the generic
## defense.armor_mult / defense.armor_regen_delay_mult / team.armor_regen_delay_mult keys.
class_name PerkArmorer
extends PerkComponent

const KEY: StringName = &"perk.armorer"


func after_hit(out: Dictionary) -> void:
	_try_break_immunity(out, num("break_immunity_s"), num("break_immunity_cooldown_s"))


func tick(delta: float) -> void:
	_tick_immunity(delta)
