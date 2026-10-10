## Panic button staff run to (gameplay_prefabs.md `alarm_button`). Owner: ENV A.
## Not interactive for the crew. Wall-mounted: pivot back-centre, front -Z. `UsePoint` is where
## the NPC stands to press it.
class_name AlarmButton
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/alarm_button/alarm_button_placeholder.tscn")

var pressed: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


## Where an NPC stands to press it (UsePoint, else the button).
func use_point_position() -> Vector3:
	return use_point.global_position if use_point != null else global_position


## Server: an NPC (`by_net_id`) presses the button -> alarm_raised(&"alarm_button").
func press(by_net_id: int = 0) -> void:
	if not Net.is_authority():
		return
	pressed = true
	_raise_alarm(&"alarm_button", by_net_id if by_net_id != 0 else net_id)
