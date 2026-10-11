## One firing-range dummy preset (B1-05, B4-13). Owner: ENV B. Rows live in range_dummies.tres.
##
## Balance source (D-010): enemy balance belongs to ENV A's EnemyDef. Health and headshot_mult per
## difficulty are read from the EnemyDef at `enemy_path` (data: ENV A's enemies folder per
## data_schemas.md, read-only; its id must equal `enemy_id`) whenever ENV A ships it with a
## non-empty table. The `health` / `headshot_mult` arrays
## below are a STOPGAP used only for enemies A has not shipped yet (PD2 table SHAPE, research §2.6).
##
## Armour (B4-13, D-052, damage.md v1.1): ENV A's EnemyDef is the single source. `armor()` returns
## `NpcHitRules.armor_of(enemy_def())` (the canonical keys of systems/ai/README.md "Armour params":
## armor_body_mult, frontal_armor + frontal_armor_arc_deg, explosive_mult, shield, shield_pierce_mult,
## plate_health). On a tree where NpcHitRules has no armor_of yet (pre-A3-08), `_armor_of_mirror`
## reads the same keys the same way (canonical, else the pre-D-052 names); delete it once trunk has
## A3-08. RangeDamageModel applies them with NpcHitRules' semantics.
## The only B value left is `shield_stopgap`, used while the EnemyDef carries no `shield` key at all
## (pre-A3-08 Bulwark: its shield is a scene node, not data). Ignored as soon as A's key exists.
class_name RangeDummyDef
extends Resource

@export var id: StringName = &""                  ## &"range_dummy.light"
@export var name_key: StringName = &""            ## strings.csv key
@export var enemy_id: StringName = &""            ## EnemyDef this mirrors (groups.md canonical id)
## Where ENV A ships that EnemyDef (.tres). Missing file = not shipped yet -> B stopgap below.
@export var enemy_path: String = ""
@export var health: PackedFloat32Array = PackedFloat32Array()         ## STOPGAP per Enums.Difficulty
@export var headshot_mult: PackedFloat32Array = PackedFloat32Array()  ## STOPGAP per Enums.Difficulty
@export var respawn_delay_s: float = 1.5           ## dead -> stands back up at full health

@export_group("Armour STOPGAP (only while the EnemyDef has no `shield` key)")
@export var shield_stopgap: bool = false

var _enemy: EnemyDef = null
var _enemy_checked: bool = false
var _armor: Dictionary = {}


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


## The canonical armour set of the mirrored EnemyDef (see header). Cached; do not mutate.
func armor() -> Dictionary:
	if not _armor.is_empty():
		return _armor
	var e: EnemyDef = enemy_def()
	_armor = armor_of_enemy(e)
	if shield_stopgap and (e == null or not e.params.has("shield")):
		_armor["shield"] = true
		if e == null or not e.params.has("shield_pierce_mult"):
			_armor["shield_pierce_mult"] = CombatTweak.data().shield_pierce_damage_mult
	return _armor


## NpcHitRules.armor_of(def) when ENV A's tree has it (single source of truth), else the mirror.
static func armor_of_enemy(def: EnemyDef) -> Dictionary:
	var rules: Script = NpcHitRules
	if rules.has_method(&"armor_of"):
		return (rules.call(&"armor_of", def) as Dictionary).duplicate(true)
	return _armor_of_mirror(def)


## Pre-A3-08 mirror of NpcHitRules.armor_of (same keys, legacy names, defaults). Delete with A3-08.
static func _armor_of_mirror(def: EnemyDef) -> Dictionary:
	var p: Dictionary = def.params if def != null else {}
	var a: Dictionary = {
		"armor_body_mult": float(p.get("armor_body_mult", p.get("body_armor_mult", 1.0))),
		"frontal_armor": float(p.get("frontal_armor", p.get("frontal_plate_mult", 1.0))),
		"frontal_armor_arc_deg": float(p.get("frontal_armor_arc_deg", p.get("frontal_plate_arc_deg", 0.0))),
		"explosive_mult": float(p.get("explosive_mult", 1.0)),
		"shield": bool(p.get("shield", false)),
		"shield_pierce_mult": float(p.get("shield_pierce_mult", 1.0)),
	}
	if not p.has("frontal_armor") and not p.has("frontal_plate_mult") and float(a["frontal_armor_arc_deg"]) > 0.0:
		a["frontal_armor"] = 0.0  # a legacy arc without a mult blocks (as armor_of)
	var plates: Array[float] = []
	if p.has("plate_health"):
		for v: Variant in p["plate_health"] as Array:
			plates.append(float(v))
	elif p.has("faceplate_hp") or p.has("visor_hp"):
		plates = [float(p.get("faceplate_hp", 150.0)), float(p.get("visor_hp", 160.0))]
	a["plate_health"] = plates
	if bool(a["shield"]) and not p.has("shield_pierce_mult"):
		a["shield_pierce_mult"] = CombatTweak.data().shield_pierce_damage_mult
	return a


static func _pick(values: PackedFloat32Array, difficulty: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[clampi(difficulty, 0, values.size() - 1)]
