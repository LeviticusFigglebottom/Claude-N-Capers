## D-111 review capture (windowed): a police officer takes hits from the front, left, back and right, then dies;
## a frame every CAPTURE_S goes to --anim-out as NNN.png for a before/after strip. Owner: ENV A.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 640x480 \
##     res://tests/a/e2e/anim_hits_capture.tscn -- --anim-out=/abs/dir
extends Node

const CAPTURE_S: float = 0.1
const HIT_GAP_S: float = 0.9
const HITS: Array[Vector3] = [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]

var _out: String = ""
var _frame: int = 0
var _cop: NpcBase = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--anim-out="):
			_out = a.trim_prefix("--anim-out=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/anim_hits"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 7, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 30)))
	var cop: NpcBase = rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), {})
	cop.get_node("Brain").set_physics_process(false)
	cop.max_health = 1000.0
	cop.health = 1000.0
	var cam: Camera3D = Camera3D.new()
	rt.add_child(cam)
	cam.global_position = Vector3(1.3, 1.3, -2.0)
	cam.look_at(Vector3(0, 0.85, 0))
	cam.current = true
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	rt.add_child(sun)
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 2.0
	_cop = cop
	await _frames(1.0)
	for d: Vector3 in HITS:
		cop.take_hit({"amount": 10.0, "direction": d, "type": Enums.DamageType.BULLET})
		await _frames(HIT_GAP_S)
	cop.take_hit({"amount": 5000.0, "direction": Vector3(0, 0, 1), "type": Enums.DamageType.BULLET})
	await _frames(2.0)
	print("[ANIMCAP] %d frames in %s" % [_frame, _out])
	get_tree().quit(0)


func _frames(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%03d.png" % [_out, _frame])
		var d: AnimDriver = AnimDriver.of(_cop) if _cop != null else null
		print("[ANIMCAP] frame %03d clip %s" % [_frame, d.clip if d != null else &"-"])
		_frame += 1
		await get_tree().create_timer(CAPTURE_S, true, false, true).timeout
		t += CAPTURE_S
