## B1-07: strings.csv parses cleanly, required keys exist, StringTable formatting and missing keys.
extends TestCase

const REQUIRED_KEYS: Array[String] = [
	"ui.prompt.answer_pager", "ui.prompt.bag_body", "ui.prompt.tie_civilian", "ui.prompt.pick_lock",
	"ui.prompt.use_keycard", "ui.prompt.place_drill", "ui.prompt.fix_drill", "ui.prompt.take_loot",
	"ui.prompt.secure_bag", "ui.prompt.break_case", "ui.prompt.revive", "ui.prompt.mask_up",
	"ui.prompt.open_door", "ui.prompt.interact", "ui.blocked.casing",
	"ui.stat.damage", "ui.stat.accuracy", "ui.stat.stability", "ui.stat.concealment", "ui.stat.threat",
	"ui.stat.magazine", "ui.stat.total_ammo", "ui.stat.rate_of_fire", "ui.stat.reload",
	"ui.stat.detection_risk", "heist.glasshouse.name", "ui.results.stealth_bonus_banked",
]
const ITEM_IDS: Array[String] = [
	"weapon.kestrel_p9", "mod.p9_suppressor", "mod.p9_reflex_sight", "mod.p9_extended_mag",
	"melee.folding_knife", "armor.tailored_suit", "armor.light_vest", "armor.patrol_vest",
	"armor.heavy_vest", "armor.flak_rig", "armor.tactical_plate", "armor.breacher_plate",
	"deployable.doctor_bag", "deployable.ammo_bag", "deployable.body_bag_case",
	"loot.jewelry", "loot.cash", "loot.body_bag",
]

const VOICE_LINES_PATH: String = "res://content/data/voice/lines.tres"

var _table: Dictionary = {}
var _dups: Array[String] = []


func before_all() -> void:
	_table = StringTable.parse_csv(StringTable.CSV_PATH, _dups)


func test_csv_parses_without_duplicates() -> void:
	assert_true(_table.size() > 100, "strings.csv has %d keys" % _table.size())
	assert_eq(_dups.size(), 0, "duplicate keys: %s" % [_dups])
	for k: String in _table.keys():
		assert_true(String(_table[k]).strip_edges() != "", "empty text for %s" % k)
		assert_eq(k, k.strip_edges().to_lower(), "key must be lowercase without spaces: %s" % k)


func test_required_keys_present() -> void:
	for k: String in REQUIRED_KEYS:
		assert_has(_table, k)
	assert_eq(_table.get("ui.blocked.casing", ""), "Mask up first (hold {mask_key})")  # PO-5.11: actionable


func test_every_p1_item_has_name_and_desc() -> void:
	for id: String in ITEM_IDS:
		assert_has(_table, "item.%s.name" % id)
		assert_has(_table, "item.%s.desc" % id)


func test_every_difficulty_has_a_name() -> void:
	for d: String in Enums.Difficulty.keys():
		assert_has(_table, "ui.difficulty.%s" % d.to_lower())


func test_xp_line_keys_present() -> void:
	for k: StringName in PayoutCalculator.XP_ORDER:
		assert_has(_table, String(k))


func test_commas_survive_quoting() -> void:
	var s: String = String(_table.get("ui.menu.quit_confirm", ""))
	assert_eq(s, "Leave the game? Unsecured loot stays behind.")
	var with_comma: String = String(_table.get("voice.vo.mercer.heist_start_casing_1", ""))
	assert_true(with_comma.contains(","), "quoted field with a comma kept whole: %s" % with_comma)


func test_format_placeholders() -> void:
	assert_eq(StringTable.format("Hold {key} to revive {name}", {"key": "F", "name": "Wren"}), "Hold F to revive Wren")
	assert_eq(StringTable.format("No args"), "No args")
	assert_eq(StringTable.format("{a} and {b}", {"a": 1}), "1 and {b}")


