## D-165: windowed Afterhours dance-floor review. Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_ah_dance_review.gd
##
## Writes into res://assets/characters/_review/ah_cast/:
##   ah_dance_lod_<group>.png  every AH look of the group (staff / patrons / dancers) in a lineup, rows = dance_a/b/c at
##                             two phases, each as LOD0 (glb meshes) then LOD2 (CrowdLod, forced), to catch limbs that
##                             pop or tear on the proxy mid-dance.
##   ah_dance_floor_stress.png bench_crowd's ah50 floor (same seeded spots, 5-18 m, natural LOD) under the club's neon
##                             light from the player's eye and from the DJ booth, with the visible triangles / draw calls
##                             of each view printed ("[FLOOR]") and stamped on the tile.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const Bench: GDScript = preload("res://world/characters/_tools/bench_crowd.gd")
const OUT_DIR: String = "res://assets/characters/_review/ah_cast/"
const GROUPS: Dictionary = {
	"staff": ["club_bouncer", "club_bouncer_b", "club_bouncer_c", "club_bouncer_d", "club_bouncer_e", "club_bouncer_f",
		"club_bartender", "club_bartender_b", "club_bartender_c", "club_bartender_d", "club_dj"],
	"patrons": ["club_patron", "club_patron_b", "club_patron_c", "club_patron_d", "club_patron_e", "club_patron_f",
		"club_patron_g", "club_patron_h", "club_patron_i", "club_patron_j", "club_patron_k", "club_patron_l"],
	"dancers": ["club_dancer", "club_dancer_b", "club_dancer_c", "club_dancer_d", "club_dancer_e", "club_dancer_f",
		"club_dancer_g", "club_dancer_h", "club_dancer_i", "club_dancer_j", "club_dancer_k", "club_dancer_l"],
}
const CLIPS: Array[String] = ["dance_a", "dance_b", "dance_c"]
## phases (fraction of the loop) sampled per clip: an off-beat reach and a later step
const PHASES: Array[float] = [0.3, 0.7]
const STRIP: Vector2i = Vector2i(1600, 250)
const SPACING_M: float = 0.85
const FLOOR_TILE: Vector2i = Vector2i(960, 540)

var _vp: SubViewport
var _cam: Camera3D
var _env: WorldEnvironment
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_ah_dance_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	for group: String in GROUPS:
		await _lineup(group, GROUPS[group])
	await _floor()
	quit(1 if _errors > 0 else 0)


func _lineup(group: String, ids: Array) -> void:
	var bodies: Array[Node3D] = []
	var x0: float = -0.5 * SPACING_M * float(ids.size() - 1)
	for i: int in ids.size():
		var body: Node3D = (load(Spec.scene_path("char_" + String(ids[i]))) as PackedScene).instantiate() as Node3D
		_vp.add_child(body)
		body.position = Vector3(x0 + SPACING_M * float(i), 0.0, 0.0)
		body.rotation.y = deg_to_rad(-20.0)
		bodies.append(body)
	_vp.size = STRIP
	_cam.fov = 22.0
	var dist: float = 1.1 / tan(deg_to_rad(_cam.fov * 0.5))
	var view: Transform3D = _view(Vector3(0.0, 1.0, -dist), Vector3(0.0, 0.95, 0.0))
	var rows: int = CLIPS.size() * PHASES.size() * 2
	var sheet: Image = Image.create(STRIP.x, STRIP.y * rows, false, Image.FORMAT_RGBA8)
	var row: int = 0
	for clip: String in CLIPS:
		for phase: float in PHASES:
			for lod2: bool in [false, true]:
				for body: Node3D in bodies:
					if not CrowdLod.force_level(body, lod2):
						_errors += 1
						push_error("render_ah_dance_review: %s has no LOD2" % body.name)
					var ap: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
					var anim: String = "humanoid/" + clip
					if not ap.has_animation(anim):
						_errors += 1
						push_error("render_ah_dance_review: no %s" % anim)
						continue
					ap.play(anim)
					ap.seek(phase * ap.current_animation_length, true)
					ap.pause()
				var img: Image = await _grab(view)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, STRIP), Vector2i(0, STRIP.y * row))
				print("render_ah_dance_review: %s row %d = %s @%.1f %s" % [group, row, clip, phase, "LOD2" if lod2 else "LOD0"])
				row += 1
	_save(sheet, "ah_dance_lod_%s.png" % group)
	for body: Node3D in bodies:
		body.queue_free()
	await process_frame


