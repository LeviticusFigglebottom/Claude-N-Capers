## Dumpster / closet hiding bagged bodies (S6.3). Owner: ENV A.
## Hosts a child `Zone` (MapZone BODY_HIDE): body bags dropped/thrown inside are never discovered.
## Visual: `Lid` (pivot), `Inside` marker. Floor object: pivot bottom-centre, front -Z.
## Not interactive (bags enter through the zone). LootManager calls `store_bag` for a body bag
## inside `Zone`; up to `capacity` bags are hidden (`hidden_from_stealth`), more stay visible.
class_name BodyContainer
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/body_container/body_container_placeholder.tscn")

## Body bags it holds.
@export var capacity: int = 2

var stored: int = 0

var _bags: Array[Node] = []

@onready var zone: MapZone = $Zone as MapZone


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Lid", "Inside"])


func _prefab_ready() -> void:
	# A1-03 behaviour (M2): lid animation.
	pass


## LootManager: hide `bag` in here if there is room. Returns true when stored (or already).
func store_bag(bag: Node) -> bool:
	_prune()
	if _bags.has(bag):
		return true
	if _bags.size() >= capacity:
		return false
	_bags.append(bag)
	stored = _bags.size()
	return true


## LootBag: `bag` left the container (picked up again / freed).
func release_bag(bag: Node) -> void:
	_bags.erase(bag)
	_prune()


func is_full() -> bool:
	_prune()
	return _bags.size() >= capacity


func _prune() -> void:
	var keep: Array[Node] = []
	for b: Node in _bags:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			keep.append(b)
	_bags = keep
	stored = _bags.size()