## D-022 QB-4: strings.en.translation is registered in project.godot, so tr() must resolve.
func test_text_translates_when_registered() -> void:
	assert_true(StringTable.has(&"ui.menu.play"), "strings.en.translation registered (D-022 QB-4)")
	assert_eq(StringTable.text(&"ui.menu.play"), "Play")
	assert_eq(StringTable.text(&"ui.prompt.revive", {"key": "F", "name": "Dutch"}), "Hold F to revive Dutch")
	assert_eq(StringTable.text(&"ui.results.stealth_bonus_banked", {"pct": 20}),
		"Stealth bonus banked for your next job: +20%")
	assert_eq(StringTable.text(&"ui.results.xp.stealth"), "Stealth bonus")


func test_missing_key_warns_once_and_returns_key() -> void:
	Log.capture = true
	Log.captured.clear()
	var key: StringName = &"ui.test.definitely_missing_key"
	assert_eq(StringTable.text(key), "ui.test.definitely_missing_key")
	assert_eq(StringTable.text(key, {"x": 1}), "ui.test.definitely_missing_key")
	var hits: int = 0
	for l: String in Log.captured:
		if l.contains("definitely_missing_key"):
			hits += 1
	Log.capture = false
	Log.captured.clear()
	assert_eq(hits, 1, "warned exactly once")
	assert_false(StringTable.has(key))


## D-038 QA-14: the keys ENV A requests; `ui.blocked.*` is canonical (no `ui.prompt.blocked.*` left).
func test_qa14_keys_and_blocked_rename() -> void:
	for k: String in ["ui.blocked.code_unknown", "ui.blocked.requires_bag", "ui.blocked.no_deployable",
			"ui.blocked.no_space", "ui.prompt.enter_code", "ui.prompt.read_note", "ui.prompt.place_saw",
			"ui.prompt.place_c4", "ui.prompt.start_time_lock", "ui.prompt.zipline_bag",
			"ui.prompt.use_first_aid_kit", "ui.prompt.ecm_feedback", "ui.prompt.uncuff",
			"ui.prompt.suspicious_not_allowed", "voice.vo.guard.cuff_warning", "voice.vo.mercer.abort"]:
		assert_has(_table, k)
	for k: String in _table.keys():
		assert_false(k.begins_with("ui.prompt.blocked."), "renamed to ui.blocked.*: %s" % k)
	var table: VoiceLineTable = _voice_table()
	for id: StringName in [&"vo.guard.cuff_warning", &"vo.mercer.abort"]:
		assert_eq(table.line(id).get("text_key", &""), StringName("voice.%s" % id), "line %s" % id)


## Every literal prompt / blocked key and voice line id in ENV A's and ENV C's code exists (read-only scan).
func test_keys_requested_by_systems_exist() -> void:
	var rx: RegEx = RegEx.create_from_string("\\b(ui\\.(?:blocked|prompt)\\.[a-z0-9_.]*[a-z0-9_]\\.?|vo\\.[a-z]+\\.[a-z0-9_]+)")
	var table: VoiceLineTable = _voice_table()
	var files: Array[String] = []
	for root: String in ["res://systems", "res://world", "res://core"]:
		_collect_code(root, files)
	var found: int = 0
	var vo_ids: int = 0
	for path: String in files:
		for m: RegExMatch in rx.search_all(FileAccess.get_file_as_string(path)):
			var k: String = m.get_string(1)
			found += 1
			if k.begins_with("vo.") and k.ends_with("_"):
				# Format-string prefix (e.g. "vo.crew.ack_%s"): some line must complete it.
				assert_true(_has_line_prefix(table, k), "voice lines %s* (used in %s)" % [k, path])
			elif k.ends_with("."):
				# Built prefix (e.g. "ui.prompt.station." + id): at least one real key must sit under it.
				assert_true(_has_key_prefix(k), "keys %s* (used in %s)" % [k, path])
			elif k.begins_with("vo."):
				assert_false(table.line(StringName(k)).is_empty(), "voice line %s (used in %s)" % [k, path])
				assert_has(_table, "voice.%s" % k, "voice text for %s (QA-27)" % k)
				vo_ids += 1
			else:
				assert_has(_table, k, "used in %s" % path)
	assert_true(found > 10, "scan found %d keys" % found)
	assert_true(vo_ids >= 4, "scan found %d literal vo ids (abort, pager_last, cuff_warning, dev_start)" % vo_ids)


