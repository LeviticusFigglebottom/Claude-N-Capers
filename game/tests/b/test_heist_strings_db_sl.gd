## D-115 strings audit, Dockside Burn (B-DB) and Shadow Ledger (B-SL), LEAD r228: each heist's objective lines in the
## order its mission adds them resolve and read with the data the mission passes (no raw or dropped counter), the
## briefing tells the rolled facts right, the contact / radio lines claim nothing the mission does not do, and the
## payday drops the pager chip on a loud-only heist. Data-only except the payday screen: the missions are read as text.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const MISSION_PATH: String = "res://world/heists/%s/%s_mission.gd"
const HEISTS: Array[StringName] = [&"dockside_burn", &"shadow_ledger"]
## The data each mission's add_objective / update_objective_data passes for the counted steps (pinned from
## dockside_burn_mission.gd `secure` and shadow_ledger_mission.gd `secure` / _on_bag_secured), and the text it must read.
const COUNTED: Array[Dictionary] = [
	{"key": &"objective.dockside_burn.secure", "args": {"bags": 4, "count": 0, "total": 4},
		"text": "Secure four bags of cash or rifles (0/4)"},
	{"key": &"objective.dockside_burn.secure", "args": {"bags": 4, "count": 3, "total": 4},
		"text": "Secure four bags of cash or rifles (3/4)"},
	{"key": &"objective.shadow_ledger.secure", "args": {"laptop": 1, "drives": 2},
		"text": "Secure the laptop and two drive bags"},
	{"key": &"objective.shadow_ledger.secure",
		"args": {"laptop": 1, "drives": 2, "laptop_secured": true, "drives_secured": 1},
		"text": "Secure the laptop and two drive bags (1/2 drives)"},
]
## Claims the audit removed: each must never come back (a fixed rifle-container count, a burn before it happens, the
## Co-op "down" when [cartel] only ends at the police call, a ride before it is called, an escape "the way you came").
const MUST_NOT_SAY: Dictionary = {
	&"dockside_burn": ["Two of those containers", "Only two hold", "Co-op boys are down", "Thermite on the product",
		"Get to the ride when you're done", "the product's burning. That's the job", "Whatever you can't carry",
		"Drill it or blow it", "sits in the strongroom,", "the job fails without it"],
	&"shadow_ledger": ["Leave the way you came", "That gets you past the server room door",
		"make yourselves invisible while it works", "You've seen the offices"],
}
## Words for features the game does not have (D-115 "no unbuilt-feature text").
const UNBUILT: Array[String] = ["coming soon", "not implemented", "not yet", "placeholder", "TODO", "debug"]

var _table: Dictionary = {}


func before_all() -> void:
	_table = StringTable.parse_csv(StringTable.CSV_PATH)


## Every objective the mission adds, in its order, has a clean string; the mission's order is HeistDef.objectives.
func test_mission_objectives_in_order_resolve() -> void:
	var rx: RegEx = RegEx.create_from_string("add_objective\\(&\"(\\w+)\", &\"([\\w.]+)\"")
	for h: StringName in HEISTS:
		var src: String = FileAccess.get_file_as_string(MISSION_PATH % [h, h])
		var ids: Array[StringName] = []
		for m: RegExMatch in rx.search_all(src):
			var key: String = m.get_string(2)
			assert_eq(key, "objective.%s.%s" % [h, m.get_string(1)], "%s: objective key follows the id" % h)
			assert_true(_table.has(key), "%s: %s exists" % [h, key])
			var text: String = ObjectivesPanel.objective_text({"text_key": StringName(key), "args": {}})
			assert_false(text.contains("{") or text.contains("objective."), "%s: %s reads \"%s\"" % [h, key, text])
			ids.append(StringName(m.get_string(1)))
		var def: HeistDef = HeistRegistry.get_def(h)
		assert_eq(ids, def.objectives, "%s: mission adds the HeistDef objectives in order" % h)


func test_counted_objectives_fill_their_args() -> void:
	for c: Dictionary in COUNTED:
		var text: String = ObjectivesPanel.objective_text({"text_key": c["key"], "args": c["args"]})
		assert_eq(text, String(c["text"]), "%s with %s" % [c["key"], c["args"]])


func test_briefings_read_right() -> void:
	var db: Dictionary = BriefingModel.build(&"dockside_burn", Enums.Difficulty.HAZARDOUS)
	var brief: String = String(db["briefing_text"])
	assert_true(brief.contains("strongroom") and brief.contains("count-room"), "DB: the cash is in either place: " + brief)
	assert_true(brief.contains("cash or rifles"), "DB: the four bags are cash or rifles")
	# For ENV A/C: briefing_objectives can name this key (an id with a dot is a key) in place of the rolled strongroom.
	var step: Array[Dictionary] = BriefingModel.objective_lines(&"dockside_burn", [&"ui.briefing.step.dockside_burn.cash"])
	assert_eq(String(step[0]["text"]), "Get the cash: the strongroom door or the count-room cage", "DB: either-cash step")
	var sl: Dictionary = BriefingModel.build(&"shadow_ledger", Enums.Difficulty.HAZARDOUS)
	assert_true(String(sl["briefing_text"]).contains("two drive bags"), "SL: the required loot is named")
	for model: Dictionary in [db, sl]:
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
			if not (key.contains(".%s." % h) or key.contains(".%s_" % h) or key.contains("_%s_" % h) or key.ends_with(".%s" % h) \
					or key.begins_with("item.loot.ledger_") and h == &"shadow_ledger"):
				continue
			n += 1
			var text: String = String(_table[k])
			for bad: String in MUST_NOT_SAY[h] as Array:
				assert_false(text.contains(bad), "%s: %s still says \"%s\"" % [h, key, bad])
			for w: String in UNBUILT:
				assert_false(text.to_lower().contains(w.to_lower()), "%s: %s mentions \"%s\"" % [h, key, w])
		assert_true(n >= 40, "%s: %d strings scanned" % [h, n])


## Payday: a loud-only heist (Dockside Burn: no pagers) shows no pager chip, a stealth one does; SL's fail reason reads.
## (The "Payday: <heist>" header is B-GN's ui.results.title_heist on env/b-content.)
func test_payday_pager_chip_only_with_pagers() -> void:
	assert_false(PaydayScreen.has_pagers(&"dockside_burn"), "DB is LOUD_ONLY: no pagers")
	assert_true(PaydayScreen.has_pagers(&"shadow_ledger"), "SL has pagers")
	assert_true(PaydayScreen.has_pagers(&""), "unknown heist keeps the chip")
	for h: StringName in HEISTS:
		var screen: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
		screen.apply_to_profile = false
		add_child(screen)
		await wait_frames(1)
		var result: Dictionary = HeistCatalog.sample_result()
		result["heist_id"] = h
		screen.show_result(result)
		var chips: Label = screen.find_child("SummaryChips", true, false) as Label
		assert_true(chips != null, "%s: summary chips" % h)
		if chips != null:
			assert_eq(chips.text.contains("Pagers"), h == &"shadow_ledger", "%s: %s" % [h, chips.text])
		screen.queue_free()
		await wait_frames(1)
	assert_eq(UiText.t(PaydayScreen.fail_reason_key(&"stealth_only_alarm")), "The alarm went off on a stealth-only job.")
