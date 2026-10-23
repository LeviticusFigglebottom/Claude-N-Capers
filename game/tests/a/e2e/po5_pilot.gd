# gdlint:disable=max-public-methods
## PO-5 (D-086): walks the local player like a person would. Owner: ENV A (test support).
## Everything goes through PlayerInputDriver (Input.parse_input_event): mouse motion turns, WASD moves,
## F interacts, G masks. The route comes from the navmesh (what a player who knows the map would walk);
## the pilot never teleports, never sets bot intents and never writes game state.
## Stuck detection: holding forward with < stuck_min_m progress in stuck_window_s is logged as a
## blocker row (position + what is in front), then the pilot tries jump / strafe before giving up.
class_name Po5Pilot
extends RefCounted

## Ticks without an interaction session before use() presses interact again (interrupted hold).
const REPRESS_TICKS: int = 20
## use() on a door walks (opening doors on the way) to within this of it before open_door() squares up (m).
const DOOR_NEAR_M: float = 1.8
## "Near" is also within this height (m): a target one floor up / down is not near (ND: the pilot stood over the
## basement VaultGate and pressed its reader through the slab).
const NEAR_DY_M: float = 1.5
## goto(): a closed door whose doorway the route crosses within this of the crew is opened first (m).
const DOOR_LOOKAHEAD_M: float = 1.8
## _pass_leaf: half width of a clear lane through a doorway (crew capsule radius 0.35, less a little) (m).
const LANE_HALF_M: float = 0.3
## _through_link: inside this (m) of an open door's plane the pilot walks straight across, ending this far past it.
const THROUGH_DOOR_M: float = 0.8  # < THROUGH_PAST_M, or the crossing never ends (DB-7 q4 ANEast)
const THROUGH_PAST_M: float = 0.9
## _door_on_line: a closed door within this (m) of the crew's plane is opened before stepping across it.
const LINE_DOOR_M: float = 1.0
## _through_link: how far along the nav path (m) a crossing of the doorway counts as "the route leaves through it".
## shoots_from_floor: at most this many alive enemies within FLOOR_FIGHT_M (m) for a downed pilot to fight back.
const FLOOR_FIGHT_MAX: int = 3  # LEAD: hold fire with 4+ enemies near
const FLOOR_FIGHT_M: float = 20.0
## engage(): with an empty mag, an enemy this close (m) gets the other weapon or a melee strike (_close_quarters).
const CLOSE_QUARTERS_M: float = 2.5
const THROUGH_LOOKAHEAD_M: float = 4.0
## goto: standing at the end of a nav path that stops this far (m, flat) short of the target = unreachable (OF-X2).
const UNREACHABLE_M: float = 2.0
## Loud: a visible enemy within this range is fought before / during a hold (S9.1: damage cancels holds) (m).
const HOLD_THREAT_M: float = 20.0
## Longest clearing fight before holding anyway (s).
const CLEAR_MAX_S: float = 15.0
## Eye-ray probe drops below the head for visibility / aim: head, chest, hips (m).
const AIM_DROPS: Array[float] = [0.0, 0.45, 0.8]
## D-122: the crew (and this pilot) path on navigation layer 1 only. Breach links of loud-breachable locked doors sit on
## Door.NAV_LAYER_BREACH (layer 2, police / specials), so a shut locked door reads as no path.
const NAV_LAYERS_CREW: int = 1
## P's GN-P1 rerun (out of ammo at the Argus terminal): reload in a lull once the mag is below this share of its size.
const TOP_UP_FRACTION: float = 0.5
## goto(): seconds between lull reload checks while walking.
const TOP_UP_EVERY_S: float = 1.0

var d: Node = null  # po5_flow driver (note(), shot())
var inp: PlayerInputDriver = null
var crew: CrewController = null
var stuck_window_s: float = 2.0
var stuck_min_m: float = 0.35
## Max mouse travel per physics tick (px): a fast but human flick.
var max_px_per_tick: float = 120.0
var stuck_spots: Array[Dictionary] = []
## Loud: shoot enemies in sight while walking / waiting.
var combat: bool = false
## Where to look while holding a position with nobody in sight (the doorway the police come through).
var watch_point: Vector3 = Vector3.INF
var shots_fired: int = 0
## Stealth hook: every goto / use tick (not while answering a pager) the pilot asks `hook_need`
## (`func() -> bool`, synchronous); when true it lets go of its keys and awaits `hook` (`func() -> bool`,
## may take over the input: shout a civilian...; returns true when it acted), then carries on.
var hook_need: Callable = Callable()
var hook: Callable = Callable()
## goto() does not log its timeouts (short step-wise gotos while stalking).
var quiet: bool = false
## _unstick shouts at a civilian blocking the way at once (loud flows). Stealth turns it off: it backs off
## and lets them pass first, and shouts only after 4 tries (a shouted civilian gets up panicked when the
## intimidation runs out, so the stealth flow then has to keep them down).
var shout_blockers: bool = true
## With shout_blockers off: unstick tries before the pilot shouts at a civilian anyway.
var block_shout_after: int = 4
## goto() also needs |dy| <= this to arrive (INF = horizontal distance only; stealth flows set it for stairs).
var arrive_dy: float = NEAR_DY_M
## The closed door the last goto() gave up at because the crew cannot open it now (GN loud: the lockdown-BARRED
## Calloway shutter; the navmesh still runs through the doorway), else null.
var last_blocked_door: Door = null
## goto(): stuck recoveries in one leg before it gives up, 0 = never (auto_loud sets it: the caller re-plans, sets the
## target aside, other markers first). P's GN loud rerun: STUCK x4 on the BronzeDoorsE LeafBody2, then 1200 s there.
var stuck_give_up: int = 0
## The ladder the last goto() stopped at because the crew carries a bag (ladders refuse bags, S10.1b), else null.
var last_ladder_with_bag: Ladder = null
## The last goto() gave up after `stuck_give_up` stuck recoveries (no progress), not at a door or a timeout.
var last_goto_stuck: bool = false
## Stealth: never press F unless the component is aimed (a press with nothing usable aimed is a shout,
## S7.1: it puts every civilian within shout_all_within_m down, the sales floor through the wall).
var no_blind_press: bool = false
var _in_hook: bool = false
var _last_engage: float = -1.0
var _door_tries: Dictionary[Door, int] = {}
## Nesting of the short detour walks goto() makes when stuck (they do not detour again).
var _detour_depth: int = 0
## Ladders of the heist (found once) and a climb in progress (no ladder legs inside it).
var _ladders: Array[Ladder] = []
var _climbing: bool = false
## _through_link hysteresis: the door being crossed, for which target, to which side (its local z sign).
var _through_door: Door = null
var _through_target: Vector3 = Vector3.INF
var _through_side: float = 0.0
var _rad_px: Vector2 = Vector2.ONE


func _init(driver: Node, p_crew: CrewController) -> void:
	d = driver
	crew = p_crew
	inp = PlayerInputDriver.new(driver)
	# PO-5.1: the game captures the mouse itself (MouseCapture, D-087); po5_flow clicks like a player
	_rad_px = PlayerInputDriver.mouse_radians_per_px()


func dt() -> float:
	return 1.0 / Engine.physics_ticks_per_second


func tick() -> void:
	await d.get_tree().physics_frame


## One mouse correction toward (yaw, pitch); returns the remaining yaw error (rad).
## The error is measured against PlayerInput's own look (read-only peek): injected mouse events are flushed into
## it synchronously, while crew.look_yaw follows a physics tick later (several ticks bunch up under load).
## Steering from the lagging crew value made corrections stack and limit-cycle across +-PI.
func steer(yaw: float, pitch: float) -> float:
	var cur: Vector2 = _view()
	var ey: float = wrapf(yaw - cur.x, -PI, PI)
	var ep: float = pitch - cur.y
	var px: Vector2 = Vector2(-ey / _rad_px.x, -ep / _rad_px.y)
	if px.length() > max_px_per_tick:
		px = px.normalized() * max_px_per_tick
	if px.length() > 0.05:
		inp.look(px.x, px.y)
	return ey


