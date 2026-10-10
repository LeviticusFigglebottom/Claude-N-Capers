## B1-07: strings.csv parses cleanly, required keys exist, StringTable formatting and missing keys.
extends TestCase

const REQUIRED_KEYS: Array[String] = [
	"ui.prompt.answer_pager", "ui.prompt.bag_body", "ui.prompt.tie_civilian", "ui.prompt.pick_lock",
	"ui.prompt.use_keycard", "ui.prompt.place_drill", "ui.prompt.fix_drill", "ui.prompt.take_loot",
	"ui.prompt.secure_bag", "ui.prompt.break_case", "ui.prompt.revive", "ui.prompt.mask_up",
	"ui.prompt.open_door", "ui.prompt.interact", "ui.prompt.blocked.casing",
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
	assert_eq(_table.get("ui.prompt.blocked.casing", ""), "Suspicious actions not allowed")


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
