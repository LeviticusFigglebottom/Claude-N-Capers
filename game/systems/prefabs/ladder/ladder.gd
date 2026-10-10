## Climbable ladder (S9.11). Owner: ENV A.
## Floor object: pivot bottom-centre, climb side -Z, wall/ledge at +Z.
## Visual: `Top` and `Bottom` markers (climb end points). The placeholder is resized to `height_m`.
## Climbing (server, teleport-with-duration): a masked crew member in NORMAL state standing within
## ladder_grab_radius_m of `Bottom` (or `Top`) who holds interact, or moves forward while facing the
## ladder (ladder_forward_cone_deg), is moved at ladder_climb_speed_mps along
## Bottom -> (Bottom.x, Top.y, Bottom.z) -> Top (reversed going down), with no physics in between.
## S1.1: casing (unmasked) crew cannot climb. S10.1b (A3-10): nor can crew carrying a bag.
## Downed / tased mid-climb = let go where they are.
## After a climb the crew member must release interact / forward before grabbing again.
## Runs from a HeistRuntime crew tick handler (after the crew's own movement each tick), so it needs
## no CrewController state. P2 limitation: remote humans (client-predicted movement) are not moved.
class_name Ladder
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/ladder/ladder_placeholder.tscn")
## Height the placeholder is modelled at.
const PLACEHOLDER_HEIGHT_M: float = 3.0
## Crew meta set while climbing (value = this ladder).
const META_CLIMBING: StringName = &"climbing_ladder"
## Max height difference to a marker for a grab (m).
const GRAB_HEIGHT_M: float = 0.6

@export var height_m: float = 3.0

## slot -> { "path": PackedVector3Array, "length": float, "d": float (m travelled), "up": bool }
var _climbs: Dictionary[int, Dictionary] = {}
## slot -> true until interact / forward is released after a climb.
var _latch: Dictionary[int, bool] = {}


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Top", "Bottom"])


func _prefab_ready() -> void:
	if using_placeholder:
		var rails: Node3D = visual_node("Rails") as Node3D
		if rails != null:
			rails.scale.y = height_m / PLACEHOLDER_HEIGHT_M
		var top: Node3D = visual_node("Top") as Node3D
		if top != null:
			top.position.y = height_m
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null:
		rt.add_crew_tick_handler(_on_crew_tick)


func is_climbing(slot: int) -> bool:
	return _climbs.has(slot)


## 0..1 progress of slot's climb (0 when not climbing).
func climb_progress(slot: int) -> float:
	if not _climbs.has(slot):
		return 0.0
	var c: Dictionary = _climbs[slot]
	return clampf(float(c["d"]) / maxf(float(c["length"]), 0.001), 0.0, 1.0)


func top_position() -> Vector3:
	var n: Node3D = visual_node("Top") as Node3D
	return n.global_position if n != null else global_position + Vector3.UP * height_m


func bottom_position() -> Vector3:
	var n: Node3D = visual_node("Bottom") as Node3D
	return n.global_position if n != null else global_position


## Seconds a full climb takes.
func climb_time() -> float:
	return _path_length(_path(true)) / maxf(Tweak.interaction().ladder_climb_speed_mps, 0.01)


## Server: start climbing (tests / AI). Returns false if `crew` cannot climb now.
func start_climb(crew: CrewController, up: bool) -> bool:
	if not Net.is_authority() or crew == null or _climbs.has(crew.slot) or not _can_climb(crew):
		return false
	var path: PackedVector3Array = _path(up)
	_climbs[crew.slot] = {"path": path, "length": _path_length(path), "d": 0.0, "up": up}
	crew.set_meta(META_CLIMBING, self)
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null and rt.interaction != null:
		rt.interaction.cancel(crew.slot)
	return true


func _can_climb(crew: CrewController) -> bool:
	if crew.crew_state != Enums.CrewState.NORMAL or crew.is_casing():  # S1.1
		return false
	if crew.is_carrying_bag():  # S10.1b (QC-17): no ladders with a bag; throw it or use a lift/zipline
		return false
	if not crew.has_meta(META_CLIMBING):
		return true
	return not is_instance_valid(crew.get_meta(META_CLIMBING))


func _on_crew_tick(crew: CrewController, intent: CrewIntent, delta: float) -> void:
	if not Net.is_authority() or not is_inside_tree():
		return
	if _climbs.has(crew.slot):
		_advance(crew, delta)
		return
	var wants: bool = intent != null and (intent.interact or intent.move.y > 0.5)
	if not wants:
		_latch.erase(crew.slot)
		return
	if _latch.get(crew.slot, false):
		return
	var bottom: Vector3 = bottom_position()
	var top: Vector3 = top_position()
	if _near(crew.global_position, bottom) and _triggered(crew, intent):
		start_climb(crew, true)
	elif _near(crew.global_position, top) and _triggered(crew, intent):
		start_climb(crew, false)


func _triggered(crew: CrewController, intent: CrewIntent) -> bool:
	if intent.interact:
		return true
	var to: Vector3 = global_position - crew.global_position
	to.y = 0.0
	var fwd: Vector3 = crew.aim_direction()
	fwd.y = 0.0
	if to.length() < 0.01 or fwd.length() < 0.01:
		return false
	return fwd.angle_to(to) <= deg_to_rad(Tweak.interaction().ladder_forward_cone_deg)


func _near(p: Vector3, marker: Vector3) -> bool:
	var flat: Vector2 = Vector2(p.x - marker.x, p.z - marker.z)
	return flat.length() <= Tweak.interaction().ladder_grab_radius_m and absf(p.y - marker.y) <= GRAB_HEIGHT_M


func _advance(crew: CrewController, delta: float) -> void:
	var c: Dictionary = _climbs[crew.slot]
	if crew.crew_state != Enums.CrewState.NORMAL:
		_end(crew)  # let go
		return
	var d: float = float(c["d"]) + Tweak.interaction().ladder_climb_speed_mps * delta
	c["d"] = d
	var path: PackedVector3Array = c["path"]
	crew.global_position = _point_at(path, d)
	crew.velocity = Vector3.ZERO
	if d >= float(c["length"]):
		crew.global_position = path[path.size() - 1]
		_end(crew)


func _end(crew: CrewController) -> void:
	_climbs.erase(crew.slot)
	_latch[crew.slot] = true
	if crew.has_meta(META_CLIMBING) and crew.get_meta(META_CLIMBING) == self:
		crew.remove_meta(META_CLIMBING)


func _path(up: bool) -> PackedVector3Array:
	var b: Vector3 = bottom_position()
	var t: Vector3 = top_position()
	var mid: Vector3 = Vector3(b.x, t.y, b.z)
	return PackedVector3Array([b, mid, t]) if up else PackedVector3Array([t, mid, b])


static func _path_length(path: PackedVector3Array) -> float:
	var l: float = 0.0
	for i: int in range(1, path.size()):
		l += path[i - 1].distance_to(path[i])
	return l


static func _point_at(path: PackedVector3Array, d: float) -> Vector3:
	var left: float = d
	for i: int in range(1, path.size()):
		var seg: float = path[i - 1].distance_to(path[i])
		if left <= seg and seg > 0.0:
			return path[i - 1].lerp(path[i], left / seg)
		left -= seg
	return path[path.size() - 1]
