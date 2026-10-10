## Loot spawn: a stack the crew bags up and carries (gameplay_prefabs.md `loot_spawn`). Owner: ENV A.
## Interaction = "bag it" (InteractionTweak.bag_loot_s); `count` bags can be taken from it.
## Floor object: pivot bottom-centre. The UsePoint must be on the navmesh (heist_map.md §3).
## Behaviour (A1-07): each completion spawns a LootBag of `loot_id` (`moved = true`) through
## LootManager and puts it straight on the crew member's back; disabled once `remaining` is 0.
## Not usable while already carrying a bag.
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
	interactable.allowed_with_bag = false
	interactable.enabled = remaining > 0
	interactable.completed.connect(_on_completed)


func _on_completed(crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if not Net.is_authority() or c == null or remaining <= 0 or c.is_carrying_bag():
		return
	var mgr: LootManager = HeistRuntime.get_service(G.SVC_LOOT) as LootManager
	if mgr == null:
		return
	var bag: LootBag = mgr.spawn_bag(loot_id, Transform3D(Basis.IDENTITY, c.global_position), true)
	if bag == null:
		return
	remaining -= 1
	mgr.carry(bag, c)
	if remaining <= 0:
		interactable.enabled = false
		if visual_root != null:
			visual_root.visible = false
