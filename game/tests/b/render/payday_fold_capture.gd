## r246 OF payday: three unlocked achievements (First Score, Quiet Weekend, No Harm Done) wrap under the fold at
## 1280x720 and 1920x1080; the panel must take focus so d-pad up from Continue scrolls it into view.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/payday_fold_capture.gd -- <out.png>
## Prints "PROBE focus_mode=2" and "PROBE focused=AchievementsUnlocked" when it works.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/payday_fold_capture_worker.gd"))
	root.add_child(w)
