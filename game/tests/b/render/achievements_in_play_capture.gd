## D-115 achievements in play: windowed shots of the payday with two unlocks (toast + section).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/achievements_in_play_capture.gd -- <out_dir>
## Prints "ACH SHOT <path>" per frame. Never touches the player's save (a per-process profile root).
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/achievements_in_play_worker.gd"))
	root.add_child(w)
