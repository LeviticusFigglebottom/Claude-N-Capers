## Phone civilians/guards run to to call the police (gameplay_prefabs.md `phone`). Owner: ENV A.
## Not interactive for the crew. `UsePoint` is where the NPC stands to make the call.
class_name Phone
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/phone/phone_placeholder.tscn")

var used: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


## Where an NPC stands to make the call (UsePoint, else the phone).
func use_point_position() -> Vector3:
	return use_point.global_position if use_point != null else global_position


## Server: an NPC (`by_net_id`) completes a call -> alarm_raised(&"phone_call").
func call_police(by_net_id: int = 0) -> void:
	if not Net.is_authority():
		return
	used = true
	_raise_alarm(&"phone_call", by_net_id if by_net_id != 0 else net_id)
