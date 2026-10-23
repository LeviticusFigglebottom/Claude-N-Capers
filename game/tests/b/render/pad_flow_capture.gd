## LEAD r309 gamepad-only pass (see pad_flow_capture_worker.gd).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/pad_flow_capture.gd -- <out_dir> <heist_id>
## Needs the heist offered (the un-hide). PNGs <out_dir>/<heist>/NN_<step>_<w>x<h>.png; "PAD ..." lines on stdout.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/pad_flow_capture_worker.gd"))
	root.add_child(w)
