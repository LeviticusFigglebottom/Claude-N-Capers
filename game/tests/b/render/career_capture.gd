## B7-01 career screen windowed shot (a played profile with payday card totals).

##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/career_capture.gd -- <out_dir>
## Prints "CAREER SHOT <path>" per frame.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/career_capture_worker.gd"))
	root.add_child(w)
