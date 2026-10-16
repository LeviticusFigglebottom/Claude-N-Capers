## X-4: Nightfall Depository (night_deposit) stealth end-to-end, seed 11 (ROUTINE): kc_records keycard, the
## code_manager_planner note, timed antechamber lasers, a 60 s time lock, boat escape (esc_boat_quay).
## Route and harness shortcuts: game/tests/a/e2e/x4_stealth_flow.gd (route_night_deposit).
extends "res://tests/a/x4_stealth_case.gd"

const SEED: int = 11


func test_x4_nd_stealth_completes_without_alarm() -> void:
	await run_stealth(&"night_deposit", SEED,
		[&"casing", &"keycard", &"code", &"vault_gate", &"time_lock", &"time_lock_wait", &"secure"])
