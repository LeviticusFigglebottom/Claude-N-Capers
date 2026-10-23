## AH-A1 test helper: an AfterhoursMission's objective state / data in short calls. Owner: ENV A.
class_name AfterhoursMissionProbe
extends RefCounted

const DONE: int = Enums.ObjectiveState.COMPLETED
const ACTIVE: int = Enums.ObjectiveState.ACTIVE
const HIDDEN: int = Enums.ObjectiveState.HIDDEN

var mission: HeistMission = null


func _init(m: HeistMission) -> void:
	mission = m


func state(id: StringName) -> int:
	return mission.objective_state(id)


func data(id: StringName) -> Dictionary:
	for o: Dictionary in mission.objectives():
		if StringName(o["id"]) == id:
			return o.get("data", {}) as Dictionary
	return {}


func gear_line() -> StringName:
	return StringName(mission.call(&"gear_line"))