## (yaw, pitch) the player is steering: PlayerInput's accumulators, else the crew's look.
func _view() -> Vector2:
	var pin: Node = crew.get_node_or_null(^"PlayerInput")
	var y: Variant = pin.get(&"_yaw") if pin != null else null
	var p: Variant = pin.get(&"_pitch") if pin != null else null
	if y is float and p is float:
		return Vector2(float(y), float(p))
	return Vector2(crew.look_yaw, crew.look_pitch)


## Measure the live mouse -> look mapping like a player getting used to the sensitivity: nudge the mouse,
## see how far (and which way) the view moved. Sets _rad_px (radians per px; the sign included), so the
## steering does not depend on settings / sensitivity formulas staying as the harness assumes.
func calibrate() -> void:
	for axis: int in 2:
		var px: Vector2 = Vector2(40.0, 0.0) if axis == 0 else Vector2(0.0, 30.0)
		var before: float = _view().x if axis == 0 else _view().y
		inp.look(px.x, px.y)
		var moved: float = 0.0
		for _f: int in 12:
			await d.get_tree().process_frame
			await tick()
			moved = (_view().x if axis == 0 else _view().y) - before
			if absf(moved) > 1e-5:
				break
		if absf(moved) <= 1e-5:
			d.note("FINDING calibrate: mouse %s motion did not move the view" % ["X" if axis == 0 else "Y"])
			continue
		var per_px: float = -moved / (px.x if axis == 0 else px.y)  # steer: look delta = -px * rad_px
		if axis == 0:
			_rad_px.x = per_px
		else:
			_rad_px.y = per_px
		inp.look(-px.x, -px.y)  # put the view back
		for _g: int in 3:
			await d.get_tree().process_frame
	d.note("pilot: calibrated %.6f rad/px yaw, %.6f rad/px pitch (settings formula said %s)" % [_rad_px.x, _rad_px.y,
		PlayerInputDriver.mouse_radians_per_px()])


func steer_at(point: Vector3) -> void:
	var v: Vector3 = point - crew.eye_position()
	steer(atan2(-v.x, -v.z), atan2(v.y, Vector2(v.x, v.z).length()))


func face(point: Vector3, tol: float = 0.03, timeout_s: float = 3.0) -> bool:
	var t: float = 0.0
	while t < timeout_s:
		var v: Vector3 = point - crew.eye_position()
		var yaw: float = atan2(-v.x, -v.z)
		var pitch: float = atan2(v.y, Vector2(v.x, v.z).length())
		var ey: float = steer(yaw, pitch)
		if absf(ey) <= tol and absf(pitch - _view().y) <= tol:
			await tick()  # the crew applies the look a physics tick later
			await tick()
			return true
		await tick()
		t += dt()
	return false


func nav_path(to: Vector3) -> PackedVector3Array:
	var map: RID = crew.get_world_3d().navigation_map
	return NavPath.query(map, crew.global_position, to, true, NAV_LAYERS_CREW | Ladder.NAV_LAYER)


## OF-A6 (Haz seed 5: 15 min at the burnt hole's edge): the climbable Ladder whose NavLink the leg to `corner` takes, as
## [ladder, up], else []. The path reaches the ladder's far end while the crew stands at its near end.
func _ladder_leg(corner: Vector3) -> Array:
	if _climbing:
		return []
	if _ladders.is_empty():
		var rt: HeistRuntime = HeistRuntime.of(crew)
		if rt != null:
			for n: Node in rt.find_children("*", "Ladder", true, false):
				_ladders.append(n as Ladder)
	var pos: Vector3 = crew.global_position
	for l: Ladder in _ladders:
		if not is_instance_valid(l) or not l.is_climbable():
			continue
		var bottom: Vector3 = l.bottom_position()
		var top: Vector3 = l.top_position()
		if flat_dist(pos, bottom) <= 1.5 and absf(pos.y - bottom.y) <= 1.0 and corner.y > pos.y + 1.0 \
				and corner.distance_to(top) <= 1.6:
			return [l, true]
		if flat_dist(pos, top) <= 1.5 and absf(pos.y - top.y) <= 1.0 and corner.y < pos.y - 1.0 \
				and corner.distance_to(bottom) <= 1.6:
			return [l, false]
	return []


## Climb `l` like a player with ENV P's free climb (CrewLadderClimb): up = stand on the climb line facing the wall and
## hold forward (level look); down = stand at the Top marker facing the climb side, look down past
## ladder_down_pitch_deg and hold forward. True when the crew reached the other end.
func climb_ladder(l: Ladder, up: bool) -> bool:
	_climbing = true
	var bottom: Vector3 = l.bottom_position()
	var top: Vector3 = l.top_position()
	var wall: Vector3 = l.face_normal()
	d.note("pilot: ladder %s %s (%.1f m)" % [l.name, "up" if up else "down", top.y - bottom.y])
	var ok: bool = false
	if await goto(bottom if up else top - wall * 0.3, 0.3, 20.0, false, false):
		var look: Vector3 = (bottom + wall + Vector3.UP * 1.6) if up else (bottom - wall * 0.6)
		await face(look, 0.05, 2.0)
		inp.press(&"move_forward")
		var t: float = 0.0
		var limit: float = (top.y - bottom.y) / maxf(Tweak.crew().ladder_climb_speed_mps, 0.5) + 6.0
		while t < limit and crew.crew_state == Enums.CrewState.NORMAL:
			var y: float = crew.global_position.y
			if (up and y >= top.y - 0.15 and not crew.ladder.is_climbing()) \
					or (not up and y <= bottom.y + 0.3 and not crew.ladder.is_climbing()):
				ok = true
				break
			steer(atan2(-(look - crew.eye_position()).x, -(look - crew.eye_position()).z),
				deg_to_rad(Tweak.crew().ladder_down_pitch_deg - 25.0) if not up else 0.0)
			await tick()
			t += dt()
		inp.release(&"move_forward")
	d.note("pilot: ladder %s %s -> %s at %s" % [l.name, "up" if up else "down", "OK" if ok else "FAILED",
		_v(crew.global_position)])
	_climbing = false
	return ok


## ENV C (DB-7 ChamberBSouth): D-073 doors are baked CLOSED; an open one is crossed by its NavLink over a ~1.2 m
## off-mesh gap, where map_get_path snaps the start to either gap edge and the corner flips. Inside an open door's
## doorway (|local z| < THROUGH_DOOR_M, within its width) with the target beyond THROUGH_PAST_M on the far side: walk straight along the
## door normal to THROUGH_PAST_M past the plane (inside the opening). Else null.
func _through_link(target: Vector3, path: PackedVector3Array = PackedVector3Array()) -> Variant:
	var out: Variant = _through_link_pick(target, path)
	if out == null:
		_through_door = null
	return out


func _through_link_pick(target: Vector3, path: PackedVector3Array) -> Variant:
	for n: Node in crew.get_tree().get_nodes_in_group(Door.GROUP):
		var door: Door = n as Door
		if door == null or not door.is_open:
			continue
		var inv: Transform3D = door.global_transform.affine_inverse()
		var me: Vector3 = inv * crew.global_position
		if absf(me.z) >= THROUGH_DOOR_M or absf(me.y) > NEAR_DY_M:
			continue
		var half: float = door.effective_width() * 0.5
		if absf(me.x) > half:
			continue
		var x: float = clampf(me.x, -half + LANE_HALF_M + 0.1, half - LANE_HALF_M - 0.1)
		if door == _through_door and target.is_equal_approx(_through_target):
			# B's DB GatehouseNorth stall: inside the band the path start snaps to either edge of the door's NavLink gap,
			# so the crossing side flipped every re-plan (the pilot shuttled between the two corners). Keep the first.
			return door.global_transform * Vector3(x, 0.0, _through_side * THROUGH_PAST_M)
		var tz: float = (inv * target).z
		var via: float = path_crosses(door, path)
		if via == 0.0:
			via = path_side(door, path)  # the path's own way out of the doorway, not the straight line to the target
		if via != 0.0:
			tz = via * (THROUGH_PAST_M + 1.0)  # OF-X1 ND XferDoor: the path leaves through this door to a target behind us
		if absf(tz) <= THROUGH_PAST_M or (signf(tz) == signf(me.z) and absf(tz) <= absf(me.z)):
			continue  # the target is on this side, or about in the door's plane (OF-X1 ND RecordsDoor: a corridor
			# target 0.1 m off the plane of the door across the hall pinned the pilot between the two corners)
		_through_door = door
		_through_target = target
		_through_side = signf(tz)
		return door.global_transform * Vector3(x, 0.0, _through_side * THROUGH_PAST_M)
	return null


