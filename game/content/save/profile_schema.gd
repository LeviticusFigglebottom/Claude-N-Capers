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
}


## Every current field, typed; see the header. `d` is not modified.
static func sanitize(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for f: String in FIELDS:
		var spec: Array = FIELDS[f]
		out[f] = _field(f, d, StringName(spec[0]), spec[1])
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
	elif v is Array:
		match kind:
			SKILL_SETS:
				out = _skill_sets(path, v as Array)
			CUSTOM_MASKS:
				out = _custom_masks(path, v as Array)
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