func _has_key_prefix(prefix: String) -> bool:
	for key: Variant in _table:
		if String(key).begins_with(prefix) and String(key).length() > prefix.length():
			return true
	return false


## D-039: objective ids are the heist design doc's `[tag]`s, never guesses.
func test_glasshouse_objectives_follow_the_design_doc() -> void:
	var tags: Array[String] = ["casing", "keycard", "code", "workshop_door", "safe", "safe_loot", "secure", "escape"]  # LEAD: D-117 §3 doc gains [code] (round 219)
	var doc: String = ProjectSettings.globalize_path("res://").path_join("../docs/design/heists/glasshouse.md")
	if FileAccess.file_exists(doc):
		var text: String = FileAccess.get_file_as_string(doc)
		var sec: String = text.get_slice("## Objectives", 1).get_slice("\n## ", 0)
		var rx: RegEx = RegEx.create_from_string("`\\[([a-z_]+)\\]`")
		var doc_tags: Array[String] = []
		for m: RegExMatch in rx.search_all(sec):
			if not doc_tags.has(m.get_string(1)):
				doc_tags.append(m.get_string(1))
		assert_eq(doc_tags, tags, "design doc tags")
	var ph: Dictionary = BriefingModel.ui_data().placeholder_heists.get(&"glasshouse", {}) as Dictionary
	var ids: Array[String] = []
	for id: Variant in ph.get("objectives", []) as Array:
		ids.append(String(id))
	assert_eq(ids, tags, "briefing placeholder objective ids")
	for t: String in tags:
		assert_has(_table, "objective.glasshouse.%s" % t)
	# D-114 §1 / PO6-04: the silent stealth route adds a `code` step (A's mission); the doc's Objectives section is
	# the lead's to update, so the key is allowed here until then.
	var added: Array[String] = ["code"]
	for k: String in _table.keys():
		if k.begins_with("objective.glasshouse."):
			var tag: String = k.trim_prefix("objective.glasshouse.")
			assert_true(tags.has(tag) or added.has(tag), "no guessed objective key: %s" % k)


## D-043 QA-24: every AI teammate order is acknowledged with `vo.crew.ack_<order>`: crew_ai_brain.gd builds
## the id as "vo.crew.ack_%s" % order for any order accepted by CrewOrders.is_order(), i.e. CrewOrders.ORDERS
## (read from A's class here, so a new order without a line fails).
func test_crew_order_acks_exist() -> void:
	var table: VoiceLineTable = _voice_table()
	for o: StringName in CrewOrders.ORDERS:
		var l: Dictionary = table.line(StringName("vo.crew.ack_%s" % o))
		assert_eq(l.get("speaker", &""), &"crew", "ack line for %s" % o)
		assert_has(_table, "voice.vo.crew.ack_%s" % o)
	for k: String in ["ui.blocked.push_bar_outside", "ui.prompt.trade_hostage", "ui.prompt.convert", "ui.prompt.cable_tie"]:
		assert_has(_table, k)


func _has_line_prefix(table: VoiceLineTable, prefix: String) -> bool:
	for l: Dictionary in table.lines:
		if String(l.get("id", "")).begins_with(prefix):
			return true
	return false


func _collect_code(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		_collect_code(dir_path.path_join(sub), out)


func _voice_table() -> VoiceLineTable:
	return load(VOICE_LINES_PATH) as VoiceLineTable
