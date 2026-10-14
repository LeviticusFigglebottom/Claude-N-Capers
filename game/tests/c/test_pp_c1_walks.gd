## PP-C-1 (D-082 playability pass): a real-input walk of every ENV C heist. Owner: ENV C.
## The human crew member (slot 0) is driven only through PInputDriver (ENV P: InputMap actions + mouse look
## into PlayerInput; never set_bot_intent): from the player spawn it walks the navmesh path to every
## gameplay use point (doors, devices, loot, objectives), turning with turn_to_yaw at each path corner and
## holding move_forward. A leg that makes no progress in front of a closed door is handled like a player: mask
## up (G hold) if the door needs it, aim at its handle, hold F for the door's time (lockpick 8 s), retry. A leg
## that still stalls is a STUCK row (position, target, corner, why) and the walk resumes from the target by a
## setup teleport (logged). Zero-length legs (already at the use point, e.g. after a teleport) are dropped.
## A door a walk cannot open (VAULT / CODE / ELECTRONIC / BARRED, KEYCARD without a card) is a LOCKED row, not
## STUCK; reaching such a door when it is the leg's own target is an ok leg plus an AT-LOCKED-DOOR row.
## Setup shortcuts (outside movement, named): skip_casing, no AI teammates, every map
## NPC despawned (isolate_npc), security cameras removed and the assault director stopped (the walker masks up
## and does not dodge cameras; a camera alarm or a loud-only map would bring police that down it), so no NPC
## can end the walk. Ladders on the path are climbed like a player (masked, face the ladder, hold forward). Rows: docs/levels/pp_c1.md.
extends TestCase
@warning_ignore_start("unsafe_method_access", "unsafe_property_access", "unsafe_call_argument", "untyped_declaration")

## ENV P's driver, loaded at run time so this file still parses where env/p-play is not merged (it is P-owned).
const DRIVER_PATH: String = "res://tests/p/p_input_driver.gd"

const HEISTS: Dictionary = {&"glasshouse": 1001, &"night_deposit": 1001, &"dockside_burn": 1001}
const MAX_TARGETS: int = 14
const CORNER_M: float = 0.6
## The last corner is the use point in front of a prop / door: within arm's reach counts.
const GOAL_M: float = 1.1
const SPEED_MIN_MPS: float = 1.0

var _rt: HeistRuntime = null
var _inp: Object = null
var _rows: Array[String] = []


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func after_all() -> void:
	var f: FileAccess = FileAccess.open("user://pp_c1_rows.md", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_rows) + "\n")
	print("[PP-C-1] rows -> %s" % ProjectSettings.globalize_path("user://pp_c1_rows.md"))


func test_walk_glasshouse() -> void:
	await _walk_heist(&"glasshouse")


func test_walk_night_deposit() -> void:
	await _walk_heist(&"night_deposit")


func test_walk_dockside_burn() -> void:
	await _walk_heist(&"dockside_burn")


## D-085 human mode: the same legs, but a path corner next to a doorway is replaced by the door's centre line
## (1 m in front of the leaf, then 1 m behind it), the way a player lines up a door.
func test_doors_glasshouse() -> void:
	await _walk_heist(&"glasshouse", true)


func test_doors_night_deposit() -> void:
	await _walk_heist(&"night_deposit", true)


func test_doors_dockside_burn() -> void:
	await _walk_heist(&"dockside_burn", true)


