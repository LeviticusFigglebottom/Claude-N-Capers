## Escape area activated by the mission (C10). Owner: ENV A.
## Hosts a child `Zone` (MapZone ESCAPE, BoxShape3D centred on the origin footprint, bottom at
## floor, sized by `zone_size_m`). HeistMission.activate_escape() calls `activate()` on this node.
## The zone stays in the escape_zone group while inactive; only `monitoring` is toggled.
## While active (server): once every human crew member not in custody stands inside `Zone`, the heist
## ends with success: `HeistRuntime.end_heist(true, escaped)` where `escaped` = humans inside + AI
## teammates not in custody (they come along). Without humans (bot-only tests) slot 0 counts as
## the human.
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


func _physics_process(_delta: float) -> void:
	if not active or not Net.is_authority():
		return
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null or rt.phase == Enums.HeistPhase.ENDED:
		return
	var escaped: Array[int] = escaping_slots(rt)
	if not escaped.is_empty():
		rt.end_heist(true, escaped)


## Slots that escape now, or [] while a required (human, not in custody) crew member is outside.
func escaping_slots(rt: HeistRuntime) -> Array[int]:
	var crew: Array[CrewController] = rt.crew_members()
	var humans: Array[CrewController] = []
	for c: CrewController in crew:
		if not c.is_ai:
			humans.append(c)
	if humans.is_empty():
		for c: CrewController in crew:
			if c.slot == 0:
				humans.append(c)
	var required: Array[CrewController] = []
	for c: CrewController in humans:
		if c.crew_state != Enums.CrewState.CUSTODY:
			required.append(c)
	var out: Array[int] = []
	if required.is_empty():
		return out
	for c: CrewController in required:
		if not ZoneUtil.contains(zone, c.global_position + Vector3.UP * 0.5):
			return []
		out.append(c.slot)
	for c: CrewController in crew:
		if not humans.has(c) and c.crew_state != Enums.CrewState.CUSTODY:
			out.append(c.slot)
	out.sort()
	return out


func _apply_active() -> void:
	if zone != null:
		zone.set_deferred(&"monitoring", active)
	if visual_root != null:
		visual_root.visible = active
