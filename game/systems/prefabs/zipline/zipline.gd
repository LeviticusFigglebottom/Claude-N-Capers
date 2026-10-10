## Bag zipline (S9.11, P2). Owner: ENV A. Interaction attaches the carried bag; it slides to `end`.
class_name Zipline
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/zipline/zipline_placeholder.tscn")

## Node3D (Marker3D) where the line ends.
@export var end: NodePath
@export_group("Interaction")
## -1 = InteractionTweak.zipline_attach_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().zipline_attach_s


func _prefab_ready() -> void:
	interactable.kind = &"attach_bag"
	# A1-03 behaviour (P2): require a carried bag, slide it to `end`, secure at a zone there.
