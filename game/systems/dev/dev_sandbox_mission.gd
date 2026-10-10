## Mission script of the ENV A dev sandbox (testing only; never ships). Owner: ENV A.
## Objectives: get_loot (secure 1 bag) -> escape (activated on the first secured bag, after the
## rolled `escape_delay` scalar in seconds).
extends HeistMission


func _on_mission_start() -> void:
	add_objective(&"get_loot", &"obj.dev_sandbox.get_loot")
	require_loot(&"get_loot", 1)
	add_objective(&"escape", &"obj.dev_sandbox.escape", Enums.ObjectiveState.HIDDEN)
	on_event(&"loot_secured", _on_bag_secured)
	say(&"vo.mercer.dev_start")


func _on_bag_secured(_bag: int, _loot_id: StringName, _value: int) -> void:
	if objective_state(&"escape") != Enums.ObjectiveState.HIDDEN or timer_left(&"escape_delay") > 0.0:
		return
	var delay: float = float(variant(&"escape_delay")) if variant(&"escape_delay") != null else 0.0
	if delay > 0.0:
		start_timer(&"escape_delay", delay, _open_escape)
	else:
		_open_escape()


func _open_escape() -> void:
	activate(&"escape")
	activate_escape(&"escape_van")
