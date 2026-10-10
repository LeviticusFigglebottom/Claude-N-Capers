## Escape area activated by the mission (C10). Owner: ENV A.
## Hosts a child `Zone` (MapZone ESCAPE, BoxShape3D centred on the origin footprint, bottom at
## floor, sized by `zone_size_m`). HeistMission.activate_escape() calls `activate()` on this node.
## The zone stays in the escape_zone group while inactive; only `monitoring` is toggled.
class_name EscapeZone
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/escape_zone/escape_zone_placeholder.tscn")
## Footprint the placeholder is modelled at (m).
const PLACEHOLDER_FOOTPRINT_M: Vector2 = Vector2(4.0, 4.0)

## Escape variant (matches the heist's `escape_type` scalar, e.g. &"van", &"walk", &"boat").
@export var escape_type: StringName = &"van"
@export var active: bool = false
@export var zone_size_m: Vector3 = Vector3(4.0, 3.0, 4.0)

@onready var zone: MapZone = $Zone as MapZone


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _prefab_ready() -> void:
	ZoneUtil.size_box_zone(zone, zone_size_m)
	if using_placeholder and visual_instance != null:
		visual_instance.scale = Vector3(zone_size_m.x / PLACEHOLDER_FOOTPRINT_M.x, 1.0, zone_size_m.z / PLACEHOLDER_FOOTPRINT_M.y)
	_apply_active()


## Mission: escape is available here (C10).
func activate() -> void:
	active = true
	_apply_active()


func _apply_active() -> void:
	if zone != null:
		zone.set_deferred(&"monitoring", active)
	if visual_root != null:
		visual_root.visible = active
	# A1-03 behaviour (M2): crew inside an active zone -> escape / end_heist.
