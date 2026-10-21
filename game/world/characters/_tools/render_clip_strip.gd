## A strip of one character's clip at chosen frames, front three-quarter, for checking single-frame snaps windowed
## (D polish, test_reaction_steps). One row per --clip, one tile per frame. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 \
##     --path game --script res://world/characters/_tools/render_clip_strip.gd -- --look=security_officer \
##     --clip=surrender:0,1,2,3,4 --clip=mask_on:21,22,23,24,25,26 --out=res://assets/characters/_review/x.png
extends SceneTree

const TILE: Vector2i = Vector2i(220, 330)

var _vp: SubViewport
var _cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var look: String = "security_officer"
	var out: String = "res://assets/characters/_review/clip_strip.png"
	var rows: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--look="):
			look = a.trim_prefix("--look=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--clip="):
			var parts: PackedStringArray = a.trim_prefix("--clip=").split(":")
			var frames: Array[int] = []
			for s: String in parts[1].split(","):
				frames.append(int(s))
			rows.append([parts[0], frames])
	_stage()
	var body: Node3D = (load("res://world/characters/%s/%s.tscn" % [look, look]) as PackedScene).instantiate() as Node3D
	_vp.add_child(body)
	var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
	var cols: int = 1
	for r: Array in rows:
		cols = maxi(cols, (r[1] as Array).size())
	var sheet: Image = Image.create(TILE.x * cols, TILE.y * maxi(1, rows.size()), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.22))
	for y: int in rows.size():
		var clip: String = "humanoid/" + String(rows[y][0])
		var frames: Array = rows[y][1]
		for x: int in frames.size():
			player.play(clip)
			player.seek(int(frames[x]) / 30.0, true)
			player.pause()
			_cam.global_transform = Transform3D.IDENTITY.looking_at(Vector3(1.6, -0.3, 2.6), Vector3.UP) \
				.translated(Vector3(-1.6, 1.3, -2.6))
			for _i: int in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * x, TILE.y * y))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	sheet.save_png(out)
	print("render_clip_strip: wrote %s" % out)
	quit(0)


func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, 200.0, 0.0)
	key.shadow_enabled = true
	_vp.add_child(key)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	_vp.add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_vp.add_child(_cam)
	_cam.current = true
