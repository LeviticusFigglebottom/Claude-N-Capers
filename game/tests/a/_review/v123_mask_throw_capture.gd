## V1.23 windowed review (not a test): a crew body (rook rig) masking up and throwing a grenade, driven by AnimDriver /
## CrewActionAnim as in game: mask_on follows the mask-up hold (mask_progress), the throw comes from CrewThrowables
## (pin cue -> clip + grenade at HandL/Socket, release -> ThrownItem). Needs ENV D's D-116 clips.
##   xvfb-run -a -s "-screen 0 1280x960x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 \
##     --path game --resolution 800x900 res://tests/a/_review/v123_mask_throw_capture.tscn -- --out=<dir>
## Writes <out>/casing_no_weapon.png (unmasked: no weapon), mask_hold_before_event.png (hold just before 18/30: no
## mask), mask_hold_event.png (the event: mask on the face), mask_on_after.png (masked, clip over, weapon drawn),
## mask_hold_walking.png (masking while walking: upper-body layer, legs walking), throw_pin.png (grenade in the left
## hand), throw_release.png (the release frame, the grenade spawned) and throw_running.png (a throw on the run).
## Owner: ENV A.
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
	await _mask_walking_scene()
	await _throw_scene()
	await _throw_running_scene()
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
	plane.size = Vector2(80.0, 80.0)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.46, 0.48)
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.current = true


func _crew(loadout: Loadout, x: float, masked: bool) -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Crew"}, loadout)
	crew.heister = &"rook"
	crew.net_id = 88400 + int(x)
	crew.position = Vector3(x, 0.0, 0.0)
	if crew.loadout.mask == &"" and crew.loadout.mask_descriptor.is_empty():
		crew.loadout.mask = &"mask.gilded_heron"
	add_child(crew)
	if masked:
		crew.set_masked(true)  # spawned masked: armed at once
	for _i: int in 4:
		await get_tree().process_frame
	crew.set_physics_process(false)
	crew.position = Vector3(x, 0.0, 0.0)  # no floor collider here: undo the settle-in fall
	var d: AnimDriver = AnimDriver.of(crew)
	d.set_process(false)
	d.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return crew


func _step(d: AnimDriver, dt: float) -> void:
	d.tick(dt)
	d.player.advance(dt)


## Front 3/4 from the body's left-front (the body faces -Z), whole body.
func _look_at_body(crew: CrewController, side: float) -> void:
	var target: Vector3 = crew.global_position + Vector3(0.0, 1.0, 0.0)
	var eye: Vector3 = crew.global_position + Vector3(side * 1.7, 1.5, -3.4)
	_cam.global_transform = Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _shot(file: String, d: AnimDriver, note: String) -> void:
	for _i: int in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	var path: String = _out.path_join(file)
	var ca: CrewActionAnim = d.crew_action
	print("v123_capture: %s %s (%s; clip %s action %s t=%.3f frame %d layer %.2f weapon %s mask %s grenade %s)" % [
		path, error_string(img.save_png(path)), note, d.clip, ca.action, ca.time, roundi(ca.time * 30.0),
		ca.layer.influence if ca.layer != null else 0.0, d.weapon_visual.visible if d.weapon_visual != null else false,
		ca.mask_preview() != null or _real_mask_on(d), ca.held_item() != null])


func _real_mask_on(d: AnimDriver) -> bool:
	var m: Node3D = AnimDriver.socket_of(d.get_parent(), "Head").get_node_or_null(NodePath(CrewView.MASK_NAME)) as Node3D
	return m != null and m.visible


func _mask_scene() -> void:
	var crew: CrewController = await _crew(null, 0.0, false)
	var d: AnimDriver = AnimDriver.of(crew)
	_look_at_body(crew, -1.0)
	for _i: int in 3:
		_step(d, DT)
	await _shot("casing_no_weapon.png", d, "casing")
	var up_s: float = Tweak.crew().mask_up_time_s
	var event_f: int = roundi(AnimTweak.data().mask_on_s() * AnimTweak.SOURCE_FPS)
	var hold: CrewIntent = CrewIntent.new()
	hold.mask_up = true
	crew.intent = hold
	for f: int in range(1, 40):
		crew._tick_server_actions(DT * up_s)  # the real S1.2 hold, one clip frame per tick
		d.tick(DT)
		if f == event_f - 1:
			await _shot("mask_hold_before_event.png", d, "hold p=%.2f" % crew.mask_progress)
		elif f == event_f:
			await _shot("mask_hold_event.png", d, "hold p=%.2f" % crew.mask_progress)
		d.player.advance(DT)
		if crew.masked:
			break
	for _i: int in 12:
		_step(d, DT)
	await _shot("mask_on_after.png", d, "masked")
	crew.queue_free()


func _mask_walking_scene() -> void:
	var crew: CrewController = await _crew(null, -4.0, false)
	var d: AnimDriver = AnimDriver.of(crew)
	var up_s: float = Tweak.crew().mask_up_time_s
	for f: int in 30:
		crew.position += Vector3(0.0, 0.0, -1.6 * DT)
		crew.velocity = Vector3(0.0, 0.0, -1.6)
		if f >= 8:
			crew.mask_progress = minf(crew.mask_progress + DT / up_s, 0.95)
		_look_at_body(crew, -1.0)
		d.tick(DT)
		if f == 8 + 20:
			await _shot("mask_hold_walking.png", d, "walking p=%.2f" % crew.mask_progress)
		d.player.advance(DT)
	crew.queue_free()


func _thrower(x: float) -> CrewController:
	var def: ThrowableDef = ContentDB.throwable(&"throwable.frag")
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.throwable = def.id if def != null else &""
	var crew: CrewController = await _crew(l, x, true)
	CrewThrowables.set_count(crew, 2)
	return crew


func _throw_scene() -> void:
	var crew: CrewController = await _thrower(4.0)
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
		if f == 4:
			await _shot("throw_pin.png", d, "windup")
		elif released[0]:
			await _shot("throw_release.png", d, "release, grenades %d" % get_tree().get_nodes_in_group(ThrownItem.GROUP).size())
			break
		d.player.advance(DT)
	for item: Node in get_tree().get_nodes_in_group(ThrownItem.GROUP):
		item.queue_free()
	crew.queue_free()


func _throw_running_scene() -> void:
	var crew: CrewController = await _thrower(8.0)
	var d: AnimDriver = AnimDriver.of(crew)
	var hold: CrewIntent = CrewIntent.new()
	hold.throw_item = true
	for f: int in 20:
		crew.position += Vector3(0.0, 0.0, -3.0 * DT)
		crew.velocity = Vector3(0.0, 0.0, -3.0)
		if f >= 8:
			crew.throwables.tick(hold, DT)
		_look_at_body(crew, 1.0)
		d.tick(DT)
		if f == 8 + 8:
			await _shot("throw_running.png", d, "running")
		d.player.advance(DT)
	for item: Node in get_tree().get_nodes_in_group(ThrownItem.GROUP):
		item.queue_free()
	crew.queue_free()
