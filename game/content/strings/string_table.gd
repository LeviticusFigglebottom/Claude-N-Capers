## Player-facing text lookup. All strings live in res://content/data/strings/strings.csv (columns
## `keys,en`), imported by Godot's standard CSV translation importer (D-021). The generated
## strings.en.translation is registered by the lead in project.godot; this class NEVER registers
## translations itself. Controls can simply use tr()/auto-translate with the same keys.
##
##   StringTable.text(&"ui.results.total", {"amount": "12,000"})  -> tr(key) + {name} formatting
## A key that tr() returns unchanged is missing: Log.warn once per key, return the key.
class_name StringTable
extends RefCounted

const CSV_PATH: String = "res://content/data/strings/strings.csv"

static var _warned: Dictionary = {}


static func text(key: StringName, args: Dictionary = {}) -> String:
	var s: String = String(TranslationServer.translate(key))
	if s == String(key):
		if not _warned.has(key):
			_warned[key] = true
			Log.warn(&"strings", "missing string key '%s'" % key)
		return String(key)
	return format(s, args)


## True when the key translates (i.e. the translation is registered and contains it).
static func has(key: StringName) -> bool:
	return String(TranslationServer.translate(key)) != String(key)


## `{name}` placeholder substitution (String.format). Unknown placeholders are left as-is.
static func format(template: String, args: Dictionary = {}) -> String:
	if args.is_empty():
		return template
	return template.format(args)


## Parse strings.csv as text: key -> en. For tooling/tests (validating keys without tr()).
## Duplicate keys are reported in `duplicates` when given.
static func parse_csv(path: String = CSV_PATH, duplicates: Array[String] = []) -> Dictionary:
	var out: Dictionary = {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		Log.error(&"strings", "cannot open %s" % path)
		return out
	var header: PackedStringArray = f.get_csv_line()
	var col: int = header.find("en")
	if header.is_empty() or header[0] != "keys" or col < 0:
		Log.error(&"strings", "%s: header must be 'keys,en'" % path)
		return out
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() <= col or row[0].strip_edges() == "":
			continue
		if out.has(row[0]):
			duplicates.append(row[0])
		out[row[0]] = row[col]
	return out
