## Type schema of a profile save dict (B4-16). Owner: ENV B. Static; pure (no content lookups).
##
## sanitize(d) runs AFTER SaveService.migrate(): it returns a dict with EVERY field of the current
## version, each of the right JSON type. A missing field gets its default silently; a field of the
## wrong type (e.g. `"cash": "lots"`) gets its default with a Log.warn, and a bad element inside a
## list or map (e.g. a number in owned_weapons, a string skill level) is dropped with a Log.warn.
## Unknown top-level keys are dropped. Content ids are NOT checked here (ProfileValidator does that).
## Field reference (types, defaults, since-version): content/docs/save_format.md. Keep FIELDS, that
## doc and PlayerProfile in step.
class_name ProfileSchema
extends RefCounted

const LOG_CHANNEL: StringName = &"save"
## Field kinds.
const INT: StringName = &"int"
const FLOAT: StringName = &"float"
const STRING: StringName = &"string"
const ID_LIST: StringName = &"id_list"
const INT_MAP: StringName = &"int_map"
const FLOAT_MAP: StringName = &"float_map"
const ANY_MAP: StringName = &"any_map"
const SKILL_SETS: StringName = &"skill_sets"
const CUSTOM_MASKS: StringName = &"custom_masks"
const ACHIEVEMENTS: StringName = &"achievements"
const LOADOUT: StringName = &"loadout"
## String -> String map (notoriety_choices).
const STRING_MAP: StringName = &"string_map"
## A String of at most SHORT_ID_MAX_LENGTH characters (music_choice); longer -> default + warn.
const SHORT_ID: StringName = &"short_id"
const SHORT_ID_MAX_LENGTH: int = 64
## Career stats (v7, B7-01): {section: {key: int >= 0}} / {section: {id: {key: int >= 0}}} (Career.SECTIONS).
const CAREER: StringName = &"career"
## String -> String map whose keys and values are at most SHORT_ID_MAX_LENGTH characters (weapon_finishes).
const SHORT_STRING_MAP: StringName = &"short_string_map"
## Heist freshness (v9, D-139): {"recent": [id], "runs": int >= 0, "last_run": {id: int >= 0}, "completed": [id]}.
const FRESHNESS: StringName = &"freshness"
## Crew bot loadouts (v10, D-145.4 / PO-19): exactly CREW_SLOTS entries {CREW_FIELDS} (CrewLoadouts).
const CREW_LOADOUTS: StringName = &"crew_loadouts"
const CREW_SLOTS: int = 3
## Crew loadout entry fields -> [kind, default] ("" / [] = the bot's default).
const CREW_FIELDS: Dictionary = {
	"weapon": [SHORT_ID, ""], "mods": [ID_LIST, []], "armor": [SHORT_ID, ""], "mask": [SHORT_ID, ""],
	"outfit": [SHORT_ID, ""], "ability": [SHORT_ID, ""], "boost": [SHORT_ID, ""],
}
## Career sections whose values are counter maps (the others are counters directly).
const CAREER_NESTED: Array[String] = ["heists", "difficulties"]
## Top-level field -> [kind, default, since-version]. Order = file order of the doc.
const FIELDS: Dictionary = {
	"version": [INT, 0, 1],
	"profile_name": [STRING, "", 0],
	"cash": [INT, 0, 0],
	"stash": [INT, 0, 0],
	"xp": [INT, 0, 0],
	"level": [INT, 0, 0],
	"banked_stealth_mult": [FLOAT, 1.0, 2],
	"owned_weapons": [ID_LIST, [], 0],
	"owned_mods": [ID_LIST, [], 0],
	"owned_masks": [ID_LIST, [], 0],
	"owned_mask_parts": [ID_LIST, [], 4],
	"custom_masks": [CUSTOM_MASKS, [], 4],
	"loadout": [LOADOUT, {}, 0],
	"skill_sets": [SKILL_SETS, [], 3],
	"active_skill_set": [INT, 0, 3],
	"perk_cards": [INT_MAP, {}, 3],
	"unlocks": [ID_LIST, [], 5],
	"achievements": [ACHIEVEMENTS, {}, 5],
	"pro_job_locks": [FLOAT_MAP, {}, 5],
	"notoriety": [INT, 0, 6],
	"notoriety_xp": [INT, 0, 6],
	"notoriety_choices": [STRING_MAP, {}, 6],
	"held_skill_sets": [SKILL_SETS, [], 6],
	"music_choice": [SHORT_ID, "", 6],
	"career": [CAREER, {"totals": {}, "heists": {}, "difficulties": {}, "bags": {}, "weapons": {}}, 7],
	"weapon_finishes": [SHORT_STRING_MAP, {}, 7],
	"freshness": [FRESHNESS, {"recent": [], "runs": 0, "last_run": {}, "completed": []}, 9],
	"crew_loadouts": [CREW_LOADOUTS, [], 10],
	"stats": [INT_MAP, {}, 0],
	"settings": [ANY_MAP, {}, 0],
}
## Loadout sub-fields -> [kind, default].
const LOADOUT_FIELDS: Dictionary = {
	"primary": [STRING, ""], "primary_mods": [ID_LIST, []],
	"secondary": [STRING, ""], "secondary_mods": [ID_LIST, []],
	"melee": [STRING, ""], "throwable": [STRING, ""], "deployable": [STRING, ""],
	"deployable_secondary": [STRING, ""], "armor": [STRING, ""], "mask": [STRING, ""],
	"perk_deck": [STRING, ""], "perk_deck_cards": [INT, 0], "skills": [INT_MAP, {}],
	"heister": [SHORT_ID, ""],  # D-073, additive in v6: a missing key reads as "" (no preference)
}


