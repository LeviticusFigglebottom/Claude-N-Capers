## Gear bag in a civilian-start heist (S1.3, HeistDef.start_mode = civilian). Owner: ENV A.
## A civilian crew member holds the interaction to take their gear: civilian mode ends (casing, can mask
## up), `item_picked_up(&"item.gear", slot)` [R]. The bag stays for the rest of the crew; it is only
## usable by civilians (civilian_allowed; anyone else already has their gear). AI teammates gear up when the
## first human crew member does (D-065 P5 ruling; they never walk to the bag).
class_name GearPickup
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/gear_pickup/gear_pickup_placeholder.tscn")
const ITEM: StringName = &"item.gear"
const KIND: StringName = &"pick_up_gear"

@export_group("Interaction")
## -1 = InteractionTweak.item_pickup_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = true
@export var civilian_allowed: bool = true
@export var noise: StringName = &"silent"

## Crew slots that took their gear here.
var taken_by: Array[int] = []


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().item_pickup_s


func _prefab_ready() -> void:
	interactable.kind = KIND
	interactable.prompt_key = &"ui.prompt.pick_up_gear"
	interactable.extra_check = func(crew: Node) -> StringName:
		return InteractableComponent.BLOCK_NONE if crew != null and crew.get(&"civilian") == true \
			else InteractableComponent.BLOCK_STATE  # only crew still without their gear
	interactable.aim_filter = func(crew: Node) -> bool: return crew != null and crew.get(&"civilian") == true
	interactable.completed.connect(_on_completed)


func _on_completed(crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if not Net.is_authority() or c == null or not c.civilian:
		return
	c.civilian = false
	taken_by.append(c.slot)
	_emit_fact(&"item_picked_up", [ITEM, c.slot])
	if not c.is_ai:  # D-065 P5 ruling: AI teammates gear up with the first human (they never walk here)
		var rt: HeistRuntime = HeistRuntime.of(self)
		for m: CrewController in (rt.crew_members() if rt != null else []):
			if m.is_ai and m.civilian:
				m.civilian = false
	_off_when_all_geared()


## B r308 HUD pass: once nobody in the crew still needs gear the bag is no longer an interactable for anyone (each
## geared member already stops targeting it through the aim filter).
func _off_when_all_geared() -> void:
	var rt: HeistRuntime = HeistRuntime.of(self)
	for m: CrewController in (rt.crew_members() if rt != null else []):
		if m.civilian:
			return
	interactable.enabled = false
