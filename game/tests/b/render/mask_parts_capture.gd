## Round 244 windowed shot of the achievement mask parts: row 1 the six new pattern fallbacks (procedural, texture off),
## row 2 the same patterns with D's textures, row 3 the seven new materials (metal ones show the pattern-readability fix).

##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/mask_parts_capture.gd -- <out_dir>
## Prints "MASKS SHOT <path>" per frame.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/mask_parts_capture_worker.gd"))
	root.add_child(w)
