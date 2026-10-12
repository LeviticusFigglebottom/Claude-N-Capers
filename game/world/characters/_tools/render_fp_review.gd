## PP-D-1 review: characters as a first-person player sees them. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --script res://world/characters/_tools/render_fp_review.gd
## Eye 1.65 m, perspective Camera3D (vertical FOV FP_FOV), 1280x720, LOD chosen by the real visibility ranges
## (nothing forced). Writes res://assets/characters/_review/fp_<d>m.png for d in DISTANCES, plus
## fp_pop_crowd.png / fp_pop_unit.png: the centre crop just inside and just outside the switch distance,
## enlarged 4x nearest (left = inside / LOD0-1, right = outside / CrowdLod).
extends SceneTree

const OUT_DIR: String = "res://assets/characters/_review/"
const IDS: Array[String] = ["security_officer", "club_patron", "cartel_gunman", "gallery_patron", "corpsman", "tac_heavy"]
const DISTANCES: Array[int] = [10, 20, 30, 40]
const FP_FOV: float = 75.0
const EYE_H: float = 1.65
const SIZE: Vector2i = Vector2i(1280, 720)
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const ANIM_IDS: Array[String] = ["club_patron", "security_officer", "cartel_gunman"]
const CLIPS: Array[StringName] = [&"humanoid/walk", &"humanoid/run", &"humanoid/aim_rifle"]
const SCOPE_ZOOM: float = 4.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for d: int in DISTANCES:
		var img: Image = await _render(float(d), IDS)
		img.save_png(OUT_DIR + "fp_%dm.png" % d)
	await _pop("fp_pop_crowd.png", ["club_patron", "gallery_patron"], 20.0)
	await _pop("fp_pop_unit.png", ["security_officer", "cartel_gunman"], 35.0)
	# anim_lod_<clip>.png: top row LOD0, bottom row CrowdLod (forced), mid-clip pose, close ortho-ish crop
	for clip: StringName in CLIPS:
		var a: Image = await _render(6.0, ANIM_IDS, FP_FOV, 1.0, clip, 0)
		var b: Image = await _render(6.0, ANIM_IDS, FP_FOV, 1.0, clip, 1)
		_stack(a, b).save_png(OUT_DIR + "anim_lod_%s.png" % String(clip).get_file())
	# scope_40m.png: 40 m at FOV/4; top = zoom ignored (CrowdLod shows), bottom = D-084 apply_zoom (LOD0)
	var s0: Image = await _render(40.0, IDS, FP_FOV / SCOPE_ZOOM, 1.0)
	var s1: Image = await _render(40.0, IDS, FP_FOV / SCOPE_ZOOM, SCOPE_ZOOM)
	_stack(s0, s1).save_png(OUT_DIR + "scope_40m.png")
	print("render_fp_review: wrote fp_*m.png, fp_pop_*.png")
	quit(0)


func _pop(name: String, ids: Array[String], switch_m: float) -> void:
	var a: Image = _crop(await _render(switch_m - 1.5, ids))
	var b: Image = _crop(await _render(switch_m + 1.5, ids))
	var out: Image = Image.create(a.get_width() * 2 + 4, a.get_height(), false, a.get_format())
	out.fill(Color.BLACK)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + 4, 0))
	out.resize(out.get_width() * 4, out.get_height() * 4, Image.INTERPOLATE_NEAREST)
	out.save_png(OUT_DIR + name)


func _stack(a: Image, b: Image) -> Image:
	var out: Image = Image.create(a.get_width(), a.get_height() * 2 + 4, false, a.get_format())
	out.fill(Color.BLACK)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(0, a.get_height() + 4))
	return out


func _crop(img: Image) -> Image:
	var w: int = 160
	var h: int = 120
	return img.get_region(Rect2i(SIZE.x / 2 - w / 2, SIZE.y / 2 - h / 2 + 10, w, h))


func _render(dist: float, ids: Array[String], fov: float = FP_FOV, zoom: float = 1.0, clip: StringName = &"",
		force: int = -1) -> Image:
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.46, 0.48, 0.52)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	root.add_child(vp)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 150.0, 0.0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80.0, 120.0)
	ground.mesh = plane
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.36, 0.37)
	ground.material_override = gm
	vp.add_child(ground)
	var spacing: float = 0.9 + dist * 0.035
	for i: int in range(ids.size()):
		var packed: PackedScene = load("res://world/characters/%s/%s.tscn" % [ids[i], ids[i]]) as PackedScene
		var ch: Node3D = packed.instantiate() as Node3D
		ch.position = Vector3(spacing * (i - (ids.size() - 1) * 0.5), 0.0, 0.0)
		vp.add_child(ch)
		if force >= 0:
			CrowdLod.force_level(ch, force == 1)
		else:
			CrowdLod.apply_zoom(ch, zoom)
		if clip != &"":
			var ap: AnimationPlayer = ch.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			ap.play(clip)
			ap.seek(ap.current_animation_length * 0.4, true)
			ap.pause()
	var cam: Camera3D = Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = 200.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, EYE_H, -dist), Vector3(0.0, 1.1, 0.0), Vector3.UP)
	cam.current = true
	for i: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img
