## PP-D playability review: enemy classes in real heist lighting, first person, 720p. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --script res://world/characters/_tools/render_heist_review.gd
## For each map: picks the first Spawns marker (then 8 yaw directions) with a clear 42 m line at chest height,
## places the enemy line-up (idle_alert, real LOD ranges) across the view at 10/20/40 m (or the clear
## distance), eye 1.65 m, FOV 75. Writes res://assets/characters/_review/heist_<map>_<d>m.png.
extends SceneTree

const OUT_DIR: String = "res://assets/characters/_review/"
const MAPS: Array[String] = ["night_deposit", "glasshouse", "dockside_burn"]
const IDS: Array[String] = ["patrol_officer", "tac_light", "tac_heavy", "stinger", "bulwark", "longshot", "corpsman",
	"phantom", "security_officer", "cartel_gunman"]
const DISTANCES: Array[float] = [10.0, 20.0, 40.0]
## Two line-ups per distance (a: regular units, b: specials).
const GROUPS: Array = [["patrol_officer", "security_officer", "tac_light", "cartel_gunman", "frd_agent"],
	["tac_heavy", "stinger", "bulwark", "longshot", "corpsman", "phantom"]]
const SLOTS: int = 6
const FLOOR_TOL: float = 0.25
const EYE_H: float = 1.65
const SIZE: Vector2i = Vector2i(1280, 720)


## User args (after --): [map] [tag]; map limits the run to one map, tag is appended to the file names.
var _tag: String = ""
var _only_10: bool = false
var _dists: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var maps: Array[String] = MAPS
	if args.size() >= 1:
		maps = [args[0]]
		_only_10 = true
	if args.size() >= 2 and args[1] != "-":
		_tag = "_" + args[1]
	if args.size() >= 3:
		_dists = [float(args[2])]
	print("render_heist_review: renderer %s, adapter %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name()])
	for m: String in maps:
		await _map(m)
	print("render_heist_review: done")
	quit(0)


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b)
	return space.intersect_ray(q)


func _ground(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var hit: Dictionary = _ray(space, p + Vector3.UP * 1.5, p + Vector3.DOWN * 4.0)
	return (hit["position"] as Vector3).y if not hit.is_empty() else p.y


## Lineup slots at distance d across the view: floor only (the down ray lands within FLOOR_TOL of the eye
## marker's floor, so no props / vehicles), free standing room (no hit in a 0.4 m box around the chest), and a
## clear line of sight from the eye to the chest and the head. Left to right as seen by the camera.
func _slots(space: PhysicsDirectSpaceState3D, o: Vector3, fwd: Vector3, d: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var side: Vector3 = fwd.cross(Vector3.UP).normalized()
	var spacing: float = 1.0 + d * 0.02
	var eye: Vector3 = o + Vector3.UP * EYE_H
	for i: int in range(SLOTS * 3):
		if out.size() >= SLOTS:
			break
		# centre-out order: 0, +1, -1, +2, -2 ...
		var k: int = (i + 1) / 2 * (1 if i % 2 == 1 else -1)
		var p: Vector3 = o + fwd * d - side * spacing * k
		var hit: Dictionary = _ray(space, p + Vector3.UP * 2.2, p + Vector3.DOWN * 3.0)
		if hit.is_empty() or absf((hit["position"] as Vector3).y - o.y) > FLOOR_TOL:
			continue
		p.y = (hit["position"] as Vector3).y
		var chest: Vector3 = p + Vector3.UP * 1.3
		var blocked: bool = false
		for off: Vector3 in [side * 0.35, -side * 0.35, fwd * 0.35, -fwd * 0.35]:
			if not _ray(space, chest, chest + off).is_empty():
				blocked = true
		for tgt: Vector3 in [chest, p + Vector3.UP * 1.7, p + Vector3.UP * 0.6]:
			if not _ray(space, eye, tgt).is_empty():
				blocked = true
		if not blocked:
			out.append(p)
	out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return (a - o).dot(side) < (b - o).dot(side))
	return out


func _map(m: String) -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var level: Node3D = (load("res://world/heists/%s/%s.tscn" % [m, m]) as PackedScene).instantiate() as Node3D
	vp.add_child(level)
	for i: int in range(3):
		await physics_frame
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var spawns: Node = level.get_node_or_null(^"Spawns")
	var marks: Array[Node] = spawns.get_children() if spawns != null else []
	var best: Array = []
	var best_score: int = -1
	for mk: Node in marks:
		if not (mk is Node3D):
			continue
		var t: Transform3D = (mk as Node3D).global_transform
		for k: int in range(16):
			var dir: Vector3 = (-t.basis.z).rotated(Vector3.UP, TAU * k / 16.0)
			dir.y = 0.0
			if dir.length() < 0.1:
				continue
			dir = dir.normalized()
			var score: int = 0
			for d: float in DISTANCES:
				score += _slots(space, t.origin, dir, d).size() * (2 if d >= 40.0 else 1)
			if score > best_score:
				best_score = score
				best = [t.origin, dir]
	if best.is_empty():
		print("%s: no viewpoint" % m)
		vp.queue_free()
		return
	var o: Vector3 = best[0]
	var fwd: Vector3 = best[1]
	print("%s: view from %s dir %s score %d" % [m, o, fwd, best_score])
	for d: float in (_dists if not _dists.is_empty() else ([10.0] if _only_10 else DISTANCES)):
		var slots: Array[Vector3] = _slots(space, o, fwd, d)
		for g: int in range(GROUPS.size()):
			var ids: Array = GROUPS[g]
			var chars: Array[Node3D] = []
			var placed: Array[String] = []
			for i: int in range(mini(ids.size(), slots.size())):
				var ch: Node3D = (load("res://world/characters/%s/%s.tscn" % [ids[i], ids[i]]) as PackedScene).instantiate() as Node3D
				vp.add_child(ch)
				ch.global_position = slots[i]
				ch.look_at(Vector3(o.x, slots[i].y, o.z), Vector3.UP)
				var aps: Array[Node] = ch.find_children("*", "AnimationPlayer", true, false)
				if not aps.is_empty():
					var ap: AnimationPlayer = aps[0] as AnimationPlayer
					ap.play(&"humanoid/idle_alert")
					ap.seek(0.5, true)
				chars.append(ch)
				placed.append(String(ids[i]))
			var cam: Camera3D = Camera3D.new()
			cam.fov = 75.0
			cam.near = 0.05
			cam.far = 300.0
			vp.add_child(cam)
			var aim: Vector3 = o + fwd * d
			if not chars.is_empty():
				aim = Vector3.ZERO
				for ch: Node3D in chars:
					aim += ch.global_position
				aim /= float(chars.size())
			cam.look_at_from_position(o + Vector3.UP * EYE_H, aim + Vector3.UP * 1.1, Vector3.UP)
			cam.current = true
			for i: int in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			var name: String = "heist_%s_%dm_%s%s.png" % [m, int(d), "ab"[g], _tag]
			vp.get_texture().get_image().save_png(OUT_DIR + name)
			print("%s: %s left->right %s (%d/%d slots clear)" % [m, name, placed, slots.size(), SLOTS])
			cam.queue_free()
			for ch: Node3D in chars:
				ch.queue_free()
			await process_frame
	vp.queue_free()
	await process_frame
