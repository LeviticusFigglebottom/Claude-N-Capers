## Afterhours B content (LEAD r299 go, items 1-7; docs/design/heists/afterhours.md): the map-independent data B
## writes before C's def and map and A's mission: pre-planning point labels, briefing steps and surprises, voice
## lines (Accountant, Mercer, the new `dj` speaker), the first-time card and the D-148 XP row. Staged: nothing here
## puts Afterhours on the Board (heist_list keeps it hidden until the un-hide).
extends TestCase

const HEIST: StringName = &"afterhours"
## The doc's Pre-planning table, in order.
const POINTS: Array[StringName] = [
	&"pp_spawn_foyer", &"pp_spawn_vip", &"pp_spawn_alley", &"pp_gear_wc", &"pp_gear_cloak", &"pp_gear_booth",
	&"pp_gear_van", &"pp_insider_keycard", &"pp_back_door", &"pp_count_window", &"pp_drop_alley", &"pp_drop_roof",
	&"pp_drop_tolley", &"pp_escape_alley", &"pp_escape_tolley",
]
## The doc's bad rare events (BriefingIntel names surprises only; count_left_open / extra_product are good).
const SURPRISES: Array[StringName] = [&"vip_party", &"off_duty_cop", &"co_op_pickup", &"rooftop_watch"]
## The doc's Audio/lighting VO ids (vo.mercer.afterhours_gear_location is one line per gear_drop slot, so the
## mission names the place without a text argument).
const VO_IDS: Array[StringName] = [
	&"vo.accountant.briefing_afterhours_1", &"vo.accountant.briefing_afterhours_2",
	&"vo.accountant.briefing_afterhours_3", &"vo.accountant.afterhours_contact_intro",
	&"vo.accountant.afterhours_payday", &"vo.mercer.briefing_afterhours_1", &"vo.mercer.briefing_afterhours_2",
	&"vo.mercer.afterhours_intro", &"vo.mercer.afterhours_gear_wc", &"vo.mercer.afterhours_gear_cloak",
	&"vo.mercer.afterhours_gear_booth", &"vo.mercer.afterhours_gear_van", &"vo.mercer.afterhours_gear_picked",
	&"vo.mercer.afterhours_keycard_found", &"vo.mercer.afterhours_office_open", &"vo.mercer.afterhours_code_found",
	&"vo.mercer.afterhours_safe_open", &"vo.mercer.afterhours_drill_started", &"vo.mercer.afterhours_drill_jam",
	&"vo.mercer.afterhours_drill_done", &"vo.mercer.afterhours_product_found", &"vo.mercer.afterhours_count_room",
	&"vo.mercer.afterhours_last_pager", &"vo.mercer.afterhours_lasers", &"vo.mercer.afterhours_music_cut",
	&"vo.mercer.afterhours_crowd_out", &"vo.mercer.afterhours_required_secured", &"vo.mercer.afterhours_van_eta",
	&"vo.mercer.afterhours_escape", &"vo.mercer.afterhours_couriers", &"vo.mercer.afterhours_off_duty_cop",
	&"vo.dj.afterhours_alarm", &"vo.dj.afterhours_shoutout_1", &"vo.dj.afterhours_shoutout_2",
	&"vo.dj.afterhours_shoutout_3",
]

var _strings: Dictionary = {}


func before_all() -> void:
	_strings = StringTable.parse_csv()


func test_preplan_points_and_briefing_strings() -> void:
	for p: StringName in POINTS:
		assert_has(_strings, "ui.preplan.point.afterhours.%s" % p)
	for e: StringName in SURPRISES:
		assert_has(_strings, BriefingIntel.EVENT_KEY_FMT % [HEIST, e])
	for s: String in ["safe", "bonus"]:
		assert_has(_strings, "ui.briefing.step.afterhours.%s" % s)
	var briefing: String = String(_strings.get("heist.afterhours.briefing", ""))
	assert_true(briefing.contains("Marlin Avenue") and briefing.contains("three bags"), briefing)


func test_voice_lines_and_dj_speaker() -> void:
	var table: VoiceLineTable = load("res://content/data/voice/lines.tres") as VoiceLineTable
	for id: StringName in VO_IDS:
		var l: Dictionary = table.line(id)
		assert_false(l.is_empty(), "%s in lines.tres" % id)
		assert_has(_strings, String(l.get("text_key", "")), "%s has text" % id)
	assert_has(VoiceLineTable.SPEAKERS, &"dj")
	assert_false(VoiceLineTable.HEISTERS.has(&"dj"), "crew lines never stand in for the DJ")
	var overlay: SubtitleOverlay = SubtitleOverlay.new()
	assert_eq(overlay.speaker_style(&"dj")[0], "DJ", "subtitle name")
	assert_eq(overlay.speaker_style(&"guard")[0], "Guard", "no name key: the capitalised id")
	overlay.free()
	var radio: int = 0
	for l: Dictionary in table.lines:
		if StringName(l.get("heist", &"")) == HEIST and String(l.get("event", "")).begins_with("radio."):
			radio += 1
			assert_eq(l.get("speaker"), &"accountant", "the contact's radio: %s" % l["id"])
	assert_eq(radio, 8, "Accountant radio lines")


func test_card_and_xp_row() -> void:
	assert_has(OnboardingTips.HEISTS, HEIST)
	var rows: Array = OnboardingCard.ROWS.get(OnboardingTips.heist_tip(HEIST), []) as Array
	assert_eq(rows.size(), 4, "four card rows")
	for r: Array in rows:
		assert_has(_strings, String(r[1]))
	assert_has(_strings, "ui.tip.heist_afterhours.title")
	var pay: PayoutTweak = load("res://content/data/tweak/payout.tres") as PayoutTweak
	assert_eq(int(pay.base_xp_by_heist.get(HEIST, 0)), 2500, "D-148 M heist")
