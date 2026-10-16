## D-117 §6 "every VO line is said": the VO coverage audit (content/voice/tools/vo_coverage.gd; report
## content/docs/vo_coverage.md, regenerate with `godot --headless --path game -s res://content/voice/tools/vo_coverage_cli.gd`).
## Text scans only. (a) code never says an id the VoiceLineTable lacks; (b) every line B's own triggers own
## (briefing, contact radio heist lines) is said; (c) the A / C / B-reserve unsaid lines are explicit allowlists
## that can only shrink: a listed line that becomes said must be removed, and a new unsaid line fails.
extends TestCase

const VoCoverage: GDScript = preload("res://content/voice/tools/vo_coverage.gd")
const HEISTS: Array[StringName] = [
	&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn", &"gallery_night",
]

## ENV A: lines only A code can trigger and does not yet (pd2_fidelity C8 barks). Empty since A's D-117 bark
## director; it stays shrink-only like the others.
const UNSAID_A: Array[StringName] = []  # every A line is said: the D-117 bark director, env/a-core dd20d1f0 (round 226)

## B reserve: a contact's generic radio lines that no current heist reaches (each fact has an always-ready heist
## line, or no heist with that contact has the fact: only Night Deposit fails an objective). Kept on purpose for
## RadioTweak.speaker_overrides and new heists (content/docs/radio.md "Coverage").
const UNSAID_B_RESERVE: Array[StringName] = [
	&"vo.vance.radio_objective_done_1", &"vo.vance.radio_objective_done_2", &"vo.vance.radio_objective_done_3",
	&"vo.vance.radio_objective_failed_1", &"vo.vance.radio_objective_failed_2", &"vo.vance.radio_objective_failed_3",
	&"vo.vance.radio_escape_available_1", &"vo.vance.radio_escape_available_2", &"vo.vance.radio_escape_available_3",
	&"vo.vance.radio_escape_1", &"vo.vance.radio_escape_2", &"vo.vance.radio_escape_3",
	&"vo.reyes.radio_objective_done_1", &"vo.reyes.radio_objective_done_2", &"vo.reyes.radio_objective_done_3",
	&"vo.reyes.radio_objective_new_1", &"vo.reyes.radio_objective_new_2", &"vo.reyes.radio_objective_new_3",
	&"vo.reyes.radio_objective_failed_1", &"vo.reyes.radio_objective_failed_2", &"vo.reyes.radio_objective_failed_3",
	&"vo.reyes.radio_escape_available_1", &"vo.reyes.radio_escape_available_2", &"vo.reyes.radio_escape_available_3",
	&"vo.reyes.radio_escape_1", &"vo.reyes.radio_escape_2", &"vo.reyes.radio_escape_3",
	&"vo.accountant.radio_objective_done_1", &"vo.accountant.radio_objective_done_2", &"vo.accountant.radio_objective_done_3",
	&"vo.accountant.radio_objective_new_1", &"vo.accountant.radio_objective_new_2", &"vo.accountant.radio_objective_new_3",
	&"vo.accountant.radio_escape_available_1", &"vo.accountant.radio_escape_available_2", &"vo.accountant.radio_escape_available_3",
	&"vo.accountant.radio_escape_1", &"vo.accountant.radio_escape_2", &"vo.accountant.radio_escape_3",
	&"vo.mercer.radio_objective_failed_1", &"vo.mercer.radio_objective_failed_2", &"vo.mercer.radio_objective_failed_3",
]

## ENV C: contact radio lines keyed to a HeistDef objective the mission never adds or moves.
##   glasshouse extra_bags / salon / display_cases: HeistDef.briefing_optional (D-117 §4) lists them, but
##     glasshouse_mission.gd never add_objective()s them (doc docs/design/heists/glasshouse.md: more than 2 bags,
##     the G6 salon, the display cases), so radio.objective_done never fires;
##   gallery_night extras / lockers: added (doc §Objectives stealth 9) but never complete()d.
const UNSAID_C: Array[StringName] = [
	&"vo.vance.glasshouse_radio_extra_bags", &"vo.vance.glasshouse_radio_salon",
	&"vo.vance.glasshouse_radio_display_cases", &"vo.vance.gallery_night_radio_extras",
	&"vo.vance.gallery_night_radio_lockers",
]

var _r: Dictionary = {}


func before_all() -> void:
	_r = VoCoverage.call(&"audit")


func test_audit_covers_every_heist() -> void:
	var heists: Array = _r.get("heists", []) as Array
	for h: StringName in HEISTS:
		assert_has(heists, h, "audit iterates %s" % h)
	assert_true((_r.get("lines", []) as Array).size() > 400, "table lines inventoried")


func test_no_missing_ids() -> void:
	for m: Dictionary in _r.get("missing", []) as Array:
		fail("code says %s (%s) but lines.tres has no such line" % [m["id"], m["site"]])


func test_every_line_has_text() -> void:
	for id: String in _r.get("no_text", []) as Array:
		fail("%s has no strings.csv text" % id)


func test_no_voice_strings_without_a_line() -> void:
	for k: String in _r.get("orphan_strings", []) as Array:
		fail("%s has no VoiceLineTable line: nothing can say it" % k)


func test_b_lines_are_said() -> void:
	for row: Dictionary in VoCoverage.call(&"unsaid", _r, "B") as Array:
		fail("B line %s is never said: %s" % [row["id"], row["reason"]])


func test_unsaid_a_allowlist() -> void:
	_check_allowlist("A", UNSAID_A)


func test_unsaid_b_reserve_allowlist() -> void:
	_check_allowlist("R", UNSAID_B_RESERVE)


func test_unsaid_c_allowlist() -> void:
	_check_allowlist("C", UNSAID_C)


func test_heist_mission_lines_are_said() -> void:
	for h: StringName in HEISTS:
		var c: Dictionary = VoCoverage.call(&"counts", _r, h)
		assert_true(int(c["lines"]) > 0, "%s has lines" % h)
		assert_eq(int(c["A"]) + int(c["B"]), 0, "%s: no unsaid A/B lines" % h)


func _check_allowlist(owner: String, allow: Array[StringName]) -> void:
	var actual: Array[StringName] = []
	for row: Dictionary in VoCoverage.call(&"unsaid", _r, owner) as Array:
		actual.append(StringName(row["id"]))
		if not allow.has(StringName(row["id"])):
			fail("new unsaid %s line %s (%s): say it, or list it here" % [owner, row["id"], row["reason"]])
	for id: StringName in allow:
		if not actual.has(id):
			fail("%s is no longer an unsaid %s line: remove it from the allowlist" % [id, owner])
	assert_eq(actual.size(), allow.size(), "unsaid %s count" % owner)