## LEAD 2026-10-12: the Glasshouse SalonDoor frame (13.0, 0, 10.0) snag. The door is opened by setup (it is
## LOCKPICK), then slot 0 walks through the frame both ways, 3 lateral offsets, AI corner + human door-centre
## modes, in stealth and after the alarm (loud). Each crossing is a leg; a stall is a STUCK row.
func test_salon_door_glasshouse() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 1001, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch glasshouse")
		return
	if not ResourceLoader.exists(DRIVER_PATH):
		skip("ENV P p_input_driver.gd not in this tree (merge env/p-play to walk)")
		return
	_inp = (load(DRIVER_PATH) as GDScript).new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "nav ready")
	_quiet_map()
	var door: Door = _rt.map.get_node("Gameplay/Doors/SalonDoor") as Door
	door.call(&"unlock")
	door.call(&"set_open", true)
	await wait_physics_frames(10)
	var rid: RID = c.get_world_3d().navigation_map
	for loud: bool in [false, true]:
		if loud:
			_rt.stealth.raise_alarm(&"pp_salon", 0)
			await wait_until(func() -> bool: return _rt.phase == Enums.HeistPhase.LOUD, 3.0)
		for door_centres: bool in [false, true]:
			var ok: int = 0
			var n: int = 0
			for dz: float in [-0.3, 0.0, 0.3]:
				for pair: Array in [[Vector3(10.5, 0.0, 10.0 + dz), Vector3(15.0, 0.0, 10.0 - dz)],
						[Vector3(15.0, 0.0, 10.0 + dz), Vector3(10.5, 0.0, 10.0 - dz)]]:
					var a0: Vector3 = NavigationServer3D.map_get_closest_point(rid, pair[0])
					var b0: Vector3 = NavigationServer3D.map_get_closest_point(rid, pair[1])
					_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, a0 + Vector3.UP * 0.05))
					await wait_physics_frames(3)
					var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, c.global_position, b0, true)
					n += 1
					var res: Dictionary = await _follow(c, _door_centred(path) if door_centres else path)
					if bool(res["ok"]):
						ok += 1
					else:
						_row(&"glasshouse", "STUCK-%s-%s" % ["DOOR" if door_centres else "AI", "LOUD" if loud else "STEALTH"],
							"SalonDoor", res["at"], "stalled before corner %s (%s)" % [res["corner"], res["why"]])
			print("[PP-C-1] glasshouse SalonDoor (%s, %s): %d / %d crossings ok" % [
				"doors" if door_centres else "corners", "loud" if loud else "stealth", ok, n])


func _walk_heist(heist: StringName, door_centres: bool = false) -> void:
	_rt = await HeistLauncher.launch(heist, int(HEISTS[heist]), Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch %s" % heist)
		return
	if not ResourceLoader.exists(DRIVER_PATH):
		skip("ENV P p_input_driver.gd not in this tree (merge env/p-play to walk)")
		return
	_inp = (load(DRIVER_PATH) as GDScript).new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "%s nav ready" % heist)
	_quiet_map()
	await wait_physics_frames(2)
	var rid: RID = c.get_world_3d().navigation_map
	var targets: Array[Array] = _targets(_rt.map)
	var legs: int = 0
	var ok_legs: int = 0
	var stuck: int = 0
	var t0: int = Time.get_ticks_msec()
	var walked: float = 0.0
	var dropped: int = 0
	var locked: int = 0
	for tg: Array in targets:
		_rt.isolate_npc(null)
		var goal: Vector3 = NavigationServer3D.map_get_closest_point(rid, tg[1])
		var path: PackedVector3Array = _dedupe(NavigationServer3D.map_get_path(rid, c.global_position, goal, true))
		if path.size() >= 1 and _flat_len(path) < GOAL_M and absf(path[0].y - goal.y) < 0.5:
			dropped += 1  # 0 m leg (already at the use point, e.g. right after a setup teleport): nothing to walk
			continue
		if path.size() < 2 or path[path.size() - 1].distance_to(goal) > 0.75:
			_row(heist, "NAV", tg[0], c.global_position, "no navmesh path from the previous stop")
			continue
		legs += 1
		var res: Dictionary = await _follow(c, _door_centred(path) if door_centres else path,
			_rt.map.get_node_or_null(NodePath(String(tg[0]))))
		walked += float(res["walked"])
		if bool(res["ok"]):
			ok_legs += 1
			if res.has("note"):  # reached its target door, which a walk cannot open (keycard / drill / vault)
				_row(heist, "AT-LOCKED-DOOR", tg[0], res["at"], String(res["note"]))
		else:
			# LOCKED: behind a progression lock a walk cannot open (vault / keycard without the card / code / ...).
			var locked_by: bool = bool(res.get("locked", false))
			if locked_by:
				locked += 1
			else:
				stuck += 1
			_row(heist, ("LOCKED-" if locked_by else "STUCK-") + ("DOOR" if door_centres else "AI"), tg[0], res["at"],
				"stalled before corner %s (%s)" % [res["corner"], res["why"]])
			_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, goal + Vector3.UP * 0.05))  # setup reset (logged)
			await wait_physics_frames(3)
	var secs: float = float(Time.get_ticks_msec() - t0) / 1000.0
	var mode: String = "doors" if door_centres else "corners"
	print(("[PP-C-1] %s (%s): %d targets, %d legs walked, %d ok, %d stuck, %d behind progression locks, "
		+ "%d 0 m legs dropped, %.0f m in %.0f s wall, ")
		% [heist, mode, targets.size(), legs, ok_legs, stuck, locked, dropped, walked, secs]
		+ "masked %s, phase %s" % [c.masked, Enums.HeistPhase.keys()[_rt.phase]])
	assert_true(legs > 0, "%s: at least one leg walked" % heist)
	_rows.append("| %s | summary (%s) | | %d/%d legs ok, %d stuck, %d locked, %.0f m walked |" % [heist, mode, ok_legs, legs,
		stuck, locked, walked])


