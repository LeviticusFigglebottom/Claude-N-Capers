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
## Navigation (A3-10): the ladder builds its own bidirectional NavigationLink3D child `NavLink` from
## the Bottom grab point to the Top grab point (the marker positions a climber stands at: Bottom is off
## the climb face on -Z on the floor, Top is on the landing), on navigation layer NAV_LAYER only. Every
## default agent / path query (NPCs, police, CrewAiBrain bots, civilians) uses layer 1 (`walkable`), so
## they never route over a ladder they cannot climb; a climber's query uses `1 | Ladder.NAV_LAYER`.
## The link is enabled while `usable` and the prefab is enabled.
## OF-A2 (QC-61): two switches, one NavLink. `usable` (replicated) = climbable while still shown (a grate-covered
## areaway ladder); GameplayPrefab `set_enabled` / `enabled_at_start` (replicated "pe") = present at all (hidden,
## no collision, not climbable, NavLink off: a rope ladder dropped down a breached hole). Climbable =
## `is_climbable()` = both; the NavLink always follows `is_climbable()`.
## OF-A6 (D-136, lead): `height_m` may change at runtime (the OF rope ladder stowed at 3.2 m, dropped to its
## `burn_height_m` 4.0 m at the burn-through): the placeholder's rails / Top and the NavLink ends re-fit (replicated,
## NetEntityCodec GENERIC_PROPS). An art visual keeps its own Top marker.
## PO-16 (D-145, ENV P free climb): a crew member flagged `set_free_climber(crew, true)` (P's CrewLadderClimb, real-input
## humans) is skipped by the walk-in / interact trigger here; `start_climb()` still works for scripts, tests and bots.
## Geometry for P's controller: climb_line(), face_normal(), top_step_off(), bottom_step_off().
class_name Ladder
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/ladder/ladder_placeholder.tscn")
## Height the placeholder is modelled at.
const PLACEHOLDER_HEIGHT_M: float = 3.0
## Crew meta set while climbing (value = this ladder).
const META_CLIMBING: StringName = &"climbing_ladder"
## PO-16: crew meta (true) = this crew climbs freely (ENV P's controller); no teleport-climb trigger.
const META_FREE_CLIMB: StringName = &"ladder_free_climb"
## Max height difference to a marker for a grab (m).
const GRAB_HEIGHT_M: float = 0.6
## Navigation layer bitmask value of ladder links: layer 4 (project name "ladder"; layer 2 is "npc_only").
## queries on layer 1 never use them; a climber (unburdened masked human crew) queries
## `1 | Ladder.NAV_LAYER`. NavigationLink3D ends connect to navmesh polygons within the map's
## link_connection_radius (Godot default 1.0 m), and the grab markers stand on the floor / landing.
const NAV_LAYER: int = 8
const NAV_LINK_NAME: String = "NavLink"

@export var height_m: float = 3.0:
	set(v):
		if is_equal_approx(height_m, v):
			return
		height_m = v
		if _nav_link != null:
			_fit_height()
## False: nobody can climb and the NavLink is disabled (the ladder stays visible; see set_enabled).
@export var usable: bool = true:
	set(v):
		usable = v
		_refresh_nav_link()

## slot -> { "path": PackedVector3Array, "length": float, "d": float (m travelled), "up": bool }
var _climbs: Dictionary[int, Dictionary] = {}
## slot -> true until interact / forward is released after a climb.
var _latch: Dictionary[int, bool] = {}
var _nav_link: NavigationLink3D = null


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Top", "Bottom"])


func _prefab_ready() -> void:
	_fit_placeholder()
	_setup_nav_link()
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null:
		rt.add_crew_tick_handler(_on_crew_tick)


## The placeholder's rails and Top follow height_m.
func _fit_placeholder() -> void:
	if not using_placeholder:
		return
	var rails: Node3D = visual_node("Rails") as Node3D
	if rails != null:
		rails.scale.y = height_m / PLACEHOLDER_HEIGHT_M
	var top: Node3D = visual_node("Top") as Node3D
	if top != null:
		top.position.y = height_m


## OF-A6: a runtime height change re-fits the placeholder and the NavLink ends.
func _fit_height() -> void:
	_fit_placeholder()
	_nav_link.start_position = _local_of(bottom_position())
	_nav_link.end_position = _local_of(top_position())


## OF-A2: climbable now (usable and the prefab enabled).
func is_climbable() -> bool:
	return usable and prefab_enabled


func _on_enabled_changed(on: bool) -> void:
	_refresh_nav_link()
	if not on:
		for slot: int in _climbs.keys():  # a climber on a ladder that goes away lets go where he is
			var crew: CrewController = _crew_of(slot)
			if crew != null:
				_end(crew)
			else:
				_climbs.erase(slot)


func _refresh_nav_link() -> void:
	if _nav_link != null:
		_nav_link.enabled = is_climbable()


func _crew_of(slot: int) -> CrewController:
	var rt: HeistRuntime = HeistRuntime.of(self)
	return rt.crew_controller(slot) as CrewController if rt != null else null


## The ladder's NavigationLink3D (layer NAV_LAYER), or null before ready.
func nav_link() -> NavigationLink3D:
	return _nav_link


## Link ends at the grab points (ladder-local): Bottom on the floor at the foot (-Z side), Top on the
## landing. Both are where `_near` lets a climber grab, so an agent arriving at an end can climb.
func _setup_nav_link() -> void:
	_nav_link = NavigationLink3D.new()
	_nav_link.name = NAV_LINK_NAME
	_nav_link.bidirectional = true
	_nav_link.navigation_layers = NAV_LAYER
	_nav_link.start_position = _local_of(bottom_position())
	_nav_link.end_position = _local_of(top_position())
	_nav_link.enabled = is_climbable()
	add_child(_nav_link)


func _local_of(world: Vector3) -> Vector3:
	return to_local(world) if is_inside_tree() else world - position


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


## PO-16: world bottom and top of the vertical a climber holds: [Bottom, (Bottom.x, Top.y, Bottom.z)].
func climb_line() -> Array[Vector3]:
	var b: Vector3 = bottom_position()
	return [b, Vector3(b.x, top_position().y, b.z)]


## PO-16: flat unit direction from the climb side toward the wall / ledge (+Z of the ladder).
func face_normal() -> Vector3:
	var z: Vector3 = global_basis.z
	z.y = 0.0
	return z.normalized() if z.length() > 0.001 else Vector3.BACK


## PO-16: where a climber steps off at the top (the landing, `Top`).
func top_step_off() -> Vector3:
	return top_position()


## PO-16: where a climber steps off at the bottom (the floor at the foot, `Bottom`).
func bottom_step_off() -> Vector3:
	return bottom_position()


## PO-16: flag `crew` as a free climber (ENV P's controller drives it): the walk-in / interact trigger skips it.
static func set_free_climber(crew: Node, on: bool) -> void:
	if crew == null:
		return
	if on:
		crew.set_meta(META_FREE_CLIMB, true)
	elif crew.has_meta(META_FREE_CLIMB):
		crew.remove_meta(META_FREE_CLIMB)


static func is_free_climber(crew: Node) -> bool:
	return crew != null and bool(crew.get_meta(META_FREE_CLIMB, false))


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
	if not is_climbable():
		return false
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
	if is_free_climber(crew):  # PO-16: ENV P's controller climbs this crew
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
