## Small loot: cash bundle / jewelry picked up without a bag (S10.3). Owner: ENV A.
## Interaction completes -> small_loot_taken(value, slot) [R] and the prefab frees itself.
class_name SmallLoot
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/small_loot/small_loot_placeholder.tscn")

## Payout added to the heist result (integer dollars).
@export var value: int = 500
@export var loot_id: StringName = &""
@export_group("Interaction")
## -1 = InteractionTweak.small_loot_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var taken: bool = false
## PP audit: small loot a DrillPoint targets (ATM cash behind a saw) stays locked until the device finishes
## (open_by_device). Replicated (generic `locked`); the interactable is off while locked.
var locked: bool = false:
	set(v):
		locked = v
		if interactable != null:
			interactable.enabled = not v and not taken


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().small_loot_s


func _prefab_ready() -> void:
	interactable.kind = &"take_loot"
	interactable.casing_pickup_item = true  # S1.1
	interactable.completed.connect(_on_completed)
	if locked:
		interactable.enabled = false


## DrillPoint hook: this loot sits behind the device (called when the drill point is ready).
func lock_for_device() -> void:
	locked = true


## DrillPoint.open_target: the device finished, the loot can be taken.
func open_by_device() -> void:
	locked = false


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or taken or locked:
		return
	taken = true
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	var v: int = int(round(float(value) * Modifiers.mult(slot, &"loot.small_loot_value_mult"))) if slot >= 0 else value
	_emit_fact(&"small_loot_taken", [v, slot])  # A4-04: loot.small_loot_value_mult
	queue_free()
