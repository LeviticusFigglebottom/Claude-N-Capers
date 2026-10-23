## D-163 / D-164: windowed in-hand review of the hand-held throwables (assets/equipment/eqp_<id>), each attached at
## a crew body's HandR Socket with the hand-held convention (origin = the grip, the item rising along +Y), the body
## holding it up at chest height (the texting walk). Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_throwable_hand_review.gd
##
## Columns = items; rows: full body three-quarter front, then a close-up on the item. Writes
## res://assets/equipment/_review/eqp_throwables_in_hand.png.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/equipment/_review/"
const OUT_FILE: String = "eqp_throwables_in_hand.png"
const BODY: String = "char_crew_dutch"
const CLIP: String = "walk_text"
const TIME: float = 0.4
const ITEMS: Array[String] = ["eqp_pocket_ecm", "eqp_smoke_bomb", "eqp_gas_dispenser", "eqp_leech_ampule"]
const TILE: Vector2i = Vector2i(300, 420)
const CLOSE: Vector2i = Vector2i(300, 300)

var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_throwable_hand_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	var sheet: Image = Image.create(TILE.x * ITEMS.size(), TILE.y + CLOSE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.2))
	for c: int in range(ITEMS.size()):
		await _cell(sheet, c)
	var err: Error = sheet.save_png(OUT_DIR + OUT_FILE)
	if err != OK:
		_errors += 1
		push_error("render_throwable_hand_review: could not save %s (%s)" % [OUT_FILE, error_string(err)])
	else:
		print("render_throwable_hand_review: wrote %s%s" % [OUT_DIR, OUT_FILE])
	quit(1 if _errors > 0 else 0)


func _cell(sheet: Image, c: int) -> void:
	var id: String = ITEMS[c]
	var body: Node3D = (load(Spec.scene_path(BODY)) as PackedScene).instantiate() as Node3D
	CrowdLod.force_level(body, false)
	_vp.add_child(body)
	var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
	if player.has_animation("humanoid/" + CLIP):
		player.play("humanoid/" + CLIP)
		player.seek(TIME, true)
		player.pause()
	else:
		_errors += 1
		push_error("render_throwable_hand_review: no humanoid/%s" % CLIP)
	var hand: Node3D = body.find_child("HandR", true, false) as Node3D
	var socket: Node3D = hand.get_node_or_null("Socket") as Node3D if hand != null else null
	if socket == null:
		_errors += 1
		push_error("render_throwable_hand_review: %s has no HandR/Socket" % BODY)
		body.queue_free()
		return
	var item: Node3D = (load("res://assets/equipment/%s/%s.glb" % [id, id]) as PackedScene).instantiate() as Node3D
	socket.add_child(item)
	await process_frame
	_label.text = id.trim_prefix("eqp_")
	_label.visible = true
	_vp.size = TILE
	var front: Image = await _grab(_view(Vector3(1.4, 1.2, -3.0), Vector3(0.0, 0.9, 0.0)))
	sheet.blit_rect(front, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * c, 0))
	_label.visible = false
	var target: Vector3 = _bounds(item).get_center()
	_vp.size = CLOSE
	var close: Image = await _grab(_view(target + Vector3(0.5, 0.2, -0.8).normalized() * 0.42, target))
	sheet.blit_rect(close, Rect2i(Vector2i.ZERO, CLOSE), Vector2i(TILE.x * c, TILE.y))
	body.queue_free()
	await process_frame


func _bounds(item: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mi: Node in item.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


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
	key.rotation_degrees = Vector3(-40.0, 160.0, 0.0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -30.0, 0.0)
	fill.light_energy = 0.5
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
	_label.position = Vector3(0.0, 2.02, 0.0)
	_label.pixel_size = 0.0022
	_label.font_size = 36
	_label.outline_size = 8
	_label.modulate = Color(1.0, 1.0, 1.0)
	_vp.add_child(_label)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.02
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