## Walk a nav path with real input. Returns {"ok", "at", "corner", "why", "walked"}.
## A stall in front of a closed door is handled like a player: mask up if the door needs it (G hold), aim at the
## door's handle (mouse look), hold F for the door's own interaction time (open / lockpick / keycard), go on.
## `target`: the leg's target prefab; stalling at that very door within reach of its handle reaches it (ok + "note").
func _follow(c: CrewController, raw_path: PackedVector3Array, target: Node = null) -> Dictionary:
	var walked: float = 0.0
	var path: PackedVector3Array = _dedupe(raw_path)
	for i: int in range(1, path.size()):
		var corner: Vector3 = path[i]
		var flat: Vector3 = corner - c.global_position
		flat.y = 0.0
		var last: bool = i == path.size() - 1
		if flat.length() < (GOAL_M if last else CORNER_M):
			continue
		var tries: int = 0
		while true:
			flat = corner - c.global_position
			flat.y = 0.0
			var yaw: float = atan2(-flat.x, -flat.z)
			if not await _inp.turn_to_yaw(c, yaw, 0.05, 2.0):
				return {"ok": false, "at": c.global_position, "corner": corner, "why": "turn_to_yaw failed", "walked": walked}
			var start: Vector3 = c.global_position
			var dist: float = flat.length()
			var reached: bool = await _inp.walk_until(&"move_forward", func() -> bool:
				var d: Vector3 = corner - c.global_position
				d.y = 0.0
				return d.length() < (GOAL_M if last else CORNER_M) or d.dot(flat) < 0.0, dist / SPEED_MIN_MPS + 1.0)
			walked += start.distance_to(c.global_position)
			if reached:
				break
			tries += 1
			var door: Door = _blocking_door(c, path, i)
			var ladder: Ladder = _ladder_near(c, corner) if door == null else null
			var why: String = ""
			if door != null:
				why = await _open_door(c, door)
			elif ladder != null:
				why = await _use_ladder(c, ladder)
			var used: bool = door != null or ladder != null
			if door != null and why != "" and door == target and _progression_locked(c, door):
				return {"ok": true, "at": c.global_position, "corner": corner, "why": "", "walked": walked, "note": why}
			if tries > 2 or (used and why != "") or (not used and tries > 1):
				var tail: String = why
				if tail == "":
					tail = "no closed door or ladder in the way" if not used else "`%s` used but still blocked" % (
						door.name if door != null else ladder.name)
				return {"ok": false, "at": c.global_position, "corner": corner,
					"why": "no progress (%.1f m of %.1f m): %s" % [start.distance_to(c.global_position), dist, tail],
					"walked": walked, "locked": door != null and why != "" and _progression_locked(c, door)}
			await wait_seconds(0.3)
	return {"ok": true, "at": c.global_position, "corner": Vector3.ZERO, "why": "", "walked": walked}


## The closed door the walker is stuck at: the first closed doorway on the rest of the path (from the crew), else the
## nearest closed door whose handle is within interaction reach.
func _blocking_door(c: CrewController, path: PackedVector3Array, from_i: int) -> Door:
	var rest: PackedVector3Array = PackedVector3Array([c.global_position])
	rest.append_array(path.slice(from_i))
	var hit: Dictionary = Door.first_closed_on_path(get_tree(), rest, 3.0)
	if not hit.is_empty():
		var hd: Door = hit["door"] as Door
		if hd.interactable != null \
				and c.eye_position().distance_to(hd.interactable.global_position) <= Tweak.interaction().reach_m + 0.35:
			return hd
	var best: Door = null
	var best_d: float = 1.0  # flat m from the doorway centre: the walker is pressed against this leaf
	for n: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var d: Door = n as Door
		if d == null or d.is_open or d.interactable == null or not _rt.is_ancestor_of(d):
			continue
		var o: Vector3 = d.global_position - c.global_position
		var dist: float = Vector2(o.x, o.z).length()
		if dist < best_d and absf(o.y) < 1.0:
			best = d
			best_d = dist
	return best


## A locked door a walk cannot open: not LOCKPICK, and not a KEYCARD door the walker holds a card for.
func _progression_locked(c: CrewController, door: Door) -> bool:
	if not door.locked or door.lock == Door.Lock.LOCKPICK:
		return false
	return door.lock != Door.Lock.KEYCARD or c.item_count(Door.KEYCARD_ITEM) <= 0


