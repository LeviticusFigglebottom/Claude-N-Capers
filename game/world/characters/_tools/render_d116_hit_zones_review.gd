## D-116: windowed review of the hit-zone flinches (hit_head, hit_chest, hit_shoulder_l/_r, hit_leg_l/_r) on a cop
## (tac_light). Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_d116_hit_zones_review.gd
##
## One row per clip: frame 0 (= idle_alert frame 0) from the side, then the `impact` frame from the front and from the
## side (the cop faces -Z; the red cross marks the root). Writes res://assets/characters/_review/d116_hit_zones.png.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/"
const OUT_FILE: String = "d116_hit_zones.png"
const CHAR: String = "char_tac_light"
## clip -> impact frame (SOURCE clip.<name> events)
const CLIPS: Dictionary = {
	"hit_head": 2, "hit_chest": 3, "hit_shoulder_l": 3, "hit_shoulder_r": 3, "hit_leg_l": 3, "hit_leg_r": 3,
}
## The leg flinches: the catch step (hit foot planted back) after impact.
const STEP_FRAME: int = 8
const TILE: Vector2i = Vector2i(330, 400)
const TARGET: Vector3 = Vector3(0.0, 0.95, 0.0)

var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_d116_hit_zones_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	var front: Transform3D = _view(Vector3(0.55, 1.25, -3.3), TARGET)
	var side: Transform3D = _view(Vector3(3.3, 1.2, -0.15), TARGET)
	var cols: int = 4
	var sheet: Image = Image.create(TILE.x * cols, TILE.y * CLIPS.size(), false, Image.FORMAT_RGBA8)
	var body: Node3D = (load(Spec.scene_path(CHAR)) as PackedScene).instantiate() as Node3D
	CrowdLod.force_level(body, false)
	_vp.add_child(body)
	var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
	var row: int = 0
	for clip: String in CLIPS:
		var anim: String = "humanoid/" + clip
		if not player.has_animation(anim):
			_errors += 1
			push_error("render_d116_hit_zones_review: %s has no %s" % [CHAR, anim])
			row += 1
			continue
		var at: int = int(CLIPS[clip])
		var shots: Array = [[0, side, "f0 side"], [at, front, "impact f%d front" % at], [at, side, "impact f%d side" % at]]
		shots.append([STEP_FRAME, side, "step f%d side" % STEP_FRAME] if clip.begins_with("hit_leg")
			else [at, _view(Vector3(-2.2, 1.6, -2.4), TARGET), "impact f%d 3/4 L" % at])
		for i: int in range(shots.size()):
			var shot: Array = shots[i]
			player.play(anim)
			player.seek(float(shot[0]) / 30.0, true)
			player.pause()
			_label.text = "%s\n%s" % [clip, shot[2]]
			var img: Image = await _grab(shot[1])
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i, TILE.y * row))
		row += 1
	body.queue_free()
	var err: Error = sheet.save_png(OUT_DIR + OUT_FILE)
	if err != OK:
		_errors += 1
		push_error("render_d116_hit_zones_review: could not save %s (%s)" % [OUT_FILE, error_string(err)])
	else:
		print("render_d116_hit_zones_review: wrote %s%s" % [OUT_DIR, OUT_FILE])
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
	_label.pixel_size = 0.0009
	_label.font_size = 36
	_label.outline_size = 8
	_label.modulate = Color(1.0, 1.0, 1.0)
	_vp.add_child(_label)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_vp.add_child(_cam)
	_cam.current = true


func _view(eye: Vector3, target: Vector3) -> Transform3D:
	return Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _grab(view: Transform3D) -> Image:
	_cam.global_transform = view
	# the label floats in the top-left of the frame, in front of the camera
	_label.global_position = view * Vector3(-0.2, 0.44, -1.5)
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
