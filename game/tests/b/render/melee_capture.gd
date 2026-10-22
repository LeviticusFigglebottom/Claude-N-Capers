## P5 melee roster (LEAD r280 queue (2)): a windowed shot of the loadout's melee picker with all 12 melees, the
## default (folding knife) selected, and one with a heavy pick focused (its stats and description).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/melee_capture.gd -- <out_dir>
## Prints "MELEE SHOT <path>" per frame. Never touches the player's save (a per-process profile root).
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/melee_capture_worker.gd"))
	root.add_child(w)
