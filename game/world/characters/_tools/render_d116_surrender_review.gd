## D-116: windowed review of the surrender variants (hands_up*, surrender*, surrender_idle*, kneel_cuffed*). Owner:
## ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_d116_surrender_review.gd
##
## One row per (group, time): three patrol officers side by side, one per variant (original, _b, _c), all at the same
## clip time, seen from the front-left and from behind-right (the cuffed hands). Writes
## res://assets/characters/_review/d116_surrender_variants.png.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/"
const OUT_FILE: String = "d116_surrender_variants.png"
const CHAR: String = "char_patrol_officer"
## [group members, time (s), label]
const ROWS: Array = [
	[["hands_up", "hands_up_b", "hands_up_c"], 0.9, "hands_up* @0.9s"],
	[["surrender", "surrender_b", "surrender_c"], 0.45, "surrender* @0.45s"],
	[["surrender", "surrender_b", "surrender_c"], 1.1, "surrender* @1.1s"],
	[["surrender", "surrender_b", "surrender_c"], 2.0, "surrender* end (same pose)"],
	[["surrender_idle", "surrender_idle_b", "surrender_idle_c"], 1.5, "surrender_idle* @1.5s"],
	[["kneel_cuffed", "kneel_cuffed_b", "kneel_cuffed_c"], 1.6, "kneel_cuffed* @1.6s"],
]
const SPACING: float = 1.1
const TILE: Vector2i = Vector2i(720, 400)
const VIEWS: Array = [[Vector3(-1.8, 1.7, 4.4), Vector3(-0.1, 0.8, 0.0)], [Vector3(2.6, 1.8, -3.9), Vector3(0.1, 0.8, 0.0)]]

var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_d116_surrender_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	var bodies: Array[Node3D] = []
	for i: int in range(3):
		var body: Node3D = (load(Spec.scene_path(CHAR)) as PackedScene).instantiate() as Node3D
		CrowdLod.force_level(body, false)
		body.position = Vector3((float(i) - 1.0) * SPACING, 0.0, 0.0)
		body.rotation.y = PI  # face the cameras (+Z)
		_vp.add_child(body)
		bodies.append(body)
	var sheet: Image = Image.create(TILE.x * VIEWS.size(), TILE.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	for r: int in range(ROWS.size()):
		var row: Array = ROWS[r]
		var members: Array = row[0]
		for i: int in range(3):
			var player: AnimationPlayer = bodies[i].get_node("AnimationPlayer") as AnimationPlayer
			var anim: String = "humanoid/" + String(members[i])
			if not player.has_animation(anim):
				_errors += 1
				push_error("render_d116_surrender_review: %s has no %s" % [CHAR, anim])
				continue
			player.play(anim)
			player.seek(minf(float(row[1]), player.get_animation(anim).length), true)
			player.pause()
		_label.text = "%s\nfront L->R: %s | %s | %s (back view mirrored)" % [row[2], members[0], members[1], members[2]]
		for v: int in range(VIEWS.size()):
			var img: Image = await _grab(_view(VIEWS[v][0], VIEWS[v][1]))
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * v, TILE.y * r))
	var err: Error = sheet.save_png(OUT_DIR + OUT_FILE)
	if err != OK:
		_errors += 1
		push_error("render_d116_surrender_review: could not save %s (%s)" % [OUT_FILE, error_string(err)])
	else:
		print("render_d116_surrender_review: wrote %s%s" % [OUT_DIR, OUT_FILE])
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
	key.rotation_degrees = Vector3(-50.0, -150.0, 0.0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 40.0, 0.0)
	fill.light_energy = 0.4
	_vp.add_child(fill)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.48, 0.5)
	vis.material_override = mat
	_vp.add_child(vis)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0.0, 2.15, 0.0)
	_label.pixel_size = 0.0028
	_label.font_size = 40
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
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
