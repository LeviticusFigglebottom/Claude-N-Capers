## perk.grinder (Bloodletter, PD2 Grinder). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## Damaging an enemy (at most once per stack_cooldown_s) adds a stack that heals heal_per_tick every
## tick_s for duration_s. Stacks run in parallel. Only while wearing one of allowed_armor_ids.
class_name PerkGrinder
extends PerkComponent

const KEY: StringName = &"perk.grinder"

## Active stacks: x = seconds left, y = time accumulated toward the next tick.
var stacks: Array[Vector2] = []

var _stack_cd: float = 0.0


func armor_allowed() -> bool:
	return PerkUtil.id_in(param("allowed_armor_ids", []), PerkUtil.armor_id(crew))


func on_damage_dealt(_victim: Node, info: Dictionary) -> void:
	if float(info.get("amount", 0.0)) <= 0.0 or _stack_cd > 0.0 or not armor_allowed():
		return
	stacks.append(Vector2(num("duration_s"), 0.0))
	_stack_cd = num("stack_cooldown_s")


func tick(delta: float) -> void:
	_stack_cd = maxf(_stack_cd - delta, 0.0)
	if stacks.is_empty():
		return
	var tick_s: float = maxf(num("tick_s"), 0.01)
	var heal: float = 0.0
	for i: int in range(stacks.size() - 1, -1, -1):
		var s: Vector2 = stacks[i]
		var step: float = minf(delta, s.x)
		s.y += step
		s.x -= step
		while s.y >= tick_s:
			s.y -= tick_s
			heal += num("heal_per_tick")
		if s.x <= 0.0:
			stacks.remove_at(i)
		else:
			stacks[i] = s
	if heal > 0.0 and _health() != null:
		_health().heal(heal)
