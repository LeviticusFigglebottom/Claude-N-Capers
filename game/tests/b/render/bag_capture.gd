## Lead (C's art-gap brief): LootDef.bag_model in a real Glasshouse run. An AI teammate stands 3 m ahead of
## the camera with its back turned and carries a heavy bag (gold); a light (jewelry) and a medium (cash
## bricks) bag lie dropped beside it; then the teammate throws its bag. Run from the clone root:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/bag_capture.gd -- <out_dir>
## PNGs: <out_dir>/<NN>_<shot>_<w>x<h>.png; "BAG ..." lines on stdout.
extends SceneTree
## Launcher only: the worker (uses autoloads) is loaded after the first frame.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/bag_capture_worker.gd"))
	root.add_child(w)
