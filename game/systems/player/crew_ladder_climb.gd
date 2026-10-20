## PO-16 / D-145: PD2-style free ladder climbing for human crew (PD2 PlayerMovement ladder state). Owner: ENV P.
## Held by CrewController (`ladder`) and ticked from its movement simulation (server, and the owning client's
## prediction). Walking into a ladder's climb line while facing it attaches; while attached W/S moves along the
## ladder, the direction set by the look pitch (looking down below ladder_down_pitch_deg reverses it: look down +
## forward climbs down), gravity is off and the player keeps full look (no camera lock, no forced animation).
## Jump lets go (pushed off the wall); reaching the bottom steps off onto the floor; climbing past the top steps off
## toward the Top marker on the landing. Rules kept from the Ladder prefab: masked only (S1.1 casing), no bag
## (S10.1b), NORMAL state only (downed / tased = let go). Bots keep Ladder's own climb: the human opts out of it with
## Ladder.META_CLIMBING pointing at the crew (Ladder._can_climb refuses a live climbing meta) on the ticks the prefab
## could start one; a climb the prefab already runs (Ladder.start_climb) is left alone.
## Geometry (Ladder): climb side -Z of the prefab; `bottom_position()` stands off the face on the floor;
## `top_position()` stands on the landing. The climb line is the vertical through the bottom marker, from its height
## up to the top marker's height (the same path Ladder's own climb uses).
## Numbers: CrewTweak "Ladders" group.
class_name CrewLadderClimb
extends RefCounted

## Farther than this from both the climb line and the Top marker (m): the crew was moved off the ladder.
const LET_GO_M: float = 1.5

## The ladder attached to (null = not climbing).
var ladder: Ladder = null
## Stepping off at the top: moving toward the Top marker until on the landing.
var stepping_off: bool = false

var _crew: CrewController = null
var _ladders: Array[Ladder] = []
var _scanned: bool = false
var _jump_latch: bool = false


func _init(crew: CrewController) -> void:
	_crew = crew


func is_climbing() -> bool:
	return ladder != null


## Opt the human crew out of Ladder's own (teleport) climb, or back in (free climbing off / a bot).
func sync_opt_out(on: bool) -> void:
	var has: bool = _crew.has_meta(Ladder.META_CLIMBING) and _crew.get_meta(Ladder.META_CLIMBING) == _crew
	if on and not has and not _crew.has_meta(Ladder.META_CLIMBING):
		_crew.set_meta(Ladder.META_CLIMBING, _crew)
	elif not on and has:
		_crew.remove_meta(Ladder.META_CLIMBING)


## One movement tick. Returns true when the ladder drove the velocity this tick (the caller then skips its
## walking / gravity / jump and just moves).
func tick(i: CrewIntent, delta: float, tw: CrewTweak) -> bool:
	if ladder != null and not _still_ok(ladder):
		_detach()
	if ladder == null:
		_jump_latch = _jump_latch and i.jump
		var l: Ladder = _find_attach(i, tw)
		if l == null:
			return false
		ladder = l
		stepping_off = false
		_jump_latch = i.jump
	return _climb(i, delta, tw)


func _climb(i: CrewIntent, delta: float, tw: CrewTweak) -> bool:
	var bottom: Vector3 = ladder.bottom_position()
	var top: Vector3 = ladder.top_position()
	var pos: Vector3 = _crew.global_position
	if i.jump and not _jump_latch:  # let go: off the wall (the climb side is -Z of the prefab)
		var off: Vector3 = -ladder.global_basis.z
		off.y = 0.0
		off = off.normalized() if off.length() > 0.01 else Vector3.BACK
		_crew.velocity = off * tw.ladder_jump_off_mps + Vector3.UP * tw.ladder_jump_off_up_mps
		_jump_latch = true
		_detach()
		return true
	_jump_latch = _jump_latch and i.jump
	if stepping_off:
		var to: Vector3 = Vector3(top.x - pos.x, 0.0, top.z - pos.z)
		if to.length() < 0.15 or (_crew.grounded and to.length() < 0.6):
			_detach()
			return false
		var v: Vector3 = to.normalized() * tw.ladder_step_off_mps
		_crew.velocity = Vector3(v.x, maxf(top.y + 0.05 - pos.y, 0.0) * 4.0, v.z)
		return true
	var dir: float = i.move.y  # forward / back
	if _crew.look_pitch < deg_to_rad(tw.ladder_down_pitch_deg):
		dir = -dir
	var vy: float = clampf(dir, -1.0, 1.0) * tw.ladder_climb_speed_mps
	if pos.y >= top.y - 0.02 and vy > 0.0:  # past the top: step off onto the landing
		stepping_off = true
		return _climb(i, delta, tw)
	if pos.y <= bottom.y + 0.02 and vy < 0.0:  # at the bottom: step off onto the floor
		_detach()
		return false
	# Held on the climb line (the bottom marker's vertical), with no gravity.
	var line: Vector3 = Vector3(bottom.x - pos.x, 0.0, bottom.z - pos.z)
	var pull: Vector3 = line * clampf(tw.ladder_snap_rate * delta, 0.0, 1.0) / maxf(delta, 0.0001)
	_crew.velocity = Vector3(pull.x, vy, pull.z)
	return true


