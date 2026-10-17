## D-130 windowed shots: Golden Hour's heist select card (stealth note) and its briefing "Known security" at Routine and
## Lethal. Until C's GH generator row lands, the D-130 GH values are set on the loaded def here (fixture).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/d130_capture.gd -- <out_dir>
## Prints "D130 SHOT <path>" per frame.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/d130_capture_worker.gd"))
	root.add_child(w)
