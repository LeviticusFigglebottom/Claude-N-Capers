## D-139 windowed shots: heist select freshness notes (a repeat penalty, a rotation bonus) and the payday freshness
## money / XP lines with their reason.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/freshness_capture.gd -- <out_dir>
## Prints "FRESH SHOT <path>" per frame.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/freshness_capture_worker.gd"))
	root.add_child(w)
