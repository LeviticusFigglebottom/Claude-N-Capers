## AssaultDirector helper: which EnemyDefs the director may spawn (A3-03). Owner: ENV A. Server only.
## - L1.5 factions: faction_for(difficulty) from DirectorTweak.faction_by_difficulty; a role id
##   (groups.md: reskins keep the role id) resolves to enemies/<faction suffix>/<name>.tres when that
##   file exists, else enemies/<name>.tres, else null (specials not implemented yet: skipped).
## - PO-18 (D-145 §3): below DirectorTweak.armored_min_difficulty (Hazardous) no armored unit spawns: resolve()
##   remaps an armored id to DirectorTweak.armored_substitutes (TAC Heavy -> TAC Light) or skips it.
## - L4.11 special caps: DifficultyDef.special_limits[key] bounds the alive specials per key; ids
##   with a DirectorTweak.shared_limit_prefixes prefix share it (D-022: enemy.wrecker_* ->
##   enemy.wrecker). Aegis squad members (AegisCaptain) never count.
class_name EnemyRoster
extends RefCounted

const ENEMY_DIR: String = "res://systems/ai/data/enemies/"

var director: AssaultDirector = null

var _defs: Dictionary[StringName, EnemyDef] = {}
var _missing_logged: Dictionary[StringName, bool] = {}


func _init(p_director: AssaultDirector) -> void:
	director = p_director


func faction_for(difficulty: int) -> StringName:
	return faction_for_tweak(director.tweak, difficulty)


func faction() -> StringName:
	return faction_for(_difficulty())


## EnemyDef for `enemy_id` under the current faction and difficulty (cached), or null. PO-18: see resolve().
func enemy_def(enemy_id: StringName) -> EnemyDef:
	var key: StringName = _key(faction(), enemy_id)
	if _defs.has(key):
		return _defs[key]
	var def: EnemyDef = resolve(director.tweak, _difficulty(), enemy_id)
	if def == null and not _missing_logged.has(enemy_id):
		_missing_logged[enemy_id] = true
		Log.info(&"director", "no EnemyDef for %s on this difficulty (missing, or armored below %d): skipped"
			% [enemy_id, director.tweak.armored_min_difficulty])
	_defs[key] = def
	return def


## L1.5 faction id of `difficulty` in `tw` (&"" when the table is empty).
static func faction_for_tweak(tw: DirectorTweak, difficulty: int) -> StringName:
	var arr: Array[StringName] = tw.faction_by_difficulty
	if arr.is_empty():
		return &""
	return arr[clampi(difficulty, 0, arr.size() - 1)]


## The EnemyDef the director spawns for `enemy_id` on `difficulty` (no cache, no runtime): the faction def
## (enemies/<faction suffix>/<name>.tres, else enemies/<name>.tres, else null), then PO-18 (D-145 §3): below
## tw.armored_min_difficulty an armored def (has_body_armor) becomes its tw.armored_substitutes def (itself unarmored)
## or null (skipped).
static func resolve(tw: DirectorTweak, difficulty: int, enemy_id: StringName) -> EnemyDef:
	var fac: StringName = faction_for_tweak(tw, difficulty)
	var def: EnemyDef = load_def(fac, enemy_id)
	if def == null or difficulty >= tw.armored_min_difficulty or not has_body_armor(def):
		return def
	var sub: StringName = tw.armored_substitutes.get(enemy_id, &"")
	if sub == &"" or sub == enemy_id:
		return null
	var sdef: EnemyDef = load_def(fac, sub)
	return null if sdef == null or has_body_armor(sdef) else sdef


## Faction def of `enemy_id`: enemies/<faction suffix>/<name>.tres when it exists, else enemies/<name>.tres, else null.
static func load_def(fac: StringName, enemy_id: StringName) -> EnemyDef:
	var nm: String = String(enemy_id).trim_prefix("enemy.")
	var suffix: String = String(fac).trim_prefix("faction.")
	var fpath: String = ENEMY_DIR + suffix + "/" + nm + ".tres"
	if suffix != "" and ResourceLoader.exists(fpath):
		return load(fpath) as EnemyDef
	var path: String = ENEMY_DIR + nm + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as EnemyDef
	return null


## PO-18 (D-145 §3): `def` has damage-reducing body armor (NpcHitRules.armor_of): a frontal plate (frontal_armor < 1
## inside a frontal arc, L4.2 TAC Heavy), generic body armor (armor_body_mult < 1, L3.4) or plates (L4.6 Wrecker).
## A carried ballistic shield (L4.5 Bulwark) is not body armor.
static func has_body_armor(def: EnemyDef) -> bool:
	if def == null:
		return false
	var a: Dictionary = NpcHitRules.armor_of(def)
	if float(a["frontal_armor_arc_deg"]) > 0.0 and float(a["frontal_armor"]) < 1.0:
		return true
	if float(a["armor_body_mult"]) < 1.0:
		return true
	return not (a["plate_health"] as Array).is_empty()


## Tests / modes: use `def` for `enemy_id` under the current faction.
func set_def_override(enemy_id: StringName, def: EnemyDef) -> void:
	_defs[_key(faction(), enemy_id)] = def


## The DifficultyDef.special_limits key `enemy_id` counts toward.
func special_limit_key(enemy_id: StringName) -> StringName:
	for prefix: StringName in director.tweak.shared_limit_prefixes:
		if String(enemy_id).begins_with(String(prefix)):
			return prefix
	return enemy_id


## Max alive for the limit key of `enemy_id` (-1 = unlimited).
func special_limit(enemy_id: StringName) -> int:
	var key: StringName = special_limit_key(enemy_id)
	var rt: HeistRuntime = director.runtime()
	var lim: Dictionary = rt.difficulty_def.special_limits if rt != null and rt.difficulty_def != null else {}
	for k: Variant in lim.keys():
		if StringName(str(k)) == key:
			return int(lim[k])
	return director.tweak.special_limit_default


## Alive units counting toward `key` (Aegis squad members excluded).
func special_alive(key: StringName) -> int:
	var k: int = 0
	for npc: NpcBase in director.alive_units():
		if npc.enemy_def != null and not AegisCaptain.is_aegis_unit(npc) \
				and special_limit_key(npc.enemy_def.id) == key:
			k += 1
	return k


## False when `def` is a special whose limit is reached.
func can_spawn_special(def: EnemyDef) -> bool:
	if def == null or not def.is_special:
		return true
	var lim: int = special_limit(def.id)
	return lim < 0 or special_alive(special_limit_key(def.id)) < lim


static func _key(fac: StringName, enemy_id: StringName) -> StringName:
	return StringName("%s|%s" % [fac, enemy_id])


func _difficulty() -> int:
	var rt: HeistRuntime = director.runtime()
	return rt.difficulty if rt != null else 0
