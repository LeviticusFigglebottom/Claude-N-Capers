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
## A3-03 (L1.3): weight multiplier per escalation stage index (0 = 50%, 1 = 75%, 2 = 100%);
## empty = 1.0 on every stage, 0 = never on that stage.
@export var stage_weight_mult: PackedFloat32Array = PackedFloat32Array()
## A3-03 (L1.5): faction ids (&"faction.tac", &"faction.frd", ...) this group belongs to; empty = all.
@export var factions: Array[StringName] = []


func weight(difficulty: int) -> float:
	if weights.is_empty():
		return 1.0
	return maxf(weights[clampi(difficulty, 0, weights.size() - 1)], 0.0)


## A3-03 (L1.3/L1.5): weight on `difficulty` at escalation `stage` for `faction` (0 = excluded).
func weight_for(difficulty: int, stage: int, faction: StringName = &"") -> float:
	if not factions.is_empty() and faction != &"" and not factions.has(faction):
		return 0.0
	var mult: float = 1.0
	if not stage_weight_mult.is_empty():
		mult = maxf(stage_weight_mult[clampi(stage, 0, stage_weight_mult.size() - 1)], 0.0)
	return weight(difficulty) * mult


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