## Open `door` the way a player does. Returns "" when it is open, else why not (a genuine block).
func _open_door(c: CrewController, door: Door) -> String:
	var tag: String = "door `%s` (%s, %s)" % [door.name, Door.Lock.keys()[door.lock], "locked" if door.locked else "unlocked"]
	var comp: InteractableComponent = door.interactable
	var why: String = "has no Interactable"
	if comp != null:
		why = await _use_door(c, door, comp)
	return "" if why == "" else "%s %s" % [tag, why]


func _use_door(c: CrewController, door: Door, comp: InteractableComponent) -> String:
	var reason: StringName = comp.availability(c)
	if reason == InteractableComponent.BLOCK_CASING and not c.masked:
		await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)  # G hold, as a player masks up
		await wait_physics_frames(2)
		reason = comp.availability(c)
		if not c.masked:
			reason = &"mask-up hold did not mask"
	if reason != InteractableComponent.BLOCK_NONE:
		return "not usable: %s" % reason
	if not await _aim_at(c, comp.global_position):
		return "could not aim at its handle"
	if _rt.interaction.aimed_component(c) != comp:
		return "handle not aimed (%.1f m from the eye)" % c.eye_position().distance_to(comp.global_position)
	var hold_s: float = comp.duration_for(c) + 0.5
	await _inp.hold(&"interact", hold_s)  # F hold for the door's own time (lockpick 8 s)
	await wait_physics_frames(3)
	await _aim_pitch(c, 0.0)
	return "" if door.is_open else "still closed after a %.1f s interact hold" % hold_s


## A ladder end the walker stands at (same height; within 1.5 m flat, or 3 m when the stalled corner is a floor
## above / below, i.e. the nav path takes the ladder's link).
func _ladder_near(c: CrewController, corner: Vector3) -> Ladder:
	var reach: float = 3.0 if absf(corner.y - c.global_position.y) > 1.5 else 1.5
	var best: Ladder = null
	var best_d: float = reach
	for n: Node in _rt.map.find_children("*", "Ladder", true, false):
		var lad: Ladder = n as Ladder
		for m: Vector3 in [lad.bottom_position(), lad.top_position()]:
			var d: float = Vector2(m.x - c.global_position.x, m.z - c.global_position.z).length()
			if d < best_d and absf(m.y - c.global_position.y) < Ladder.GRAB_HEIGHT_M:
				best = lad
				best_d = d
	return best


## Climb `lad` the way a player does: mask up if needed, step onto its end marker, face it, hold forward.
## Returns "" once the climb is done, else why not.
func _use_ladder(c: CrewController, lad: Ladder) -> String:
	if not c.masked:
		await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
		await wait_physics_frames(2)
	var up: bool = absf(lad.bottom_position().y - c.global_position.y) < absf(lad.top_position().y - c.global_position.y)
	var marker: Vector3 = lad.bottom_position() if up else lad.top_position()
	var grab: float = Tweak.interaction().ladder_grab_radius_m
	var to: Vector3 = marker - c.global_position
	if Vector2(to.x, to.z).length() > grab * 0.7:
		await _inp.turn_to_yaw(c, atan2(-to.x, -to.z), 0.05, 2.0)
		await _inp.walk_until(&"move_forward", func() -> bool:
			var d: Vector3 = marker - c.global_position
			return Vector2(d.x, d.z).length() < grab * 0.6 or lad.is_climbing(c.slot), 3.0)
	if not lad.is_climbing(c.slot):
		var face: Vector3 = lad.global_position - c.global_position
		await _inp.turn_to_yaw(c, atan2(-face.x, -face.z), 0.05, 2.0)
		await _inp.walk_until(&"move_forward", func() -> bool: return lad.is_climbing(c.slot), 2.0)
	if not lad.is_climbing(c.slot):
		return "ladder `%s` (%s): no climb started from (%.1f, %.1f, %.1f), end marker (%.1f, %.1f, %.1f), masked %s" % [
			lad.name, "up" if up else "down", c.global_position.x, c.global_position.y, c.global_position.z,
			marker.x, marker.y, marker.z, c.masked]
	await wait_until(func() -> bool: return not lad.is_climbing(c.slot), lad.climb_time() + 2.0)
	await wait_physics_frames(3)
	return ""


## Setup only: no NPC, no camera, no assault (see header).
func _quiet_map() -> void:
	_rt.isolate_npc(null)
	for cam: SecurityCamera in SecurityCamera.cameras_in(_rt):
		cam.get_parent().remove_child(cam)
		cam.queue_free()
	var dir: Node = _rt.service(G.SVC_DIRECTOR)
	if dir != null:
		dir.process_mode = Node.PROCESS_MODE_DISABLED


