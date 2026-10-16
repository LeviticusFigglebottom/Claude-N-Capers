## D-115 windowed evidence (D-086): ENV D characters playing prop clips with HandProps attached (mop, pour, phone,
## smoke, teller cash). PNG goes to --cap-out. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 1280x540 \
##     res://tests/a/e2e/d115_hand_props_capture.tscn -- --cap-out=/abs/dir
extends Node3D

const CAST: Array = [
	["npc_bank_cleaner", &"mop"], ["club_bartender", &"bartender_pour"], ["npc_helena_moor", &"phone_call"],
	["security_officer", &"smoke"], ["npc_bank_teller", &"teller_count"],
]

var _out: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cap-out="):
			_out = a.trim_prefix("--cap-out=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/d115"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.34, 0.38)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(20, 8)
	floor_mesh.mesh = pm
	add_child(floor_mesh)
	for i: int in CAST.size():
		var path: String = NpcVisuals.scene_path(String(CAST[i][0]))
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			push_error("[D115CAP] missing %s" % path)
			continue
		var c: Node3D = ps.instantiate() as Node3D
		add_child(c)
		c.position = Vector3((i - 2) * 1.5, 0, 0)
		c.rotation.y = PI  # face the camera (+Z)
		var ap: AnimationPlayer = c.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		var full: String = "%s/%s" % [AnimDriver.LIBRARY, CAST[i][1]]
		if ap != null and ap.has_animation(full):
			ap.play(full)
			ap.seek(0.6, true)
		var props: PackedStringArray = HandProps.sync(c, CAST[i][1])
		print("[D115CAP] %s %s -> %s (clip %s)" % [CAST[i][0], CAST[i][1], props, ap != null and ap.has_animation(full)])
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.4, 4.6)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/d115_hand_props.png" % _out)
	print("[D115CAP] done: %s" % _out)
	get_tree().quit(0)
