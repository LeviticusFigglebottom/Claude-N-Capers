## A5-03 item pickup (QC-84; the keycard_pickup shape generalised). Owner: ENV A.
## A box of `count` x `item_id` (default `item.c4`: Rolling Thunder's magazine boxes, 4 charges each). Interaction
## completes -> the crew member gets the items (CrewController.add_item), item_picked_up(item_id, slot) [R], the prefab
## frees itself. Pre-planning drops of an `item.*` kind spawn one (PreplanAssets: `params.count`, default 1).
class_name ItemPickup
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/item_pickup/item_pickup_placeholder.tscn")

@export var item_id: StringName = &"item.c4"
@export var count: int = 1
@export_group("Interaction")
## -1 = InteractionTweak.item_pickup_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var taken: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().item_pickup_s


func _prefab_ready() -> void:
	interactable.kind = &"pickup_item"
	interactable.completed.connect(_on_completed)


## PreplanAssets: a drop of kind `item.*` (`params.count`).
func configure_preplan(_asset_id: StringName, drop: Dictionary) -> void:
	var kind: StringName = StringName(drop.get("kind", item_id))
	if String(kind).begins_with(PreplanAssets.ITEM_PREFIX):
		item_id = kind
	count = maxi(int((drop.get("params", {}) as Dictionary).get("count", count)), 1)


func _net_state() -> Dictionary:
	return {"taken": taken}


func _apply_net_state(d: Dictionary) -> void:
	taken = bool(d.get("taken", taken))


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or taken:
		return
	var c: CrewController = crew as CrewController
	if c == null:
		return
	taken = true
	c.add_item(item_id, count)
	_emit_fact(&"item_picked_up", [item_id, c.slot])
	queue_free()
