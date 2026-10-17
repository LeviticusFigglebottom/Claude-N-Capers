## D-115 strings audit of Gallery Night (LEAD r228, B-GN) against docs/design/heists/gallery_night.md. Pins:
## every objective the mission adds, in its order, resolves to a clean string whose {args} the mission fills;
## every mission VO line has text; no GN text names a feature the map does not have (wall plaques, ...);
## the loud briefing offers the hack OR the drill; [secure] names what it counts; payday names the job; the
## briefing list follows D-117 §5; the loot lines keep D-075's order. Data-only: the mission is read as text.
extends TestCase

const HEIST: StringName = &"gallery_night"
const MISSION_PATH: String = "res://world/heists/gallery_night/gallery_night_mission.gd"
const DEF_PATH: String = "res://world/heists/gallery_night/gallery_night_def.tres"
const VOICE_LINES_PATH: String = "res://content/data/voice/lines.tres"
## Format-string VO ids the mission builds, with every value it can pass (canvas tags; escape kind).
const VO_FORMATS: Dictionary = {
	"vo.mercer.gallery_night_canvas_found_%s": ["lantern", "orchard", "widow", "saint"],
	"vo.mercer.gallery_night_%s_eta": ["van", "limo"],
}
## Words for things Gallery Night does not build (the audit found "read the plaques": the map has no plaques).
const UNBUILT: Array[String] = ["plaque", "bribe", "disguise", "zipline", "helicopter", "thermite", "c4"]

var _table: Dictionary = {}
var _voice: VoiceLineTable
var _src: String = ""


func before_all() -> void:
	_table = StringTable.parse_csv(StringTable.CSV_PATH)
	_voice = load(VOICE_LINES_PATH) as VoiceLineTable
	_src = FileAccess.get_file_as_string(MISSION_PATH)


## [{id, args: [arg names the mission passes]}] for each `_add(&"id", ...)` in source order.
func _mission_adds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rx: RegEx = RegEx.create_from_string("^\\s*_add\\(&\"([a-z_]+)\"(.*)$")
	var key_rx: RegEx = RegEx.create_from_string("\"([a-z_]+)\"\\s*:")
	for line: String in _src.split("\n"):
		var m: RegExMatch = rx.search(line)
		if m == null:
			continue
		var args: Array[String] = []
		for k: RegExMatch in key_rx.search_all(m.get_string(2)):
			args.append(k.get_string(1))
		out.append({"id": m.get_string(1), "args": args})
	return out


func test_mission_objectives_in_order_resolve_and_fill() -> void:
	var adds: Array[Dictionary] = _mission_adds()
	var def: HeistDef = load(DEF_PATH) as HeistDef
	var ids: Array[StringName] = []
	for a: Dictionary in adds:
		ids.append(StringName(a["id"]))
	assert_eq(ids, def.objectives, "the mission adds the HeistDef's objectives in the def's order")
	var arg_rx: RegEx = RegEx.create_from_string("\\{([a-z_]+)\\}")
	for a: Dictionary in adds:
		var key: String = "objective.%s.%s" % [HEIST, a["id"]]
		assert_true(_table.has(key) and String(_table[key]).strip_edges() != "", "%s has text" % key)
		var text: String = String(_table.get(key, ""))
		for m: RegExMatch in arg_rx.search_all(text):
			assert_true((a["args"] as Array).has(m.get_string(1)),
					"%s: {%s} is filled by the mission's _add data %s" % [key, m.get_string(1), a["args"]])
	# The two counters read as the mission starts them.
	var find: String = ObjectivesPanel.objective_text({"text_key": &"objective.gallery_night.find_canvases",
			"args": {"found": 0, "total": 4}})
	assert_eq(find, "Find the listed canvases (0/4)", "find_canvases at start")
	var secure: String = ObjectivesPanel.objective_text({"text_key": &"objective.gallery_night.secure",
			"args": {"count": 1, "total": 2}})
	assert_eq(secure, "Secure The Lantern Bearer and one more (1/2)", "[secure] names what it counts (D-075)")


func test_relabels_the_mission_uses_exist() -> void:
	for k: String in ["objective.gallery_night.casing_last_call", "objective.gallery_night.hack_loud"]:
		assert_true(_src.contains("&\"%s\"" % k) or _src.contains("\"%s\"" % k), "mission still uses %s" % k)
		assert_true(_table.has(k) and not String(_table[k]).contains("{"), "%s has plain text" % k)


