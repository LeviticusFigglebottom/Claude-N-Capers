## AH-D1 dj_mix windowed review: club_dj playing dj_mix behind a stand-in booth built from the SOURCE `ah_dj_placement`
## numbers (deck top 1.00 m, front edge 0.30 m ahead, a mixer block and the right jog wheel where the hands work), seen
## from the crowd (front three-quarter) and from the side at frames across the loop, the cue hold included. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 \
##     --path game --script res://world/characters/_tools/render_ah_dj_review.gd
## Writes res://assets/characters/_review/ah_d1/dj_mix_review.png (rows: front 3/4, side; columns: FRAMES).
extends SceneTree

const SCENE: String = "res://world/characters/club_dj/club_dj.tscn"
const OUT: String = "res://assets/characters/_review/ah_d1/dj_mix_review.png"
const FRAMES: Array[int] = [0, 45, 80, 105, 140, 200]
const TILE: Vector2i = Vector2i(320, 400)
## _anim_ah: DECK_Z, DECK_EDGE, FADER, JOG (Blender x, y -> Godot x, -z)
const DECK_Z: float = 1.00
const DECK_EDGE: float = 0.30
const FADER: Vector2 = Vector2(-0.10, 0.44)
const JOG: Vector2 = Vector2(0.24, 0.47)

var _vp: SubViewport
var _cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_stage()
	var body: Node3D = (load(SCENE) as PackedScene).instantiate() as Node3D
	_vp.add_child(body)
	var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
	var sheet: Image = Image.create(TILE.x * FRAMES.size(), TILE.y * 2, false, Image.FORMAT_RGBA8)
	for i: int in FRAMES.size():
		player.play("humanoid/dj_mix")
		player.seek(FRAMES[i] / 30.0, true)
		player.pause()
		var a: Image = await _grab(Vector3(-1.5, 1.6, -2.2), Vector3(0.0, 1.05, -0.2))
		var b: Image = await _grab(Vector3(1.9, 1.2, -0.25), Vector3(0.0, 1.05, -0.25))
		sheet.blit_rect(a, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i, 0))
		sheet.blit_rect(b, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i, TILE.y))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	sheet.save_png(OUT)
	print("render_ah_dj_review: wrote %s" % OUT)
	quit(0)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	_vp.add_child(m)


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
	env.environment.background_color = Color(0.2, 0.18, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.environment.ambient_light_energy = 0.5
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, 200.0, 0.0)
	key.shadow_enabled = true
	_vp.add_child(key)
	# the booth: a desk 1.4 m wide, 0.6 m deep, front edge DECK_EDGE ahead (Godot -z), top at DECK_Z
	_box(Vector3(1.4, DECK_Z, 0.6), Vector3(0.0, DECK_Z * 0.5, -DECK_EDGE - 0.3), Color(0.25, 0.25, 0.28))
	_box(Vector3(0.18, 0.03, 0.26), Vector3(FADER.x, DECK_Z + 0.015, -FADER.y), Color(0.1, 0.1, 0.1))
	var jog: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.10
	cyl.bottom_radius = 0.10
	cyl.height = 0.02
	jog.mesh = cyl
	jog.position = Vector3(JOG.x, DECK_Z + 0.01, -JOG.y)
	_vp.add_child(jog)
	_box(Vector3(6.0, 0.01, 6.0), Vector3(0.0, -0.005, 0.0), Color(0.35, 0.33, 0.35))
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_vp.add_child(_cam)
	_cam.current = true


func _grab(eye: Vector3, target: Vector3) -> Image:
	_cam.global_transform = Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)
	for _i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
