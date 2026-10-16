## D-115 item 2: windowed outfit-clipping audit of the new civilians in their panic, cower, surrender and death
## clips. Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_d115_civ_clip_audit.gd \
##     [-- clip_key ...]
##
## One sheet per clip pose: a column per civilian, row 1 a front three-quarter view, row 2 a back three-quarter view,
## both framed on the posed skeleton. Writes res://assets/characters/_review/d115_civ_clip_audit/<key>.png. Pass clip
## keys after `--` to render only those.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/d115_civ_clip_audit/"
const CHARS: Array[String] = [
	"char_civilian_manager_vossberg", "char_civilian_sales_b", "char_civilian_clerk", "char_dock_worker",
	"char_dock_worker_b", "char_dock_packer", "char_npc_cleaner_sl_b",
]
## sheet key -> [clip, time (s)]: the time is where the outfit is most stressed (held pose, flinch peak, end of a fall).
const SHOTS: Dictionary = {
	"hands_up": ["hands_up", 1.0], "surrender_end": ["surrender", 1.6], "kneel_cuffed": ["kneel_cuffed", 1.5],
	"cower": ["cower", 1.0], "cower_stand_flinch1": ["cower_stand", 1.3], "cower_stand_flinch2": ["cower_stand", 3.6],
	"cower_seated": ["cower_seated", 1.5], "flee_a": ["flee", 0.17], "flee_b": ["flee", 0.5],
	"death_front_end": ["death_front", 1.8], "death_front_b_end": ["death_front_b", 2.0],
	"death_back_end": ["death_back", 1.8], "death_back_b_end": ["death_back_b", 2.0],
	"death_side_end": ["death_side", 2.0], "death_kneel_mid": ["death_kneel", 0.6], "death_kneel_end": ["death_kneel", 1.5],
	"death_kneel_cuffed_end": ["death_kneel_cuffed", 1.5], "death_crouch_end": ["death_crouch", 1.5],
	"death_seated_slump_end": ["death_seated_slump", 1.6], "death_seated_fall_end": ["death_seated_fall", 2.0],
	# close-ups: [clip, time, focus bone, half-size (m), camera elevation]
	"zoom_surrender_head": ["surrender", 1.6, "head", 0.32, 0.3],
	"zoom_cower_head": ["cower", 1.0, "head", 0.34, 0.6],
	"zoom_cower_seated_head": ["cower_seated", 1.5, "head", 0.32, 0.3],
	"zoom_cower_seated_lap": ["cower_seated", 1.5, "hips", 0.42, 0.5],
	"zoom_kneel_cuffed_back": ["kneel_cuffed", 1.5, "spine", 0.42, 0.2],
	"zoom_kneel_cuffed_feet": ["kneel_cuffed", 1.5, "shin.L", 0.4, 0.3],
	"zoom_cower_stand_hips": ["cower_stand", 1.3, "hips", 0.42, 0.1],
	"zoom_hands_up_chest": ["hands_up", 1.0, "chest", 0.38, 0.15],
	"zoom_cower_seated_lap_top": ["cower_seated", 1.5, "thigh.L", 0.32, 1.6],
}
const TILE: Vector2i = Vector2i(320, 400)
const FOV: float = 34.0

var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_d115_civ_clip_audit: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	var keys: Array = OS.get_cmdline_user_args()
	if keys.is_empty():
		keys = SHOTS.keys()
	var bodies: Array[Node3D] = []
	for id: String in CHARS:
		var body: Node3D = (load(Spec.scene_path(id)) as PackedScene).instantiate() as Node3D
		CrowdLod.force_level(body, false)
		body.visible = false
		_vp.add_child(body)
		bodies.append(body)
	for key: String in keys:
		if not SHOTS.has(key):
			_errors += 1
			push_error("render_d115_civ_clip_audit: unknown key %s" % key)
			continue
		var clip: String = String(SHOTS[key][0])
		var t: float = float(SHOTS[key][1])
		var sheet: Image = Image.create(TILE.x * CHARS.size(), TILE.y * 2, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.2, 0.2, 0.2))
		for c: int in range(CHARS.size()):
			var body: Node3D = bodies[c]
			body.visible = true
			var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
			var anim: String = "humanoid/" + clip
			if not player.has_animation(anim):
				_errors += 1
				push_error("render_d115_civ_clip_audit: %s has no %s" % [CHARS[c], anim])
				body.visible = false
				continue
			player.play(anim)
			player.seek(t, true)
			player.pause()
			await process_frame
			var skel: Skeleton3D = body.get_node("Skeleton3D") as Skeleton3D
			var spec: Array = SHOTS[key]
			var box: AABB = _bone_box(skel)
			var low: bool = box.size.y < 0.9
			var elev: Array[float] = [0.95 if low else 0.25, 0.95 if low else 0.35]
			if spec.size() >= 5:
				var bone: int = skel.find_bone(String(spec[2]))
				var half: float = float(spec[3])
				box = AABB(skel.global_transform * skel.get_bone_global_pose(maxi(bone, 0)).origin, Vector3.ZERO).grow(half)
				elev = [float(spec[4]), float(spec[4])]
			_label.visible = spec.size() < 5
			_label.text = "%s\n%s @%.2fs" % [CHARS[c].trim_prefix("char_").replace("civilian_", "civ_"), clip, t]
			_label.position = box.get_center() + Vector3(0.0, box.size.y * 0.5 + 0.02, 0.0)
			var front_dir: Vector3 = Vector3(-0.55, elev[0], -1.0).normalized()
			var back_dir: Vector3 = Vector3(0.6, elev[1], 1.0).normalized()
			for v: int in range(2):
				var img: Image = await _grab(_frame(box, front_dir if v == 0 else back_dir))
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * c, TILE.y * v))
			body.visible = false
		var path: String = OUT_DIR + key + ".png"
		var err: Error = sheet.save_png(path)
		if err != OK:
			_errors += 1
			push_error("render_d115_civ_clip_audit: could not save %s (%s)" % [path, error_string(err)])
		else:
			print("render_d115_civ_clip_audit: wrote %s" % path)
	quit(1 if _errors > 0 else 0)


func _bone_box(skel: Skeleton3D) -> AABB:
	var box: AABB = AABB(skel.global_transform * skel.get_bone_global_pose(0).origin, Vector3.ZERO)
	for i: int in range(skel.get_bone_count()):
		box = box.expand(skel.global_transform * skel.get_bone_global_pose(i).origin)
	return box.grow(0.2)


func _frame(box: AABB, dir: Vector3) -> Transform3D:
	var r: float = box.size.length() * 0.5
	var d: float = r / tan(deg_to_rad(FOV * 0.5)) * 1.1
	var target: Vector3 = box.get_center() + Vector3(0.0, 0.06, 0.0)
	var eye: Vector3 = target + dir * d
	return Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


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
	env.environment.ambient_light_energy = 0.7
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, 160.0, 0.0)
	key.light_energy = 1.1
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -30.0, 0.0)
	fill.light_energy = 0.6
	_vp.add_child(fill)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.48, 0.5)
	vis.material_override = mat
	_vp.add_child(vis)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0018
	_label.font_size = 36
	_label.outline_size = 8
	_label.modulate = Color(1.0, 1.0, 1.0)
	_label.no_depth_test = true
	_vp.add_child(_label)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_vp.add_child(_cam)
	_cam.current = true


func _grab(view: Transform3D) -> Image:
	_cam.global_transform = view
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
