## AssaultDirector helper: which EnemyDefs the director may spawn (A3-03). Owner: ENV A. Server only.
## - L1.5 factions: faction_for(difficulty) from DirectorTweak.faction_by_difficulty; a role id
##   (groups.md: reskins keep the role id) resolves to enemies/<faction suffix>/<name>.tres when that
##   file exists, else enemies/<name>.tres, else null (specials not implemented yet: skipped).
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
	var arr: Array[StringName] = director.tweak.faction_by_difficulty
	if arr.is_empty():
		return &""
	return arr[clampi(difficulty, 0, arr.size() - 1)]


func faction() -> StringName:
	var rt: HeistRuntime = director.runtime()
	return faction_for(rt.difficulty if rt != null else 0)


## EnemyDef for `enemy_id` under the current faction (cached), or null.
func enemy_def(enemy_id: StringName) -> EnemyDef:
	var fac: StringName = faction()
	var key: StringName = _key(fac, enemy_id)
	if _defs.has(key):
		return _defs[key]
	var nm: String = String(enemy_id).trim_prefix("enemy.")
	var def: EnemyDef = null
	var suffix: String = String(fac).trim_prefix("faction.")
	var fpath: String = ENEMY_DIR + suffix + "/" + nm + ".tres"
	if suffix != "" and ResourceLoader.exists(fpath):
		def = load(fpath) as EnemyDef
	var path: String = ENEMY_DIR + nm + ".tres"
	if def == null and ResourceLoader.exists(path):
		def = load(path) as EnemyDef
	if def == null and not _missing_logged.has(enemy_id):
		_missing_logged[enemy_id] = true
		Log.info(&"director", "no EnemyDef for %s yet (%s): its units are skipped" % [enemy_id, path])
	_defs[key] = def
	return def


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
