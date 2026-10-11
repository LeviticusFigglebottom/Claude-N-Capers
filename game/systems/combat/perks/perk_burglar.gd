## perk.burglar (Prowler, PD2 Burglar). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## While standing still or crouched (PerkUtil.still_or_crouched): enemy target-selection weight x
## still_aggro_mult, and the armor regen delay runs x 1 / still_regen_delay_mult faster (0.8 = the
## delay is 80% as long). Bagging / lockpick / pager / crouch speed and dodge use generic keys.
class_name PerkBurglar
extends PerkComponent

const KEY: StringName = &"perk.burglar"


func aggro_mult(_from: Node3D) -> float:
	return float(param("still_aggro_mult", 1.0)) if PerkUtil.still_or_crouched(crew) else 1.0


func tick(delta: float) -> void:
	var h: CrewHealth = _health()
	var m: float = float(param("still_regen_delay_mult", 1.0))
	if h == null or h.regen_delay_left <= 0.0 or m <= 0.0 or m >= 1.0 or not PerkUtil.still_or_crouched(crew):
		return
	# CrewHealth removes `delta` itself after this hook; remove the extra part here.
	h.regen_delay_left = maxf(h.regen_delay_left - delta * (1.0 / m - 1.0), 0.0)
