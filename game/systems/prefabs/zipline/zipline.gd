## Bag zipline (S9.11, P2). Owner: ENV A.
## Interaction (kind &"attach_bag", zipline_attach_s) needs a carried bag (else blocked
## `ui.blocked.requires_bag`). On completion the bag leaves the crew member (loot_dropped [R],
## thrown = false), hangs at the `Interactable` (line start) and slides to the `end` node at
## zipline_speed_mps, frozen and without collision; at the end it is released there and falls
## (a SECURE_LOOT zone at the end secures it as usual). Several bags may travel at once.
## Player zipline: P3 hook (not implemented).
class_name Zipline
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/zipline/zipline_placeholder.tscn")
const BLOCK_REQUIRES_BAG: StringName = &"ui.blocked.requires_bag"

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

## Bags on the line: [{ "bag": LootBag, "t": float (0..1) }].
var riding: Array[Dictionary] = []


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().zipline_attach_s


func _prefab_ready() -> void:
	interactable.kind = &"attach_bag"
	interactable.prompt_key = &"ui.prompt.zipline_bag"
	interactable.extra_check = _availability
	interactable.completed.connect(_on_completed)


## Line start / end in world space.
func start_position() -> Vector3:
	return interactable.global_position


func end_position() -> Vector3:
	var e: Node3D = get_node_or_null(end) as Node3D if not end.is_empty() else null
	return e.global_position if e != null else start_position()


## Seconds a bag takes from start to end.
func travel_time() -> float:
	return start_position().distance_to(end_position()) / maxf(Tweak.interaction().zipline_speed_mps, 0.01)


func _availability(crew: Node) -> StringName:
	if end.is_empty() or get_node_or_null(end) == null:
		return InteractableComponent.BLOCK_DISABLED
	if crew != null and not bool(crew.call(&"is_carrying_bag")):
		return BLOCK_REQUIRES_BAG
	return InteractableComponent.BLOCK_NONE


func _on_completed(crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if not Net.is_authority() or c == null or not c.is_carrying_bag():
		return
	var bag: LootBag = c.carried_bag as LootBag
	if bag == null:
		return
	c.set_carried_bag(null)
	bag.release(start_position(), Vector3.ZERO, false)
	_hang(bag)
	riding.append({"bag": bag, "t": 0.0})
	_emit_fact(&"loot_dropped", [bag.net_id, c.slot, false])
	_cue(&"cue.zipline_attach", start_position())


func _physics_process(delta: float) -> void:
	if riding.is_empty() or not Net.is_authority():
		return
	var dur: float = maxf(travel_time(), 0.01)
	var a: Vector3 = start_position()
	var b: Vector3 = end_position()
	for i: int in range(riding.size() - 1, -1, -1):
		var r: Dictionary = riding[i]
		var raw: Variant = r["bag"]
		var bag: LootBag = raw as LootBag if is_instance_valid(raw) else null
		if bag == null or bag.is_carried() or bag.secured:
			riding.remove_at(i)
			continue
		var t: float = minf(float(r["t"]) + delta / dur, 1.0)
		r["t"] = t
		bag.global_position = a.lerp(b, t)
		bag.rest_time = 0.0  # never secured mid-line
		if t >= 1.0:
			riding.remove_at(i)
			bag.release(b, Vector3.ZERO, false)


## Frozen, no collision, not pick-up-able while it slides.
func _hang(bag: LootBag) -> void:
	bag.freeze = true
	bag.collision_layer = 0
	bag.collision_mask = 0
	bag.linear_velocity = Vector3.ZERO
	if bag.interactable != null:
		bag.interactable.enabled = false