## The side (+1 / -1, the door's local z) of the first `path` point past THROUGH_PAST_M from `door`'s plane (same floor)
## within THROUGH_LOOKAHEAD_M, else 0. B's DB GatehouseNorth stall: the start snapped to the gap's far edge (no
## crossing), and the straight line to the target (north) disagreed with the path (south, then around).
static func path_side(door: Door, path: PackedVector3Array) -> float:
	var inv: Transform3D = door.global_transform.affine_inverse()
	var left: float = THROUGH_LOOKAHEAD_M
	for i: int in range(path.size()):
		if i > 0:
			left -= path[i - 1].distance_to(path[i])
			if left < 0.0:
				break
		var l: Vector3 = inv * path[i]
		if absf(l.z) > THROUGH_PAST_M and absf(l.y) <= NEAR_DY_M:
			return signf(l.z)
	return 0.0


## The side (+1 / -1, the door's local z) the nav `path` crosses `door`'s doorway to within THROUGH_LOOKAHEAD_M of its
## start, else 0 (no crossing, or no path). The way the crossing step goes (not its end's side: B's DB count_cage
## stall, the StairMezz path has a corner exactly in the door's plane, local z 0, so the pilot turned back).
static func path_crosses(door: Door, path: PackedVector3Array) -> float:
	var left: float = THROUGH_LOOKAHEAD_M
	var up: Vector3 = Vector3.UP * 0.5
	for i: int in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		if door.doorway_crossing(a + up, b + up) != Vector3.INF:
			var inv: Transform3D = door.global_transform.affine_inverse()
			return signf((inv * b).z - (inv * a).z)
		left -= a.distance_to(b)
		if left <= 0.0:
			break
	return 0.0


## DB-7 (ChamberASpine): the door whose plane is within LINE_DOOR_M of the crew (same floor) and which the step to
## the next path `corner` crosses inside its width; door_ahead misses D-073 doors (the path ends at the NavLink end).
## The corner, not the heist target: a door the crew merely stands beside is not on its way (DB-7 q3 DockRoller).
func _door_on_line(corner: Vector3) -> Door:
	for n: Node in crew.get_tree().get_nodes_in_group(Door.GROUP):
		var door: Door = n as Door
		if door == null:
			continue
		var inv: Transform3D = door.global_transform.affine_inverse()
		var me: Vector3 = inv * crew.global_position
		if absf(me.z) >= LINE_DOOR_M or absf(me.y) > NEAR_DY_M:
			continue
		var to: Vector3 = inv * corner
		if absf(to.z) < 0.05 or signf(to.z) == signf(me.z):
			continue  # the step does not cross the plane
		var x: float = lerpf(me.x, to.x, absf(me.z) / (absf(me.z) + absf(to.z)))
		if absf(x) <= door.effective_width() * 0.5:
			return door
	return null


## Within `r` horizontally AND on the same floor (|dy| <= NEAR_DY_M).
func near(a: Vector3, b: Vector3, r: float) -> bool:
	return flat_dist(a, b) <= r and absf(a.y - b.y) <= NEAR_DY_M


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Walks to `target` along the navmesh until within `arrive_m` (horizontal). Returns success.
func goto(target: Vector3, arrive_m: float = 0.8, timeout_s: float = 60.0, sprint: bool = false,
		doors: bool = true) -> bool:
	var t: float = 0.0
	var path: PackedVector3Array = PackedVector3Array()
	var repath_t: float = 0.0
	var hist_pos: Vector3 = crew.global_position
	var hist_t: float = 0.0
	var recover: int = 0
	var ok: bool = false
	var top_up_t: float = 0.0
	last_blocked_door = null
	last_goto_stuck = false
	last_ladder_with_bag = null
	while t < timeout_s:
		if combat and crew.crew_state != Enums.CrewState.NORMAL:
			d.note("pilot: goto aborted, crew state %d (fight from the floor)" % crew.crew_state)
			break  # ND attempt 14: walking on while downed meant never shooting, so police cuffed the pilot
		if flat_dist(crew.global_position, target) <= arrive_m and absf(crew.global_position.y - target.y) <= arrive_dy:
			ok = true
			break
		if repath_t <= 0.0:
			path = nav_path(target)
			repath_t = 0.5
			if path.is_empty():
				d.note("pilot: NO NAV PATH from %s to %s" % [_v(crew.global_position), _v(target)])
				break
			var nav_end: Vector3 = path[path.size() - 1]
			if flat_dist(nav_end, target) > UNREACHABLE_M and near(crew.global_position, nav_end, 0.6):
				# OF-X2 (DB-7 q6): the target is behind barred doors (the path ends short of it). Walking at the raw
				# target from the path's end only pushes into the wall.
				d.note("pilot: %s unreachable: the nav path ends at %s, %.1f m short" % [_v(target), _v(nav_end),
					flat_dist(nav_end, target)])
				break
		if combat and t - _last_engage >= 2.5:
			var foe: NpcBase = nearest_enemy(10.0)
			if foe != null:
				inp.release(&"move_forward")
				await engage(foe, 1.5)
				_last_engage = t
				repath_t = 0.0
				hist_pos = crew.global_position
				hist_t = 0.0
		if _hook_wanted() and await _run_hook():
			repath_t = 0.0
			hist_pos = crew.global_position
			hist_t = 0.0
			continue
		if combat and t >= top_up_t:
			top_up_t = t + TOP_UP_EVERY_S
			await top_up()  # a player reloads on the move between fights (the tap takes 2 ticks; walking goes on)
		var corner: Vector3 = next_corner(path, crew.global_position, target)
		var leg: Array = _ladder_leg(corner)
		if not leg.is_empty() and crew.is_carrying_bag():
			# S10.1b: a ladder refuses a carried bag (headless OF 1037: 3 min of "RopeLadder up -> FAILED" with cash).
			last_ladder_with_bag = leg[0] as Ladder
			d.note("pilot: %s ahead with a bag: not climbing (the bag goes by the hoist)" % last_ladder_with_bag.name)
			break
		if not leg.is_empty():
			inp.release(&"move_forward")
			await climb_ladder(leg[0] as Ladder, bool(leg[1]))
			repath_t = 0.0
			hist_pos = crew.global_position
			hist_t = 0.0
			continue
		var line_door: Door = _door_on_line(corner) if doors else null
		if line_door != null and not line_door.is_open:
			inp.release(&"move_forward")
			if _door_blocked(line_door):
				d.note("pilot: goto blocked by %s (%s); giving up this leg" % [line_door.name, _door_why(line_door)])
				last_blocked_door = line_door
				break
			await open_door(line_door)  # DB-7 ChamberASpine: a D-073 door the path only crosses as a NavLink
			repath_t = 0.0
			hist_pos = crew.global_position
			hist_t = 0.0
			continue
		var through: Variant = _through_link(target, path)
		if through != null:
			corner = through as Vector3
		var door: Door = door_ahead(corner, path) if doors else null
		if door != null and _door_blocked(door):
			inp.release(&"move_forward")
			d.note("pilot: goto blocked by %s (%s); giving up this leg" % [door.name, _door_why(door)])
			last_blocked_door = door
			break  # P (GN loud): the lockdown-BARRED art door; pushing into it stalled the flow from t=480
		if door != null:
			inp.release(&"move_forward")
			await open_door(door)
			repath_t = 0.0
			hist_pos = crew.global_position
			hist_t = 0.0
			continue
		var v: Vector3 = corner - crew.global_position
		var ey: float = steer(atan2(-v.x, -v.z), 0.0)
		var want_fwd: bool = absf(ey) < 0.6
		if want_fwd and not inp.is_held(&"move_forward"):
			inp.press(&"move_forward")
		elif not want_fwd and inp.is_held(&"move_forward"):
			inp.release(&"move_forward")
		if sprint and want_fwd and not inp.is_held(&"sprint"):
			inp.press(&"sprint")
		await tick()
		t += dt()
		if int(t / 5.0) != int((t - dt()) / 5.0):
			d.note("pilot: t=%.0f at %s corner %s yaw_err %.2f fwd=%s path=%d" % [t, _v(crew.global_position),
				_v(corner), ey, inp.is_held(&"move_forward"), path.size()]
				+ " mouse_mode=%d state=%d look=(%.2f,%.2f) pin_yaw=%s bot=%s" % [Input.mouse_mode, crew.crew_state, crew.look_yaw,
					crew.look_pitch, crew.get_node(^"PlayerInput").get(&"_yaw"), HeistRuntime.of(crew).has_bot_intent(crew.slot)])
		repath_t -= dt()
		hist_t += dt()
		if hist_t >= stuck_window_s:
			var moved: float = flat_dist(crew.global_position, hist_pos)
			if moved < stuck_min_m and inp.is_held(&"move_forward"):
				await _log_stuck(corner)
				recover += 1
				if stuck_give_up > 0 and recover >= stuck_give_up and _detour_depth == 0:
					inp.release(&"move_forward")
					d.note("pilot: goto gave up after %d stuck recoveries at %s (re-plan)" % [recover, _v(crew.global_position)])
					last_goto_stuck = true
					break
				var leaf: Door = _leaf_contact() if doors else null
				if leaf != null and not leaf.is_open and _door_blocked(leaf):
					# P's GN loud rerun: 80 s+ pushing into StudioDoor, a closed leaf with no prompt (door_ahead finds
					# a door by its interactable near the route; a leaf the crew walks into is that door whatever it is).
					inp.release(&"move_forward")
					d.note("pilot: goto stuck on the closed leaf of %s (%s); giving up this leg" % [leaf.name, _door_why(leaf)])
					last_blocked_door = leaf
					break
				if leaf != null and not leaf.is_open:
					inp.release(&"move_forward")
					await open_door(leaf)
					repath_t = 0.0
				elif leaf != null:
					# Lead (P's GN loud rerun on 04f79b18): pressed 4 times against the OPEN BronzeDoorsE leaf
					# (LeafBody2), then stalled 1200 s. An open leaf (or one held by a body in its sweep) is an
					# obstacle: back off, then walk through the doorway's clear lane, never push the leaf again.
					inp.release(&"move_forward")
					d.note("pilot: against the open leaf of %s (swing_blocked=%s): going round it" % [leaf.name, leaf.swing_blocked])
					await inp.hold(&"move_back", 0.4)
					await _pass_leaf(leaf, corner)
					repath_t = 0.0
				elif _civilian_blocking() or _detour_depth > 0:
					await _unstick(recover)
				else:
					inp.release(&"move_forward")
					await _detour(corner, recover)
					repath_t = 0.0
			hist_pos = crew.global_position
			hist_t = 0.0
	inp.release(&"move_forward")
	inp.release(&"sprint")
	await inp.ticks(2)
	if not ok and not quiet:
		d.note("pilot: goto %s FAILED at %s after %.1f s" % [_v(target), _v(crew.global_position), t])
	return ok


