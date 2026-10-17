## D-128 live check: the detection ring and crosshair arcs in a real heist (GH, SL, ...). The player is masked and
## put in front of a real guard, the real StealthDirector fills the meter, frames are saved as it fills; then a guard
## off to the side (crosshair arc only), and a security camera when the map has one.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/detection_live_capture.gd -- <out_dir> <heist_id> [ahead|side|camera]
## Prints "LIVE RING SHOT <path>" per frame and "LIVE RING DONE".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/detection_live_capture_worker.gd"))
	root.add_child(w)
