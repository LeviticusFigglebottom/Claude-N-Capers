## SL-6: Shadow Ledger stealth end-to-end on the alternative routes the X-4 seed (test_x4_sl_stealth.gd: srv_locked,
## lap_kessler, heli) does not take. Same harness and shortcuts (x4_stealth_case.gd, e2e/x4_stealth_flow.gd); the
## variants are pinned through PreplanResult force_variants:
##   * contractor: srv_contractor (no keycard, the server door propped, the code on his laptop), Moor working late
##     (her laptop on her desk), the service-lift escape (E3, L40);
##   * study: srv_locked, the laptop in Kessler's study behind the M3 lasers, the E2 line escape.
extends "res://tests/a/x4_stealth_case.gd"

const SEED: int = 11


func test_sl6_e2e_contractor_moor_service_lift() -> void:
	await run_stealth(&"shadow_ledger", SEED,
		[&"casing", &"laptop", &"cage_code", &"cage", &"hack", &"drives", &"secure"],
		{"preplan": {"force_variants": {
			"server_room": [&"srv_contractor"], "code_note": [&"code_contractor"], "late_partner": [&"moor_late"],
			"escape": [&"esc_service"]}}})
	if flow == null or flow.rt == null:
		return
	assert_eq(flow.rt.variants.get(&"server_room"), [&"srv_contractor"], "srv_contractor")
	assert_eq(flow.rt.variants.get(&"laptop"), [&"lap_moor"], "Moor late: her laptop")
	assert_eq(flow.rt.variants.get(&"escape"), [&"esc_service"], "service lift")
	assert_eq(flow.objective(&"keycard"), Enums.ObjectiveState.COMPLETED, "[keycard] skipped")
	assert_eq(flow.objective(&"server_door"), Enums.ObjectiveState.COMPLETED, "[server_door] propped")


func test_sl6_e2e_study_laptop_line_escape() -> void:
	await run_stealth(&"shadow_ledger", SEED,
		[&"casing", &"keycard", &"laptop", &"cage_code", &"server_door", &"cage", &"hack", &"drives", &"secure"],
		{"preplan": {"force_variants": {
			"server_room": [&"srv_locked"], "late_partner": [&"moor_gone"], "laptop": [&"lap_study"],
			"escape": [&"esc_line"]}}})
	if flow == null or flow.rt == null:
		return
	assert_eq(flow.rt.variants.get(&"laptop"), [&"lap_study"], "the study laptop")
	assert_eq(flow.rt.variants.get(&"escape"), [&"esc_line"], "the E2 line")
	assert_eq(flow.lasers_tripped, 0, "past the art-hall grid without a trip")