func test_every_mission_vo_line_has_text() -> void:
	var ids: Dictionary = {}
	var rx: RegEx = RegEx.create_from_string("&\"(vo\\.[a-z]+\\.gallery_night_[a-z_]+)\"")
	for m: RegExMatch in rx.search_all(_src):
		ids[m.get_string(1)] = true
	for fmt: String in VO_FORMATS:
		assert_true(_src.contains(fmt), "mission builds %s" % fmt)
		for v: String in VO_FORMATS[fmt]:
			ids[fmt % v] = true
	assert_true(ids.size() >= 34, "%d mission VO ids" % ids.size())
	for id: String in ids:
		assert_false(_voice.line(StringName(id)).is_empty(), "lines.tres has %s" % id)
		var k: String = "voice." + id
		assert_true(_table.has(k) and String(_table[k]).strip_edges() != "", "%s has text" % k)


func test_no_unbuilt_features_in_gn_text() -> void:
	var n: int = 0
	for k: Variant in _table:
		var key: String = String(k)
		if not key.contains("gallery_night"):
			continue
		n += 1
		var low: String = String(_table[k]).to_lower()
		for w: String in UNBUILT:
			assert_true(RegEx.create_from_string("\\b%s" % w).search(low) == null, "%s mentions \"%s\"" % [key, w])
	assert_true(n >= 150, "%d GN strings scanned" % n)


func test_briefing_text_and_list() -> void:
	var loud: String = String(_table.get("heist.gallery_night.briefing_loud", ""))
	assert_true(loud.contains(", or drill"), "loud briefing: hack OR drill (doc §Objectives Loud 2): %s" % loud)
	assert_false(loud.to_lower().begins_with("if it goes loud"), "ui.briefing.if_loud already says it")
	var b: Dictionary = BriefingModel.build(HEIST, Enums.Difficulty.ROUTINE)
	var rows: Array = b["objectives"] as Array
	# D-117 §5 from the def itself (its list moves with C's generator; LEAD-approved list: casing, find_canvases,
	# the access and cut steps, secure, escape): up to 6 rows, the final step always shown with its own number.
	var def: HeistDef = load(DEF_PATH) as HeistDef
	var n: int = def.briefing_objectives.size()
	assert_eq(rows.size(), mini(n, 6), "D-117 §5: at most 5 lead steps + the final one")
	assert_eq(int(b["objectives_more"]), maxi(n - 6, 0), "+N more steps on the night only when steps are cut")
	assert_eq(StringName((rows[rows.size() - 1] as Dictionary)["id"]), def.briefing_objectives[n - 1],
			"the final step is the def's last")
	assert_eq(int((rows[rows.size() - 1] as Dictionary)["index"]), n, "the final step keeps its number")
	if n <= 6:
		var shown: Array[StringName] = []
		for r: Dictionary in rows:
			shown.append(StringName(r["id"]))
		assert_true(shown.has(&"secure"), "the win step (secure) is on the briefing: %s" % [shown])
	# LEAD ruling on the second audit: the def lists [casing, find_canvases, access step, cut step, secure, escape].
	var steps: Array[Dictionary] = BriefingModel.objective_lines(HEIST, [&"ui.briefing.step.gallery_night.access",
			&"ui.briefing.step.gallery_night.cut"])
	assert_eq(String(steps[0]["text"]), "As needed: a keycard, the Argus code and the frame-sensor hack", "GN access")
	assert_eq(String(steps[1]["text"]), "Cut The Lantern Bearer and one more listed canvas", "GN cut step (D-075)")
	for r: Dictionary in rows + (b["optional"] as Array):
		assert_false(String(r["text"]).contains("{"), "briefing row has no raw args: %s" % r["text"])
	assert_eq(String(b["loud_text"]), loud, "the loud line shows")
	assert_true(String(b["briefing_text"]).contains("Lantern Bearer"), "briefing names the centrepiece")


func test_loot_lines_keep_the_list_order() -> void:
	var def: HeistDef = load(DEF_PATH) as HeistDef
	var lines: Array[Dictionary] = BriefingModel.loot_lines(Array(def.loot), Enums.Difficulty.ROUTINE)
	assert_eq(lines.size(), 5, "five GN loot lines")
	var names: Array[String] = []
	for i: int in range(lines.size()):
		names.append(String(lines[i]["text"]))
		if i > 0:
			assert_true(int(lines[i]["value"]) < int(lines[i - 1]["value"]), "D-075 order: %s < previous" % names[i])
	assert_eq(names, ["The Lantern Bearer", "The Salt Orchard", "Widow in Blue", "The Tidewater Saint",
			"A Study"], "loot names")


func test_payday_names_the_job() -> void:
	assert_eq(PaydayScreen.title_text(HEIST), "Payday: Gallery Night", "GN payday header")
	assert_eq(PaydayScreen.title_text(&""), "Payday", "no heist id")
	assert_eq(PaydayScreen.title_text(&"no_such_heist"), "Payday", "unknown heist")
	assert_eq(String(UiText.t(PaydayScreen.fail_reason_key(&"all_custody"))), "The whole crew ended up in custody.",
			"GN fails only by custody or abort (B3)")
