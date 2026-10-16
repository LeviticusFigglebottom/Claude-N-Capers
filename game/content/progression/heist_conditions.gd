## Run conditions of the heist achievements (D-115). Owner: ENV B. Static, pure.
##
## Achievements.matches() asks passes(condition, result, facts) for heist_completed / heist_failed defs, after
## its own filters (heist, difficulty_min, stealth, loud, pro). `result` is the HeistResult (contracts/events.md),
## `facts` is HeistFacts.snapshot() ({} = no log). Every key is optional; a def without them always passes.
## Every key reads only a fact that exists, and FAILS CLOSED when that fact is missing (a result without
## `time_s`, without `crew` rows, or no fact log), so a payday that cannot prove it never unlocks it.
##
## HeistResult keys:
##   "max_time_s": float          time_s <= value.
##   "max_time_variant": String   time_s <= result.variants[<scalar id>] (e.g. Gallery Night's `last_call_s`).
##   "max_kills" / "max_civilian_kills" / "max_downs": int   crew total (every crew row, AI included) <= value.
##   "max_custody": int           crew rows `in_custody` at the end <= value.
##   "max_pagers": int            pagers_answered <= value.
##   "min_bags": int              secured bags that count as loot (COUNTED: not a tool, LootDef.is_tool, nor in
##                                PayoutTweak.xp_loot_excluded_ids, i.e. not a body bag) >= value.
##   "loot_all": [loot ids]       each secured at least once.
##   "loot_min": {loot id: n}     each secured at least n times.
##   "all_loot_secured": true     the counted secured bags reach HeistResult.loot_available (events.md v1.7: every
##                                valued bag the run offered, untaken / unopened included; > 0). No field: fails.
## Fact-log keys (need facts.recorded):
##   "objectives_completed": [ids]      each ended COMPLETED and not `skipped` by the mission.
##   "objectives_open_method": {id: method}  each ended COMPLETED-and-not-skipped AND its recorded `open_method`
##                                (objective_updated data, events.md v1.7) is that method. No method: fails.
##   "objectives_not_completed": [ids]  none of them ended COMPLETED-and-not-skipped.
##   "facts_seen" / "facts_not_seen": [{"signal": <EventBus fact>, "args": {<arg index>: <value>}}]
##                                at least one / no recorded fact of that signal whose listed args equal the values.
class_name HeistConditions
extends RefCounted

const RESULT_KEYS: Array[String] = ["max_time_s", "max_time_variant", "max_kills", "max_civilian_kills",
	"max_downs", "max_custody", "max_pagers", "min_bags", "loot_all", "loot_min", "all_loot_secured"]
const FACT_KEYS: Array[String] = ["objectives_completed", "objectives_not_completed", "objectives_open_method",
	"facts_seen", "facts_not_seen"]
## Crew-row counter per max_* key.
const CREW_MAX: Dictionary = {"max_kills": "kills", "max_civilian_kills": "civilians_killed", "max_downs": "downs"}
## Every condition key the achievement evaluators understand (Achievements filters + these).
const BASE_KEYS: Array[String] = ["event", "count", "heist", "difficulty_min", "stealth", "loud", "pro", "stat",
	"bag"]

static var _excluded: Array[StringName] = []
static var _excluded_loaded: bool = false


static func known_keys() -> Array[String]:
	var out: Array[String] = BASE_KEYS.duplicate()
	out.append_array(RESULT_KEYS)
	out.append_array(FACT_KEYS)
	return out


## Whether the def reads the in-heist fact log (so a payday without one can never unlock it).
static func needs_facts(c: Dictionary) -> bool:
	for k: String in FACT_KEYS:
		if c.has(k):
			return true
	return false


static func passes(c: Dictionary, result: Dictionary, facts: Dictionary) -> bool:
	return _result_ok(c, result) and _facts_ok(c, facts)