func _hook_wanted() -> bool:
	return hook.is_valid() and hook_need.is_valid() and not _in_hook and bool(hook_need.call())


## Runs `hook` once (not re-entrant); true when it took over the input.
func _run_hook() -> bool:
	if not hook.is_valid() or _in_hook:
		return false
	_in_hook = true
	var took: bool = bool(await hook.call())
	_in_hook = false
	if took:
		inp.release(&"move_forward")
		inp.release(&"sprint")
	return took


func _log_stuck(corner: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	var dir: Vector3 = (corner - crew.global_position)
	dir.y = 0.0
	dir = dir.normalized()
	var hits: PackedStringArray = PackedStringArray()
	for h: float in [0.05, 0.2, 0.4, 1.0]:
		var from: Vector3 = crew.global_position + Vector3(0, h, 0)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 0.8)
		q.exclude = [crew.get_rid()]
		var r: Dictionary = space.intersect_ray(q)
		if not r.is_empty():
			var col: Object = r["collider"]
			hits.append("h%.2f:%s@%s" % [h, (col as Node).get_path() if col is Node else str(col), _v(r["position"])])
	for i: int in crew.get_slide_collision_count():
		var kc: KinematicCollision3D = crew.get_slide_collision(i)
		var cn: Node = kc.get_collider() as Node
		hits.append("slide:%s@%s n=%s" % [cn.get_path() if cn != null else ^"?", _v(kc.get_position()), _v(kc.get_normal())])
	hits.append("vel=%s floor=%s state=%d" % [_v(crew.velocity), crew.is_on_floor(), crew.crew_state])
	var row: Dictionary = {"pos": crew.global_position, "toward": corner, "hits": hits}
	stuck_spots.append(row)
	d.note("pilot: STUCK at %s heading to %s; rays: %s" % [_v(crew.global_position), _v(corner), ", ".join(hits)])
	if stuck_spots.size() <= 3:
		await d.shot("stuck_%d" % stuck_spots.size())


## The Door whose leaf (its `LeafBody*` AnimatableBody3D) the crew is pressed against, else null: from the slide
## collisions of the last move, else a short knee-high ray along the facing.
func _leaf_contact() -> Door:
	var cols: Array[Object] = []
	for i: int in crew.get_slide_collision_count():
		cols.append(crew.get_slide_collision(i).get_collider())
	var fwd: Vector3 = Vector3(-sin(crew.look_yaw), 0.0, -cos(crew.look_yaw))
	var from: Vector3 = crew.global_position + Vector3(0, 0.5, 0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + fwd * 0.8)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		cols.append(hit["collider"])
	for o: Object in cols:
		var body: Node = o as Node
		if body is AnimatableBody3D and String(body.name).begins_with("LeafBody") and body.get_parent() is Door:
			return body.get_parent() as Door
	return null


## A live civilian among the bodies the crew is pressed against (stealth flows back off / shout instead).
func _civilian_blocking() -> bool:
	for i: int in crew.get_slide_collision_count():
		var b: NpcBase = crew.get_slide_collision(i).get_collider() as NpcBase
		if b != null and b.is_in_group(G.CIVILIAN) and b.is_alive():
			return true
	return false


## A live enemy the crew is pressed against (last move's slide collisions) or that stands within 0.8 m ahead at chest
## height, else null.
func _enemy_blocking() -> NpcBase:
	for i: int in crew.get_slide_collision_count():
		var b: NpcBase = crew.get_slide_collision(i).get_collider() as NpcBase
		if b != null and b.is_in_group(G.ENEMY) and b.is_alive():
			return b
	var fwd: Vector3 = Vector3(-sin(crew.look_yaw), 0.0, -cos(crew.look_yaw))
	var from: Vector3 = crew.global_position + Vector3(0, 1.0, 0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + fwd * 0.8)
	q.exclude = [crew.get_rid()]
	var hit: NpcBase = crew.get_world_3d().direct_space_state.intersect_ray(q).get("collider") as NpcBase
	return hit if hit != null and hit.is_in_group(G.ENEMY) and hit.is_alive() else null


