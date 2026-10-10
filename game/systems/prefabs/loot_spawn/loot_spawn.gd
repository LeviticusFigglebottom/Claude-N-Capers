## Loot spawn: a stack the crew bags up and carries (gameplay_prefabs.md `loot_spawn`). Owner: ENV A.
## Interaction = "bag it" (InteractionTweak.bag_loot_s); `count` bags can be taken from it.
## Floor object: pivot bottom-centre. The UsePoint must be on the navmesh (heist_map.md §3).
class_name LootSpawn
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/loot_spawn/loot_spawn_placeholder.tscn")

## LootDef id of the bags this spawn produces.
@export var loot_id: StringName = &""
@export var count: int = 1
@export_group("Interaction")
## -1 = InteractionTweak.bag_loot_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var remaining: int = 0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().bag_loot_s


func _prefab_ready() -> void:
	remaining = count
	interactable.kind = &"bag_loot"
	# A1-03 behaviour (M2, A1-07): spawn a loot bag (loot_spawned) per completion until `remaining` is 0.
