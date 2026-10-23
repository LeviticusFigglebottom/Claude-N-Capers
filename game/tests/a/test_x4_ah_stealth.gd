## AH-A1 (LEAD r305 plan (b)): Afterhours stealth end-to-end on C's map, the civilian line: the rolled gear bag (a
## civilian takes it) -> mask -> keycard -> office reader -> the code note when one rolled, the safe by code or by the
## drill -> 3 safe bags to the rolled van -> escape, no alarm. Seeds roll different gear / keycard / code slots
## (printed by the route's first note).
## Route and harness shortcuts: game/tests/a/e2e/x4_stealth_flow.gd + x4_stealth_routes.gd (route afterhours).
## SKIPs while ENV C's map is not on the branch.
extends "res://tests/a/x4_stealth_case.gd"

const HEIST: StringName = &"afterhours"
const MAP_PATH: String = "res://world/heists/afterhours/afterhours.tscn"
const ORDER: Array[StringName] = [&"gear", &"office", &"safe", &"secure", &"escape"]


func _pending() -> bool:
	if ResourceLoader.exists(MAP_PATH):
		return false
	skip("pending C G1: no afterhours map on this branch (AH-C1)")
	return true


func test_x4_ah_stealth_seed_1() -> void:
	if _pending():
		return
	await run_stealth(HEIST, 1, ORDER)


func test_x4_ah_stealth_seed_2() -> void:
	if _pending():
		return
	await run_stealth(HEIST, 2, ORDER)


func test_x4_ah_stealth_seed_3() -> void:
	if _pending():
		return
	await run_stealth(HEIST, 3, ORDER)
