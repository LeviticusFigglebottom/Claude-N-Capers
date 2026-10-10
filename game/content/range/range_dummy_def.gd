## One firing-range dummy preset (B1-05). Owner: ENV B. Rows live in range_dummies.tres.
##
## STOPGAP (D-010): enemy balance belongs to ENV A's EnemyDef. Until ENV A ships EnemyDef data
## (`systems/ai/data/enemies/`), the range carries this B-owned copy of the PD2 table SHAPE
## (research §2.6, light SWAT). When it lands, health/headshot_mult are read from the EnemyDef whose
## id is `enemy_id` and these two arrays are deleted.
class_name RangeDummyDef
extends Resource

@export var id: StringName = &""                  ## &"range_dummy.light"
@export var name_key: StringName = &""            ## strings.csv key
@export var enemy_id: StringName = &""            ## EnemyDef this mirrors (groups.md canonical id)
@export var health: PackedFloat32Array = PackedFloat32Array()         ## per Enums.Difficulty
@export var headshot_mult: PackedFloat32Array = PackedFloat32Array()  ## per Enums.Difficulty
@export var respawn_delay_s: float = 1.5           ## dead -> stands back up at full health


func health_for(difficulty: int) -> float:
	return _pick(health, difficulty, 1.0)


func headshot_mult_for(difficulty: int) -> float:
	return _pick(headshot_mult, difficulty, 1.0)


static func _pick(values: PackedFloat32Array, difficulty: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[clampi(difficulty, 0, values.size() - 1)]
