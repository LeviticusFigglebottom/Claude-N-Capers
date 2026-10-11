## Options defaults, ranges and choices (data: res://content/data/settings/settings_defaults.tres). Owner: ENV B.
## The single schema GameSettings validates against (content/docs/options.md).
##
## `sections` = {section: {key: spec}}; insertion order is the UI order. A spec is a Dictionary:
##   {"type": "float", "default": f, "min": f, "max": f, "step": f}
##   {"type": "int", "default": i, "min": i, "max": i, "options": [i, ...]}   (options = UI choices)
##   {"type": "bool", "default": b}
##   {"type": "choice", "default": "id", "options": ["id", ...]}              (stored as String)
## `action_order` = rebind list order (every project InputMap action not listed is appended).
class_name SettingsDefaults
extends Resource

const DEFAULT_PATH: String = "res://content/data/settings/settings_defaults.tres"
const T_FLOAT: String = "float"
const T_INT: String = "int"
const T_BOOL: String = "bool"
const T_CHOICE: String = "choice"

static var _cached: SettingsDefaults = null

@export var sections: Dictionary = {}
@export var action_order: Array[StringName] = []


static func load_default() -> SettingsDefaults:
	if _cached == null:
		if ResourceLoader.exists(DEFAULT_PATH):
			_cached = load(DEFAULT_PATH) as SettingsDefaults
		if _cached == null:
			Log.error(&"settings", "missing %s" % DEFAULT_PATH)
			_cached = SettingsDefaults.new()
	return _cached


## The spec of section/key ({} when unknown).
func spec(section: StringName, key: StringName) -> Dictionary:
	var s: Dictionary = sections.get(String(section), {}) as Dictionary
	return s.get(String(key), {}) as Dictionary


func keys(section: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in (sections.get(String(section), {}) as Dictionary):
		out.append(StringName(k))
	return out


func default_value(section: StringName, key: StringName) -> Variant:
	return sanitize(section, key, spec(section, key).get("default"))


## `value` clamped / validated against the spec; the default when the type is wrong.
## Returns null for an unknown section/key.
func sanitize(section: StringName, key: StringName, value: Variant) -> Variant:
	var sp: Dictionary = spec(section, key)
	if sp.is_empty():
		return null
	var def: Variant = sp.get("default")
	var out: Variant = def
	match String(sp.get("type", "")):
		T_FLOAT:
			if (value is float or value is int) and is_finite(float(value)):
				out = clampf(float(value), float(sp.get("min", -INF)), float(sp.get("max", INF)))
			else:
				out = float(def)
		T_INT:
			if (value is float or value is int) and is_finite(float(value)):
				out = clampi(roundi(float(value)), int(sp.get("min", -2147483648)), int(sp.get("max", 2147483647)))
			else:
				out = int(def)
		T_BOOL:
			out = bool(value) if value is bool else bool(def)
		T_CHOICE:
			var opts: Array = sp.get("options", []) as Array
			var s: String = String(value) if (value is String or value is StringName) else ""
			out = s if opts.has(s) else String(def)
	return out
