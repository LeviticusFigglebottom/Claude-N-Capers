## P5 melee roster models: windowed side and three-quarter shots of all 12 melee models in two rows, ids sorted
## (top row first, left to right), each at its item origin (the fist marker: a small red cross).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1920x1080 \
##       --script res://tests/b/render/melee_models_capture.gd -- <out_dir>
## Prints "MELEE MODELS SHOT <path>" per frame.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node3D = Node3D.new()
	w.set_script(load("res://tests/b/render/melee_models_capture_worker.gd"))
	root.add_child(w)
