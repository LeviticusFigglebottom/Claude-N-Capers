## B1-07: voice line table integrity and P1 coverage.
extends TestCase

const LINES_PATH: String = "res://content/data/voice/lines.tres"
const MERCER_EVENTS: Array[StringName] = [
	&"heist_start_casing", &"crew_masked", &"pager_started", &"pager_answered", &"pager_last_answer",
	&"pager_limit", &"body_discovered", &"camera_spotted", &"alarm_raised", &"device_started",
	&"device_jammed", &"device_finished", &"assault_anticipation", &"assault_build", &"assault_fade",
	&"assault_control", &"loot_secured", &"escape_available", &"crew_downed", &"crew_custody",
	&"heist_success", &"heist_failed", &"stealth_success",
]
const CREW_EVENTS: Array[StringName] = [
	&"pager_started", &"reloading", &"device_jammed", &"bagging_body", &"going_loud", &"crew_downed",
	&"reviving", &"cops_incoming", &"loot_secured", &"guard_down", &"civilian_killed",
]
const HEISTERS: Array[StringName] = [&"rook", &"sable", &"dutch", &"wren"]

var _table: VoiceLineTable = null
var _strings: Dictionary = {}


func before_all() -> void:
	_table = load(LINES_PATH) as VoiceLineTable
	_strings = StringTable.parse_csv()


func test_table_loads() -> void:
	assert_true(_table != null, "lines.tres loads as VoiceLineTable")
	if _table != null:
		assert_true(_table.lines.size() > 50)


func test_every_line_is_well_formed() -> void:
	if _table == null:
		fail("no table")
		return
	var ids: Dictionary = {}
	for l: Dictionary in _table.lines:
		var id: StringName = l.get("id", &"") as StringName
		assert_true(String(id).begins_with("vo."), "id %s" % id)
		assert_false(ids.has(id), "duplicate id %s" % id)
		ids[id] = true
		var sp: StringName = l.get("speaker", &"") as StringName
		assert_has(VoiceLineTable.SPEAKERS, sp, "speaker of %s" % id)
		assert_true(String(id).begins_with("vo.%s." % sp), "id %s names its speaker" % id)
		assert_has(VoiceLineTable.EVENTS, l.get("event", &"") as StringName, "event of %s" % id)
		assert_eq(l.get("text_key", &""), StringName("voice.%s" % id), "text_key of %s" % id)
		assert_eq(typeof(l.get("cooldown_s")), TYPE_FLOAT, "cooldown_s of %s" % id)
		assert_eq(typeof(l.get("priority")), TYPE_INT, "priority of %s" % id)


func test_every_text_key_exists_in_csv() -> void:
	if _table == null:
		fail("no table")
		return
	for l: Dictionary in _table.lines:
		assert_has(_strings, String(l.get("text_key", "")))


func test_mercer_p1_coverage() -> void:
	if _table == null:
		fail("no table")
		return
	for ev: StringName in MERCER_EVENTS:
		assert_true(_table.lines_for(ev, &"mercer").size() >= 1, "Mercer line for %s" % ev)


func test_crew_barks_have_variants_per_heister() -> void:
	if _table == null:
		fail("no table")
		return
	for who: StringName in HEISTERS:
		for ev: StringName in CREW_EVENTS:
			var n: int = _table.lines_for(ev, who).size()
			assert_true(n >= 2 and n <= 3, "%s has %d variants for %s" % [who, n, ev])


func test_line_lookup() -> void:
	if _table == null:
		fail("no table")
		return
	var l: Dictionary = _table.line(&"vo.mercer.pager_last_answer_1")
	assert_eq(l.get("speaker"), &"mercer")
	assert_eq(_table.line(&"vo.nobody.nothing"), {})
