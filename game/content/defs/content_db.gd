## Read-only lookup of every content data resource under res://content/data/<kind>/. Owner: ENV B.
## API brief: game/content/README.md. All functions are static; results are cached on first use.
## Unknown id -> Log.error + null. Difficulties are keyed by Enums.Difficulty instead of an id.
class_name ContentDB
extends RefCounted

const DATA_ROOT: String = "res://content/data"
const WEAPONS: StringName = &"weapons"
const MODS: StringName = &"mods"
const MELEE: StringName = &"melee"
const ARMOR: StringName = &"armor"
const DEPLOYABLES: StringName = &"deployables"
const LOOT: StringName = &"loot"
const DIFFICULTY: StringName = &"difficulty"
const MASKS: StringName = &"masks"
const SKILLS: StringName = &"skills"
const PERKS: StringName = &"perks"
const THROWABLES: StringName = &"throwables"
## Achievement defs (B4-20, data/achievements/).
const ACHIEVEMENTS: StringName = &"achievements"
## Weapon finish defs (B7-04, data/finishes/).
const FINISHES: StringName = &"finishes"
## Crew bot abilities and boosts (L6.2, data/bot_crew/; BotCrewDef).
const BOT_CREW: StringName = &"bot_crew"
## Every kind folder ContentDB indexes by `id` (difficulty is indexed by its enum value).
const KINDS: Array[StringName] = [
	WEAPONS, MODS, MELEE, ARMOR, DEPLOYABLES, LOOT, DIFFICULTY, MASKS, SKILLS, PERKS, THROWABLES, ACHIEVEMENTS,
	FINISHES, BOT_CREW,
]
const LOG_CHANNEL: StringName = &"content"

## kind -> { key -> Resource }
static var _index: Dictionary = {}
## kind -> { key -> resource path } (duplicate-id diagnostics)
static var _paths: Dictionary = {}
static var _tweaks: Dictionary = {}


## Sorts an array of ids (StringName/String, or int enum keys) in place by their TEXT. Never use Array.sort() on
## StringNames: `<` compares interned pointers, so the order depends on load order (D-026,
## architecture.md §8).
static func sort_ids(ids: Array) -> void:
	ids.sort_custom(id_less)


## Comparator for ids (usable with sort_custom / bsearch_custom): ints (enum keys such as
## Enums.Difficulty) numerically, everything else by its text.
static func id_less(a: Variant, b: Variant) -> bool:
	if a is int and b is int:
		return int(a) < int(b)
	return str(a) < str(b)


static func weapon(id: StringName) -> WeaponDef:
	return by_id(WEAPONS, id) as WeaponDef


static func mod(id: StringName) -> WeaponModDef:
	return by_id(MODS, id) as WeaponModDef


static func melee(id: StringName) -> MeleeDef:
	return by_id(MELEE, id) as MeleeDef


static func armor(id: StringName) -> ArmorDef:
	return by_id(ARMOR, id) as ArmorDef


static func deployable(id: StringName) -> DeployableDef:
	return by_id(DEPLOYABLES, id) as DeployableDef


static func loot(id: StringName) -> LootDef:
	return by_id(LOOT, id) as LootDef


static func throwable(id: StringName) -> ThrowableDef:
	return by_id(THROWABLES, id) as ThrowableDef


static func mask(id: StringName) -> Resource:
	return by_id(MASKS, id)


static func difficulty(d: Enums.Difficulty) -> DifficultyDef:
	return by_id(DIFFICULTY, int(d)) as DifficultyDef


## Generic lookup (also used for &"skills" and &"perks"). `key` is a StringName id, or an int for
## difficulty.
static func by_id(kind: StringName, key: Variant) -> Resource:
	var table: Dictionary = _table(kind)
	if not table.has(key):
		Log.error(LOG_CHANNEL, "unknown %s id '%s'" % [kind, key])
		return null
	return table[key]


## True when `key` is a known id of `kind` (no error for unknown ids; save validation, B4-16).
static func has(kind: StringName, key: Variant) -> bool:
	return _table(kind).has(key)


