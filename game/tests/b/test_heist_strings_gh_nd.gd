## D-115 strings audit, Golden Hour (B-GH, id glasshouse) and Nightfall Depository (B-ND, id night_deposit), LEAD
## r229: each heist's objective lines in the order its mission adds them resolve and read with the data the mission
## passes, every mission VO line has text and reads with its real args, the briefing tells what the mission does
## (GH: the slow quiet lockpick, no "back route" order; ND: no doubled loud sentence), the contact / Mercer lines
## claim nothing the mission does not do, and payday names the job. Data-only: the missions are read as text.
extends TestCase

const MISSION_PATH: String = "res://world/heists/%s/%s_mission.gd"
const VOICE_LINES_PATH: String = "res://content/data/voice/lines.tres"
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit"]
## The data each mission passes for the counted steps (glasshouse_mission.gd / night_deposit_mission.gd `secure`
## add_objective and _on_bag_secured), and the text it must read.
const COUNTED: Array[Dictionary] = [
	{"key": &"objective.glasshouse.secure", "args": {"bags": 2, "count": 0, "total": 2},
		"text": "Secure two bags (0/2)"},
	{"key": &"objective.glasshouse.secure", "args": {"bags": 2, "count": 1, "total": 2},
		"text": "Secure two bags (1/2)"},
	{"key": &"objective.night_deposit.secure", "args": {"bags": 4, "count": 0, "total": 4},
		"text": "Secure four bags (0/4)"},
	{"key": &"objective.night_deposit.secure", "args": {"bags": 4, "count": 3, "total": 4},
		"text": "Secure four bags (3/4)"},
]
## VO lines said with args (mission say() data; SubtitleOverlay rounds float args), and the text they must read.
const VO_ARGS: Array[Dictionary] = [
	{"key": &"voice.vo.mercer.glasshouse_van_eta", "args": {"seconds": 240},
		"text": "Van's pulled off. It's back in 240 seconds at the earliest, once the first wave breaks. Hold what you've got."},
	{"key": &"voice.vo.mercer.glasshouse_last_pager", "args": {"answered": 4},
		"text": "That's 4. That's the last one they'll buy."},
	{"key": &"voice.vo.mercer.night_deposit_escape_eta", "args": {"seconds": 360},
		"text": "Your ride's pulled off. It's back in 360 seconds at the earliest, once the second wave breaks. Hold."},
	{"key": &"voice.vo.mercer.night_deposit_last_pager", "args": {"answered": 3},
		"text": "That's 3 on the pagers. No more of those."},
	{"key": &"voice.vo.mercer.night_deposit_time_lock_started", "args": {"seconds": 90},
		"text": "Time lock's counting: 90 seconds. Keep the basement quiet."},
]
## Claims the audit removed; each must never come back. GH: the drill as the only way past a missing card or code (the
## safe takes a slow silent lockpick, PO6-04), "take the back route" (three routes), a drill order when the safe may be
## open, a van "N seconds out" (it waits for the first FADE too), "at the curb" (E1 is the alley), salon "coats" (it is
## two cases). ND: the doubled "If it goes loud", "the fourth pager" (the cap is data), "the code works" (said when it is
## found), "night drop is cleared" (said when its safe opens), the gate step claiming the lasers it completes before.
const MUST_NOT_SAY: Dictionary = {
	&"glasshouse": ["the safe needs the drill", "take the back route", "Put the drill on it", "seconds out",
		"at the curb", "in their coats", "Search the salon", "Secure the bags"],
	&"night_deposit": ["If it goes loud, the vault", "fourth pager", "The code works", "night drop is cleared",
		"vault gate and the lasers", "seconds out", "Secure the bags"],
}
## Words for features neither map builds (D-115 "no unbuilt-feature text").
const UNBUILT: Array[String] = ["coming soon", "not implemented", "placeholder", "todo", "debug", "zipline",
	"helicopter", "disguise", "bribe", "thermite", "c4"]

var _table: Dictionary = {}
var _voice: VoiceLineTable


func before_all() -> void:
	_table = StringTable.parse_csv(StringTable.CSV_PATH)
	_voice = load(VOICE_LINES_PATH) as VoiceLineTable


func _src(h: StringName) -> String:
	return FileAccess.get_file_as_string(MISSION_PATH % [h, h])


## The objective ids the mission adds, in source order, each once (GH adds keycard / code in both branches).
func _mission_ids(h: StringName) -> Array[StringName]:
	var rx: RegEx = RegEx.create_from_string("add_objective\\(&\"(\\w+)\", &\"([\\w.]+)\"")
	var ids: Array[StringName] = []
	for m: RegExMatch in rx.search_all(_src(h)):
		assert_eq(m.get_string(2), "objective.%s.%s" % [h, m.get_string(1)], "%s: objective key follows the id" % h)
		if not ids.has(StringName(m.get_string(1))):
			ids.append(StringName(m.get_string(1)))
	return ids