## Stuck against something that is not the target (a prop, a cop, a wall corner the path hugs): side-step to a
## navmesh point beside the crew, alternating sides (odd attempts right, even left) and widening (0.7 m, then
## 1.2 m), a step toward `corner`, then the caller re-paths. Falls back to a jump when no side point is free.
func _detour(corner: Vector3, attempt: int) -> void:
	var fwd: Vector3 = corner - crew.global_position
	fwd.y = 0.0
	if fwd.length() < 0.05:
		fwd = Vector3(-sin(crew.look_yaw), 0.0, -cos(crew.look_yaw))
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP)
	var lat: float = 0.7 if attempt <= 2 else 1.2
	var first: float = 1.0 if attempt % 2 == 1 else -1.0
	for side: float in [first, -first]:
		var want: Vector3 = crew.global_position + right * side * lat + fwd * 0.3
		var snap: Vector3 = NavigationServer3D.map_get_closest_point(crew.get_world_3d().navigation_map, want)
		if flat_dist(snap, want) > 0.35 or absf(snap.y - crew.global_position.y) > 0.6:
			continue
		d.note("pilot: detour %s %.1f m to %s (attempt %d)" % ["right" if side > 0.0 else "left", lat, _v(snap), attempt])
		_detour_depth += 1
		var ok: bool = await goto(snap, 0.3, 3.0, false, false)
		_detour_depth -= 1
		if ok:
			return
	await inp.tap(&"jump")
	await inp.ticks(20)


## Through the doorway of an open `door` whose leaf the crew is pressed against: the lane across the doorway (local
## x offsets) that a knee-high ray along the door normal crosses without hitting anything (leaf, frame), walked
## from 0.8 m on the crew's side to 0.9 m past the door plane (rays 1.2 m each side). No clear lane: a plain side-step detour.
func _pass_leaf(door: Door, corner: Vector3) -> void:
	var xf: Transform3D = door.global_transform
	var my_z: float = signf((xf.affine_inverse() * crew.global_position).z)
	if my_z == 0.0:
		my_z = 1.0
	var half: float = door.effective_width() * 0.5
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	var lane: float = INF
	for x: float in [0.0, -half * 0.5, half * 0.5, -half * 0.75, half * 0.75]:
		var clear: bool = true
		for dx: float in [-LANE_HALF_M, 0.0, LANE_HALF_M]:  # the crew's capsule width, not just its centre line
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				xf * Vector3(x + dx, 0.5, my_z * 1.2), xf * Vector3(x + dx, 0.5, -my_z * 1.2))
			q.exclude = [crew.get_rid()]
			q.collision_mask = GameplayPrefab.LAYER_WORLD_STATIC | GameplayPrefab.LAYER_WORLD_DYNAMIC
			if not space.intersect_ray(q).is_empty():
				clear = false
				break
		if clear:
			lane = x
			break
	if lane == INF:
		d.note("pilot: no clear lane through %s: side-step instead" % door.name)
		await _detour(corner, 1)
		return
	var map: RID = crew.get_world_3d().navigation_map
	_detour_depth += 1
	for z: float in [my_z * 0.8, -my_z * 0.9]:
		var pt: Vector3 = NavigationServer3D.map_get_closest_point(map, xf * Vector3(lane, 0.0, z))
		if not await goto(pt, 0.3, 4.0, false, false):
			break
	_detour_depth -= 1


func _unstick(attempt: int) -> void:
	var foe: NpcBase = _enemy_blocking()
	if foe != null:  # LEAD GPU-18 (OF b480): 40 s of side-steps into Npc_police13/14 on the SAFlight2W stair
		d.note("pilot: %s blocks the way: shoot" % foe.name)
		await engage(foe, 3.0)
		return
	for i: int in crew.get_slide_collision_count():
		var blocker: NpcBase = crew.get_slide_collision(i).get_collider() as NpcBase
		if not shout_blockers and attempt < block_shout_after and blocker != null and blocker.is_in_group(G.CIVILIAN) and blocker.is_alive():
			# Stealth: step back and sidestep away from the civilian instead of shouting.
			var to_b: Vector3 = blocker.global_position - crew.global_position
			var right: Vector3 = Vector3(cos(crew.look_yaw), 0.0, -sin(crew.look_yaw))
			var cb: Node = blocker.get_node_or_null(^"Brain")
			d.note("pilot: civilian %s (mode %s) blocks the way: back off and let them pass" % [blocker.name,
				cb.get(&"mode") if cb != null else "?"])
			await inp.hold(&"move_back", 0.3 + 0.3 * float(mini(attempt, 3)))
			await inp.hold(&"move_left" if right.dot(to_b) > 0.0 else &"move_right", 0.5)
			await inp.ticks(int(2.5 * Engine.physics_ticks_per_second))
			return
		if blocker != null and blocker.is_in_group(G.CIVILIAN) and blocker.is_alive():
			d.note("pilot: civilian %s blocks the way: shout" % blocker.name)
			await face(blocker.head_position() - Vector3(0, 0.4, 0), 0.05, 1.0)
			await inp.tap(&"shout")
			await inp.ticks(40)
			return
	if attempt % 2 == 1:
		await inp.tap(&"jump")
		await inp.ticks(20)
	else:
		var side: StringName = &"move_left" if attempt % 4 == 0 else &"move_right"
		await inp.hold(side, 0.4)


