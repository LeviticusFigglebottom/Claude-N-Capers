## Security-room console (gameplay_prefabs.md `camera_station`). Owner: ENV A.
## Killing/dominating the operator turns every camera off; interacting loops the cameras (skill).
## Visual: `Screens` (MeshInstance3D(s); A swaps their material to off/static), `Seat` marker.
class_name CameraStation
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/camera_station/camera_station_placeholder.tscn")

## SpawnPoint (CAMERA_OPERATOR) whose NPC operates this station.
@export var operator_spawn: NodePath
@export_group("Interaction")
## -1 = InteractionTweak.camera_loop_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = true
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Screens", "Seat"])


func _default_interaction_time() -> float:
	return Tweak.interaction().camera_loop_s


func _prefab_ready() -> void:
	interactable.kind = &"loop_cameras"
	# A1-03 behaviour (M2): operator binding, cameras_loop_disabled, skill gate, screens material.
