## D-115 objective/HUD text audit: for each shipped heist, every player-facing string the heist can show
## (HeistDef objectives / briefing / optional lines, loot and escape names, pre-planning assets, points and
## blueprint labels, voice lines, plus every literal key its mission/map files reference) exists in
## strings.csv, is non-empty, has only documented {placeholders}, and carries no raw key, dev tag or id.
## Data-only: no scene is instanced (the map .tscn files are read as text).
extends TestCase

const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn", &"gallery_night",
	&"ostrander_federal", &"rolling_thunder"]  # RT: LEAD's D-115 done check (round 292)
const HEIST_DIR: String = "res://world/heists/%s"
const DEF_PATH: String = "res://world/heists/%s/%s_def.tres"
const BLUEPRINT_PATH: String = "res://content/data/preplanning/blueprints/%s.tres"
const VOICE_LINES_PATH: String = "res://content/data/voice/lines.tres"
## Format args the heist code passes (objective data and voice_line_requested context). Anything else in
## a heist string is an unresolved placeholder.
## drives / drives_secured: Shadow Ledger's [secure] data (D-115 B-SL). opened: Rolling Thunder's [trucks] data
## (rolling_thunder_mission update_objective_data(&"trucks", {opened, total})).
const ALLOWED_ARGS: Array[String] = ["count", "total", "found", "seconds", "answered", "escape", "shutters_in_s",
	"drives", "drives_secured", "opened"]
## Dev tags that must never reach the player.
const BANNED: Array[String] = ["[loud]", "[stealth]", "[tag]", "TODO", "TBD", "PLACEHOLDER", "FIXME", "XXX"]

var _table: Dictionary = {}
var _voice: VoiceLineTable
## Any key-shaped token ("objective.x", "ui.prompt.y", "loot.cash"), a G-gate tag, or a {placeholder}.
var _raw_key_rx: RegEx = RegEx.create_from_string(
		"\\b(objective|ui|vo|voice|heist|item|loot|asset|music|achievement)\\.[a-z_]")
var _gate_rx: RegEx = RegEx.create_from_string("\\bG[0-9]\\b")
var _arg_rx: RegEx = RegEx.create_from_string("\\{([^{}]*)\\}")
## Literal string keys in the heist's code and map text (asset and item ids are content ids, checked via the HeistDef).
var _ref_rx: RegEx = RegEx.create_from_string(
		"\"((?:objective|ui|vo|heist)\\.[A-Za-z0-9_.%]+)\"")


func before_all() -> void:
	_table = StringTable.parse_csv(StringTable.CSV_PATH)
	_voice = load(VOICE_LINES_PATH) as VoiceLineTable


func test_heist_defs_resolve_to_doc_text() -> void:
	for h: StringName in HEISTS:
		var def: HeistDef = load(DEF_PATH % [h, h]) as HeistDef
		assert_true(def != null, "%s def loads" % h)
		if def == null:
			continue
		var keys: Array[String] = ["heist.%s.name" % h, "heist.%s.subtitle" % h, "heist.%s.brief" % h]
		if def.briefing != "":
			assert_true(_table.has(def.briefing), "%s: HeistDef.briefing is a strings key (%s)" % [h, def.briefing])
			keys.append(def.briefing)
		if def.briefing_loud_key != &"":
			keys.append(String(def.briefing_loud_key))
		for ids: Array in [def.objectives, def.briefing_objectives, def.briefing_optional]:
			for oid: StringName in ids:
				# A dotted entry (ui.briefing.step.<heist>.<step>) is a strings key as-is (BriefingModel.objective_lines).
				keys.append(String(oid) if String(oid).contains(".") else "objective.%s.%s" % [h, oid])
		for eid: StringName in def.escape_options:
			keys.append("ui.briefing.escape.%s" % eid)
		for lid: StringName in def.loot:
			if ContentDB.has(&"loot", lid):
				keys.append(String(UiText.item_key(lid)))
		var assets: Dictionary = (def.preplanning.get("assets", {}) as Dictionary) if def.preplanning is Dictionary else {}
		for aid: Variant in assets:
			keys.append("item.%s.name" % aid)
			keys.append("item.%s.desc" % aid)
		assert_eq(UiText.t(StringName("heist.%s.name" % h)), def.display_name, "%s: name matches HeistDef.display_name" % h)
		for k: String in keys:
			_check(h, k, "HeistDef")


func test_keys_referenced_by_heist_files() -> void:
	for h: StringName in HEISTS:
		var files: Array[String] = []
		_collect(HEIST_DIR % h, files)
		var bp: String = BLUEPRINT_PATH % h
		if FileAccess.file_exists(bp):
			files.append(bp)
		assert_true(files.size() > 3, "%s: heist files found" % h)
		var literal: int = 0
		for path: String in files:
			for m: RegExMatch in _ref_rx.search_all(FileAccess.get_file_as_string(path)):
				var k: String = m.get_string(1)
				if k.contains("%"):
					# Format string (e.g. "vo.mercer.gallery_night_%s_eta"): some key must complete its prefix.
					var prefix: String = k.get_slice("%", 0)
					var full: String = ("voice." + prefix) if prefix.begins_with("vo.") else prefix
					assert_true(_has_prefix(full), "%s: keys %s* (format string in %s)" % [h, full, path])
				elif k.ends_with("."):
					assert_true(_has_prefix(k), "%s: keys %s* (built in %s)" % [h, k, path])
				elif k.begins_with("vo."):
					assert_false(_voice.line(StringName(k)).is_empty(), "%s: voice line %s (in %s)" % [h, k, path])
					_check(h, "voice.%s" % k, path)
					literal += 1
				else:
					_check(h, k, path)
					literal += 1
		assert_true(literal >= 10, "%s: scan found %d literal keys" % [h, literal])