## All resources of a kind, sorted by key for deterministic UI and tests.
static func all_of(kind: StringName) -> Array:
	var table: Dictionary = _table(kind)
	var keys: Array = table.keys()
	sort_ids(keys)
	var out: Array = []
	for k: Variant in keys:
		out.append(table[k])
	return out


static func all_weapons() -> Array:
	return all_of(WEAPONS)


static func all_mods() -> Array:
	return all_of(MODS)


static func all_melees() -> Array:
	return all_of(MELEE)


## L6.2: the bot abilities (`kind` BotCrewDef.ABILITY) or boosts (BOOST), in picker order (order, then id).
static func bot_crew(kind: String) -> Array[BotCrewDef]:
	var out: Array[BotCrewDef] = []
	for r: Variant in all_of(BOT_CREW):
		var d: BotCrewDef = r as BotCrewDef
		if d != null and d.kind == kind:
			out.append(d)
	out.sort_custom(func(a: BotCrewDef, b: BotCrewDef) -> bool:
		return a.order < b.order or (a.order == b.order and id_less(a.id, b.id)))
	return out


static func all_armors() -> Array:
	return all_of(ARMOR)


static func all_deployables() -> Array:
	return all_of(DEPLOYABLES)


static func all_loots() -> Array:
	return all_of(LOOT)


static func all_throwables() -> Array:
	return all_of(THROWABLES)


static func all_difficulties() -> Array:
	return all_of(DIFFICULTY)


## Tweak resource by file name: &"concealment_curve", &"display_stats", ...
static func tweak(tweak_name: StringName) -> Resource:
	if _tweaks.has(tweak_name):
		return _tweaks[tweak_name]
	var path: String = "%s/tweak/%s.tres" % [DATA_ROOT, tweak_name]
	var res: Resource = null
	if ResourceLoader.exists(path):
		res = ResourceLoader.load(path)
	if res == null:
		Log.error(LOG_CHANNEL, "unknown tweak '%s'" % tweak_name)
		return null
	_tweaks[tweak_name] = res
	return res


## TESTS/TOOLING ONLY: adds (or replaces) one resource in the index of `kind` under `key`, e.g. a
## test-only SkillDef. Gone after clear_cache(). Never call from game code.
static func inject(kind: StringName, key: Variant, res: Resource) -> void:
	_table(kind)[key] = res


## Drop every cache (tests, hot reload).
static func clear_cache() -> void:
	_index.clear()
	_paths.clear()
	_tweaks.clear()


static func _table(kind: StringName) -> Dictionary:
	if not _index.has(kind):
		_scan(kind)
	return _index[kind]


static func _scan(kind: StringName) -> void:
	var table: Dictionary = {}
	var paths: Dictionary = {}
	_index[kind] = table
	_paths[kind] = paths
	var dir: String = "%s/%s" % [DATA_ROOT, kind]
	if not DirAccess.dir_exists_absolute(dir):
		return
	_scan_dir(kind, dir, table, paths)


## Recursive (skills live in skills/<tree>/<subtree>/). Resources without an `id` property (layout
## files such as skills/trees.tres) are not items and are skipped; difficulty is keyed by its enum.
static func _scan_dir(kind: StringName, dir: String, table: Dictionary, paths: Dictionary) -> void:
	var entries: Array = Array(ResourceLoader.list_directory(dir))
	entries.sort()
	for entry: String in entries:
		if entry.ends_with("/"):
			_scan_dir(kind, dir.path_join(entry.trim_suffix("/")), table, paths)
			continue
		if not (entry.ends_with(".tres") or entry.ends_with(".res")):
			continue
		var path: String = dir.path_join(entry)
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			Log.error(LOG_CHANNEL, "failed to load %s" % path)
			continue
		if kind != DIFFICULTY and res.get(&"id") == null:
			continue
		var key: Variant = _key_of(kind, res)
		if table.has(key):
			Log.error(LOG_CHANNEL, "duplicate %s id '%s' in %s and %s" % [kind, key, paths[key], path])
			continue
		table[key] = res
		paths[key] = path


static func _key_of(kind: StringName, res: Resource) -> Variant:
	if kind == DIFFICULTY:
		return int(res.get(&"difficulty"))
	return StringName(res.get(&"id"))
