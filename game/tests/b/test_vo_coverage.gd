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

## ENV A: nothing maps these facts to their lines yet (no bark director; VoiceLineTable.lines_for has no A caller).
## Mercer's event barks (casing start, mask-up, pager, cameras, devices, custody, results) and the per-heister
## crew barks (pager_started, device_jammed, crew_downed, reloading, bagging_body, going_loud, reviving,
## cops_incoming, loot_secured, guard_down, civilian_killed). pd2_fidelity C8.
const UNSAID_A: Array[StringName] = [
	&"vo.mercer.heist_start_casing_1", &"vo.mercer.heist_start_casing_2", &"vo.mercer.crew_masked_1",
	&"vo.mercer.crew_masked_2", &"vo.mercer.pager_started_1", &"vo.mercer.pager_started_2",
	&"vo.mercer.pager_answered_1", &"vo.mercer.pager_answered_2", &"vo.mercer.pager_last_answer_1",
	&"vo.mercer.pager_last_answer_2", &"vo.mercer.pager_limit_1", &"vo.mercer.pager_limit_2",
	&"vo.mercer.pager_failed_1", &"vo.mercer.pager_failed_2", &"vo.mercer.body_discovered_1",
	&"vo.mercer.body_discovered_2", &"vo.mercer.camera_spotted_1", &"vo.mercer.camera_spotted_2",
	&"vo.mercer.device_started_1", &"vo.mercer.device_started_2", &"vo.mercer.device_jammed_1",
	&"vo.mercer.device_jammed_2", &"vo.mercer.device_finished_1", &"vo.mercer.device_finished_2",
	&"vo.mercer.crew_downed_1", &"vo.mercer.crew_downed_2", &"vo.mercer.crew_custody_1",
	&"vo.mercer.crew_custody_2", &"vo.mercer.heist_success_1", &"vo.mercer.heist_success_2",
	&"vo.mercer.heist_failed_1", &"vo.mercer.heist_failed_2", &"vo.mercer.stealth_success_1",
	&"vo.mercer.stealth_success_2", &"vo.rook.pager_started_1", &"vo.rook.pager_started_2",
	&"vo.rook.reloading_1", &"vo.rook.reloading_2", &"vo.rook.device_jammed_1",
	&"vo.rook.device_jammed_2", &"vo.rook.bagging_body_1", &"vo.rook.bagging_body_2",
	&"vo.rook.going_loud_1", &"vo.rook.going_loud_2", &"vo.rook.crew_downed_1",
	&"vo.rook.crew_downed_2", &"vo.rook.reviving_1", &"vo.rook.reviving_2",
	&"vo.rook.cops_incoming_1", &"vo.rook.cops_incoming_2", &"vo.rook.loot_secured_1",
	&"vo.rook.loot_secured_2", &"vo.rook.guard_down_1", &"vo.rook.guard_down_2",
	&"vo.rook.civilian_killed_1", &"vo.rook.civilian_killed_2", &"vo.sable.pager_started_1",
	&"vo.sable.pager_started_2", &"vo.sable.reloading_1", &"vo.sable.reloading_2",
	&"vo.sable.device_jammed_1", &"vo.sable.device_jammed_2", &"vo.sable.bagging_body_1",
	&"vo.sable.bagging_body_2", &"vo.sable.going_loud_1", &"vo.sable.going_loud_2",
	&"vo.sable.crew_downed_1", &"vo.sable.crew_downed_2", &"vo.sable.reviving_1",
	&"vo.sable.reviving_2", &"vo.sable.cops_incoming_1", &"vo.sable.cops_incoming_2",
	&"vo.sable.loot_secured_1", &"vo.sable.loot_secured_2", &"vo.sable.guard_down_1",
	&"vo.sable.guard_down_2", &"vo.sable.civilian_killed_1", &"vo.sable.civilian_killed_2",
	&"vo.dutch.pager_started_1", &"vo.dutch.pager_started_2", &"vo.dutch.reloading_1",
	&"vo.dutch.reloading_2", &"vo.dutch.device_jammed_1", &"vo.dutch.device_jammed_2",
	&"vo.dutch.bagging_body_1", &"vo.dutch.bagging_body_2", &"vo.dutch.going_loud_1",
	&"vo.dutch.going_loud_2", &"vo.dutch.crew_downed_1", &"vo.dutch.crew_downed_2",
	&"vo.dutch.reviving_1", &"vo.dutch.reviving_2", &"vo.dutch.cops_incoming_1",
	&"vo.dutch.cops_incoming_2", &"vo.dutch.loot_secured_1", &"vo.dutch.loot_secured_2",
	&"vo.dutch.guard_down_1", &"vo.dutch.guard_down_2", &"vo.dutch.civilian_killed_1",
	&"vo.dutch.civilian_killed_2", &"vo.wren.pager_started_1", &"vo.wren.pager_started_2",
	&"vo.wren.reloading_1", &"vo.wren.reloading_2", &"vo.wren.device_jammed_1",
	&"vo.wren.device_jammed_2", &"vo.wren.bagging_body_1", &"vo.wren.bagging_body_2",
	&"vo.wren.going_loud_1", &"vo.wren.going_loud_2", &"vo.wren.crew_downed_1",
	&"vo.wren.crew_downed_2", &"vo.wren.reviving_1", &"vo.wren.reviving_2",
	&"vo.wren.cops_incoming_1", &"vo.wren.cops_incoming_2", &"vo.wren.loot_secured_1",
	&"vo.wren.loot_secured_2", &"vo.wren.guard_down_1", &"vo.wren.guard_down_2",
	&"vo.wren.civilian_killed_1", &"vo.wren.civilian_killed_2", &"vo.marten.pager_started_1",
	&"vo.marten.pager_started_2", &"vo.marten.reloading_1", &"vo.marten.reloading_2",
	&"vo.marten.device_jammed_1", &"vo.marten.device_jammed_2", &"vo.marten.bagging_body_1",
	&"vo.marten.bagging_body_2", &"vo.marten.going_loud_1", &"vo.marten.going_loud_2",
	&"vo.marten.crew_downed_1", &"vo.marten.crew_downed_2", &"vo.marten.reviving_1",
	&"vo.marten.reviving_2", &"vo.marten.cops_incoming_1", &"vo.marten.cops_incoming_2",
	&"vo.marten.loot_secured_1", &"vo.marten.loot_secured_2", &"vo.marten.guard_down_1",
	&"vo.marten.guard_down_2", &"vo.marten.civilian_killed_1", &"vo.marten.civilian_killed_2",
	&"vo.jay.pager_started_1", &"vo.jay.pager_started_2", &"vo.jay.reloading_1",
	&"vo.jay.reloading_2", &"vo.jay.device_jammed_1", &"vo.jay.device_jammed_2",
	&"vo.jay.bagging_body_1", &"vo.jay.bagging_body_2", &"vo.jay.going_loud_1",
	&"vo.jay.going_loud_2", &"vo.jay.crew_downed_1", &"vo.jay.crew_downed_2",
	&"vo.jay.reviving_1", &"vo.jay.reviving_2", &"vo.jay.cops_incoming_1",
	&"vo.jay.cops_incoming_2", &"vo.jay.loot_secured_1", &"vo.jay.loot_secured_2",
	&"vo.jay.guard_down_1", &"vo.jay.guard_down_2", &"vo.jay.civilian_killed_1",
	&"vo.jay.civilian_killed_2",
]

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