## Every string whose key names the heist (objectives, radio and briefing lines, blueprint and pre-planning
## labels, achievements, music) and every voice line tagged with it.
func test_every_heist_string_is_clean() -> void:
	for h: StringName in HEISTS:
		var n: int = 0
		for k: Variant in _table:
			var key: String = String(k)
			if key.contains(".%s." % h) or key.contains(".%s_" % h) or key.ends_with(".%s" % h) \
					or key.contains("_%s_" % h):
				_check(h, key, "strings.csv")
				n += 1
		for l: Dictionary in _voice.lines:
			if StringName(l.get("heist", &"")) == h or String(l.get("id", "")).contains(String(h)):
				var tk: String = String(l.get("text_key", ""))
				assert_true(tk != "", "%s: voice line %s has a text_key" % [h, l.get("id", "")])
				_check(h, tk, "voice line %s" % l.get("id", ""))
		assert_true(n >= 20, "%s: %d heist strings audited" % [h, n])


## The checker itself rejects what the audit is for.
## LEAD r224: every carried-item id (`item.*` that is not an asset or a bag) a heist or a prefab hands out has a display
## name (UiText.item_key), and every loot id a heist lists has one too, def-less small loot included
## (loot.small_valuables keeps no LootDef by D-120; the briefing lists it by name).
func test_carried_items_and_loot_ids_have_names() -> void:
	var files: Array[String] = []
	for h: StringName in HEISTS:
		_collect(HEIST_DIR % h, files)
	_collect("res://systems/prefabs", files)
	var rx: RegEx = RegEx.create_from_string("&\"(item\\.[a-z0-9_]+)\"")
	var items: Dictionary = {}
	for f: String in files:
		if not f.ends_with(".gd"):
			continue
		for m: RegExMatch in rx.search_all(FileAccess.get_file_as_string(f)):
			var id: String = m.get_string(1)
			if not id.begins_with("item.asset.") and not id.begins_with("item.loot."):
				items[id] = f
	assert_true(items.has("item.keycard") and items.has("item.code_note"), "carried items found: %s" % [items.keys()])
	for id: String in items:
		_check(&"carried", String(UiText.item_key(StringName(id))), String(items[id]))
	for h2: StringName in HEISTS:
		var def: HeistDef = load(DEF_PATH % [h2, h2]) as HeistDef
		for loot: StringName in def.loot:
			_check(h2, String(UiText.item_key(loot)), "HeistDef.loot")
	var lines: Array[Dictionary] = BriefingModel.loot_lines([&"loot.cash", &"loot.small_valuables"], 0)
	assert_eq(lines.size(), 2, "the def-less small loot lists by name")
	assert_true(bool(lines[1].get("small", false)) and String(lines[1]["text"]) == "Small valuables", str(lines[1]))
	assert_false(ContentDB.has(ContentDB.LOOT, &"loot.small_valuables"), "D-120: still no LootDef")


func test_checker_rejects_raw_text() -> void:
	assert_true(_problem("Find objective.glasshouse.keycard") != "", "raw objective key")
	assert_true(_problem("Press ui.prompt.use") != "", "raw prompt key")
	assert_true(_problem("Bag the loot.cash") != "", "loot id")
	assert_true(_problem("[loud] Drill the safe") != "", "dev tag")
	assert_true(_problem("G0 placeholder room") != "", "gate tag")
	assert_true(_problem("Secure {bags}") != "", "undocumented placeholder")
	assert_true(_problem("Secure {count/{total}") != "", "unbalanced braces")
	assert_eq(_problem("Bag the loot. Then secure the bags ({count}/{total})"), "", "plain text passes")


func _check(h: StringName, key: String, where: String) -> void:
	if not _table.has(key):
		fail("%s: missing string %s (from %s)" % [h, key, where])
		return
	var p: String = _problem(String(_table[key]))
	assert_eq(p, "", "%s: %s = \"%s\" (from %s)" % [h, key, _table[key], where])


## "" when `text` is fine, else what is wrong with it.
func _problem(text: String) -> String:
	var out: Array[String] = []
	if text.strip_edges() == "":
		out.append("empty")
	for b: String in BANNED:
		if text.contains(b):
			out.append("dev tag %s" % b)
	var m: RegExMatch = _raw_key_rx.search(text)
	if m != null:
		out.append("raw key %s" % m.get_string())
	if _gate_rx.search(text) != null:
		out.append("gate tag")
	if text.count("{") != text.count("}"):
		out.append("unbalanced braces")
	for a: RegExMatch in _arg_rx.search_all(text):
		if not ALLOWED_ARGS.has(a.get_string(1)):
			out.append("placeholder {%s}" % a.get_string(1))
	return ", ".join(out)


func _has_prefix(prefix: String) -> bool:
	for k: Variant in _table:
		if String(k).begins_with(prefix) and String(k).length() > prefix.length():
			return true
	return false


func _collect(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		_collect(dir_path.path_join(sub), out)
