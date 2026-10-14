## D-109 windowed pass (lead, GN-B1 polish): each heist's briefing through the real MenuFlow at Hazardous.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/briefing_capture.gd -- <out_dir> [heist_id ...]
## PNGs: <out_dir>/<NN>_briefing_<heist>_<w>x<h>.png; "BRIEF ..." lines on stdout.
extends SceneTree
## Launcher only: the worker (uses autoloads) is loaded after the first frame.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/briefing_capture_worker.gd"))
	root.add_child(w)