func _floor() -> void:
	var p: Dictionary = Bench.PRESETS["ah50"]
	var ids: Array = p["ids"]
	var n: int = int(p["n"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()   # review placement only, as bench_crowd's seed 1
	rng.seed = 1
	var origin: Vector3 = Vector3(0.0, 0.0, 0.0)
	var bodies: Array[Node3D] = []
	for i: int in n:
		var body: Node3D = (load(Spec.scene_path("char_" + String(ids[i % ids.size()]))) as PackedScene).instantiate() as Node3D
		_vp.add_child(body)
		var d: float = lerpf(float(p["near"]), float(p["far"]), rng.randf())
		var a: float = deg_to_rad(rng.randf_range(-30.0, 30.0))
		body.position = origin + Vector3(sin(a) * d, 0.0, -cos(a) * d)
		body.rotation.y = rng.randf_range(0.0, TAU)
		var ap: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
		ap.play(StringName("humanoid/" + CLIPS[i % 3]))
		ap.seek(rng.randf_range(0.0, ap.current_animation_length), true)
		ap.pause()
		bodies.append(body)
	_vp.size = FLOOR_TILE
	_cam.fov = 75.0
	var views: Array = [
		["player eye 1.65 m", _view(Vector3(0.0, 1.65, 0.0), Vector3(0.0, 1.2, -12.0))],
		["DJ booth 2.6 m", _view(Vector3(0.0, 2.6, -21.0), Vector3(0.0, 0.6, -9.0))],
	]
	var sheet: Image = Image.create(FLOOR_TILE.x, FLOOR_TILE.y * views.size(), false, Image.FORMAT_RGBA8)
	for v: int in views.size():
		var img: Image = await _grab(views[v][1])
		var tris: int = _vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		var draws: int = _vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var shadow_tris: int = _vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		var shadow_draws: int = _vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var lod2: int = 0
		for body: Node3D in bodies:
			if _cam.global_position.distance_to(body.global_position) >= CrowdLod.CROWD_SWITCH_M:
				lod2 += 1
		print("[FLOOR] view=\"%s\" n=%d at_lod2=%d visible_tris=%d visible_draws=%d shadow_tris=%d shadow_draws=%d"
			% [views[v][0], n, lod2, tris, draws, shadow_tris, shadow_draws])
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, FLOOR_TILE), Vector2i(0, FLOOR_TILE.y * v))
	_save(sheet, "ah_dance_floor_stress.png")
	for body: Node3D in bodies:
		body.queue_free()
	await process_frame


func _save(sheet: Image, file: String) -> void:
	var err: Error = sheet.save_png(OUT_DIR + file)
	if err != OK:
		_errors += 1
		push_error("render_ah_dance_review: could not save %s (%s)" % [file, error_string(err)])
	else:
		print("render_ah_dance_review: wrote %s%s" % [OUT_DIR, file])


## The Velvet's floor light (render_d130_cast_review --light=neon): dark room, magenta key, violet fill.
func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = STRIP
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_env = WorldEnvironment.new()
	_env.environment = Environment.new()
	_env.environment.background_mode = Environment.BG_COLOR
	_env.environment.background_color = Color(0.05, 0.04, 0.07)
	_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.environment.ambient_light_color = Color(0.35, 0.25, 0.55)
	_env.environment.ambient_light_energy = 0.35
	_vp.add_child(_env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, 160.0, 0.0)
	key.light_color = Color(1.0, 0.35, 0.75)
	key.light_energy = 1.3
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -30.0, 0.0)
	fill.light_color = Color(0.45, 0.38, 1.0)
	fill.light_energy = 0.8
	_vp.add_child(fill)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.33)
	vis.material_override = mat
	_vp.add_child(vis)
	_cam = Camera3D.new()
	_cam.far = 200.0
	_vp.add_child(_cam)
	_cam.current = true


func _view(eye: Vector3, target: Vector3) -> Transform3D:
	return Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _grab(view: Transform3D) -> Image:
	_cam.global_transform = view
	for i: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
