## Heists offered by the menus. Owner: ENV B. Heists come from HeistRegistry (core, D-024: no hard
## paths into world/); per-heist UI data from res://content/data/ui/heist_list.tres.
## QB-55 (D-049): a heist is offered (menus, Board, broker, direct launch) only when its HeistDef AND
## its map scene exist (HeistRegistry.get_def + HeistRegistry.map_scene_path). No placeholders.
##
## entries() -> Array[Dictionary] sorted by id, of
##   { "id": StringName, "name_key": StringName, "subtitle_key": StringName, "brief_key": StringName,
##     "base_payout": int (UNSCALED, like HeistResult.contract_pay), "mode": int (Enums.HeistMode),
##     "def": HeistDef }
class_name HeistCatalog
extends RefCounted

const LIST_PATH: String = "res://content/data/ui/heist_list.tres"
const SAMPLE_RESULT_PATH: String = "res://content/data/ui/sample_heist_result.json"


## D-117 §2: the profile difficulty progression is read from (MenuFlow sets it when it loads the profile).
static var progress_profile: PlayerProfile = null

static func heist_list() -> UiHeistList:
	var l: UiHeistList = null
	if ResourceLoader.exists(LIST_PATH):
		l = load(LIST_PATH) as UiHeistList
	if l == null:
		Log.error(&"ui", "heist list missing: %s" % LIST_PATH)
		l = UiHeistList.new()
	return l


static func entries() -> Array[Dictionary]:
	var defs: Dictionary = {}
	for id: StringName in HeistRegistry.ids():
		var def: HeistDef = HeistRegistry.get_def(id)
		if def != null:
			defs[id] = def
	return entries_from(defs, is_ready)


## True when the heist's map scene exists (HeistRegistry.map_scene_path).
static func has_map(heist_id: StringName) -> bool:
	return ResourceLoader.exists(HeistRegistry.map_scene_path(heist_id))


## The menus' readiness gate: not "hidden", the map exists and so does every heist_list.tres "requires" path (OF-B1: Ostrander
## Federal waits on its mission script, OF-A6, on top of C's G1 def + map). `exists` = Callable(String) -> bool
## (default ResourceLoader.exists; tests pass a fake).
static func is_ready(heist_id: StringName, exists: Callable = Callable()) -> bool:
	var check: Callable = exists if exists.is_valid() else func(p: String) -> bool: return ResourceLoader.exists(p)
	if heist_list().is_hidden(heist_id):  # C's G1 ships a mission stub: the switch flips when A's mission lands
		return false
	if not bool(check.call(HeistRegistry.map_scene_path(heist_id))):
		return false
	for p: String in heist_list().requires_for(heist_id):
		if not bool(check.call(p)):
			return false
	return true


## Pure builder behind entries(): `defs` is { heist id: HeistDef } (the registry's view); `map_exists`
## is Callable(StringName) -> bool (default: every def counts as having a map).
static func entries_from(defs: Dictionary, map_exists: Callable = Callable()) -> Array[Dictionary]:
	var ids_found: Array[StringName] = []
	for id: Variant in defs:
		if defs[id] != null and (not map_exists.is_valid() or bool(map_exists.call(StringName(id)))):
			ids_found.append(StringName(id))
	ContentDB.sort_ids(ids_found)
	var out: Array[Dictionary] = []
	for id: StringName in ids_found:
		var def: HeistDef = defs[id] as HeistDef
		out.append({
			"id": id,
			"name_key": StringName("heist.%s.name" % id),
			"subtitle_key": StringName("heist.%s.subtitle" % id),
			"brief_key": StringName("heist.%s.brief" % id),
			"base_payout": def.base_payout,
			"mode": int(def.mode),
			"def": def,
		})
	return out


## The mode label key for `heist_id`: heist_list.tres "mode_key" when set (D-075), else the HeistMode's label
## (one source for the Board, the heist select and the briefing).
static func mode_key(heist_id: StringName, mode: int) -> StringName:
	var override: StringName = heist_list().mode_key_for(heist_id) if heist_id != &"" else &""
	if override != &"":
		return override
	match mode:
		Enums.HeistMode.STEALTH_ONLY:
			return &"ui.heist_select.modes_stealth_only"
		Enums.HeistMode.LOUD_ONLY:
			return &"ui.heist_select.modes_loud_only"
	return &"ui.heist_select.modes_stealth_loud"


## Ids of every heist the menus offer (registry def + is_ready); direct launch validates against it.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in entries():
		out.append(StringName(e["id"]))
	return out


## Build-wide gate (heist_list unlocked_difficulties) or D-117 §2 progression: a progression difficulty opens once
## any heist was won on the one below it, read from `p` (default: progress_profile, set by MenuFlow).
static func is_difficulty_unlocked(d: int, p: PlayerProfile = null) -> bool:
	var l: UiHeistList = heist_list()
	if l.unlocked_difficulties.has(d):
		return true
	var prof: PlayerProfile = p if p != null else progress_profile
	return l.progression_difficulties.has(d) and prof != null and Career.best_difficulty_any(prof) >= d - 1


## True when `d` is locked behind progression (not the build list): the UI says what to win.
static func is_progression_difficulty(d: int) -> bool:
	return heist_list().progression_difficulties.has(d)


## Contract pay preview for a heist at a difficulty, through PayoutCalculator (same multipliers as
## the payday screen: a successful run with no loot, no crew).
static func contract_preview(base_payout: int, difficulty: int) -> int:
	var probe: Dictionary = {
		"success": true, "stealth": false, "difficulty": difficulty, "contract_pay": base_payout,
		"loot": [], "small_loot": 0, "crew": [],
	}
	return int(PayoutCalculator.compute(probe)["contract"])


## A sample HeistResult (for the payday screen without ENV A's launcher, and for tests), with JSON
## numbers converted back to the contract's types.
static func sample_result() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(SAMPLE_RESULT_PATH)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if not parsed is Dictionary:
		Log.error(&"ui", "sample result missing or invalid: %s" % SAMPLE_RESULT_PATH)
		return {}
	var d: Dictionary = parsed as Dictionary
	d.erase("_doc")
	d["heist_id"] = StringName(String(d.get("heist_id", "")))
	for k: String in ["difficulty", "contract_pay", "small_loot", "pagers_answered", "seed"]:
		d[k] = int(d.get(k, 0))
	d["time_s"] = float(d.get("time_s", 0.0))
	var loot: Array = []
	for l: Dictionary in d.get("loot", []) as Array:
		loot.append({"loot_id": StringName(String(l.get("loot_id", ""))), "value": int(l.get("value", 0))})
	d["loot"] = loot
	var crew: Array = []
	for c: Dictionary in d.get("crew", []) as Array:
		var m: Dictionary = c.duplicate()
		for k: String in ["slot", "kills", "specials_killed", "downs", "civilians_killed"]:
			m[k] = int(m.get(k, 0))
		crew.append(m)
	d["crew"] = crew
	return d
