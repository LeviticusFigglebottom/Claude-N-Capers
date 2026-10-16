## D-128: windowed shots of PD2's detection indicator on the real HUD (mock model + a tiny 3D world with capsule guards):
## a ring filling at ~30 % and ~70 %, the full red "!", two observers at once (one off to the side), a guard
## investigating a noise ("?" at 0), and a camera.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/detection_ring_capture.gd -- <out_dir>
## Prints "RING SHOT <path>" per frame.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/detection_ring_capture_worker.gd"))
	root.add_child(w)
