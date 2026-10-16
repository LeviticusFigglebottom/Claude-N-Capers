## UI text helper. Owner: ENV B. Every visible UI string goes through `t()` with a strings.csv key.
##
## t(key, args) = tr(key) + `{name}` formatting (StringTable.format). Until the lead registers the
## translation in project.godot (D-021), tr() returns the key unchanged; t() then falls back to the
## strings.csv text so menus are readable in dev builds. No warning spam (unlike StringTable.text),
## because HUD widgets refresh often.
class_name UiText
extends RefCounted

static var _csv: Dictionary = {}
static var _csv_loaded: bool = false


static func t(key: StringName, args: Dictionary = {}) -> String:
	var s: String = String(TranslationServer.translate(key))
	if s == String(key):
		s = String(_fallback().get(String(key), s))
	return StringTable.format(s, args)


## True when `key` has a string (translation or the fallback table); t() of a missing key returns the key itself.
static func has(key: StringName) -> bool:
	return String(TranslationServer.translate(key)) != String(key) or _fallback().has(String(key))


## "$12,345" style money (sign kept), via `ui.common.money`.
static func money(amount: int) -> String:
	var prefix: String = "-" if amount < 0 else ""
	return prefix + t(&"ui.common.money", {"amount": group_digits(absi(amount))})


## 12345 -> "12,345".
static func group_digits(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	var n: int = digits.length()
	for i: int in range(n):
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out


## 125.4 -> "2:05".
static func clock(seconds: float) -> String:
	var s: int = maxi(ceili(seconds), 0)
	return "%d:%02d" % [s / 60, s % 60]


## Display name key for a content id (`item.<id>.name`).
static func item_key(id: StringName) -> StringName:
	return StringName("item.%s.name" % id)


static func difficulty_key(d: int) -> StringName:
	var keys: Array = Enums.Difficulty.keys()
	return StringName("ui.difficulty.%s" % String(keys[clampi(d, 0, keys.size() - 1)]).to_lower())


static func _fallback() -> Dictionary:
	if not _csv_loaded:
		_csv_loaded = true
		_csv = StringTable.parse_csv()
	return _csv
