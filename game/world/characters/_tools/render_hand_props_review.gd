## D-115: windowed review of the hand props (world/characters/_props/hand_<prop>.tscn) attached at the
## HandR / HandL Socket of a civilian playing the ambient clips that hold them. Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_hand_props_review.gd
##
## Columns = (clip, time); rows: full body three-quarter front, then a close-up on the prop. Writes
## res://assets/characters/_review/d115_hand_props.png.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/"
const OUT_FILE: String = "d115_hand_props.png"
const INDEX: String = "res://world/characters/_props/hand_props.json"
## [character asset, clip, time (s), close-up eye direction (root space)]
const CELLS: Array = [
	["char_civilian_clerk", "phone_call", 1.0, Vector3(0.9, 0.1, -0.7)],
	["char_civilian_clerk", "smoke", 0.8, Vector3(0.9, 0.0, -0.9)],
	["char_civilian_clerk", "smoke", 1.9, Vector3(0.5, 0.3, -1.0)],
	["char_npc_bank_cleaner", "mop", 0.5, Vector3(0.5, 0.5, -1.0)],
	["char_civilian_clerk", "mug_carry_walk", 0.3, Vector3(0.6, 0.3, -1.0)],
	["char_civilian_clerk", "mug_idle", 3.5, Vector3(0.9, 0.1, -0.8)],
	["char_civilian_clerk", "walk_text", 0.4, Vector3(0.3, 0.8, -1.0)],
	["char_npc_bank_teller", "teller_count", 2.0, Vector3(-0.6, 0.5, -1.0)],
	["char_club_bartender", "bartender_pour", 1.8, Vector3(0.6, 0.3, -1.0)],
	["char_club_bartender", "bartender_wipe", 1.0, Vector3(0.6, 0.8, -1.0)],
	["char_npc_kessler", "sit_bed_read", 2.0, Vector3(0.4, 0.4, -1.0)],
	["char_civilian_clerk", "phone_seated", 2.0, Vector3(0.9, 0.1, -0.7)],
]
const TILE: Vector2i = Vector2i(230, 400)
const CLOSE: Vector2i = Vector2i(230, 230)

var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _errors: int = 0
var _props: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_hand_props_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	_props = JSON.parse_string(FileAccess.get_file_as_string(INDEX)) as Dictionary
	if _props == null or _props.is_empty():
		push_error("render_hand_props_review: no %s" % INDEX)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	var sheet: Image = Image.create(TILE.x * CELLS.size(), TILE.y + CLOSE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.2))
	for c: int in range(CELLS.size()):
		await _cell(sheet, c)
	var err: Error = sheet.save_png(OUT_DIR + OUT_FILE)
	if err != OK:
		_errors += 1
		push_error("render_hand_props_review: could not save %s (%s)" % [OUT_FILE, error_string(err)])
	else:
		print("render_hand_props_review: wrote %s%s" % [OUT_DIR, OUT_FILE])
	quit(1 if _errors > 0 else 0)


func _cell(sheet: Image, c: int) -> void:
	var cell: Array = CELLS[c]
	var clip: String = cell[1]
	var body: Node3D = (load(Spec.scene_path(cell[0])) as PackedScene).instantiate() as Node3D
	CrowdLod.force_level(body, false)
	_vp.add_child(body)
	var held: Array[Node3D] = _attach(body, clip)
	var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
	if player.has_animation("humanoid/" + clip):
		player.play("humanoid/" + clip)
		player.seek(float(cell[2]), true)
		player.pause()
	else:
		_errors += 1
		push_error("render_hand_props_review: no humanoid/%s" % clip)
	await process_frame
	_label.text = "%s @%.1fs" % [clip, float(cell[2])]
	_label.visible = true
	_vp.size = TILE
	var front: Image = await _grab(_view(Vector3(1.4, 1.2, -3.0), Vector3(0.0, 0.9, 0.0)))
	sheet.blit_rect(front, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * c, 0))
	_label.visible = false
	var box: AABB = _bounds(held)
	var target: Vector3 = box.get_center()
	var dist: float = clampf(box.size.length() * 1.3, 0.38, 1.6)
	var dir: Vector3 = (cell[3] as Vector3).normalized()
	_vp.size = CLOSE
	var close: Image = await _grab(_view(target + dir * dist, target))
	sheet.blit_rect(close, Rect2i(Vector2i.ZERO, CLOSE), Vector2i(TILE.x * c, TILE.y))
	body.queue_free()
	await process_frame


## Instantiates every hand prop whose clips include ``clip`` under its socket; returns the props.
func _attach(body: Node3D, clip: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for prop: String in _props:
		var row: Dictionary = _props[prop]
		if not (row["clips"] as Array).has(clip):
			continue
		var socket: Node3D = body.find_child(String(row["socket"]), true, false) as Node3D
		socket = socket.get_node_or_null("Socket") as Node3D if socket != null else null
		if socket == null:
			_errors += 1
			push_error("render_hand_props_review: %s has no %s/Socket" % [body.name, row["socket"]])
			continue
		var inst: Node3D = (load(String(row["scene"])) as PackedScene).instantiate() as Node3D
		socket.add_child(inst)
		out.append(inst)
	if out.is_empty():
		_errors += 1
		push_error("render_hand_props_review: no hand prop for %s" % clip)
	return out


func _bounds(held: Array[Node3D]) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for n: Node3D in held:
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
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
