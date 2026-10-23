## D-117 §6 "every VO line is said": the VO coverage audit (content/voice/tools/vo_coverage.gd; report
## content/docs/vo_coverage.md, regenerate with `godot --headless --path game -s res://content/voice/tools/vo_coverage_cli.gd`).
## Text scans only. (a) code never says an id the VoiceLineTable lacks; (b) every line B's own triggers own
## (briefing, contact radio heist lines) is said; (c) the A / C / B-reserve unsaid lines are explicit allowlists
## that can only shrink: a listed line that becomes said must be removed, and a new unsaid line fails.
extends TestCase

const VoCoverage: GDScript = preload("res://content/voice/tools/vo_coverage.gd")
const HEISTS: Array[StringName] = [
	&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn", &"gallery_night", &"rolling_thunder",
]

## ENV A: lines only A code can trigger and does not yet (pd2_fidelity C8 barks). Every A line is said (the D-117
## bark director, env/a-core dd20d1f0, round 226; OF's captain line since OF-A6 phase 2, A f326ad00). Shrink-only.
const UNSAID_A: Array[StringName] = []

## B reserve: a contact's generic radio lines that no current heist reaches (each fact has an always-ready heist
## line, or no heist with that contact has the fact: Night Deposit, and Dockside Burn's [cartel] since A 4b4fef68,
## fail an objective). Kept on purpose for
## RadioTweak.speaker_overrides and new heists (content/docs/radio.md "Coverage"). The generic escape lines are
## reached again since QB-1 (LEAD 2026-10-16) deleted the heist escape lines a mission escape line always covered.
const UNSAID_B_RESERVE: Array[StringName] = [
	&"vo.vance.radio_objective_done_1", &"vo.vance.radio_objective_done_2", &"vo.vance.radio_objective_done_3",
	&"vo.vance.radio_objective_failed_1", &"vo.vance.radio_objective_failed_2", &"vo.vance.radio_objective_failed_3",
	&"vo.reyes.radio_objective_done_1", &"vo.reyes.radio_objective_done_2", &"vo.reyes.radio_objective_done_3",
	&"vo.reyes.radio_objective_new_1", &"vo.reyes.radio_objective_new_2", &"vo.reyes.radio_objective_new_3",
	# LEAD: reyes radio_objective_failed_1..3 are reached since A 4b4fef68 ([cartel] fails at the police call).
	# LEAD r244: accountant radio_objective_done_1..3 are reached since OF-A6 (OF's vault_drill completes with vault_breach;
	# only vault_breach keeps its own line, so the generic done line covers vault_drill).
	# OF-A6 phase 2 (A f326ad00): accountant radio_objective_new_1..3 are reached (OF reveals objectives the generic
	# new line covers).
	&"vo.mercer.radio_objective_failed_1", &"vo.mercer.radio_objective_failed_2", &"vo.mercer.radio_objective_failed_3",
]

## ENV C: radio lines keyed to objectives the mission never adds or completes. Empty since C 762934d5 (GH
## extra_bags / salon / display_cases, GN lockers / extras) and OF-A6 phase 2 (A f326ad00: OF's reveals are literal
## HIDDEN -> ACTIVE, the side safes and server drives complete); shrink-only like the others.
const UNSAID_C: Array[StringName] = []

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
	if HeistRegistry.ids().has(&"rolling_thunder"):
		# RT-B1 (r276 un-hide prep): once RT's def is registered, Reyes's generic done / new lines are reached by its
		# mission (RT is Reyes's second heist), so they leave the reserve with no edit when the def lands.
		for id: StringName in UNSAID_B_RESERVE:
			if String(id).begins_with("vo.reyes.radio_objective_"):
				allow.erase(id)
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


## RT-B1 (D-151): a staged heist's lines (heist_list "hidden", no mission yet) wait for its mission as owner "S".
## Only staged heists may hold them: once the heist is offered the A / B / C rules apply and every line must be said.
func test_staged_heist_lines_wait_for_their_mission() -> void:
	for row: Dictionary in VoCoverage.call(&"unsaid", _r, "S") as Array[Dictionary]:
		var h: StringName = VoCoverage.call(&"staged_heist_of", StringName(row["id"])) as StringName
		assert_ne(h, &"", "%s waits only while its heist is staged" % row["id"])
	assert_eq(VoCoverage.call(&"staged_heist_of", &"vo.mercer.ostrander_federal_intro"), &"", "OF is offered")


## RT-B1: Rolling Thunder's 34 drafted lines exist; A's rolling_thunder_mission (env/a-core 9fff6e120) says them all,
## so on a trunk with both no RT line is unsaid by A / B / C (a staged line still waiting shows as "S").
func test_rolling_thunder_lines_exist_and_wait_or_are_said() -> void:
	var c: Dictionary = VoCoverage.call(&"counts", _r, &"rolling_thunder")
	assert_true(int(c["lines"]) >= 34, "RT lines in the table (%d)" % int(c["lines"]))
	assert_eq(int(c["A"]) + int(c["B"]) + int(c["C"]), 0, "no RT line is unsaid by A / B / C")


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
