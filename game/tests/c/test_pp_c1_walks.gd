## PP-C-1 (D-082 playability pass): a real-input walk of every ENV C heist. Owner: ENV C.
## The human crew member (slot 0) is driven only through PInputDriver (ENV P: InputMap actions + mouse look
## into PlayerInput; never set_bot_intent): from the player spawn it walks the navmesh path to every
## gameplay use point (doors, devices, loot, objectives), turning with turn_to_yaw at each path corner and
## holding move_forward. A leg that makes no progress gets one `interact` tap (a closed door) and a retry; a
## leg that still stalls is a STUCK row (position, target, corner) and the walk resumes from the target by a
## setup teleport (logged). Setup shortcuts (outside movement, named): skip_casing, no AI teammates, every map
## NPC despawned (isolate_npc), so a guard cannot end the walk. Rows: docs/levels/pp_c1.md.
extends TestCase

const HEISTS: Dictionary = {&"glasshouse": 1001, &"night_deposit": 1001, &"dockside_burn": 1001}
const MAX_TARGETS: int = 14
const CORNER_M: float = 0.6
## The last corner is the use point in front of a prop / door: within arm's reach counts.
const GOAL_M: float = 1.1
const SPEED_MIN_MPS: float = 1.0

var _rt: HeistRuntime = null
var _inp: PInputDriver = null
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


func _walk_heist(heist: StringName) -> void:
	_rt = await HeistLauncher.launch(heist, int(HEISTS[heist]), Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch %s" % heist)
		return
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "%s nav ready" % heist)
	_rt.isolate_npc(null)
	await wait_physics_frames(2)
	var rid: RID = c.get_world_3d().navigation_map
	var targets: Array[Array] = _targets(_rt.map)
	var legs: int = 0
	var ok_legs: int = 0
	var stuck: int = 0
	var t0: int = Time.get_ticks_msec()
	var walked: float = 0.0
	for tg: Array in targets:
		var goal: Vector3 = NavigationServer3D.map_get_closest_point(rid, tg[1])
		var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, c.global_position, goal, true)
		if path.size() < 2 or path[path.size() - 1].distance_to(goal) > 0.75:
			_row(heist, "NAV", tg[0], c.global_position, "no navmesh path from the previous stop")
			continue
		legs += 1
		var res: Dictionary = await _follow(c, path)
		walked += float(res["walked"])
		if bool(res["ok"]):
			ok_legs += 1
		else:
			stuck += 1
			_row(heist, "STUCK", tg[0], res["at"], "stalled before corner %s (%s)" % [res["corner"], res["why"]])
			_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, goal + Vector3.UP * 0.05))  # setup reset (logged)
			await wait_physics_frames(3)
	var secs: float = float(Time.get_ticks_msec() - t0) / 1000.0
	print("[PP-C-1] %s: %d targets, %d legs walked, %d ok, %d stuck, %.0f m in %.0f s wall" % [heist,
		targets.size(), legs, ok_legs, stuck, walked, secs])
	assert_true(legs > 0, "%s: at least one leg walked" % heist)
	_rows.append("| %s | summary | | %d/%d legs ok, %d stuck, %.0f m walked |" % [heist, ok_legs, legs, stuck, walked])


## Walk a nav path with real input. Returns {"ok", "at", "corner", "why", "walked"}.
func _follow(c: CrewController, path: PackedVector3Array) -> Dictionary:
	var walked: float = 0.0
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
			if tries > 1:
				return {"ok": false, "at": c.global_position, "corner": corner,
					"why": "no progress after interact (%.1f m of %.1f m)" % [start.distance_to(c.global_position), dist],
					"walked": walked}
			# A closed door: a real player holds interact (opens an unlocked door, picks a LOCKPICK one).
			await _inp.hold(&"interact", 10.0)
			await wait_seconds(0.5)
	return {"ok": true, "at": c.global_position, "corner": Vector3.ZERO, "why": "", "walked": walked}


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
	var s: String = "| %s | %s | `%s` | at (%.1f, %.1f, %.1f): %s |" % [heist, kind, target, at.x, at.y, at.z, note]
	_rows.append(s)
	print("[PP-C-1] " + s)
