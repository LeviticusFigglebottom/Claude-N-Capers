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

## ENV C: radio lines keyed to objectives the mission never adds or completes. Empty since C 762934d5 (GH
## extra_bags / salon / display_cases, GN lockers / extras); shrink-only like the others.
const UNSAID_C: Array[StringName] = []  # every C line is said (C 762934d5, round 226)

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
	var allow: Array[StringName] = UNSAID_B_RESERVE.duplicate()
	if _generic_abort_retired():
		allow.append(VoCoverage.GENERIC_ABORT)  # SL-6: no STEALTH_ONLY heist plays the generic abort any more
	_check_allowlist("R", allow)


## LEAD r228 (SL-6): a STEALTH_ONLY mission with `own_abort_line = true` covers its alarm with its own line, and the
## generic vo.mercer.abort is not counted for it. Shadow Ledger's own line is vo.mercer.shadow_ledger_abort.
func test_stealth_only_abort_coverage() -> void:
	var aborts: Dictionary = _r.get("aborts", {}) as Dictionary
	assert_false(aborts.has(&"dockside_burn"), "a LOUD_ONLY heist has no abort line")
	assert_true(aborts.has(&"shadow_ledger"), "SL is STEALTH_ONLY: %s" % aborts)
	var sl_def: HeistDef = HeistRegistry.get_def(&"shadow_ledger")
	var mission: String = "res://world/heists/shadow_ledger/shadow_ledger_mission.gd"
	var src: String = FileAccess.get_file_as_string(mission)
	assert_true(src.contains("say(&\"vo.mercer.shadow_ledger_abort\")"), "SL's _on_alarm says its own abort line")
	if src.contains("own_abort_line = true"):
		assert_eq(aborts[&"shadow_ledger"], &"vo.mercer.shadow_ledger_abort", "SL abort coverage is its own line")
	# The rule itself, on a fixture: with the flag the mission's line, without it the generic one.
	var fixture: String = "user://vo_cov_abort_fixture.gd"
	for own: bool in [true, false]:
		var f: FileAccess = FileAccess.open(fixture, FileAccess.WRITE)
		var src_fx: String = "extends HeistMission\n\n\nfunc _on_mission_start() -> void:\n%s"
		src_fx += "\tsay(&\"vo.mercer.shadow_ledger_intro\")\n\n\nfunc _on_alarm(_reason: StringName) -> void:\n"
		src_fx += "\tsay(&\"vo.mercer.shadow_ledger_abort\")\n"
		f.store_string(src_fx % ("\town_abort_line = true\n" if own else ""))
		f.close()
		assert_eq(VoCoverage.call(&"abort_line", sl_def, fixture),
				&"vo.mercer.shadow_ledger_abort" if own else VoCoverage.GENERIC_ABORT, "own_abort_line %s" % own)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	var generic: Dictionary = {}
	for row: Dictionary in _r["lines"] as Array:
		if row["id"] == VoCoverage.GENERIC_ABORT:
			generic = row
	assert_false(generic.is_empty(), "the generic abort line is inventoried")
	var users: Array = aborts.values().filter(func(v: Variant) -> bool: return v == VoCoverage.GENERIC_ABORT)
	assert_eq((generic["sites"] as Array).is_empty(), users.is_empty(),
			"the generic abort counts as said only while a STEALTH_ONLY heist uses it: %s" % aborts)


func _generic_abort_retired() -> bool:
	for v: Variant in (_r.get("aborts", {}) as Dictionary).values():
		if v == VoCoverage.GENERIC_ABORT:
			return false
	return true


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
