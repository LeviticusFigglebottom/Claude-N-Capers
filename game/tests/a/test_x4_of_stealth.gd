## X-4 / OF-A6: Ostrander Federal (ostrander_federal) stealth end-to-end, the ghost line (doc §Stealth routes) on 3
## seeds whose rolls differ (printed by the flow's launch line):
##   seed 3: kc_on_manager + mgr_vault (shout Ashgrove down in the basement, tie him, take his card), srv_basement (the
##     rack line: the laser controller turns the lz_timed grid off, the rack hack starts the 210 s time lock, the
##     cash cage padlock), heli terrace escape;
##   seed 7: kc_manager_desk, pc_exec hack (Executive level), lz_sweep crossed between its beams, the code at the time
##     lock (150 s) and at the cash cage keypad, van at the dock;
##   seed 6: kc_security, pc_vault_ops hack, lz_static (bypass gap / crouch), 210 s, van on Tannery Street.
## Route and harness shortcuts: game/tests/a/e2e/x4_stealth_flow.gd + x4_stealth_routes.gd (route ostrander_federal).
## SKIPs "pending C G1" while ENV C's map is not on the branch (env/a-core before OF-C1 lands).
extends "res://tests/a/x4_stealth_case.gd"

const HEIST: StringName = &"ostrander_federal"
const MAP_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const PENDING: String = "pending C G1: no ostrander_federal map on this branch (OF-C1)"
## Seed 3 needs C's manager routes (fcc83280: Patrols/Routes/ManagerVaultRoute, its LK WC away stop).
const ROUTE_MGR_VAULT: String = "route_id = &\"mgr_vault\""
const PENDING_ROUTES: String = "pending C fcc83280: no mgr_vault CivilianRoute in the map"
const PC_LINE: Array[StringName] = [&"keycard", &"code_pc", &"vault_gate", &"time_lock", &"time_lock_wait", &"secure",
	&"escape"]
const RACK_LINE: Array[StringName] = [&"keycard", &"vault_gate", &"lasers", &"server", &"time_lock_wait", &"secure",
	&"escape"]


func _pending() -> bool:
	if ResourceLoader.exists(MAP_PATH):
		return false
	skip(PENDING)
	return true


func test_x4_of_stealth_seed_18_rack_line_heli() -> void:
	if _pending():
		return
	await run_stealth(HEIST, 18, RACK_LINE)


func test_x4_of_stealth_seed_3_manager_card_vault_basement() -> void:
	if _pending():
		return
	if not FileAccess.get_file_as_string(MAP_PATH).contains(ROUTE_MGR_VAULT):
		skip(PENDING_ROUTES)
		return
	await run_stealth(HEIST, 3, RACK_LINE)
	if flow != null:
		assert_true(bool(flow.facts.get(&"curator_tied", false)), "Ashgrove tied for his keycard (kc_on_manager)")
		assert_true(bool(flow.facts.get(&"carrier_caught_away", false)), "caught alone in his away window (mgr_vault)")


func test_x4_of_stealth_seed_35_manager_card_gallery() -> void:
	if _pending():
		return
	await run_stealth(HEIST, 35, PC_LINE)
	if flow != null:
		assert_true(bool(flow.facts.get(&"curator_tied", false)), "Ashgrove tied for his keycard (kc_on_manager)")


func test_x4_of_stealth_seed_7_exec_pc_sweep_dock_van() -> void:
	if _pending():
		return
	await run_stealth(HEIST, 7, PC_LINE)


func test_x4_of_stealth_seed_6_vault_ops_pc_static_tannery_van() -> void:
	if _pending():
		return
	await run_stealth(HEIST, 6, PC_LINE)