## Mouse-look at `p` (yaw, then pitch).
func _aim_at(c: CrewController, p: Vector3) -> bool:
	var to: Vector3 = p - c.eye_position()
	if not await _inp.turn_to_yaw(c, atan2(-to.x, -to.z), 0.02, 2.0):
		return false
	return await _aim_pitch(c, atan2(to.y, Vector2(to.x, to.z).length()))


## Mouse-look (vertical) until the crew's pitch is within 0.02 rad of `pitch`.
func _aim_pitch(c: CrewController, pitch: float) -> bool:
	var rpp: float = _inp.mouse_radians_per_px()
	for _i: int in 12:
		var err: float = pitch - c.look_pitch
		if absf(err) <= 0.02:
			return true
		_inp.look(0.0, -err / rpp)  # +y (mouse down) lowers the pitch
		await wait_physics_frames(6)
	return absf(pitch - c.look_pitch) <= 0.02


## `path` without consecutive points at the same spot (a teleport or a nav corner on the start point).
func _dedupe(path: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in path:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.05:
			out.append(p)
	return out


func _flat_len(path: PackedVector3Array) -> float:
	var s: float = 0.0
	for i: int in range(1, path.size()):
		s += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
	return s


## Use points of gameplay prefabs (+ zone centres), greedy nearest-first from the player spawn.
func _targets(map: Node) -> Array[Array]:
	var pts: Array[Array] = []
	var gp: Node = map.get_node_or_null(^"Gameplay")
	if gp != null:
		for up: Node in gp.find_children("UsePoint", "Node3D", true, false):
			var owner_n: Node = up.get_parent()
			if owner_n.is_inside_tree() and (owner_n as Node3D).is_visible_in_tree():
				pts.append([String(map.get_path_to(owner_n)), (up as Node3D).global_position])
	var c: Vector3 = (_rt.crew_controller(0) as Node3D).global_position
	var out: Array[Array] = []
	var step: int = maxi(1, pts.size() / MAX_TARGETS)
	var picked: Array[Array] = []
	for i: int in range(0, pts.size(), step):
		picked.append(pts[i])
	while not picked.is_empty() and out.size() < MAX_TARGETS:
		var best: int = 0
		for j: int in range(picked.size()):
			if (picked[j][1] as Vector3).distance_to(c) < (picked[best][1] as Vector3).distance_to(c):
				best = j
		out.append(picked[best])
		c = picked[best][1]
		picked.remove_at(best)
	return out


func _row(heist: StringName, kind: String, target: String, at: Vector3, note: String) -> void:
	var s: String = "| %s | %s | `%s` | at (%.1f, %.1f, %.1f), nearest door %s: %s |" % [heist, kind, target, at.x, at.y,
		at.z, _nearest_door(at), note]
	_rows.append(s)
	print("[PP-C-1] " + s)


## Corners within 1.5 m (flat) of a Door become [1 m before the leaf centre, 1 m past it] on the walker's side.
func _door_centred(path: PackedVector3Array) -> PackedVector3Array:
	var doors: Array[Node] = _rt.map.find_children("*", "Door", true, false)
	var out: PackedVector3Array = PackedVector3Array([path[0]])
	var used: Dictionary = {}
	for i: int in range(1, path.size()):
		var p: Vector3 = path[i]
		var hit: Door = null
		for n: Node in doors:
			var d: Door = n as Door
			var o: Vector3 = d.global_position
			if Vector2(o.x - p.x, o.z - p.z).length() < 1.5 and absf(o.y - p.y) < 1.5 and i < path.size() - 1:
				hit = d
				break
		if hit == null:
			out.append(p)
			continue
		if used.has(hit.get_instance_id()):
			continue
		used[hit.get_instance_id()] = true
		var xf: Transform3D = hit.global_transform
		var front: Vector3 = xf * Vector3(0.0, 0.0, -1.0)
		var back: Vector3 = xf * Vector3(0.0, 0.0, 1.0)
		var prev: Vector3 = out[out.size() - 1]
		if prev.distance_to(back) < prev.distance_to(front):
			var t: Vector3 = front
			front = back
			back = t
		front.y = p.y
		back.y = p.y
		out.append(front)
		out.append(back)
	return out


## Nearest Door prefab to `at` ("name d m"), so A / P can reproduce a stall headless.
func _nearest_door(at: Vector3) -> String:
	if _rt == null or _rt.map == null:
		return "?"
	var best: String = "none"
	var best_d: float = INF
	for n: Node in _rt.map.find_children("*", "Door", true, false):
		var d: float = (n as Node3D).global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = "`%s` %.1f m" % [n.name, d]
	return best
