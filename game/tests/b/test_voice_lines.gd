## B1-07: voice line table integrity and P1 coverage.
extends TestCase

const LINES_PATH: String = "res://content/data/voice/lines.tres"
## Mercer's generic alarm / assault / loot / escape lines were retired (lead): the contact radio speaks those facts.
const MERCER_EVENTS: Array[StringName] = [
	&"heist_start_casing", &"crew_masked", &"pager_started", &"pager_answered", &"pager_last_answer",
	&"pager_limit", &"body_discovered", &"camera_spotted", &"device_started", &"device_jammed",
	&"device_finished", &"crew_downed", &"crew_custody", &"heist_success", &"heist_failed", &"stealth_success",
]
const CREW_EVENTS: Array[StringName] = [
	&"pager_started", &"reloading", &"device_jammed", &"bagging_body", &"going_loud", &"crew_downed",
	&"reviving", &"cops_incoming", &"loot_secured", &"guard_down", &"civilian_killed",
]
const HEISTERS: Array[StringName] = [&"rook", &"sable", &"dutch", &"wren", &"marten", &"jay", &"juno", &"hale"]

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


## Shadow Ledger mission lines (ENV C shadow_ledger_mission.gd say() ids): Mercer + the contact.
func test_shadow_ledger_mission_lines() -> void:
	if _table == null:
		fail("no table")
		return
	var ids: Array[StringName] = [&"vo.accountant.shadow_ledger_contact_intro"]
	for x: String in ["intro", "laptop_found", "keycard_found", "code_found", "cage_open", "hack_started",
			"hack_interrupted", "hack_done", "lasers", "time_lock_started", "time_lock_open", "last_pager",
			"required_secured", "escape", "abort"]:
		ids.append(StringName("vo.mercer.shadow_ledger_" + x))
	for id: StringName in ids:
		var l: Dictionary = _table.line(id)
		assert_eq(l.get("event"), &"mission", "%s is a mission line" % id)
		assert_eq(int(l.get("priority", 0)), 90, "%s priority" % id)
		assert_has(_strings, "voice." + String(id))
	var ctx: Dictionary = {
		"vo.mercer.shadow_ledger_hack_started": "{seconds}",
		"vo.mercer.shadow_ledger_time_lock_started": "{seconds}",
		"vo.mercer.shadow_ledger_escape": "{escape}",
		"vo.mercer.shadow_ledger_last_pager": "{answered}",
	}
	for id: String in ctx:
		assert_true(String(_strings.get("voice." + id, "")).contains(String(ctx[id])), "%s uses %s" % [id, ctx[id]])


## Every say() id in the heist mission scripts of this tree has a line.
func test_every_mission_say_has_a_line() -> void:
	if _table == null:
		fail("no table")
		return
	var re: RegEx = RegEx.create_from_string("say\\(&\"(vo\\.[a-z_]+\\.[a-z0-9_]+)\"")
	var seen: int = 0
	for heist: String in DirAccess.get_directories_at("res://world/heists"):
		var dir: String = "res://world/heists/%s" % heist
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with("_mission.gd"):
				continue
			var src: String = FileAccess.get_file_as_string("%s/%s" % [dir, f])
			for m: RegExMatch in re.search_all(src):
				seen += 1
				var id: StringName = StringName(m.get_string(1))
				assert_false(_table.line(id).is_empty(), "%s/%s says %s" % [heist, f, id])
	assert_true(seen > 0, "mission scripts found")


## B5-04 Dockside Burn: every VO id in ENV C's G0 doc (D-064, "VO line ids"): Reyes and Mercer
## mission lines (event mission, priority 90) plus the briefing sets. Text in strings.csv (voice.<id>).
func test_dockside_burn_doc_lines() -> void:
	if _table == null:
		fail("no table")
		return
	var mission: Array[StringName] = [
		&"vo.reyes.dockside_burn_contact_intro", &"vo.reyes.dockside_burn_payday", &"vo.mercer.dockside_burn_intro",
	]
	for x: String in ["cartel_awake", "police_called", "breach", "product_found", "thermite_reminder",
			"burn_started", "burn_done", "strongroom_drill", "drill_jam", "strongroom_open", "count_cage", "lift_dead",
			"containers_hint", "weapons_found", "sniper_crane", "sniper_roof", "gangway", "reinforcements",
			"fog_lifts", "required_secured", "van_eta", "boat_eta", "escape"]:
		mission.append(StringName("vo.mercer.dockside_burn_" + x))
	for id: StringName in mission:
		var l: Dictionary = _table.line(id)
		assert_eq(l.get("event"), &"mission", "%s is a mission line" % id)
		assert_eq(int(l.get("priority", 0)), 90, "%s priority" % id)
		assert_has(_strings, "voice." + String(id))
	var briefing: Array[StringName] = [
		&"vo.reyes.briefing_dockside_burn_1", &"vo.reyes.briefing_dockside_burn_2", &"vo.reyes.briefing_dockside_burn_3",
		&"vo.mercer.briefing_dockside_burn_1", &"vo.mercer.briefing_dockside_burn_2",
	]
	for id: StringName in briefing:
		assert_eq(_table.line(id).get("event"), &"briefing", "%s is a briefing line" % id)
	assert_eq(mission.size() + briefing.size(), 31, "the doc's VO id list")
	for id: String in ["vo.mercer.dockside_burn_van_eta", "vo.mercer.dockside_burn_boat_eta"]:
		assert_true(String(_strings.get("voice." + id, "")).contains("{seconds}"), "%s uses {seconds}" % id)
