## Escape area activated by the mission (C10). Owner: ENV A.
## Hosts a child `Zone` (MapZone ESCAPE, BoxShape3D centred on the origin footprint, bottom at
## floor, sized by `zone_size_m`). HeistMission.activate_escape() calls `activate()` on this node.
## The zone stays in the escape_zone group while inactive; only `monitoring` is toggled.
## While active (server): once every human crew member not in custody stands inside `Zone`, the heist
## ends with success: `HeistRuntime.end_heist(true, escaped)` where `escaped` = humans inside + AI
## teammates not in custody (they come along). Without humans (bot-only tests) slot 0 counts as
## the human.
## A3-10 (QC-19, D-042): `escape_type` is one of ESCAPE_TYPES (van, boat, heli, lift, zipline, walk;
## anything else logs a warning). `arrival_delay_s` > 0: after `activate()` the vehicle approaches
## for that long (visual hidden, nobody can escape; `arrival_time_left()` for the HUD), then it
## arrives (visual shown, cue.escape_arrive) and the zone works. `bag_only`: the zone never ends the
## heist; once arrived its `Zone` joins the SECURE_LOOT group, so bags resting in it are secured (a
## zipline / lift drop: the crew leave by another escape). Visual nodes required on art (not on the
## placeholder) by type: van `Body`, `DoorL`, `DoorR`; heli `Body`, `Rotor`; boat `Body`.
class_name EscapeZone
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/escape_zone/escape_zone_placeholder.tscn")
## Footprint the placeholder is modelled at (m).
const PLACEHOLDER_FOOTPRINT_M: Vector2 = Vector2(4.0, 4.0)
## gameplay_prefabs.md v1.2 (QC-19).
const ESCAPE_TYPES: Array[StringName] = [&"van", &"boat", &"heli", &"lift", &"zipline", &"walk"]
const TYPE_VISUAL_NODES: Dictionary = {
	&"van": ["Body", "DoorL", "DoorR"], &"heli": ["Body", "Rotor"], &"boat": ["Body"],
}

## Escape variant (matches the heist's `escape_type` scalar, e.g. &"van", &"walk", &"boat").
@export var escape_type: StringName = &"van"
@export var active: bool = false
@export var zone_size_m: Vector3 = Vector3(4.0, 3.0, 4.0)
## Seconds between activate() and the vehicle's arrival (heli / boat approach). 0 = present.
@export var arrival_delay_s: float = 0.0
## Bags only (zipline / lift drop): secures bags, crew cannot escape here.
@export var bag_only: bool = false

## Seconds until arrival after activation (-1 = not activated yet, 0 = arrived).
var arrival_left: float = -1.0

@onready var zone: MapZone = $Zone as MapZone


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	if using_placeholder:
		return PackedStringArray()
	return PackedStringArray(TYPE_VISUAL_NODES.get(escape_type, []))


func _prefab_ready() -> void:
	if not ESCAPE_TYPES.has(escape_type):
		Log.warn(LOG_CHANNEL, "%s: unknown escape_type '%s' (gameplay_prefabs.md v1.2)" % [name, escape_type])
	if active:
		arrival_left = maxf(arrival_delay_s, 0.0)
	ZoneUtil.size_box_zone(zone, zone_size_m)
	if using_placeholder and visual_instance != null:
		visual_instance.scale = Vector3(zone_size_m.x / PLACEHOLDER_FOOTPRINT_M.x, 1.0, zone_size_m.z / PLACEHOLDER_FOOTPRINT_M.y)
	_apply_active()


## Mission: escape is available here (C10).
func activate() -> void:
	if active:
		return
	active = true
	arrival_left = maxf(arrival_delay_s, 0.0)
	_apply_active()


## True once the escape is active and its vehicle has arrived.
func has_arrived() -> bool:
	return active and arrival_left == 0.0


## HUD: seconds until the vehicle arrives (0 once arrived or while inactive).
func arrival_time_left() -> float:
	return arrival_left if active and arrival_left > 0.0 else 0.0


func _physics_process(delta: float) -> void:
	if not active or not Net.is_authority():
		return
	if arrival_left > 0.0:
		arrival_left = maxf(arrival_left - delta, 0.0)
		if arrival_left > 0.0:
			return
		_apply_active()
		_cue(&"cue.escape_arrive", global_position)
	if bag_only:
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
	var arrived: bool = active and arrival_left <= 0.0
	if zone != null:
		zone.set_deferred(&"monitoring", active)
		if bag_only and arrived and not zone.is_in_group(G.LOOT_SECURE_ZONE):
			zone.add_to_group(G.LOOT_SECURE_ZONE)
		elif not arrived and zone.is_in_group(G.LOOT_SECURE_ZONE):
			zone.remove_from_group(G.LOOT_SECURE_ZONE)
	if visual_root != null:
		visual_root.visible = arrived