static func _result_ok(c: Dictionary, r: Dictionary) -> bool:
	if c.has("max_time_s") and not (r.has("time_s") and float(r["time_s"]) <= float(c["max_time_s"])):
		return false
	if c.has("max_time_variant"):
		var vars: Dictionary = r.get("variants", {}) as Dictionary
		var key: String = String(c["max_time_variant"])
		var v: Variant = vars.get(key, vars.get(StringName(key)))  # String or StringName keys (replicated or local)
		if not r.has("time_s") or not (v is int or v is float) or float(r["time_s"]) > float(v):
			return false
	var crew: Array = r.get("crew", []) as Array
	for k: String in CREW_MAX:
		if c.has(k) and (crew.is_empty() or _crew_total(crew, CREW_MAX[k]) > int(c[k])):
			return false
	if c.has("max_custody"):
		var held: int = 0
		for row: Variant in crew:
			held += int(bool((row as Dictionary).get("in_custody", false))) if row is Dictionary else 0
		if crew.is_empty() or held > int(c["max_custody"]):
			return false
	if c.has("max_pagers") and not (r.has("pagers_answered") and int(r["pagers_answered"]) <= int(c["max_pagers"])):
		return false
	var bags: Dictionary = secured_counts(r)
	if c.has("min_bags") and (not r.has("loot") or _sum(bags) < int(c["min_bags"])):
		return false
	for id: Variant in c.get("loot_all", []) as Array:
		if int(bags.get(StringName(id), 0)) < 1:
			return false
	var mins: Dictionary = c.get("loot_min", {}) as Dictionary
	for id: Variant in mins:
		if int(bags.get(StringName(id), 0)) < int(mins[id]):
			return false
	if bool(c.get("all_loot_secured", false)) and not (r.has("loot_available") and int(r["loot_available"]) > 0
			and _sum(bags) >= int(r["loot_available"])):
		return false
	return true


static func _facts_ok(c: Dictionary, f: Dictionary) -> bool:
	if not needs_facts(c):
		return true
	if not bool(f.get("recorded", false)):
		return false
	var objs: Dictionary = f.get("objectives", {}) as Dictionary
	for id: Variant in c.get("objectives_completed", []) as Array:
		if not _done(objs, StringName(id)):
			return false
	for id: Variant in c.get("objectives_not_completed", []) as Array:
		if _done(objs, StringName(id)):
			return false
	var methods: Dictionary = c.get("objectives_open_method", {}) as Dictionary
	for id: Variant in methods:
		var o: Dictionary = objs.get(StringName(id), {}) as Dictionary
		if not _done(objs, StringName(id)) or not _same(o.get("open_method", &""), methods[id]):
			return false
	var events: Array = f.get("events", []) as Array
	for pat: Variant in c.get("facts_seen", []) as Array:
		if not _seen(events, pat as Dictionary):
			return false
	for pat: Variant in c.get("facts_not_seen", []) as Array:
		if _seen(events, pat as Dictionary):
			return false
	return true


## Secured counted bags per loot id (HeistResult.loot).
static func secured_counts(r: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for e: Variant in r.get("loot", []) as Array:
		if not e is Dictionary:
			continue
		var id: StringName = StringName((e as Dictionary).get("loot_id", &""))
		if counts_as_loot(id):
			out[id] = int(out.get(id, 0)) + 1
	return out


## A bag that is profit: not a tool (thermite, D-068) and not excluded from bag XP (body bags).
static func counts_as_loot(id: StringName) -> bool:
	if id == &"":
		return false
	if ContentDB.has(ContentDB.LOOT, id) and ContentDB.loot(id).is_tool:
		return false
	return not _excluded_ids().has(id)


## PayoutTweak.xp_loot_excluded_ids (body bags), read once.
static func _excluded_ids() -> Array[StringName]:
	if not _excluded_loaded:
		_excluded_loaded = true
		var tw: PayoutTweak = null
		if ResourceLoader.exists(PayoutCalculator.DEFAULT_TWEAK_PATH):
			tw = load(PayoutCalculator.DEFAULT_TWEAK_PATH) as PayoutTweak
		if tw != null:
			_excluded = tw.xp_loot_excluded_ids.duplicate()
	return _excluded


static func _done(objs: Dictionary, id: StringName) -> bool:
	var o: Dictionary = objs.get(id, {}) as Dictionary
	return int(o.get("state", -1)) == Enums.ObjectiveState.COMPLETED and not bool(o.get("skipped", false))


static func _seen(events: Array, pat: Dictionary) -> bool:
	var sig: StringName = StringName(pat.get("signal", &""))
	var want: Dictionary = pat.get("args", {}) as Dictionary
	for e: Variant in events:
		var ev: Array = e as Array
		if ev.size() < 2 or StringName(ev[0]) != sig:
			continue
		var args: Array = ev[1] as Array
		var ok: bool = true
		for i: Variant in want:
			var idx: int = int(i)
			ok = ok and idx < args.size() and _same(args[idx], want[i])
		if ok:
			return true
	return false


static func _same(a: Variant, b: Variant) -> bool:
	var sa: bool = a is String or a is StringName
	var sb: bool = b is String or b is StringName
	if sa or sb:
		return sa and sb and String(a) == String(b)
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return a == b


static func _crew_total(crew: Array, key: String) -> int:
	var n: int = 0
	for row: Variant in crew:
		if row is Dictionary:
			n += int((row as Dictionary).get(key, 0))
	return n


static func _sum(d: Dictionary) -> int:
	var n: int = 0
	for k: Variant in d:
		n += int(d[k])
	return n
