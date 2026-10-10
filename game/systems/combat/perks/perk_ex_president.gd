## perk.ex_president (Incumbent, PD2 Ex-President). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## Each kill by the holder while their armor is above 0 banks store_per_kill health (cap
## max_store_by_armor[armor] x max_store_mult). When armor breaks and starts to regenerate, the bank
## is paid out as health. kill_regen_speedup_fraction (> 0): a kill while armor is broken cuts that
## fraction x (1 - armor_tier / 6) from the remaining armor regen delay.
class_name PerkExPresident
extends PerkComponent

const KEY: StringName = &"perk.ex_president"

## Banked health.
var stored: float = 0.0

var _broken: bool = false


func max_store() -> float:
	var table: Variant = param("max_store_by_armor", {})
	var id: StringName = PerkUtil.armor_id(crew)
	var cap: float = PerkTweak.data().ex_president_fallback_store
	if table is Dictionary and ((table as Dictionary).has(id) or (table as Dictionary).has(String(id))):
		cap = float((table as Dictionary).get(id, (table as Dictionary).get(String(id))))
	return cap * maxf(num("max_store_mult"), 0.0)


func on_kill(_victim: Node, _info: Dictionary) -> void:
	var h: CrewHealth = _health()
	if h == null:
		return
	if h.armor > 0.0:
		stored = minf(stored + num("store_per_kill"), max_store())
		return
	var frac: float = num("kill_regen_speedup_fraction")
	if frac > 0.0 and h.regen_delay_left > 0.0:
		var tier: int = PerkTweak.armor_tier(PerkUtil.armor_id(crew))
		h.regen_delay_left -= h.regen_delay_left * frac * (1.0 - float(tier) / 6.0)


func after_hit(_out: Dictionary) -> void:
	var h: CrewHealth = _health()
	if h != null and h.max_armor > 0.0 and h.armor <= 0.0:
		_broken = true


func tick(_delta: float) -> void:
	var h: CrewHealth = _health()
	if h == null or not _broken or h.regen_delay_left > 0.0:
		return
	_broken = false  # armor starts regenerating now: pay out the bank
	if stored > 0.0:
		h.heal(stored)
	stored = 0.0
