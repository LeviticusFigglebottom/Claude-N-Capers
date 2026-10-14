## D-102 bag-run pacing probe. Carries each heist bag source's real loot weight along the navmesh route to every
## escape (and the thermite to every burn point) with REAL input (PInputDriver: move_forward + sprint held, mouse
## look steering), timing each run. Run as a scene; --old swaps in the pre-D-102 carry values for a comparison:
##   timeout 3000 /opt/godot/godot --headless --fixed-fps 60 --path game res://tests/p/_review/bag_run_probe.tscn \
##     -- --heist=dockside_burn [--seed=1002] [--old] [--max_routes=40] [--out=/abs/file.json] [--nobag] [--debug]
## Windowed (D-086), a single route and a screenshot every --shot_s game seconds:
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --fixed-fps 60 --path game \
##     res://tests/p/_review/bag_run_probe.tscn -- --heist=dockside_burn --only=3 --shot_s=4 --shots=/abs/dir
## Prints one "[BAGRUN] ..." line per route and "[BAGRUN] RESULT ...". Owner: ENV P.
extends Node

const REACH_WAYPOINT_M: float = 0.6
const ARRIVE_M: float = 1.5
const STALL_S: float = 4.0

var _args: Dictionary = {}
var _rt: HeistRuntime = null
var _inp: PInputDriver = null
var _ticks: int = 0
var _rows: Array[Dictionary] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var code: int = await _run()
	get_tree().quit(code)


func _physics_process(_delta: float) -> void:
	_ticks += 1


