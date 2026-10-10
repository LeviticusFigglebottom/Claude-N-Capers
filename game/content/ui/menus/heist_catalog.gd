## Heists offered by the menus. Owner: ENV B. Heists come from HeistRegistry (core, D-024: no hard
## paths into world/); per-heist UI data and placeholders from res://content/data/ui/heist_list.tres.
## A heist listed there with placeholder fields shows as a placeholder only while the registry has
## no def for it (HeistRegistry.get_def returns null quietly, so no error spam).
##
## entries() -> Array[Dictionary] sorted by id, of
##   { "id": StringName, "name_key": StringName, "subtitle_key": StringName, "brief_key": StringName,
##     "base_payout": int (UNSCALED, like HeistResult.contract_pay), "mode": int (Enums.HeistMode),
##     "def": HeistDef or null, "placeholder": bool }
class_name HeistCatalog
extends RefCounted

const LIST_PATH: String = "res://content/data/ui/heist_list.tres"
const SAMPLE_RESULT_PATH: String = "res://content/data/ui/sample_heist_result.json"


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
	return entries_from(defs, heist_list())


## Pure builder behind entries(): `defs` is { heist id: HeistDef } (the registry's view).
static func entries_from(defs: Dictionary, list: UiHeistList) -> Array[Dictionary]:
	var ids_found: Array[StringName] = []
	for id: Variant in defs:
		ids_found.append(StringName(id))
	for id: Variant in list.heists:
		var data: Dictionary = list.heists[id] as Dictionary
		if not defs.has(StringName(id)) and data.has("placeholder_base_payout"):
			ids_found.append(StringName(id))
	ContentDB.sort_ids(ids_found)
	var out: Array[Dictionary] = []
	for id: StringName in ids_found:
		var def: HeistDef = defs.get(id) as HeistDef
		var data: Dictionary = list.heists.get(id, {}) as Dictionary
		out.append({
			"id": id,
			"name_key": StringName("heist.%s.name" % id),
			"subtitle_key": StringName("heist.%s.subtitle" % id),
			"brief_key": StringName("heist.%s.brief" % id),
			"base_payout": def.base_payout if def != null else int(data.get("placeholder_base_payout", 0)),
			"mode": int(def.mode) if def != null else int(data.get("placeholder_mode", 0)),
			"def": def,
			"placeholder": def == null,
		})
	return out


## Ids of every heist the menus offer (registry + placeholders); direct launch validates against it.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in entries():
		out.append(StringName(e["id"]))
	return out


static func is_difficulty_unlocked(d: int) -> bool:
	return heist_list().unlocked_difficulties.has(d)


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
