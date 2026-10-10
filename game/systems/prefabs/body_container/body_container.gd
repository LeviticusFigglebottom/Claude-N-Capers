## Dumpster / closet hiding bagged bodies (S6.3). Owner: ENV A.
## Hosts a child `Zone` (MapZone BODY_HIDE): body bags dropped/thrown inside are never discovered.
## Visual: `Lid` (pivot), `Inside` marker. Floor object: pivot bottom-centre, front -Z.
## Not interactive in A1-03 (bags enter through the zone).
class_name BodyContainer
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/body_container/body_container_placeholder.tscn")

## Body bags it holds.
@export var capacity: int = 2

var stored: int = 0

@onready var zone: MapZone = $Zone as MapZone


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Lid", "Inside"])


func _prefab_ready() -> void:
	# A1-03 behaviour (M2, A1-07): count bags in `zone` against `capacity`, lid animation.
	pass
