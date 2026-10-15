## PO6-03 windowed device timer capture (D-086): Golden Hour from MenuFlow, the local crew in front of a DrillPoint,
## a drill placed (running), then jammed, at 1280x720 / 1920x1080. Run from the clone root:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/device_timer_capture.gd -- <out_dir>
## PNGs: <out_dir>/<NN>_<step>_<w>x<h>.png. Exits 0.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/device_timer_capture_worker.gd"))
	root.add_child(w)
