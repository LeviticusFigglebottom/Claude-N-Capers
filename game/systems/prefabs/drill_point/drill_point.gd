## Where a drill / thermal drill / saw is placed (S9.3, S9.4). Owner: ENV A.
## Interaction = place the device (InteractionTweak.drill_place_s); the device runs `duration_s`
## (-1 = default per device), jams per Modifiers, and opens `target` (calls its `unlock()`).
## The drill art is a separate device visual with a `Bit` node (visual_slots.md); the placeholder
## only marks the spot. -Z points into the lock.
class_name DrillPoint
extends GameplayPrefab

enum Device { DRILL, THERMAL, SAW }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/drill_point/drill_point_placeholder.tscn")

@export var device: Device = Device.DRILL
## Run time in s. -1 = InteractionTweak drill_duration_s / thermal_duration_s / saw_duration_s.
@export var duration_s: float = -1.0
## What this opens (Door, Safe, ...).
@export var target: NodePath
@export_group("Interaction")
## -1 = InteractionTweak.drill_place_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().drill_place_s


## Effective device run time (s).
func effective_duration() -> float:
	if duration_s >= 0.0:
		return duration_s
	var tw: InteractionTweak = Tweak.interaction()
	match device:
		Device.THERMAL:
			return tw.thermal_duration_s
		Device.SAW:
			return tw.saw_duration_s
		_:
			return tw.drill_duration_s


func _prefab_ready() -> void:
	interactable.kind = &"place_drill"
	# A1-03 behaviour (M2): device spawn, device_started/jammed/restarted/finished, 25 m noise
	# (12.5 m occluded), jams via GameRng.stream(&"drills"), fix interaction, unlock target.
