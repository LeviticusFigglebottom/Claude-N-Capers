## Rolling Thunder mission flow: G1 STUB (RT-C1, ENV C), so the greybox loads and shows its objective markers (as OF-C1
## did for Ostrander Federal). Owner: ENV A from here (RT-A6: setup clock, marshal, signals, early alarm, clean / crash
## stop, trucks, lift, 3 escapes, 8 rare events, VO). Design: docs/design/heists/rolling_thunder.md §Objectives /
## Mission script notes; docs/process/next_heist_rolling_thunder.md §6. Contract heist_map.md §6: only the HeistMission
## API, EventBus and nodes of this map (found by objective_tag).
## The map's tags: casing, signals, charges, thermite, thermite_bag, marshal, convoy, ambush, escort, trucks, cargo,
## secure, escape, escape_wait, goods_lift, lift_breaker, player_perch, pay_station, diner_till, diner_safe, petty_cash,
## frame_ladder, site_gate, bonds_courier, holdout_h1..h4.
extends HeistMission

## [objective id, marker tags] of the setup line this stub lists (text keys: objective.rolling_thunder.<id>).
const STUB_OBJECTIVES: Array = [
	[&"casing", [&"casing"]], [&"signals", [&"signals"]], [&"convoy", [&"convoy"]], [&"trucks", [&"trucks"]],
	[&"secure", [&"secure"]], [&"escape", [&"escape"]],
]
## Bags to secure (doc Loot path, D-075).
const REQUIRED_BAGS: int = 4


func _on_mission_start() -> void:
	for row: Array in STUB_OBJECTIVES:
		var oid: StringName = row[0]
		add_objective(oid, StringName("objective.rolling_thunder.%s" % oid), Enums.ObjectiveState.ACTIVE,
			{"marker_tags": row[1]})
	require_loot(&"secure", REQUIRED_BAGS)
