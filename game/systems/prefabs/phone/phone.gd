## Phone civilians/guards run to to call the police (gameplay_prefabs.md `phone`). Owner: ENV A.
## Not interactive for the crew. `UsePoint` is where the NPC stands to make the call.
class_name Phone
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/phone/phone_placeholder.tscn")


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _prefab_ready() -> void:
	# A1-03 behaviour (M2, A1-06): NPC call -> alarm_raised(&"phone_call", net_id).
	pass
