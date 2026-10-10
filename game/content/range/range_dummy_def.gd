## One firing-range dummy preset (B1-05, B4-13). Owner: ENV B. Rows live in range_dummies.tres.
##
## Balance source (D-010): enemy balance belongs to ENV A's EnemyDef. Health and headshot_mult per
## difficulty are read from the EnemyDef at `enemy_path` (data: ENV A's enemies folder per
## data_schemas.md, read-only; its id must equal `enemy_id`) whenever ENV A ships it with a
## non-empty table. The `health` / `headshot_mult` arrays
## below are a STOPGAP used only for enemies A has not shipped yet (PD2 table SHAPE, research §2.6).
##
## Armor (B4-13, L3.4, L4.2, L4.5, L4.6): read from `EnemyDef.params` with the PARAM_* keys when the
## EnemyDef has them, otherwise from the B fields below (STOPGAP, switch when A3-01/A3-06 add them):
## * frontal_armor / armor_body_mult: BODY hits from the front take x armor_body_mult (0 = blocked)
##   unless the hit pierced armor (`info.pierced_armor`). HEAD and LIMB are unarmored (TAC Heavy).
## * shield / shield_pierce_mult: a separate shield hitbox in front of the dummy. A hit on it passes
##   through at x shield_pierce_mult when `info.shield_pierce`, otherwise it is blocked (Bulwark).
## * plate_health: staged weak-point plates (WEAKPOINT hitbox over the face) in break order, e.g.
##   Wrecker [150, 160] = faceplate then visor; the head is headshot-immune until every plate is off.
## Explosions and fire ignore armor and shields (L3.4/L4.5).
class_name RangeDummyDef
extends Resource

## EnemyDef.params keys this preset looks for (proposed to ENV A for A3-06; see header).
const PARAM_FRONTAL_ARMOR: String = "frontal_armor"
const PARAM_ARMOR_BODY_MULT: String = "armor_body_mult"
const PARAM_SHIELD: String = "shield"
const PARAM_SHIELD_PIERCE_MULT: String = "shield_pierce_mult"
const PARAM_PLATE_HEALTH: String = "plate_health"

@export var id: StringName = &""                  ## &"range_dummy.light"
@export var name_key: StringName = &""            ## strings.csv key
@export var enemy_id: StringName = &""            ## EnemyDef this mirrors (groups.md canonical id)
## Where ENV A ships that EnemyDef (.tres). Missing file = not shipped yet -> B stopgap below.
@export var enemy_path: String = ""
@export var health: PackedFloat32Array = PackedFloat32Array()         ## STOPGAP per Enums.Difficulty
@export var headshot_mult: PackedFloat32Array = PackedFloat32Array()  ## STOPGAP per Enums.Difficulty
@export var respawn_delay_s: float = 1.5           ## dead -> stands back up at full health

@export_group("Armor (STOPGAP until EnemyDef.params carries it)")
@export var frontal_armor: bool = false
@export var armor_body_mult: float = 0.0
@export var shield: bool = false
@export var shield_pierce_mult: float = 0.25
@export var plate_health: PackedFloat32Array = PackedFloat32Array()

var _enemy: EnemyDef = null
var _enemy_checked: bool = false


## ENV A's EnemyDef for `enemy_id`, or null while A has not shipped it.
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


## True when health/headshot come from ENV A's EnemyDef (not the B stopgap arrays).
func uses_enemy_def() -> bool:
	var e: EnemyDef = enemy_def()
	return e != null and not e.health.is_empty()


func health_for(difficulty: int) -> float:
	var e: EnemyDef = enemy_def()
	if e != null and not e.health.is_empty():
		return _pick(e.health, difficulty, 1.0)
	return _pick(health, difficulty, 1.0)


func headshot_mult_for(difficulty: int) -> float:
	var e: EnemyDef = enemy_def()
	if e != null and not e.headshot_mult.is_empty():
		return _pick(e.headshot_mult, difficulty, 1.0)
	return _pick(headshot_mult, difficulty, 1.0)


func has_frontal_armor() -> bool:
	return bool(_param(PARAM_FRONTAL_ARMOR, frontal_armor))


func armor_body_mult_value() -> float:
	return float(_param(PARAM_ARMOR_BODY_MULT, armor_body_mult))


func has_shield() -> bool:
	return bool(_param(PARAM_SHIELD, shield))


func shield_pierce_mult_value() -> float:
	return float(_param(PARAM_SHIELD_PIERCE_MULT, shield_pierce_mult))


func plates() -> PackedFloat32Array:
	var v: Variant = _param(PARAM_PLATE_HEALTH, plate_health)
	if v is PackedFloat32Array:
		return v
	var out: PackedFloat32Array = PackedFloat32Array()
	if v is Array:
		for x: Variant in v:
			out.append(float(x))
	return out


func _param(key: String, fallback: Variant) -> Variant:
	var e: EnemyDef = enemy_def()
	if e != null and e.params.has(key):
		return e.params[key]
	return fallback


static func _pick(values: PackedFloat32Array, difficulty: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[clampi(difficulty, 0, values.size() - 1)]
