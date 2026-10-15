## PO6-18: windowed review of the pose-aware deaths (death_crouch, death_kneel_cuffed, death_kneel, death_prone,
## death_downed). Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_pose_deaths_review.gd
##
## One row per clip: a Security Officer and a civilian, each at the source pose the death starts from (the source
## clip's frame), the death's frame 0 and its last frame, on a floor. Writes
## res://assets/characters/_review/po6_18_pose_deaths_windowed.png.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/"
const OUT_FILE: String = "po6_18_pose_deaths_windowed.png"
const CHARS: Array[String] = ["char_security_officer", "char_civilian_customer_a"]
## clip -> [source clip, source time (s), clip length (s)]
const CLIPS: Dictionary = {
	"death_crouch": ["crouch_idle", 0.0, 1.5], "death_kneel_cuffed": ["kneel_cuffed", 0.0, 1.5],
	"death_kneel": ["surrender", 1.6, 1.5], "death_prone": ["lie_down", 0.0, 1.0], "death_downed": ["downed", 0.0, 1.2],
}
const TILE: Vector2i = Vector2i(400, 300)

var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_pose_deaths_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	var cols: int = CHARS.size() * 3
	var sheet: Image = Image.create(TILE.x * cols, TILE.y * CLIPS.size(), false, Image.FORMAT_RGBA8)
	var view: Transform3D = _view(Vector3(2.3, 1.9, -2.0), Vector3(-0.25, 0.35, -0.2))
	var row: int = 0
	for clip: String in CLIPS:
		var spec: Array = CLIPS[clip]
		for c: int in range(CHARS.size()):
			var body: Node3D = (load(Spec.scene_path(CHARS[c])) as PackedScene).instantiate() as Node3D
			CrowdLod.force_level(body, false)
			_vp.add_child(body)
			var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
			var shots: Array = [[String(spec[0]), float(spec[1]), "%s @%.2fs" % [spec[0], spec[1]]],
				[clip, 0.0, "%s f0" % clip], [clip, float(spec[2]), "%s end" % clip]]
			for i: int in range(shots.size()):
				var shot: Array = shots[i]
				var anim: String = "humanoid/" + String(shot[0])
				if not player.has_animation(anim):
					_errors += 1
					push_error("render_pose_deaths_review: %s has no %s" % [CHARS[c], anim])
					continue
				player.play(anim)
				player.seek(float(shot[1]), true)
				player.pause()
				_label.text = "%s\n%s" % [shot[2], CHARS[c].trim_prefix("char_")]
				var img: Image = await _grab(view)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * (c * 3 + i), TILE.y * row))
			body.queue_free()
			await process_frame
		row += 1
	var err: Error = sheet.save_png(OUT_DIR + OUT_FILE)
	if err != OK:
		_errors += 1
		push_error("render_pose_deaths_review: could not save %s (%s)" % [OUT_FILE, error_string(err)])
	else:
		print("render_pose_deaths_review: wrote %s%s" % [OUT_DIR, OUT_FILE])
	quit(1 if _errors > 0 else 0)


func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, 150.0, 0.0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -40.0, 0.0)
	fill.light_energy = 0.4
	_vp.add_child(fill)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.48, 0.5)
	vis.material_override = mat
	_vp.add_child(vis)
	# root marker: a thin cross on the floor at the character root (the root must not move)
	for axis: Vector3 in [Vector3(0.3, 0.004, 0.02), Vector3(0.02, 0.004, 0.3)]:
		var m: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = axis
		m.mesh = box
		var mm: StandardMaterial3D = StandardMaterial3D.new()
		mm.albedo_color = Color(0.9, 0.2, 0.1)
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mm
		_vp.add_child(m)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(-1.1, 1.2, 0.5)
	_label.pixel_size = 0.003
	_label.font_size = 40
	_label.outline_size = 8
	_label.modulate = Color(1.0, 1.0, 1.0)
	_vp.add_child(_label)
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_vp.add_child(_cam)
	_cam.current = true


func _view(eye: Vector3, target: Vector3) -> Transform3D:
	return Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _grab(view: Transform3D) -> Image:
	_cam.global_transform = view
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
