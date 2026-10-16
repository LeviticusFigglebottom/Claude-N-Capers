## V1.23 windowed review (not a test): a crew body (rook rig) masking up (mask_on) and throwing a grenade
## (throw_grenade), driven by AnimDriver exactly as in game: the mask-up from CrewController.set_masked, the throw from
## CrewThrowables (pin cue -> clip, release -> ThrownItem). Needs ENV D's D-116 clips.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 \
##     --path game --resolution 800x900 res://tests/a/_review/v123_mask_throw_capture.tscn -- --out=<dir>
## Writes <out>/mask_on_before_event.png (frame before mask_on@, weapon holstered, no mask), mask_on_event.png (the
## event frame: mask on the face), mask_on_after.png (clip over: the masked hold, weapon drawn), throw_pin.png (the
## pin pull) and throw_release.png (the release frame, the grenade just spawned). Owner: ENV A.
extends Node3D

const TILE: Vector2i = Vector2i(400, 450)
const DT: float = 1.0 / 30.0

var _out: String = "user://v123"
var _cam: Camera3D = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_stage()
	_run.call_deferred()


func _run() -> void:
	await _mask_scene()
	await _throw_scene()
	print("v123_capture: done -> %s" % _out)
	get_tree().quit(0)


func _stage() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.64)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	key.shadow_enabled = true
	add_child(key)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.46, 0.48)
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_cam.current = true


func _crew(loadout: Loadout, x: float) -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Crew"}, loadout)
	crew.heister = &"rook"
	crew.net_id = 88400 + int(x)
	crew.position = Vector3(x, 0.0, 0.0)
	add_child(crew)
	for _i: int in 4:
		await get_tree().process_frame
	crew.set_physics_process(false)
	crew.position = Vector3(x, 0.0, 0.0)  # no floor collider here: undo the settle-in fall
	if crew.loadout.mask == &"" and crew.loadout.mask_descriptor.is_empty():
		crew.loadout.mask = &"mask.gilded_heron"
	var d: AnimDriver = AnimDriver.of(crew)
	d.set_process(false)
	d.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return crew


func _step(d: AnimDriver, dt: float) -> void:
	d.tick(dt)
	d.player.advance(dt)


## Front 3/4 from the body's left-front (the body faces -Z), at chest height.
func _look_at_body(crew: CrewController, side: float) -> void:
	var target: Vector3 = crew.global_position + Vector3(0.0, 1.35, 0.0)
	var eye: Vector3 = crew.global_position + Vector3(side * 1.3, 1.6, -2.4)
	_cam.global_transform = Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _shot(file: String, note: String) -> void:
	for _i: int in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	var path: String = _out.path_join(file)
	print("v123_capture: %s %s (%s)" % [path, error_string(img.save_png(path)), note])


func _mask_scene() -> void:
	var crew: CrewController = await _crew(null, 0.0)
	var d: AnimDriver = AnimDriver.of(crew)
	_look_at_body(crew, -1.0)
	for _i: int in 3:
		_step(d, DT)
	crew.set_masked()
	var event_f: int = roundi(AnimTweak.data().mask_on_s() * AnimTweak.SOURCE_FPS)
	var mask: Node3D = AnimDriver.socket_of(crew, "Head").get_node_or_null(NodePath(CrewView.MASK_NAME)) as Node3D
	for f: int in range(1, 31 + 8):
		d.tick(DT)
		var pos: float = d.player.current_animation_position
		var info: String = "clip %s t=%.3f frame %d mask %s weapon %s" % [d.clip, pos, roundi(pos * 30.0),
			mask.visible if mask != null else "none", d.weapon_visual.visible if d.weapon_visual != null else "none"]
		if f == event_f - 1:
			await _shot("mask_on_before_event.png", info)
		elif f == event_f + 1:
			await _shot("mask_on_event.png", info)
		elif f == 31 + 7:
			await _shot("mask_on_after.png", info)
		d.player.advance(DT)
	crew.queue_free()


func _throw_scene() -> void:
	var def: ThrowableDef = ThrowableDef.new()
	def.id = &"throwable.v123_capture_frag"
	def.kind = ThrownItem.KIND_FRAG
	def.count = 3
	def.radius_m = 1.0
	def.fuse_s = 30.0
	ContentDB.inject(ContentDB.THROWABLES, def.id, def)
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.throwable = def.id
	var crew: CrewController = await _crew(l, 3.0)
	crew.masked = true
	CrewThrowables.set_count(crew, 2)
	var d: AnimDriver = AnimDriver.of(crew)
	_look_at_body(crew, 1.0)
	for _i: int in 3:
		_step(d, DT)
	var hold: CrewIntent = CrewIntent.new()
	hold.throw_item = true
	var released: Array[bool] = [false]
	crew.throwables.released.connect(func() -> void: released[0] = true)
	for f: int in 40:
		crew.throwables.tick(hold, DT)
		d.tick(DT)
		var pos: float = d.player.current_animation_position
		var info: String = "clip %s t=%.3f frame %d" % [d.clip, pos, roundi(pos * 30.0)]
		if f == 0:
			await _shot("throw_pin.png", info)
		elif released[0]:
			await _shot("throw_release.png", info + " grenades %d" % get_tree().get_nodes_in_group(ThrownItem.GROUP).size())
			break
		d.player.advance(DT)
	crew.queue_free()
