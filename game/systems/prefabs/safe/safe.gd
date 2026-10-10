## Lockable safe (S9.8). Owner: ENV A. Opened by any of `methods`:
## &"drill", &"saw", &"c4", &"lockpick" (needs interaction.can_lockpick_safes), &"code".
## Visual: `Body`, `Door` (pivot at hinge), `DrillPoint` marker (-Z into the lock), `LootAnchor`.
## Floor object: pivot bottom-centre, door on the front (-Z).
class_name Safe
extends GameplayPrefab

enum Size { SMALL, MEDIUM, LARGE }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/safe/safe_placeholder.tscn")

@export var size: Size = Size.MEDIUM
@export var methods: Array[StringName] = [&"drill"]
@export_group("Interaction")
## -1 = InteractionTweak.drill_place_s (placing the drill on `DrillPoint`).
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var opened: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Body", "Door", "DrillPoint", "LootAnchor"])


func _default_interaction_time() -> float:
	return Tweak.interaction().drill_place_s


func _prefab_ready() -> void:
	interactable.kind = &"place_drill"
	# A1-03 behaviour (M2, P2): methods, size-dependent collision/drill time, time lock, loot.