## Walks within reach of `comp`, aims at it and holds interact until it completes (or `done` returns true).
func use(comp: InteractableComponent, timeout_s: float = 30.0, done: Callable = Callable(), walk: bool = true) -> bool:
	var door: Door = comp.owner_node() as Door
	if walk and door != null:
		# ND attempts 15/16: the generic stand spot missed the lock and F became a shout. Walk there with normal
		# routing first (it opens the doors on the way: attempt 17 stuck at the TellerDoor heading for the
		# VaultGate), then square up with open_door().
		if not near(crew.global_position, door.global_position, DOOR_NEAR_M):
			await goto(stand_point(door.global_position), DOOR_NEAR_M, 60.0)
		if door.is_open:
			return true  # the walk's own door handling already opened it (a second use would close it)
		return await open_door(door)
	var target: Vector3 = comp.global_position
	var stand: Vector3 = _use_stand(comp)
	if walk and not await goto(stand, 0.5, 60.0) and is_instance_valid(comp):
		d.note("pilot: could not reach %s (%s)" % [comp.get_path(), comp.kind])
		# Behind a door it cannot open: pressing F through the wall for 30 s does nothing (P GN-P1). Out of reach (PO5
		# GN 1792002290: the walk to the Argus terminal timed out 3.2 m short on the stairs, then F at nothing for 30 s):
		# hand back, the caller walks again.
		var far: bool = is_instance_valid(comp) and crew.eye_position().distance_to(target) > Tweak.interaction().explicit_reach_m
		if far:
			d.note("pilot: %s out of reach after the walk: not pressing" % comp.kind)
		if last_blocked_door != null or far:
			return false
	if not is_instance_valid(comp):
		return false
	await face(target)
	var isys: InteractionSystem = HeistRuntime.of(crew).interaction
	var aimed: InteractableComponent = isys.aimed_component(crew)
	if aimed != comp:
		var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(crew.eye_position(), target, 1)
		q.exclude = [crew.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		var ang: float = rad_to_deg(crew.aim_direction().angle_to(target - crew.eye_position()))
		d.note("pilot: aimed %s, wanted %s (dist %.2f, angle %.1f deg, avail '%s', LOS ray hit %s at %s)" % [
			aimed.get_path() if aimed != null else ^"<none>", comp.get_path(), crew.eye_position().distance_to(target),
			ang, comp.availability(crew), (hit["collider"] as Node).get_path() if not hit.is_empty() else ^"-",
			_v(hit["position"]) if not hit.is_empty() else "-"])
	if no_blind_press and not await _aim_on(comp, target):
		d.note("pilot: use %s (%s) NOT PRESSED: not aimed (a blind F press is a shout)" % [comp.get_path(), comp.kind])
		return done.is_valid() and bool(done.call())
	var completed: Array[bool] = [false]
	var cb: Callable = func(_c: Node) -> void: completed[0] = true
	comp.completed.connect(cb)
	if combat and await _clear_threats():  # S9.1: damage cancels a hold, so clear the area first like a player
		await face(target, 0.03, 1.0)
	# The target may be freed while clearing threats (a bag picked up, a door blown by someone else): the loop ends.
	var kind: StringName = comp.kind if is_instance_valid(comp) else &""
	if kind != &"":
		inp.press(&"interact")
	var t: float = 0.0
	var idle_ticks: int = 0
	while t < timeout_s and not completed[0] and is_instance_valid(comp) and not (done.is_valid() and bool(done.call())):
		if crew.crew_state != Enums.CrewState.NORMAL:
			break
		# A player keeps holding while nothing cancels the hold (ND attempt 20: letting go at 94 % to shoot a
		# visible cop threw the pick away); threats are cleared only once a hit has dropped it (below).
		if comp.kind != &"answer_pager" and _hook_wanted():
			inp.release(&"interact")
			if await _run_hook():
				await face(target, 0.03, 1.0)
			if not is_instance_valid(comp):  # stores1001: a bot secured the bag during the re-aim
				break
			if no_blind_press and not await _aim_on(comp, target):
				break
			inp.press(&"interact")
		steer_at(target)
		await tick()
		t += dt()
		# Interrupted (a hit, S9.1, or a block needing a release): press again like a player would, but only
		# once no session has existed for REPRESS_TICKS (a fresh press needs a few ticks to start one).
		idle_ticks = idle_ticks + 1 if isys.session(crew.slot).is_empty() else 0
		if idle_ticks >= REPRESS_TICKS and not completed[0] and is_instance_valid(comp):
			idle_ticks = 0
			inp.release(&"interact")
			await inp.ticks(2)
			if combat and await _clear_threats():  # S9.1: a hit dropped the hold, so clear the shooters first
				d.note("pilot: use %s hold dropped, cleared threats before re-pressing" % kind)
			if not is_instance_valid(comp):  # DB sweep 1001: a bot picked the bag up during the fight
				break
			# Re-aim before pressing again: an F press with the crosshair on a cop is a shout (ND attempts 15-18).
			await face(target, 0.03, 1.0)
			if no_blind_press and not await _aim_on(comp, target):
				break
			if isys.aimed_component(crew) == comp:
				d.note("pilot: use %s hold dropped (hit or blocked), re-pressing" % comp.kind)
				inp.press(&"interact")  # never re-press off target: F with nothing aimed is a shout
			else:
				var am: InteractableComponent = isys.aimed_component(crew)
				d.note("pilot: use %s re-press skipped: aimed %s (dist %.2f, angle %.1f deg)" % [comp.kind,
					am.get_path() if am != null else ^"<none>", crew.eye_position().distance_to(target),
					rad_to_deg(crew.aim_direction().angle_to(target - crew.eye_position()))])
	inp.release(&"interact")
	if is_instance_valid(comp) and comp.completed.is_connected(cb):
		comp.completed.disconnect(cb)
	await inp.ticks(3)
	var ok: bool = completed[0] or (done.is_valid() and bool(done.call()))
	if is_instance_valid(comp):
		d.note("pilot: use %s (%s) -> %s in %.1f s" % [comp.owner_node().name if comp.owner_node() else comp.name,
			comp.kind, "OK" if ok else "FAILED", t])
	return ok


## Loud: fight every visible enemy within HOLD_THREAT_M until none is left (or CLEAR_MAX_S). True when it fought.
func _clear_threats() -> bool:
	var fought: bool = false
	var t0: float = HeistRuntime.of(crew).heist_time_s
	while HeistRuntime.of(crew).heist_time_s - t0 < CLEAR_MAX_S and crew.crew_state == Enums.CrewState.NORMAL:
		var foe: NpcBase = nearest_enemy(HOLD_THREAT_M)
		if foe == null:
			break
		fought = true
		await engage(foe, 2.0)
	return fought


## True once `comp` is the aimed interactable (re-aims for up to ~1.5 s). Usable components only.
func _aim_on(comp: InteractableComponent, target: Vector3) -> bool:
	var isys: InteractionSystem = HeistRuntime.of(crew).interaction
	for i: int in 5:
		if not is_instance_valid(comp) or not comp.enabled:
			return false
		if isys.aimed_component(crew) == comp:
			return true
		await face(target + Vector3(0.0, 0.05 * float(i % 3 - 1), 0.0), 0.02, 0.3)
		await tick()
	return is_instance_valid(comp) and isys.aimed_component(crew) == comp


## A closed door within 1.8 m in front of the crew (the pilot opens it like a player: aim + hold F). With the nav
## `path` being walked: the first closed door whose doorway the route crosses within DOOR_LOOKAHEAD_M (P's PO6 GH
## stealth run: coming south through the LobbyDoor into G4, the old "handle near the segment to the next corner" test
## picked the LOCKPICK SalonBackDoor straight ahead, which the route turns away from, and a casing pilot gave up the
## leg at ui.blocked.casing). Without a path: a door whose handle is near the segment to `corner`.
func door_ahead(corner: Vector3 = Vector3.INF, path: PackedVector3Array = PackedVector3Array()) -> Door:
	if path.size() >= 2:
		return _door_on_route(path)
	var fwd: Vector3 = Vector3(-sin(crew.look_yaw), 0.0, -cos(crew.look_yaw))
	for n: Node in crew.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var door: Door = c.owner_node() as Door if c != null else null
		if door == null or door.is_open:
			continue
		var to: Vector3 = c.global_position - crew.global_position
		if absf(to.y - 1.0) > 1.2:
			continue  # another floor
		to.y = 0.0
		if to.length() < 1.8 and fwd.dot(to.normalized()) > 0.4:
			# Only a door the route goes through (near the segment to the next corner), not a side door.
			if corner != Vector3.INF:
				var seg: Vector3 = corner - crew.global_position
				seg.y = 0.0
				var along: float = clampf(to.dot(seg.normalized()), 0.0, seg.length() + 0.6) if seg.length() > 0.01 else 0.0
				var off: float = (to - seg.normalized() * along).length() if seg.length() > 0.01 else to.length()
				if off > 0.7:
					continue
			return door
	return null


## The first closed Door (any, Door.GROUP) whose doorway the route crosses within DOOR_LOOKAHEAD_M of the crew: from
## the crew along `path` (its points past the one the crew is on), legs lifted to waist height.
func _door_on_route(path: PackedVector3Array) -> Door:
	var doors: Array[Door] = []
	for n: Node in crew.get_tree().get_nodes_in_group(Door.GROUP):
		var dn: Door = n as Door
		if dn != null and not dn.is_open and flat_dist(dn.global_position, crew.global_position) < DOOR_LOOKAHEAD_M + 2.0:
			doors.append(dn)
	if doors.is_empty():
		return null
	var up: Vector3 = Vector3.UP * 0.5
	var a: Vector3 = crew.global_position
	var left: float = DOOR_LOOKAHEAD_M
	var started: bool = false
	for pt: Vector3 in path:
		if not started:
			if flat_dist(pt, crew.global_position) <= 0.45:
				continue  # the point the crew stands on
			started = true
		var b: Vector3 = pt
		var leg: float = a.distance_to(b)
		if leg > left:
			b = a.lerp(b, left / leg)
		var best: Door = null
		var best_d: float = INF
		for dn: Door in doors:
			var x: Vector3 = dn.doorway_crossing(a + up, b + up)
			if x != Vector3.INF and x.distance_to(a) < best_d:
				best = dn
				best_d = x.distance_to(a)
		if best != null:
			return best
		left -= leg
		if left <= 0.0:
			break
		a = pt
	return null


## A closed door on the route the crew cannot open now (BARRED / VAULT / ELECTRONIC, a keycard without a card) or
## that already beat three attempts.
func _door_blocked(door: Door) -> bool:
	return _door_tries.get(door, 0) >= 3 or _door_why(door) != InteractableComponent.BLOCK_NONE


func _door_why(door: Door) -> StringName:
	var comp: InteractableComponent = door.get_node_or_null(^"Interactable") as InteractableComponent
	return comp.availability(crew) if comp != null and comp.enabled else &"disabled"


func open_door(door: Door) -> bool:
	_door_tries[door] = _door_tries.get(door, 0) + 1
	var comp: InteractableComponent = door.get_node_or_null(^"Interactable") as InteractableComponent
	if comp == null:
		return false
	# Square up in front of the door, 0.8 m out on the crew's side, like a person reaching for the handle.
	var n: Vector3 = door.global_transform.basis.z
	n.y = 0.0
	n = n.normalized()
	if n.dot(crew.global_position - door.global_position) < 0.0:
		n = -n
	await goto(stand_point(comp.global_position + n * 0.8), 0.25, 8.0, false, false)
	var why: StringName = comp.availability(crew)
	if why != InteractableComponent.BLOCK_NONE:
		d.note("pilot: door %s (%s) blocked: %s" % [door.name, comp.kind, why])
		return false
	var ok: bool = await use(comp, 30.0, func() -> bool: return door.is_open, false)
	await inp.ticks(20)  # leaf swing
	return ok


## D-145 (P's GH Tense 4502): fight from the floor only where police can cuff a downed player who is not shooting
## (L2.12, from police_cuff_min_difficulty up). Below that, shots from the floor only make the pilot a target (L2.5)
## and the bleed-out pool drains in seconds; a player lies still and waits for the revive.
## D-145 (OF Cataclysm: downed at t~19, in custody 1 s later): even there only against a few (<= FLOOR_FIGHT_MAX alive
## enemies within FLOOR_FIGHT_M); against a crowd a player lies still, is cuffed (bleed-out paused) and waits for the
## uncuff, instead of drawing the whole room's fire onto the bleed-out pool.
func shoots_from_floor() -> bool:
	var rt: HeistRuntime = HeistRuntime.of(crew)
	if rt != null and rt.difficulty < CustodyTweak.data().police_cuff_min_difficulty:
		return false
	var near: int = 0
	for n: Node in crew.get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.is_alive() and npc.global_position.distance_to(crew.global_position) <= FLOOR_FIGHT_M:
			near += 1
	return near <= FLOOR_FIGHT_MAX


## Nearest live enemy within `range_m` the crew can see (an eye ray to its head, chest or hips hits it first:
## a cop behind bars or a counter still shows some of its body, like it does to a player).
func nearest_enemy(range_m: float) -> NpcBase:
	var best: NpcBase = null
	var best_d: float = range_m
	for n: Node in crew.get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.is_alive():
			continue
		var sur: PoliceSurrender = PoliceSurrender.of(npc)
		if sur != null and sur.is_surrendered():
			continue  # hands up / tied: not a threat (shooting or shouting at it wastes the hold)
		var dd: float = crew.eye_position().distance_to(npc.head_position())
		if dd < best_d and _aim_point(npc) != Vector3.INF:
			best = npc
			best_d = dd
	return best


## The first visible point of `npc` (head, chest, hips), or Vector3.INF when none is.
func _aim_point(npc: NpcBase) -> Vector3:
	var head: Vector3 = npc.head_position()
	for drop: float in AIM_DROPS:
		var pt: Vector3 = head + Vector3.DOWN * drop
		if has_los(pt, npc):
			return pt
	return Vector3.INF


func has_los(point: Vector3, target: Node = null) -> bool:
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	# The player's own bullet mask (CombatTweak.hitscan_mask): teammates never block it (ND attempts 10/12: bots
	# bunched at the pilot's side read as "no line of sight" while the cops shot them).
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(crew.eye_position(), point,
		CombatTweak.data().hitscan_mask)
	q.exclude = [crew.get_rid()]
	var r: Dictionary = space.intersect_ray(q)
	if r.is_empty():
		return true
	var col: Node = r["collider"] as Node
	return target != null and col != null and (col == target or target.is_ancestor_of(col))


## Aim at the head and fire in short bursts for up to `max_s` or until it dies / leaves sight.
func engage(npc: NpcBase, max_s: float) -> void:
	var t: float = 0.0
	# B (DB Tense r256 s1, doctor-bag cell): signal 11 at the fire loop's await; the target can be freed (killed and
	# cleaned up) during any await here, so check it after each one.
	while t < max_s and is_instance_valid(npc) and npc.is_alive():
		var aim_pt: Vector3 = _aim_point(npc)
		if aim_pt == Vector3.INF:
			break
		await face(aim_pt, 0.03, 0.25)
		if not is_instance_valid(npc) or not has_los(aim_pt, npc):
			break
		if not await _ensure_ammo():
			# Headless OF 1037: a cop in melee range (strike every 0.4 + 3.0 s) cancels every 3.5 s+ empty reload, so
			# the pilot sat at 0/131 for 140 s. Like a PD2 player: the loaded sidearm, else a melee strike.
			if not is_instance_valid(npc) or npc.global_position.distance_to(crew.global_position) > CLOSE_QUARTERS_M:
				break  # both weapons dry: nothing to shoot with
			await _close_quarters(npc)
			t += 0.5
			continue
		if not is_instance_valid(npc):
			break
		inp.press(&"fire")
		await inp.ticks(2)
		inp.release(&"fire")
		shots_fired += 1
		await inp.ticks(6)
		t += 0.25 + 8.0 * dt()
	inp.release(&"fire")


## An enemy in reach and an empty mag that a melee keeps cancelling: swap to the other weapon when its mag is loaded,
## else strike (melee) at the enemy's chest.
func _close_quarters(npc: NpcBase) -> void:
	var w: CrewWeapons = crew.weapons
	var other: int = Enums.WeaponSlot.PRIMARY if w.equipped_slot == Enums.WeaponSlot.SECONDARY \
		else Enums.WeaponSlot.SECONDARY
	if w.has_weapon(other) and w.mag(other) > 0:
		d.note("pilot: %s in reach with an empty mag: drawing the %s" % [npc.name, w.weapon_id(other)])
		await inp.tap(&"slot_primary" if other == Enums.WeaponSlot.PRIMARY else &"slot_secondary")
		await inp.ticks(30)  # draw
		return
	d.note("pilot: %s in reach with an empty mag: melee" % npc.name)
	await face(npc.global_position + Vector3(0, 1.2, 0), 0.08, 0.3)
	await inp.tap(&"melee")
	await inp.ticks(30)


## P's GN-P1 rerun (b): the pilot sat at 0/90 firing an empty gun. Like a player: an empty mag with reserve left is
## reloaded (R, then wait for it to finish); with no reserve it switches to the other weapon if that one has ammo.
## False when neither weapon can shoot. Through input only (reload / slot_primary / slot_secondary).
func _ensure_ammo() -> bool:
	var w: CrewWeapons = crew.weapons
	if w == null:
		return true
	var ws: int = w.equipped_slot
	if w.mag(ws) > 0 and not w.reloading:
		return true
	if w.reserve(ws) > 0 or w.reloading:
		if not w.reloading:
			inp.release(&"fire")
			d.note("pilot: mag empty (%d/%d), reloading" % [w.mag(ws), w.reserve(ws)])
			await inp.tap(&"reload")
		var t: float = 0.0
		while w.reloading and t < 8.0:
			await tick()
			t += dt()
		return w.mag(w.equipped_slot) > 0
	var other: int = Enums.WeaponSlot.PRIMARY if ws == Enums.WeaponSlot.SECONDARY else Enums.WeaponSlot.SECONDARY
	if w.has_weapon(other) and w.mag(other) + w.reserve(other) > 0:
		inp.release(&"fire")
		d.note("pilot: %s dry, switching weapons" % w.weapon_id(ws))
		await inp.tap(&"slot_primary" if other == Enums.WeaponSlot.PRIMARY else &"slot_secondary")
		var t2: float = 0.0
		while w.equipped_slot != other and t2 < 3.0:
			await tick()
			t2 += dt()
		await inp.ticks(30)  # draw
		return await _ensure_ammo() if w.equipped_slot == other else false
	return false


## Lull reload (P's GN-P1 rerun: the pilot ran dry at the Argus terminal): with the equipped mag below `fraction` of
## its size, reserve left, not reloading yet and no enemy in sight within HOLD_THREAT_M, press R (the player's reload
## action; CrewWeapons starts it on the press edge). True when a reload started.
func top_up(fraction: float = TOP_UP_FRACTION) -> bool:
	var w: CrewWeapons = crew.weapons
	if w == null or w.reloading or crew.crew_state != Enums.CrewState.NORMAL:
		return false
	var ws: int = w.equipped_slot
	var size: int = w.mag_size(ws)
	if size <= 0 or w.reserve(ws) <= 0 or float(w.mag(ws)) >= float(size) * fraction:
		return false
	if nearest_enemy(HOLD_THREAT_M) != null:
		return false
	inp.release(&"fire")
	await inp.tap(&"reload")
	if w.reloading:
		d.note("pilot: reload in a lull (%s %d/%d, reserve %d)" % [w.weapon_id(ws), w.mag(ws), size, w.reserve(ws)])
	return w.reloading


## Fights whatever is in sight for `seconds` (standing still), reloading between targets.
func hold_position(seconds: float, until: Callable = Callable()) -> void:
	var t: float = 0.0
	while t < seconds:
		if until.is_valid() and bool(until.call()):
			return
		var foe: NpcBase = nearest_enemy(40.0) if combat else null
		if foe != null:
			await engage(foe, 2.0)
			t += 2.0
		else:
			if watch_point != Vector3.INF:
				await face(watch_point, 0.05, 0.3)
			await top_up(1.0)  # holding with nobody in sight: fill the mag like a player in a lull
			await inp.ticks(10)
			t += 0.5


## The active, in-tree secure zone (variant slot chosen) nearest to the crew.
func secure_zone() -> SecureZone:
	var best: SecureZone = null
	for n: Node in crew.get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		var z: Node = n
		while z != null and not (z is SecureZone):
			z = z.get_parent()
		var sz: SecureZone = z as SecureZone
		if sz != null and sz.is_visible_in_tree() and (best == null or flat_dist(sz.global_position, crew.global_position)
				< flat_dist(best.global_position, crew.global_position)):
			best = sz
	return best


## Carries the bag on our back to `zone` and throws it in (G while masked + carrying), like a player
## tossing a bag into the van. Returns true when loot_secured fired for it.
func secure_carried_bag(zone: Node3D) -> bool:
	var secured: Array[int] = [0]
	var cb: Callable = func(_b: int, _l: StringName, _v: int) -> void: secured[0] += 1
	EventBus.loot_secured.connect(cb)
	var target: Vector3 = zone.global_position
	await goto(stand_point(target), 3.0, 120.0)
	if crew.crew_state != Enums.CrewState.NORMAL:
		EventBus.loot_secured.disconnect(cb)
		return false  # downed on the way: the flow fights from the floor, then carries on
	await face(target + Vector3(0, 0.8, 0), 0.05, 2.0)
	var tries: int = 0
	while crew.is_carrying_bag() and tries < 3:
		await inp.tap(&"drop_bag")
		await inp.ticks(10)
		tries += 1
	var t: float = 0.0
	while secured[0] == 0 and t < 8.0:
		await tick()
		t += dt()
	if secured[0] == 0 and not crew.is_carrying_bag():
		d.note("pilot: thrown bag not secured within 8 s (zone at %s, crew at %s)" % [_v(target), _v(crew.global_position)])
	EventBus.loot_secured.disconnect(cb)
	return secured[0] > 0


## The escape zone the mission activated (null until then).
func active_escape() -> EscapeZone:
	for n: Node in crew.get_tree().get_nodes_in_group(G.ESCAPE_ZONE):
		var z: Node = n
		while z != null and not (z is EscapeZone):
			z = z.get_parent()
		var ez: EscapeZone = z as EscapeZone
		if ez != null and ez.active:
			return ez
	return null


## The point to steer at on `path` from `pos`: the first point past the path segment nearest `pos` that is > 0.45 m
## away (flat), else `target`. P's OF ghost run 5: the path is re-planned every 0.5 s, so at walking speed its first
## point (the old start) is already ~1.7 m BEHIND the crew; taking the first point > 0.45 m away turned the pilot round
## on the spot (yaw_err 3.12, fwd false) and the 20 m dumpsters -> dock-door walk took 18 s.
static func next_corner(path: PackedVector3Array, pos: Vector3, target: Vector3) -> Vector3:
	if path.is_empty():
		return target
	# 3D (LEAD's r264 sweep, GH Routine 1001): flat, a path leg on the floor above, right over the crew, was the
	# "nearest" segment; the pilot steered at (11.6, 4.4, 5.0) 4.4 m overhead instead of the stairs and paced the
	# ground floor for 90 s under fire.
	var seg: int = 0
	var best: float = INF
	for i: int in range(path.size() - 1):
		var d: float = pos.distance_to(Geometry3D.get_closest_point_to_segment(pos, path[i], path[i + 1]))
		if d < best - 0.001:
			best = d
			seg = i
	var from: int = seg + 1 if path.size() > 1 else 0
	for i: int in range(from, path.size()):
		if flat_dist(path[i], pos) > 0.45:
			return path[i]
	return target

## The closest navmesh point to `target` (where a person would stand to reach it).
func stand_point(target: Vector3) -> Vector3:
	var map: RID = crew.get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, target)


