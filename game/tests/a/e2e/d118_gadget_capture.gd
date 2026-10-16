## D-118 windowed evidence (D-086): a crew bot (rook body, AnimDriver aim pose) in a dark test room with its
## weapon's laser and flashlight on, drawn by CrewGadgetVisual (third person). PNG goes to --cap-out.
## Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 \
##     res://tests/a/e2e/d118_gadget_capture.tscn -- --cap-out=/abs/dir
extends Node3D

var _out: String = ""
var _bot: CrewController = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cap-out="):
			_out = a.trim_prefix("--cap-out=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/d118"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _process(_delta: float) -> void:
	var ad: AnimDriver = AnimDriver.of(_bot) if _bot != null else null
	if ad != null:
		ad.set(&"_aim_hold_left", 5.0)  # hold the aim pose so the gun points ahead


func _run() -> void:
	Net.start_solo("Player", 0)
	_build_room()
	var l: Loadout = CrewWeapons.build_loadout(null)
	l.heister = &"rook"
	_bot = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	_bot.setup(1, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, l)
	_bot.masked = true
	_bot.mask_progress = 1.0
	add_child(_bot)
	NetIds.claim(_bot)
	_bot.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-20.0)), Vector3(0, 0.05, 4.0)))
	await _wait(1.0)
	var ws: int = _bot.weapons.equipped_slot
	_bot.weapons.stats(ws).gadgets = [&"laser", &"flashlight"] as Array[StringName]
	_bot.weapons.toggle_gadget()
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(2.6, 1.9, 5.6)
	cam.look_at(Vector3(-0.6, 1.0, 0.5))
	cam.current = true
	await _wait(1.0)
	for i: int in 20:  # software GL under xvfb runs a few fps: let the gadget follow the posed hand
		await get_tree().process_frame
	var g: CrewGadgetVisual = CrewGadgetVisual.of(_bot)
	if g == null:
		push_error("[D118CAP] no GadgetVisual")
		get_tree().quit(1)
		return
	var ad: AnimDriver = AnimDriver.of(_bot)
	print("[D118CAP] clip %s beam %s len %.2f dot %s light %s" % [ad.clip if ad != null else &"-", g.beam.visible,
		g.beam_length, g.dot.visible, g.light.visible])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/d118_gadget_3p.png" % _out)
	print("[D118CAP] done: %s" % _out)
	get_tree().quit(0)


func _build_room() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.01, 0.015)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.05, 0.05, 0.07)
	e.ambient_light_energy = 0.4
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var fill: OmniLight3D = OmniLight3D.new()  # faint fill so the bot's body reads in the dark room
	fill.position = Vector3(1.8, 2.4, 5.4)
	fill.omni_range = 4.0
	fill.light_energy = 0.35
	add_child(fill)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.5)
	mat.roughness = 0.9
	_box(Vector3(0, -0.5, 0), Vector3(16, 1, 16), mat)  # floor
	_box(Vector3(0, 2, -4.5), Vector3(16, 5, 1), mat)  # back wall the bot aims at
	_box(Vector3(-5.5, 2, 0), Vector3(1, 5, 16), mat)  # side wall
	_box(Vector3(-1.2, 0.6, -1.0), Vector3(1.0, 1.2, 1.0), mat)  # crate in the light


func _box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1 | CombatTweak.data().hitscan_mask
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	body.position = pos
	add_child(body)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