func test_mission_objectives_in_order_resolve() -> void:
	for h: StringName in HEISTS:
		var ids: Array[StringName] = _mission_ids(h)
		var def: HeistDef = HeistRegistry.get_def(h)
		for id: StringName in ids:
			var key: String = "objective.%s.%s" % [h, id]
			assert_true(_table.has(key) and String(_table[key]).strip_edges() != "", "%s has text" % key)
			var text: String = ObjectivesPanel.objective_text({"text_key": StringName(key), "args": {}})
			assert_false(text.contains("{") or text.contains("objective."), "%s reads \"%s\"" % [key, text])
			assert_true(def.objectives.has(id) or def.briefing_optional.has(id), "%s: %s is in the def" % [h, id])
		for id: StringName in def.objectives:
			assert_true(ids.has(id), "%s: the mission adds the def's %s" % [h, id])
	# GH: the mission's required steps are the def's list in its order, then the D-117 extras.
	var gh: HeistDef = HeistRegistry.get_def(&"glasshouse")
	var gh_ids: Array[StringName] = _mission_ids(&"glasshouse")
	assert_eq(gh_ids.slice(0, gh.objectives.size()), gh.objectives, "GH: mission order = HeistDef.objectives")
	assert_eq(gh_ids.slice(gh.objectives.size()), gh.briefing_optional, "GH: then the optional extras")


func test_counted_objectives_fill_their_args() -> void:
	for c: Dictionary in COUNTED:
		var text: String = ObjectivesPanel.objective_text({"text_key": c["key"], "args": c["args"]})
		assert_eq(text, String(c["text"]), "%s with %s" % [c["key"], c["args"]])


func test_every_mission_vo_line_has_text_and_reads_with_its_args() -> void:
	for h: StringName in HEISTS:
		var rx: RegEx = RegEx.create_from_string("&\"(vo\\.[a-z]+\\.%s_[a-z0-9_]+)\"" % h)
		var n: int = 0
		for m: RegExMatch in rx.search_all(_src(h)):
			n += 1
			var id: String = m.get_string(1)
			assert_false(_voice.line(StringName(id)).is_empty(), "lines.tres has %s" % id)
			var text: String = String(_table.get("voice." + id, ""))
			assert_true(text.strip_edges() != "", "voice.%s has text" % id)
		assert_true(n >= 9, "%s: %d mission VO ids" % [h, n])
	for v: Dictionary in VO_ARGS:
		assert_eq(UiText.t(v["key"], v["args"]), String(v["text"]), "%s with %s" % [v["key"], v["args"]])


func test_briefings_read_right() -> void:
	var gh: Dictionary = BriefingModel.build(&"glasshouse", Enums.Difficulty.ROUTINE)
	var gh_text: String = String(gh["briefing_text"])
	assert_true(gh_text.contains("lockpick") and gh_text.contains("drill"), "GH: lockpick or drill: " + gh_text)
	assert_true(gh_text.contains("two bags"), "GH: the required bags are named")
	var nd: Dictionary = BriefingModel.build(&"night_deposit", Enums.Difficulty.ROUTINE)
	var nd_text: String = String(nd["briefing_text"])
	assert_false(nd_text.to_lower().contains("if it goes loud"), "ND: the loud line says it once: " + nd_text)
	assert_true(nd_text.contains("four bags") and nd_text.contains("time lock"), "ND: names the bags and the lock")
	for model: Dictionary in [gh, nd]:
		assert_true(String(model["loud_text"]) != "", "%s: loud line" % model["heist_id"])
		for list: String in ["objectives", "optional"]:
			for o: Dictionary in model[list] as Array:
				var t: String = String(o["text"])
				assert_false(t == "" or t.contains("{") or t.contains("("), "%s %s: \"%s\"" % [model["heist_id"], list, t])
		for l: Dictionary in model["loot"] as Array:
			assert_false(String(l["text"]).begins_with("item."), "%s: loot %s has a name" % [model["heist_id"], l["loot_id"]])
			assert_true(int(l.get("value", 0)) > 0 or bool(l.get("small", false)), "%s: %s shows a value" % [model["heist_id"], l["loot_id"]])


func test_no_removed_claims_or_unbuilt_words() -> void:
	for h: StringName in HEISTS:
		var n: int = 0
		for k: Variant in _table:
			var key: String = String(k)
			if not key.contains(String(h)) or key.begins_with("ui.preplan.bp."):
				continue
			n += 1
			var text: String = String(_table[k])
			for bad: String in MUST_NOT_SAY[h] as Array:
				assert_false(text.contains(bad), "%s: %s still says \"%s\"" % [h, key, bad])
			var low: String = text.to_lower()
			for w: String in UNBUILT:
				assert_true(RegEx.create_from_string("\\b%s\\b" % w).search(low) == null, "%s: %s mentions \"%s\"" % [h, key, w])
		assert_true(n >= 40, "%s: %d strings scanned" % [h, n])


func test_first_time_card_rows_resolve() -> void:
	for h: StringName in HEISTS:
		var tip: StringName = OnboardingTips.heist_tip(h)
		assert_eq(tip, StringName("heist_%s" % h), "%s has a first-time card" % h)
		var rows: Array = OnboardingCard.ROWS.get(tip, []) as Array
		assert_true(rows.size() >= 3, "%s: card rows" % h)
		for r: Array in rows:
			assert_true(UiText.has(r[1]), "%s: %s has text" % [h, r[1]])
		assert_true(UiText.has(StringName("ui.tip.%s.title" % tip)), "%s: card title" % h)
	assert_true(UiText.t(&"ui.tip.heist_glasshouse.1").contains("lockpick"), "GH card: the quiet lockpick fallback")


func test_payday_names_the_job() -> void:
	assert_eq(PaydayScreen.title_text(&"glasshouse"), "Payday: Golden Hour")
	assert_eq(PaydayScreen.title_text(&"night_deposit"), "Payday: Nightfall Depository")
	for h: StringName in HEISTS:
		assert_true(PaydayScreen.has_pagers(h), "%s has pagers: the chip stays" % h)
	assert_eq(UiText.t(PaydayScreen.fail_reason_key(&"all_custody")), "The whole crew ended up in custody.")
