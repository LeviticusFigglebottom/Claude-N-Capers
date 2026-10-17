## Ostrander Federal mission flow: G1 STUB (OF-C1, ENV C), so the greybox loads and shows its objective markers.
## Owner: ENV A from here (OF-A6: stealth + lockdown + drill delivery + burn-through + hoist + 3 escapes + rare events
## + VO). Design: docs/design/heists/ostrander_federal.md §Objectives / Mission script notes (D-136 build notes).
## Contract heist_map.md §6: only the HeistMission API, EventBus and nodes of this map (found by objective_tag).
## The map's tags: casing, keycard (+ carrier_tag keycard_carrier on kc_on_manager), code_hint, code_pc, server, lasers,
## vault_gate, time_lock, time_lock_wait, vault_door, vault_loot, cash_cage, gold_cage, secure, escape, escape_wait,
## deposit_boxes, bond_safe, president_safe, server_drives, drill_delivery, vault_drill, vault_breach, lid, hoist.
extends HeistMission

## [objective id, marker tags] of the stealth line this stub lists (text keys: objective.ostrander_federal.<id>).
const STUB_OBJECTIVES: Array = [
	[&"casing", [&"casing"]], [&"keycard", [&"keycard"]], [&"code_pc", [&"code_pc", &"server"]],
	[&"vault_gate", [&"vault_gate"]], [&"time_lock", [&"time_lock"]], [&"vault_loot", [&"vault_loot"]],
	[&"secure", [&"secure"]], [&"escape", [&"escape"]],
]
## Bags to secure: 6, 4 on Routine (doc Loot path, D-075).
const REQUIRED_BAGS: int = 6
const REQUIRED_BAGS_ROUTINE: int = 4


func _on_mission_start() -> void:
	for row: Array in STUB_OBJECTIVES:
		var oid: StringName = row[0]
		var state: Enums.ObjectiveState = Enums.ObjectiveState.ACTIVE
		add_objective(oid, StringName("objective.ostrander_federal.%s" % oid), state, {"marker_tags": row[1]})
	require_loot(&"secure", REQUIRED_BAGS_ROUTINE if difficulty == Enums.Difficulty.ROUTINE else REQUIRED_BAGS)
