## A police spawn group (L1.4): which units arrive together, how often per difficulty, in which
## assault phases. Owner: ENV A. Data: systems/ai/data/groups/*.tres. ◇ = design values.
class_name SpawnGroupDef
extends Resource

@export var id: StringName = &""
## Canonical enemy ids (groups.md, e.g. &"enemy.patrol_officer"); parallel to unit_counts.
@export var unit_ids: Array[StringName] = []
@export var unit_counts: PackedInt32Array = PackedInt32Array()
## Selection weight per Enums.Difficulty (ROUTINE..CATACLYSM); 0 = never on that difficulty.
@export var weights: PackedFloat32Array = PackedFloat32Array()
## Enums.AssaultPhase values this group may spawn in (empty = BUILD and SUSTAIN).
@export var phases: PackedInt32Array = PackedInt32Array()


func weight(difficulty: int) -> float:
	if weights.is_empty():
		return 1.0
	return maxf(weights[clampi(difficulty, 0, weights.size() - 1)], 0.0)


func allows_phase(phase: int) -> bool:
	if phases.is_empty():
		return phase == Enums.AssaultPhase.BUILD or phase == Enums.AssaultPhase.SUSTAIN
	return phases.has(phase)


## Unit ids expanded by count, in declaration order.
func expanded_units() -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in range(unit_ids.size()):
		var n: int = unit_counts[i] if i < unit_counts.size() else 1
		for k: int in range(maxi(n, 0)):
			out.append(unit_ids[i])
	return out
