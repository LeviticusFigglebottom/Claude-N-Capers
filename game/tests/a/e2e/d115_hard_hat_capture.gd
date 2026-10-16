## D-115 windowed evidence (D-086, ENV D audit R1): dock_worker in surrender / cower with the hard-hat hand lift
## off and on (HardHatHandLift), close-ups of the head. PNGs go to --cap-out. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 \
##     res://tests/a/e2e/d115_hard_hat_capture.tscn -- --cap-out=/abs/dir
extends Node3D

const CLIPS: Array[StringName] = [&"surrender", &"cower"]

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
	var c: Node3D = (load(NpcVisuals.scene_path("dock_worker")) as PackedScene).instantiate() as Node3D
	add_child(c)
	c.rotation.y = PI
	var ap: AnimationPlayer = c.get_node(^"AnimationPlayer") as AnimationPlayer
	var sk: Skeleton3D = c.get_node(^"Skeleton3D") as Skeleton3D
	var lift: HardHatHandLift = HardHatHandLift.ensure(sk)
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.current = true
	for clip: StringName in CLIPS:
		ap.play("%s/%s" % [AnimDriver.LIBRARY, clip])
		ap.seek(ap.current_animation_length * 0.95, true)
		ap.pause()
		var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head")).origin
		cam.position = head + Vector3(0.55, 0.25, 0.75)
		cam.look_at(head + Vector3(0, 0.08, 0))
		for on: bool in [false, true]:
			lift.influence = 1.0 if on else 0.0
			lift.active = on
			for f: int in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path: String = "%s/d115_hard_hat_%s_%s.png" % [_out, clip, "lift" if on else "before"]
			get_viewport().get_texture().get_image().save_png(path)
			print("[D115HAT] %s %s applied %s" % [clip, on, lift.applied])
	print("[D115HAT] done: %s" % _out)
	get_tree().quit(0)
