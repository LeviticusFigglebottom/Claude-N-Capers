## Panic button staff run to (gameplay_prefabs.md `alarm_button`). Owner: ENV A.
## Not interactive for the crew. Wall-mounted: pivot back-centre, front -Z. `UsePoint` is where
## the NPC stands to press it.
class_name AlarmButton
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/alarm_button/alarm_button_placeholder.tscn")


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _prefab_ready() -> void:
	# A1-03 behaviour (M2, A1-06): NPC press -> alarm_raised(&"alarm_button", net_id).
	pass
