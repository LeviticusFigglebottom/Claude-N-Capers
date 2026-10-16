## X-4: Shadow Ledger (shadow_ledger, STEALTH_ONLY) stealth end-to-end, seed 11 (ROUTINE): laptop in Kessler's office
## (lap_kessler), the kc_kessler / kc_it keycards, srv_locked server door, the code_moor_planner cage code, heli escape.
## Route and harness shortcuts: game/tests/a/e2e/x4_stealth_flow.gd (route_shadow_ledger).
extends "res://tests/a/x4_stealth_case.gd"

const SEED: int = 11


func test_x4_sl_stealth_completes_without_alarm() -> void:
	await run_stealth(&"shadow_ledger", SEED,
		[&"casing", &"keycard", &"laptop", &"cage_code", &"server_door", &"cage", &"hack", &"drives", &"secure"])
