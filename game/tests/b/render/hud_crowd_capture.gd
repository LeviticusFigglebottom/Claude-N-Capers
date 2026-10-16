## LEAD r227 HUD crowding audit: every in-heist widget at once on the real HUD (mock model + a tiny 3D world),
## a loud Golden Hour moment and a stealth Gallery Night moment, at the window's resolution.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/hud_crowd_capture.gd -- <out_dir>
## Saves crowd_<moment>_<w>x<h>.png and prints "CROWD SHOT <path>" per moment.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/hud_crowd_capture_worker.gd"))
	root.add_child(w)
