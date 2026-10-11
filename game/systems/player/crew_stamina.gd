## Crew stamina (QB-60, PD2 movement_state.stamina): sprinting and jumping drain it, it regenerates
## after a pause, and a crew member at 0 cannot sprint until it is back above the threshold. Owner: ENV A.
## Held by CrewController (`stamina`) and ticked from its movement simulation (server, and the owning
## client's prediction). Numbers: CrewTweak "Stamina" group.
## Max = CrewTweak.stamina_base x movement.stamina_mult x team.stamina_mult x ArmorDef.stamina_mult
## x PerkHooks.stamina_mult (Foreman hostages); regeneration x the same perk multiplier.
## Rules: sprinting drains stamina_drain_per_s; a jump costs stamina_jump_cost and needs at least
## stamina_min_threshold; after any drain, regeneration (stamina_regen_per_s) waits
## stamina_regen_delay_s. Reaching 0 exhausts: no sprint until stamina >= stamina_min_threshold.
class_name CrewStamina
extends RefCounted

var value: float = -1.0  ## -1 = full on the first tick
var max_value: float = 0.0
## True after reaching 0, until back above CrewTweak.stamina_min_threshold.
var exhausted: bool = false
## Seconds until regeneration starts.
var regen_wait: float = 0.0
## PerkHooks.stamina_mult at the last refresh_max (scales regeneration too).
var perk_mult: float = 1.0


## Max stamina of `slot` wearing `armor` (null = no armor factor), before the perk multiplier.
static func max_for(slot: int, armor: ArmorDef) -> float:
	var m: float = Tweak.crew().stamina_base * TeamModifiers.stamina_mult(slot)
	if armor != null:
		m *= armor.stamina_mult
	return maxf(m, 0.0)


## Keeps the fraction when the max changes (modifiers / armor swap mid-heist).
func refresh_max(crew: CrewController, armor: ArmorDef) -> void:
	perk_mult = maxf(PerkHooks.stamina_mult(crew), 0.0)
	var m: float = max_for(crew.slot, armor) * perk_mult
	if value < 0.0:
		value = m
	elif not is_equal_approx(m, max_value) and max_value > 0.0:
		value = value * m / max_value
	max_value = m
	value = clampf(value, 0.0, max_value)


func can_sprint() -> bool:
	return value > 0.0 and not exhausted


func can_jump() -> bool:
	return value >= Tweak.crew().stamina_min_threshold


func on_jump() -> void:
	_drain(Tweak.crew().stamina_jump_cost)


## One movement tick. `sprinting` = the crew member sprinted this tick.
func tick(sprinting: bool, delta: float) -> void:
	var tw: CrewTweak = Tweak.crew()
	if sprinting:
		_drain(tw.stamina_drain_per_s * delta)
	elif regen_wait > 0.0:
		regen_wait = maxf(regen_wait - delta, 0.0)
	else:
		value = minf(value + tw.stamina_regen_per_s * perk_mult * delta, max_value)
	if exhausted and value >= tw.stamina_min_threshold:
		exhausted = false


## 0..1 for presentation (1 when the max is 0).
func fraction() -> float:
	return clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 1.0


## Client: the server's replicated stamina (NetEntityCodec) of a crew member this peer does not simulate.
func apply_replicated(frac: float, p_exhausted: bool) -> void:
	if max_value <= 0.0:
		max_value = 1.0
	value = clampf(frac, 0.0, 1.0) * max_value
	exhausted = p_exhausted


func _drain(amount: float) -> void:
	value = maxf(value - amount, 0.0)
	regen_wait = Tweak.crew().stamina_regen_delay_s
	if value <= 0.0:
		exhausted = true