## A BagLift's UsePoint belongs to landing 0; its runtime panels LandingPanel<i> stand at the same offset from
## landing i (P's OF burn run: the pilot walked to the vault floor to use the TW panel; C's note).
static func _landing_use_point(owner_n: Node, comp: InteractableComponent, at: Vector3) -> Vector3:
	var lift: BagLift = owner_n as BagLift
	if lift == null or not String(comp.name).begins_with(BagLift.PANEL_PREFIX):
		return at
	var i: int = String(comp.name).trim_prefix(BagLift.PANEL_PREFIX).to_int()
	if i <= 0 or i >= lift.landing_count():
		return at
	return lift.landing_transform(i) * (lift.global_transform.affine_inverse() * at)

## Where a player stands to use `comp`: the prefab's UsePoint if it has one (map-authored, the right side of
## counters / glass; not doors, usable from either side), else the nearest navmesh point with a clear line of
## sight to it (ring search).
func _use_stand(comp: InteractableComponent) -> Vector3:
	var owner_n: Node = comp.owner_node()
	var up: Node3D = null
	if owner_n != null and not (owner_n is Door):
		up = owner_n.get_node_or_null(^"UsePoint") as Node3D
	elif owner_n != null:
		up = _mounted_lock_use_point(owner_n)  # D-138 (DB CountCageGate): stand where the gate's padlock / keypad is used
	if up != null:
		return stand_point(_landing_use_point(owner_n, comp, up.global_position))
	var target: Vector3 = comp.global_position
	var near: Vector3 = stand_point(target)
	# GN probe 8: standing on a dropped bag, the crosshair never lands on it (aimed <none> at 0.67 m, 15 s of
	# skipped presses). Stand a step back from a loose bag, like a player looking down at it.
	var bag: bool = owner_n is LootBag
	if not bag and _clear_to(near, target):
		return near
	for r: float in [0.7, 1.1, 1.5]:
		for k: int in 12:
			var a: float = TAU * float(k) / 12.0
			var cand: Vector3 = stand_point(target + Vector3(cos(a), 0.0, sin(a)) * r)
			if flat_dist(cand, target) <= 1.6 and (not bag or flat_dist(cand, target) >= 0.9) and _clear_to(cand, target):
				return cand
	return near


## The UsePoint of a lock prefab (Padlock / Keypad) mounted on `door` (a direct child), else null: a barred cage gate is
## beaten at its lock, so that is where to stand (P: the DB count-cage stall; the navmesh reaches the UsePoint).
static func _mounted_lock_use_point(door: Node) -> Node3D:
	for c: Node in door.get_children():
		if c is Padlock or c is Keypad:
			var up: Node3D = c.get_node_or_null(^"UsePoint") as Node3D
			if up != null:
				return up
	return null


func _clear_to(stand: Vector3, target: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(stand + Vector3.UP * 1.5, target, 1)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 0.25


static func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
