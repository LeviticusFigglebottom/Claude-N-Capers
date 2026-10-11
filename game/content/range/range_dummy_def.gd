## One firing-range dummy preset (B1-05, B4-13). Owner: ENV B. Rows live in range_dummies.tres.
##
## Balance source (D-010): enemy balance belongs to ENV A's EnemyDef. Health and headshot_mult per
## difficulty are read from the EnemyDef at `enemy_path` (ENV A's systems/ai/data/enemies, read-only;
## its id must equal `enemy_id`). A row whose EnemyDef is missing reads 1 HP (a test fails on it).
##
## Armour (B4-13, D-052, damage.md v1.1): ENV A's EnemyDef is the single source. `armor()` returns
## `NpcHitRules.armor_of(enemy_def())` (the canonical keys of systems/ai/README.md "Armour params":
## armor_body_mult, frontal_armor + frontal_armor_arc_deg, explosive_mult, shield, shield_pierce_mult,
## plate_health). RangeDamageModel applies them with NpcHitRules' semantics.
class_name RangeDummyDef
extends Resource

@export var id: StringName = &""                  ## &"range_dummy.light"
@export var name_key: StringName = &""            ## strings.csv key
@export var enemy_id: StringName = &""            ## EnemyDef this mirrors (groups.md canonical id)
## Where ENV A ships that EnemyDef (.tres).
@export var enemy_path: String = ""
@export var respawn_delay_s: float = 1.5           ## dead -> stands back up at full health

var _enemy: EnemyDef = null
var _enemy_checked: bool = false
var _armor: Dictionary = {}


## ENV A's EnemyDef for `enemy_id`, or null when the path or id is wrong.
func enemy_def() -> EnemyDef:
	if _enemy_checked:
		return _enemy
	_enemy_checked = true
	if enemy_id == &"" or enemy_path == "" or not ResourceLoader.exists(enemy_path):
		return null
	var e: EnemyDef = load(enemy_path) as EnemyDef
	if e != null and e.id == enemy_id:
		_enemy = e
	return _enemy


## True when health/headshot come from ENV A's EnemyDef.
func uses_enemy_def() -> bool:
	var e: EnemyDef = enemy_def()
	return e != null and not e.health.is_empty()


func health_for(difficulty: int) -> float:
	var e: EnemyDef = enemy_def()
	if e != null and not e.health.is_empty():
		return _pick(e.health, difficulty, 1.0)
	return 1.0


func headshot_mult_for(difficulty: int) -> float:
	var e: EnemyDef = enemy_def()
	if e != null and not e.headshot_mult.is_empty():
		return _pick(e.headshot_mult, difficulty, 1.0)
	return 1.0


## The canonical armour set of the mirrored EnemyDef (see header). Cached; do not mutate.
func armor() -> Dictionary:
	if not _armor.is_empty():
		return _armor
	_armor = armor_of_enemy(enemy_def())
	return _armor


## NpcHitRules.armor_of(def), copied (the single source of truth, A3-08).
static func armor_of_enemy(def: EnemyDef) -> Dictionary:
	return NpcHitRules.armor_of(def).duplicate(true)


static func _pick(values: PackedFloat32Array, difficulty: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[clampi(difficulty, 0, values.size() - 1)]