func _detach() -> void:
	ladder = null
	stepping_off = false


func _still_ok(l: Ladder) -> bool:
	if not is_instance_valid(l) or not l.is_inside_tree() or not l.is_climbable() or not _can_climb():
		return false
	# Moved off the ladder by something else (a teleport, a respawn): let go.
	var pos: Vector3 = _crew.global_position
	var b: Vector3 = l.bottom_position()
	var t: Vector3 = l.top_position()
	var near_line: bool = Vector2(pos.x - b.x, pos.z - b.z).length() <= LET_GO_M
	var near_top: bool = Vector2(pos.x - t.x, pos.z - t.z).length() <= LET_GO_M
	return (near_line or near_top) and pos.y >= b.y - 0.5 and pos.y <= t.y + 1.0


func _can_climb() -> bool:
	var m: Variant = _crew.get_meta(Ladder.META_CLIMBING, null)
	if is_instance_valid(m) and m is Ladder:
		return false  # the prefab's own climb has the crew (Ladder.start_climb)
	return _crew.crew_state == Enums.CrewState.NORMAL and not _crew.is_casing() and not _crew.is_carrying_bag()


## A ladder whose climb line the crew is walking into (facing it, moving forward), or standing at the top of and
## walking toward the edge with the look pitched down (to climb down).
func _find_attach(i: CrewIntent, tw: CrewTweak) -> Ladder:
	if i.move.y < 0.1 or not _can_climb():
		return null
	var pos: Vector3 = _crew.global_position
	var fwd: Vector3 = _crew.aim_direction()
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return null
	fwd = fwd.normalized()
	for l: Ladder in _all_ladders():
		if not is_instance_valid(l) or not l.is_climbable():
			continue
		var bottom: Vector3 = l.bottom_position()
		var top: Vector3 = l.top_position()
		var wall: Vector3 = l.global_basis.z  # from the climb side toward the wall / ledge
		wall.y = 0.0
		wall = wall.normalized() if wall.length() > 0.01 else Vector3.FORWARD
		var flat: Vector2 = Vector2(pos.x - bottom.x, pos.z - bottom.z)
		var on_line: bool = flat.length() <= tw.ladder_attach_radius_m and pos.y >= bottom.y - 0.3 \
			and pos.y <= top.y - 0.3
		if on_line and fwd.angle_to(wall) <= deg_to_rad(tw.ladder_attach_cone_deg):
			return l
		# From the landing: near the top, walking back over the edge toward the climb side, looking down.
		var flat_top: Vector2 = Vector2(pos.x - top.x, pos.z - top.z)
		if flat_top.length() <= tw.ladder_attach_radius_m + 0.4 and absf(pos.y - top.y) <= 0.6 \
				and fwd.angle_to(-wall) <= deg_to_rad(tw.ladder_attach_cone_deg) \
				and _crew.look_pitch < deg_to_rad(tw.ladder_down_pitch_deg):
			_crew.global_position = Vector3(bottom.x, top.y - 0.05, bottom.z)  # over the edge onto the rungs
			return l
	return null


func _all_ladders() -> Array[Ladder]:
	if not _scanned:
		_scanned = true
		var rt: HeistRuntime = HeistRuntime.of(_crew)
		var root: Node = rt if rt != null else _crew.get_tree().current_scene
		if root != null:
			for n: Node in root.find_children("*", "Ladder", true, false):
				_ladders.append(n as Ladder)
	return _ladders
