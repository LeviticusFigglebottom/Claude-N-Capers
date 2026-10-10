## Keycard lying in the map (S9.6; random location per run via the `keycard` slot group). Owner: ENV A.
## Interaction completes -> crew gets `item.keycard`, item_picked_up [R], the prefab frees itself.
## Usable while casing (casing_allowed defaults to true here).
class_name KeycardPickup
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/keycard_pickup/keycard_pickup_placeholder.tscn")
const ITEM: StringName = &"item.keycard"

@export_group("Interaction")
## -1 = InteractionTweak.item_pickup_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = true
@export var noise: StringName = &"silent"

var taken: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().item_pickup_s


func _prefab_ready() -> void:
	interactable.kind = &"pickup_item"
	interactable.completed.connect(_on_completed)


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or taken:
		return
	var c: CrewController = crew as CrewController
	if c == null:
		return
	taken = true
	c.add_item(ITEM)
	_emit_fact(&"item_picked_up", [ITEM, c.slot])
	queue_free()