func _physics(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _run() -> int:
	var heist: StringName = StringName(String(_args.get("heist", "dockside_burn")))
	var tw: CrewTweak = Tweak.crew()
	if _args.has("old"):  # pre-D-102 (S10.1 estimates)
		tw.bag_speed_mult = PackedFloat32Array([0.95, 0.85, 0.75, 0.6])
		tw.bag_can_sprint = [true, true, false, false] as Array[bool]
		tw.bag_jump_mult = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	var run_seed: int = int(String(_args.get("seed", "1002")))
	_rt = await HeistLauncher.launch(heist, run_seed, Enums.Difficulty.ROUTINE, self, {"ai_teammates": 0, "crew_ai": false})
	if _rt == null:
		print("[BAGRUN] RESULT FAIL launch")
		return 1
	_rt.isolate_npc(null)
	var dir: Node = _rt.service(G.SVC_DIRECTOR)
	if dir != null:  # pacing only: no assault waves (a loud heist would down the probe crew mid-route)
		dir.process_mode = Node.PROCESS_MODE_DISABLED
	for n: Node in _rt.find_children("*", "Door", true, false):
		(n as Door).unlock()
		(n as Door).set_open(true)
	await _physics(10)
	var nav0: RID = get_viewport().world_3d.navigation_map
	for _k: int in 600:
		if NavigationServer3D.map_get_iteration_id(nav0) > 1 and not NavigationServer3D.map_get_regions(nav0).is_empty():
			break
		await _physics(1)
	print("[BAGRUN] nav regions %d iteration %d" % [NavigationServer3D.map_get_regions(nav0).size(),
		NavigationServer3D.map_get_iteration_id(nav0)])
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	c.stealth_hidden = true
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var spawn: Vector3 = c.global_position
	var routes: Array[Dictionary] = _routes(spawn)
	var dests: Dictionary[String, bool] = {}
	for r: Dictionary in routes:
		dests[String(r["to"])] = true
	print("[BAGRUN] %s seed %d: %d routes to %s (%s)" % [heist, run_seed, routes.size(), dests.keys(),
		"old values" if _args.has("old") else "D-102"])
	var only: int = int(String(_args.get("only", "-1")))
	var max_routes: int = int(String(_args.get("max_routes", "40")))
	for k: int in mini(routes.size(), max_routes):
		if only >= 0 and k != only:
			continue
		var row: Dictionary = await _carry_route(c, routes[k])
		row["i"] = k
		_rows.append(row)
		print("[BAGRUN] #%d %s w%d %s -> %s path %.1f m  %s  %.1f s  (%.2f m/s, sprint %d%%)" % [k, row["loot"],
			row["w"], row["from"], row["to"], row["path_m"], "OK" if row["ok"] else "FAIL " + String(row["why"]),
			row["t_s"], row["avg_mps"], row["sprint_pct"]])
	_inp.release_all()
	if _args.has("out"):
		var f: FileAccess = FileAccess.open(String(_args["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_rows, "  "))
	var fails: int = _rows.filter(func(r: Dictionary) -> bool: return not bool(r["ok"])).size()
	print("[BAGRUN] RESULT DONE routes=%d fails=%d" % [_rows.size(), fails])
	_rt.teardown()
	return 0


## Bag sources (LootSpawn: its loot's weight; the crew spawn: thermite) x destinations (every EscapeZone; burn
## points for the thermite). One route per distinct source position and destination.
func _routes(spawn: Vector3) -> Array[Dictionary]:
	var escapes: Array[Node3D] = []
	for n: Node in _rt.find_children("*", "EscapeZone", true, false):
		escapes.append(n as Node3D)
	var out: Array[Dictionary] = []
	var seen: Dictionary[String, bool] = {}
	for n: Node in _rt.find_children("*", "LootSpawn", true, false):
		var ls: LootSpawn = n as LootSpawn
		var def: LootDef = ContentDB.loot(ls.loot_id)
		var w: int = def.weight if def != null else Enums.LootWeight.MEDIUM
		for e: Node3D in escapes:
			var key: String = "%s|%s|%s" % [ls.loot_id, ls.name, e.name]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"loot": String(ls.loot_id), "w": w, "from": String(ls.name), "to": String(e.name),
				"a": ls.global_position, "b": e.global_position})
	for n: Node in _rt.find_children("*", "BurnPoint", true, false):
		var bp: Node3D = n as Node3D
		out.append({"loot": "loot.thermite", "w": Enums.LootWeight.HEAVY, "from": "spawn", "to": String(bp.name),
			"a": spawn, "b": bp.global_position})
	return out


func _carry_route(c: CrewController, r: Dictionary) -> Dictionary:
	var row: Dictionary = {"loot": r["loot"], "w": r["w"], "from": r["from"], "to": r["to"], "ok": false, "why": "",
		"t_s": 0.0, "path_m": 0.0, "avg_mps": 0.0, "sprint_pct": 0}
	var nav: RID = c.get_world_3d().navigation_map
	var a: Vector3 = NavigationServer3D.map_get_closest_point(nav, r["a"])
	var b: Vector3 = NavigationServer3D.map_get_closest_point(nav, r["b"])
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, a, b, true)
	if path.size() < 2:
		row["why"] = "no nav path (a %s -> %s, b %s -> %s, map %s, own %s)" % [r["a"], a, r["b"], b, nav,
			get_viewport().world_3d.navigation_map]
		return row
	path = CrewAiBrain.offset_corners(path, 0.45)  # keep the capsule off inside corners (D-085)
	var plen: float = 0.0
	for k: int in range(1, path.size()):
		plen += path[k].distance_to(path[k - 1])
	row["path_m"] = plen
	_rt.isolate_npc(null)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, a + Vector3.UP * 0.05))
	await _physics(5)
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	if c.is_carrying_bag():
		loot.drop_bag(c, false)
	var bag: LootBag = loot.spawn_bag(StringName(r["loot"]), Transform3D(Basis.IDENTITY, c.global_position), true,
		int(r["w"]))
	await _physics(1)
	if not _args.has("nobag"):
		loot.carry(bag, c)
	await _physics(2)
	var shot_s: float = float(String(_args.get("shot_s", "0")))
	var next_shot: float = 0.0
	var wp: int = 1
	var t0: int = _ticks
	var sprint_ticks: int = 0
	var best: float = INF
	var best_t: int = _ticks
	var timeout_s: float = plen / (Tweak.crew().walk_speed * 0.2) + 20.0
	var to0: Vector3 = path[1] - c.global_position
	await _inp.turn_to_yaw(c, atan2(-to0.x, -to0.z))
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	t0 = _ticks
	best_t = _ticks
	while true:
		await _physics(1)
		var t: float = float(_ticks - t0) / Engine.physics_ticks_per_second
		var p: Vector3 = c.global_position
		while wp < path.size() - 1 and Vector2(p.x - path[wp].x, p.z - path[wp].z).length() < REACH_WAYPOINT_M:
			wp += 1
		var d_end: float = Vector2(p.x - b.x, p.z - b.z).length()
		if d_end < ARRIVE_M and absf(p.y - b.y) < 1.5:
			row["ok"] = true
			row["t_s"] = t
			break
		var to: Vector3 = path[wp] - p
		var yaw: float = atan2(-to.x, -to.z)
		var err: float = wrapf(yaw - c.look_yaw, -PI, PI)
		if absf(err) > 0.02 and (_ticks - t0) % 3 == 0:  # input lands per rendered frame: don't stack corrections
			_inp.look(-clampf(err, -0.25, 0.25) / PInputDriver.mouse_radians_per_px(), 0.0)
		if c.sprinting:
			sprint_ticks += 1
		var rem: float = _remaining(path, wp, p)
		if rem < best - 0.25:
			best = rem
			best_t = _ticks
		if (_ticks - t0) % 60 == 0:
			_rt.isolate_npc(null)
		if _args.has("debug") and (_ticks - t0) % 30 == 0:
			print("[BAGRUN] dbg t %.1f p %s v %s sprint %s yaw %.2f->%.2f wp %d grounded %s" % [t,
				p.snapped(Vector3.ONE * 0.01), c.velocity.snapped(Vector3.ONE * 0.01), c.sprinting, c.look_yaw, yaw, wp,
				c.grounded])
			print("[BAGRUN] dbg   state %d carrying %s y %.2f" % [c.crew_state, c.is_carrying_bag(), p.y])
		if float(_ticks - best_t) / Engine.physics_ticks_per_second > STALL_S:
			row["why"] = "stalled at %s (%.1f m left)" % [p.snapped(Vector3.ONE * 0.1), rem]
			row["t_s"] = t
			break
		if t > timeout_s:
			row["why"] = "timeout"
			row["t_s"] = t
			break
		if not c.is_carrying_bag() and not _args.has("nobag"):
			row["why"] = "bag lost (state %d)" % c.crew_state
			row["t_s"] = t
			break
		if shot_s > 0.0 and t >= next_shot and _args.has("shots"):
			next_shot += shot_s
			get_viewport().get_texture().get_image().save_png("%s/route%s_%05.1f.png" % [String(_args["shots"]),
				String(_args.get("only", "x")), t])
	_inp.release(&"sprint")
	_inp.release(&"move_forward")
	if row["t_s"] > 0.0:
		row["avg_mps"] = plen / float(row["t_s"]) if row["ok"] else 0.0
		row["sprint_pct"] = int(100.0 * sprint_ticks / maxf(float(_ticks - t0), 1.0))
	if c.is_carrying_bag():
		loot.drop_bag(c, false)
	bag.queue_free()
	await _physics(10)
	return row


func _remaining(path: PackedVector3Array, wp: int, p: Vector3) -> float:
	var d: float = p.distance_to(path[wp])
	for k: int in range(wp + 1, path.size()):
		d += path[k].distance_to(path[k - 1])
	return d
