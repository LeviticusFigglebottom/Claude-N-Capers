## D-157 review: an equipment visual (the crew sentry) checked against ENV A's node contract and rendered as a
## turntable plus an in-heist shot. Prints every node with its local position, checks the contract (Base at the floor,
## Base/Yaw pivot ~0.55 m, Yaw/Pitch, Pitch/Gun, Pitch/Muzzle -Z = forward and level at rest, Pitch/Shield,
## Base/AmmoBox, no CollisionObject3D anywhere) and writes <out>/<id>_turntable.png (8 views, 45 deg apart, plus the
## same with the Shield shown and the gun yawed / pitched by code) and <out>/<id>_ingame.png (on the Glasshouse crew
## spawn floor, eye height 1.65 m).
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 960x540 --path game res://world/characters/_tools/render_equipment_review.tscn -- --out=/abs/dir \
##     [--glb=res://assets/equipment/eqp_sentry/eqp_sentry.glb]
## Owner: ENV D.
extends Node3D

const TILE: Vector2i = Vector2i(480, 360)

var _out: String = ""
var _glb: String = "res://assets/equipment/eqp_sentry/eqp_sentry.glb"
var _cam: Camera3D = null
var _log: PackedStringArray = []
var _fails: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--glb="):
			_glb = a.trim_prefix("--glb=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/equipment_review"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var id: String = _glb.get_file().get_basename()
	var model: Node3D = (load(_glb) as PackedScene).instantiate() as Node3D
	add_child(model)  # global transforms are only valid in the tree
	_check(model)
	await _turntable(id, model)
	await _ingame(id)
	var f: FileAccess = FileAccess.open("%s/%s_review_log.txt" % [_out, id], FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	print("[EQUIP] RESULT %s fails=%d %s" % ["PASS" if _fails == 0 else "FAIL", _fails, _out])
	get_tree().quit(0 if _fails == 0 else 1)


func _check(model: Node3D) -> void:
	for n: Node in model.find_children("*", "", true, false):
		if n is Node3D:
			_say("node %s (%s) local %s" % [model.get_path_to(n), n.get_class(), (n as Node3D).position])
		if n is CollisionObject3D:
			_expect(false, "no collision (A owns it): %s" % model.get_path_to(n))
	var base: Node3D = model.find_child("Base", true, false) as Node3D
	var yaw: Node3D = model.find_child("Yaw", true, false) as Node3D
	var pitch: Node3D = model.find_child("Pitch", true, false) as Node3D
	var muzzle: Node3D = model.find_child("Muzzle", true, false) as Node3D
	_expect(base != null and yaw != null and pitch != null and muzzle != null, "Base / Yaw / Pitch / Muzzle exist")
	_expect(model.find_child("Gun", true, false) != null and model.find_child("Shield", true, false) != null,
		"Pitch/Gun and Pitch/Shield exist")
	_expect(model.find_child("AmmoBox", true, false) != null, "Base/AmmoBox exists")
	if base == null or yaw == null or pitch == null or muzzle == null:
		return
	_expect(yaw.get_parent() == base and pitch.get_parent() == yaw and muzzle.get_parent() == pitch,
		"hierarchy Base/Yaw/Pitch/Muzzle")
	var yaw_h: float = yaw.global_position.y - model.global_position.y
	_expect(absf(yaw_h - 0.55) < 0.05, "Yaw pivot %.3f m above the floor (~0.55)" % yaw_h)
	var fwd: Vector3 = -muzzle.global_basis.z.normalized()
	_expect(fwd.dot(Vector3.FORWARD) > 0.99, "Muzzle -Z faces the front (-Z), level: %s" % fwd)
	var reach: float = -(pitch.global_basis.inverse() * (muzzle.global_position - pitch.global_position)).z
	_expect(reach > 0.45 and reach < 0.75, "barrel reach %.3f m in front of the pitch pivot (~0.6)" % reach)
	var stand: Array[MeshInstance3D] = []
	for n: Node in [base, model.find_child("AmmoBox", true, false)]:
		if n is MeshInstance3D:
			stand.append(n as MeshInstance3D)
	var aabb: AABB = _aabb(stand)
	_expect(aabb.size.x < 0.62 and aabb.size.z < 0.62 and aabb.position.y > -0.01,
		"stand footprint %.2f x %.2f m, nothing below the floor (%.3f)" % [aabb.size.x, aabb.size.z, aabb.position.y])


## The world AABB of `meshes` (the stand: Base and its AmmoBox, not the gun on Yaw).
func _aabb(meshes: Array[MeshInstance3D]) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in meshes:
		var box: AABB = mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _turntable(id: String, model: Node3D) -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.78, 0.79, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.52)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(4, 4)
	floor_mi.mesh = pm
	add_child(floor_mi)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_cam.current = true
	var tiles: Array[Image] = []
	for i: int in 8:
		var a: float = deg_to_rad(45.0 * i + 20.0)
		_cam.look_at_from_position(Vector3(sin(a) * 1.7, 1.0, cos(a) * 1.7), Vector3(0, 0.45, 0))
		tiles.append(await _grab())
	# the code-driven pivots and the shield: yaw 35 deg, pitch up 15 deg, Shield shown
	var yaw: Node3D = model.find_child("Yaw", true, false) as Node3D
	var pitch: Node3D = model.find_child("Pitch", true, false) as Node3D
	var shield: Node3D = model.find_child("Shield", true, false) as Node3D
	if yaw != null and pitch != null:
		yaw.rotation_degrees.y = 35.0
		pitch.rotation_degrees.x = 15.0
	for i: int in [1, 3]:
		var a: float = deg_to_rad(45.0 * i + 20.0)
		_cam.look_at_from_position(Vector3(sin(a) * 1.7, 1.0, cos(a) * 1.7), Vector3(0, 0.45, 0))
		tiles.append(await _grab())
	if shield != null:
		shield.visible = false
		var a2: float = deg_to_rad(20.0)
		_cam.look_at_from_position(Vector3(sin(a2) * 1.7, 1.0, cos(a2) * 1.7), Vector3(0, 0.45, 0))
		tiles.append(await _grab())
		shield.visible = true
	_sheet(tiles, 4, "%s/%s_turntable.png" % [_out, id])
	for c: Node in get_children():
		c.queue_free()
	await get_tree().process_frame


func _ingame(id: String) -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0})
	if rt == null:
		_say("in-game: launch failed")
		return
	for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var crew: Array[CrewController] = rt.crew_members()
	var at: Vector3 = crew[0].global_position if not crew.is_empty() else Vector3.ZERO
	var fwd: Vector3 = -crew[0].global_basis.z if not crew.is_empty() else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized()
	# the open direction: the first of 8 (the crew's facing first) with 3.5 m of clear floor at knee and chest height
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for k: int in 8:
		var d: Vector3 = fwd.rotated(Vector3.UP, k * PI / 4.0)
		var clear: bool = true
		for h: float in [0.4, 1.2]:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * h,
				at + Vector3.UP * h + d * 3.5)
			if not crew.is_empty():
				q.exclude = [crew[0].get_rid()]
			clear = clear and space.intersect_ray(q).is_empty()
		if clear:
			fwd = d
			break
	var model: Node3D = (load(_glb) as PackedScene).instantiate() as Node3D
	add_child(model)
	model.global_position = at + fwd * 2.2
	model.look_at(model.global_position + fwd, Vector3.UP)  # the sentry faces where the crew looks
	_cam = Camera3D.new()
	_cam.fov = 75.0
	add_child(_cam)
	_cam.current = true
	var side: Vector3 = Vector3(-fwd.z, 0.0, fwd.x)
	var tiles: Array[Image] = []
	_cam.look_at_from_position(at + Vector3.UP * 1.65, model.global_position + Vector3.UP * 0.45)
	tiles.append(await _grab())
	_cam.look_at_from_position(model.global_position + fwd * 2.0 + side * 1.0 + Vector3.UP * 1.3,
		model.global_position + Vector3.UP * 0.45)
	tiles.append(await _grab())
	_sheet(tiles, 2, "%s/%s_ingame.png" % [_out, id])
	_say("in-game: sentry at %s" % model.global_position)


func _grab() -> Image:
	for _i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	return img


func _sheet(tiles: Array[Image], cols: int, path: String) -> void:
	var rows: int = ceili(float(tiles.size()) / cols)
	var sheet: Image = Image.create(TILE.x * cols, TILE.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for k: int in tiles.size():
		sheet.blit_rect(tiles[k], Rect2i(Vector2i.ZERO, TILE), Vector2i((k % cols) * TILE.x, (k / cols) * TILE.y))
	sheet.save_png(path)
	_say("sheet %s" % path)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	_say("%s %s" % ["OK  " if ok else "FAIL", what])


func _say(s: String) -> void:
	_log.append(s)
	print("[EQUIP] " + s)