## Every current field, typed; see the header. `d` is not modified.
static func sanitize(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for f: String in FIELDS:
		var spec: Array = FIELDS[f]
		out[f] = _field(f, d, StringName(spec[0]), spec[1])
	if (out["crew_loadouts"] as Array).size() != CREW_SLOTS:  # a missing field: CREW_SLOTS empty entries
		out["crew_loadouts"] = empty_crew_loadouts()
	return out


static func _field(path: String, d: Dictionary, kind: StringName, default: Variant) -> Variant:
	var key: String = path.get_file() if "/" in path else path
	if not d.has(key):
		return default.duplicate(true) if (default is Array or default is Dictionary) else default
	var v: Variant = d[key]
	var out: Variant = _value(path, v, kind)
	if out == null:
		_warn("%s: expected %s, got %s; using the default" % [path, kind, type_string(typeof(v))])
		return default.duplicate(true) if (default is Array or default is Dictionary) else default
	return out


## The sanitized value, or null when `v` has the wrong type for `kind`.
static func _value(path: String, v: Variant, kind: StringName) -> Variant:
	match kind:
		INT, FLOAT, STRING, SHORT_ID:
			return _scalar(v, kind)
		ID_LIST:
			return _id_list(path, v) if v is Array else null
		LOADOUT:
			return _loadout(path, v as Dictionary) if v is Dictionary else null
	return _container(path, v, kind)


static func _scalar(v: Variant, kind: StringName) -> Variant:
	var is_text: bool = v is String or v is StringName
	match kind:
		INT:
			return _as_int(v)
		FLOAT:
			return float(v) if (v is int or v is float) else null
		SHORT_ID:
			return String(v) if is_text and String(v).length() <= SHORT_ID_MAX_LENGTH else null
	return String(v) if is_text else null


static func _container(path: String, v: Variant, kind: StringName) -> Variant:
	var out: Variant = null
	if v is Dictionary:
		var m: Dictionary = v as Dictionary
		match kind:
			INT_MAP:
				out = _int_map(path, m)
			FLOAT_MAP:
				out = _float_map(path, m)
			ANY_MAP:
				out = m.duplicate(true)
			ACHIEVEMENTS:
				out = _achievements(path, m)
			STRING_MAP:
				out = _string_map(path, m)
			SHORT_STRING_MAP:
				out = _short_string_map(path, m)
			CAREER:
				out = _career(path, m)
			FRESHNESS:
				out = _freshness(path, m)
	elif v is Array:
		match kind:
			SKILL_SETS:
				out = _skill_sets(path, v as Array)
			CUSTOM_MASKS:
				out = _custom_masks(path, v as Array)
			CREW_LOADOUTS:
				out = _crew_loadouts(path, v as Array)
	return out


## int, or a whole-valued float (JSON numbers parse as float). Anything else -> null.
static func _as_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float and is_finite(float(v)):
		return int(v)
	return null


static func _id_list(path: String, a: Array) -> Array:
	var out: Array = []
	for e: Variant in a:
		if (e is String or e is StringName) and String(e) != "":
			out.append(String(e))
		else:
			_warn("%s: dropped non-id element %s" % [path, var_to_str(e)])
	return out


static func _int_map(path: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in m:
		var n: Variant = _as_int(m[k])
		if n == null:
			_warn("%s.%s: expected int, got %s; dropped" % [path, k, type_string(typeof(m[k]))])
			continue
		out[String(k)] = n
	return out


static func _string_map(path: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in m:
		var v: Variant = m[k]
		if not (v is String or v is StringName):
			_warn("%s.%s: expected string, got %s; dropped" % [path, k, type_string(typeof(v))])
			continue
		out[String(k)] = String(v)
	return out


static func _short_string_map(path: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in m:
		var v: Variant = m[k]
		var ok: bool = (v is String or v is StringName) and String(v).length() <= SHORT_ID_MAX_LENGTH
		if not ok or String(k).length() > SHORT_ID_MAX_LENGTH or String(k) == "":
			_warn("%s.%s: expected a short string (<= %d chars); dropped" % [path, k, SHORT_ID_MAX_LENGTH])
			continue
		out[String(k)] = String(v)
	return out


## Every Career section present; counters are ints >= 0 with short keys; difficulty keys are ints.
static func _career(path: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in m:
		if not Career.SECTIONS.has(String(k)):
			_warn("%s.%s: unknown career section; dropped" % [path, k])
	for sec: String in Career.SECTIONS:
		var v: Variant = m.get(sec, {})
		var sp: String = "%s.%s" % [path, sec]
		if not v is Dictionary:
			_warn("%s: expected a map; emptied" % sp)
			v = {}
		if not CAREER_NESTED.has(sec):
			out[sec] = _counters(sp, v as Dictionary)
			continue
		var nested: Dictionary = {}
		for id: Variant in (v as Dictionary):
			var e: Variant = (v as Dictionary)[id]
			var bad_key: bool = String(id) == "" or String(id).length() > SHORT_ID_MAX_LENGTH
			bad_key = bad_key or (sec == "difficulties" and not String(id).is_valid_int())
			if bad_key or not e is Dictionary:
				_warn("%s.%s: bad entry; dropped" % [sp, id])
				continue
			nested[String(id)] = _counters("%s.%s" % [sp, id], e as Dictionary)
		out[sec] = nested
	return out


## Every freshness key present: id lists of short ids, "runs" and "last_run" counters ints >= 0 (bad parts warn and
## reset / drop).
static func _freshness(path: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in ["recent", "completed"]:
		var v: Variant = m.get(k, [])
		if not v is Array:
			_warn("%s.%s: expected a list; emptied" % [path, k])
			v = []
		var ids: Array = []
		for id: String in _id_list("%s.%s" % [path, k], v as Array):
			if id.length() <= SHORT_ID_MAX_LENGTH:
				ids.append(id)
			else:
				_warn("%s.%s: id over %d chars; dropped" % [path, k, SHORT_ID_MAX_LENGTH])
		out[k] = ids
	var runs: Variant = _as_int(m.get("runs", 0))
	if runs == null or int(runs) < 0:
		_warn("%s.runs: expected an int >= 0; using 0" % path)
		runs = 0
	out["runs"] = runs
	var last: Variant = m.get("last_run", {})
	if not last is Dictionary:
		_warn("%s.last_run: expected a map; emptied" % path)
		last = {}
	out["last_run"] = _counters("%s.last_run" % path, last as Dictionary)
	return out


## Short key -> int >= 0; anything else dropped with a warning.
static func _counters(path: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in m:
		var n: Variant = _as_int(m[k])
		if n == null or int(n) < 0 or String(k) == "" or String(k).length() > SHORT_ID_MAX_LENGTH:
			_warn("%s.%s: expected a counter (int >= 0), got %s; dropped" % [path, k, var_to_str(m[k])])
			continue
		out[String(k)] = n
	return out


static func _float_map(path: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in m:
		var v: Variant = m[k]
		if not (v is int or v is float):
			_warn("%s.%s: expected number, got %s; dropped" % [path, k, type_string(typeof(v))])
			continue
		out[String(k)] = float(v)
	return out


static func _loadout(path: String, d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for f: String in LOADOUT_FIELDS:
		var spec: Array = LOADOUT_FIELDS[f]
		out[f] = _field(path + "/" + f, d, StringName(spec[0]), spec[1])
	return out


static func _skill_sets(path: String, a: Array) -> Array:
	var out: Array = []
	for i: int in range(a.size()):
		if a[i] is Dictionary:
			out.append(_int_map("%s[%d]" % [path, i], a[i] as Dictionary))
		else:
			_warn("%s[%d]: expected a skill dict; emptied" % [path, i])
			out.append({})
	return out


## Each slot is {} or a String -> String composition; a slot with a non-string value is emptied.
static func _custom_masks(path: String, a: Array) -> Array:
	var out: Array = []
	for i: int in range(a.size()):
		var e: Variant = a[i]
		var comp: Dictionary = {}
		var ok: bool = e is Dictionary
		if ok:
			for k: Variant in (e as Dictionary):
				var v: Variant = (e as Dictionary)[k]
				if not (v is String or v is StringName):
					ok = false
					break
				comp[String(k)] = String(v)
		if not ok:
			_warn("%s[%d]: malformed composition; slot emptied" % [path, i])
			comp = {}
		out.append(comp)
	return out


## Exactly CREW_SLOTS entries, each with every CREW_FIELDS field typed: a non-dict entry is emptied, extra entries
## are dropped, missing ones added (all with a warning, except the padding of a short list).
static func _crew_loadouts(path: String, a: Array) -> Array:
	var out: Array = []
	if a.size() > CREW_SLOTS:
		_warn("%s: %d entries, keeping the first %d" % [path, a.size(), CREW_SLOTS])
	for i: int in range(CREW_SLOTS):
		var e: Variant = a[i] if i < a.size() else {}
		if not e is Dictionary:
			_warn("%s[%d]: expected a crew loadout; emptied" % [path, i])
			e = {}
		var entry: Dictionary = {}
		for f: String in CREW_FIELDS:
			var spec: Array = CREW_FIELDS[f]
			entry[f] = _field("%s[%d]/%s" % [path, i, f], e as Dictionary, StringName(spec[0]), spec[1])
		out.append(entry)
	return out


## A crew_loadouts value with CREW_SLOTS empty entries (the field default and the v9 -> v10 migration).
static func empty_crew_loadouts() -> Array:
	return _crew_loadouts("crew_loadouts", [])


static func _achievements(path: String, m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in m:
		var e: Variant = m[k]
		if not e is Dictionary:
			_warn("%s.%s: expected {progress, unlocked}; dropped" % [path, k])
			continue
		var progress: Variant = _as_int((e as Dictionary).get("progress", 0))
		var unlocked: Variant = (e as Dictionary).get("unlocked", false)
		if progress == null or not unlocked is bool:
			_warn("%s.%s: bad progress/unlocked; dropped" % [path, k])
			continue
		out[String(k)] = {"progress": progress, "unlocked": unlocked}
	return out


static func _warn(msg: String) -> void:
	Log.warn(LOG_CHANNEL, "profile: " + msg)
