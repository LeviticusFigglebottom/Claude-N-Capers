## D-161/163/164 deck items: D's hand-held models (pocket ECM, smoke bomb, gas dispenser, leech ampule) as wired in
## the ThrowableDefs, lined up upright (the held convention: grip at the origin, +Y up, face -Z) beside a 10 cm bar,
## lit, from the player's side and from behind. Checks the wiring, scale and orientation; the FP hand has no
## deck-item pose yet (CrewThrowables.throwable_def() is null for a deck item).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/deck_items_capture.gd -- <out_dir>
extends SceneTree

const IDS: Array[StringName] = [&"throwable.pocket_ecm", &"throwable.smoke_bomb", &"throwable.gas_dispenser",
	&"throwable.leech_ampule"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else "user://deck_items"
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.37)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var x: float = -0.27
	for id: StringName in IDS:
		var path: String = "res://content/data/throwables/%s.tres" % String(id).trim_prefix("throwable.")
		var def: ThrowableDef = load(path) as ThrowableDef
		if def == null or def.model == null:
			push_error("deck_items_capture: %s has no model" % id)
			continue
		var m: Node3D = def.model.instantiate() as Node3D
		m.position = Vector3(x, 0, 0)
		world.add_child(m)
		x += 0.18
	var bar: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.005, 0.1, 0.005)
	bar.mesh = box
	bar.position = Vector3(x - 0.06, 0.05, 0)
	world.add_child(bar)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.12, 1.15), Vector3(0.0, 0.05, 0), Vector3.UP)
	await _save(out + "/deck_items_front.png")
	cam.look_at_from_position(Vector3(0.75, 0.35, -0.75), Vector3(0.0, 0.05, 0), Vector3.UP)
	await _save(out + "/deck_items_back.png")
	quit(0)


func _save(path: String) -> void:
	for _i: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
