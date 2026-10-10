## Keycard reader that opens bound targets (S9.6). Owner: ENV A.
## Wall-mounted: pivot back-centre, front -Z. Visual: `Panel`, `Led`.
## Requires and consumes `item.keycard`; on completion calls `unlock()` on each target (M2).
class_name KeycardReader
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/keycard_reader/keycard_reader_placeholder.tscn")

## Doors / vaults this reader opens.
@export var targets: Array[NodePath] = []
@export_group("Interaction")
## -1 = InteractionTweak.keycard_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &"item.keycard"
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Panel", "Led"])


func _default_interaction_time() -> float:
	return Tweak.interaction().keycard_s


func _prefab_ready() -> void:
	interactable.kind = &"keycard"
	interactable.consumes_item = requires_item != &""
	# A1-03 behaviour (M2): on completed, call unlock() / open on every target; Led feedback.
