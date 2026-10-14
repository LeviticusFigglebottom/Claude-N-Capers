## Crew stamina (QB-60; D-107: PD2 movement_state.stamina / playermovement.lua). Owner: ENV P (D-076 path).
## Held by CrewController (`stamina`) and ticked from its movement simulation (server, and the owning
## client's prediction). Numbers: CrewTweak "Stamina" group.
## Max = CrewTweak.stamina_base x movement.stamina_mult x team.stamina_mult x ArmorDef.stamina_mult
## x PerkHooks.stamina_mult (Foreman hostages); regeneration x the same perk multiplier.
## Rules (D-107, PD2): sprinting drains stamina_drain_per_s. A sprint STARTS only above stamina_min_threshold
## and continues until 0. Regeneration (stamina_regen_per_s) waits stamina_regen_delay_s, a timer that restarts
## when a sprint starts or stops (PD2 set_running) and, when idle below max with no timer, starts then; it is
## cleared at full. Jumps are never blocked; only a run-jump costs stamina_jump_cost (and does not restart the
## timer). `exhausted` (HUD / net) = at or below the threshold and not sprinting.
class_name CrewStamina
extends RefCounted

var value: float = -1.0  ## -1 = full on the first tick
var max_value: float = 0.0
## D-107: at or below CrewTweak.stamina_min_threshold and not sprinting (a sprint cannot start).
var exhausted: bool = false
## PD2 _regenerate_timer: seconds until regeneration starts (<= 0 while regenerating); meaningful only while
## `regen_timer` is on (off = PD2 nil: full, or nothing has started it yet).
var regen_wait: float = 0.0
var regen_timer: bool = false
## Seconds the current sprint has lasted (0 when not sprinting); a run-jump needs > run_jump_min_s.
var sprint_time: float = 0.0
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


## D-107 (PD2 _start_action_running / _interupt_action_running): a sprint starts above the threshold and, once
## running, continues until stamina runs out.
func can_sprint(continuing: bool = false) -> bool:
	return value > 0.0 if continuing else value > Tweak.crew().stamina_min_threshold


## D-107: stamina never blocks a jump (PD2 _check_action_jump).
func can_jump() -> bool:
	return true


## D-107 (PD2 playerstandard L4156-4163): a jump while sprinting for over run_jump_min_s above the threshold with a
## move direction costs stamina_jump_cost; it does not restart the regeneration timer. True when it was a run-jump.
func on_jump(moving: bool) -> bool:
	var tw: CrewTweak = Tweak.crew()
	if not moving or sprint_time <= tw.stamina_run_jump_min_s or value <= tw.stamina_min_threshold:
		return false
	value = maxf(value - tw.stamina_jump_cost, 0.0)
	return true


## One movement tick. `sprinting` = the crew member sprinted this tick.
func tick(sprinting: bool, delta: float) -> void:
	var tw: CrewTweak = Tweak.crew()
	if sprinting != (sprint_time > 0.0):
		_restart_timer(tw)  # PD2 set_running restarts the timer on start and stop
	if sprinting:
		sprint_time += delta
		value = maxf(value - tw.stamina_drain_per_s * delta, 0.0)
	else:
		sprint_time = 0.0
		if regen_timer:
			regen_wait -= delta
			if regen_wait < 0.0:
				value = minf(value + tw.stamina_regen_per_s * perk_mult * delta, max_value)
				if value >= max_value:
					regen_timer = false
		elif value < max_value:
			_restart_timer(tw)
	exhausted = value <= tw.stamina_min_threshold and not sprinting


## 0..1 for presentation (1 when the max is 0).
func fraction() -> float:
	return clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 1.0


## Client: the server's replicated stamina (NetEntityCodec) of a crew member this peer does not simulate.
func apply_replicated(frac: float, p_exhausted: bool) -> void:
	if max_value <= 0.0:
		max_value = 1.0
	value = clampf(frac, 0.0, 1.0) * max_value
	exhausted = p_exhausted


func _restart_timer(tw: CrewTweak) -> void:
	regen_wait = tw.stamina_regen_delay_s
	regen_timer = true
