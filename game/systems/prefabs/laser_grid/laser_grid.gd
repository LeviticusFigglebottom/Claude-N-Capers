## Laser grid that trips the alarm on touch, even while casing; ECM doesn't affect it (S9.10, P2).
## Owner: ENV A. `Trigger` (Area3D, triggers layer, monitors players) is a box of `size_m`
## centred on the origin footprint, bottom at floor.
class_name LaserGrid
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/laser_grid/laser_grid_placeholder.tscn")

## &"static", &"sweeping" or &"timed_off" (S9.10).
@export var pattern: StringName = &"static"
@export var size_m: Vector3 = Vector3(2.0, 2.0, 0.1)

@onready var trigger: Area3D = $Trigger as Area3D


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _prefab_ready() -> void:
	ZoneUtil.size_box_zone(trigger, size_m)
	trigger.collision_layer = LAYER_TRIGGERS
	trigger.collision_mask = LAYER_PLAYERS
	# A1-03 behaviour (P2): body_entered -> laser_tripped + alarm_raised(&"laser"); patterns.
