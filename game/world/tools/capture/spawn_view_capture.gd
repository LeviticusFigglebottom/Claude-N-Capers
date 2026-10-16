## Windowed heist-start capture: launches a heist as P's spawn_view_probe does and saves crew 0's first view.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --rendering-driver opengl3 --path game \
##     res://world/tools/capture/spawn_view_capture.tscn -- --heist=night_deposit --out=/abs/path.png
## Owner: ENV C.
extends Node

var _heist: StringName = &"night_deposit"
var _out: String = "user://spawn_view.png"
var _frames: int = 90


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--heist="):
			_heist = StringName(a.trim_prefix("--heist="))
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--frames="):
			_frames = int(a.trim_prefix("--frames="))
	var rt: HeistRuntime = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false})
	if rt == null:
		push_error("spawn_view_capture: %s launch failed" % _heist)
		get_tree().quit(1)
		return
	for _i: int in _frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out)
	print("spawn_view_capture: saved %s" % _out)
	get_tree().quit(0)
