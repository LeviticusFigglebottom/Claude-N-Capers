## B1-04: every strings key used by the UI scenes/scripts exists in strings.csv (literal keys found
## by grep, plus the keys the UI builds from enums).
extends TestCase

const UI_ROOT: String = "res://content/ui"
const KEY_PATTERN: String = "&?\"((?:ui|heist|item|objective|contact|crew|enemy)\\.[a-z0-9_.]+)\""

var _table: Dictionary = {}


func before_all() -> void:
	_table = StringTable.parse_csv()


func test_literal_keys_exist() -> void:
	var rx: RegEx = RegEx.create_from_string(KEY_PATTERN)
	var files: Array[String] = []
	_collect(UI_ROOT, files)
	assert_true(files.size() > 10, "found UI sources: %d" % files.size())
	var found: int = 0
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in rx.search_all(text):
			found += 1
			assert_has(_table, m.get_string(1), "used in %s" % path)
	assert_true(found > 50, "grep found %d key uses" % found)


func test_enum_built_keys_exist() -> void:
	for t: String in Enums.ModType.keys():
		assert_has(_table, "ui.mod_type.%s" % t.to_lower())
	for p: int in range(Enums.AssaultPhase.size()):
		assert_has(_table, String(AssaultBanner.phase_key(p)))
	for d: int in range(Enums.Difficulty.size()):
		assert_has(_table, String(UiText.difficulty_key(d)))
	for e: Dictionary in HeistCatalog.entries():
		for k: String in ["name_key", "subtitle_key", "brief_key"]:
			assert_has(_table, String(e[k]))
	for w: String in ["phantom", "stinger"]:
		assert_has(_table, "ui.hud.%s_warning" % w)


func test_item_names_for_loadout_options() -> void:
	for kind: StringName in [ContentDB.MELEE, ContentDB.ARMOR, ContentDB.DEPLOYABLES, ContentDB.LOOT]:
		for r: Resource in ContentDB.all_of(kind):
			assert_has(_table, String(UiText.item_key(StringName(r.get(&"id")))))


func _collect(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		_collect(dir_path.path_join(sub), out)
