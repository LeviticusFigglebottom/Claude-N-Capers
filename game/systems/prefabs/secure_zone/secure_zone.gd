## Loot secure area with a vehicle/drop visual (S10.2). Owner: ENV A.
## Hosts a child `Zone` (MapZone SECURE_LOOT, BoxShape3D, centred on the origin footprint, bottom
## at floor, sized by `zone_size_m`). Bags resting/thrown inside are secured (A1-07).
## Visual (van): `Body`, `DoorL`, `DoorR` (pivots), `DropAnchor`; the rear faces -Z.
## `Collision` (world_static) is the nominal van body; turn it off with `vehicle_collision` for
## non-vehicle drop points.
class_name SecureZone
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/secure_zone/secure_zone_placeholder.tscn")

@export var zone_size_m: Vector3 = Vector3(4.0, 3.0, 8.0)
@export var vehicle_collision: bool = true

@onready var zone: MapZone = $Zone as MapZone


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Body", "DoorL", "DoorR", "DropAnchor"])


func _prefab_ready() -> void:
	ZoneUtil.size_box_zone(zone, zone_size_m)
	var col: CollisionObject3D = get_node_or_null(^"Collision") as CollisionObject3D
	if col != null and not vehicle_collision:
		col.queue_free()
	# Securing (A1-07) is LootManager's: any bag resting LootTweak.secure_rest_s inside a
	# SECURE_LOOT MapZone (this `Zone` or a map-placed one) emits loot_secured. Door animation: M2.
