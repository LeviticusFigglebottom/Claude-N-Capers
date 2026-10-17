## D-139/D-140 UI QA walk (lead queue 7): real keyboard input through hub -> Board -> heist select (Routine and Brutal:
## freshness note, pager / guard line) -> briefing -> pre-planning, then the payday screen with a freshness memory, for
## every offered heist. Each screen is scanned for clipped / trimmed labels and overlapping labels ("QA ISSUE" lines).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/ui_qa_walk.gd -- <out_dir> [pad] [heist_id ...]
## `pad`: drive it with the d-pad / A and flag keyboard key caps shown to the pad player.
## Prints "QA SHOT <path>", "QA ISSUE <screen> ..." and "QA DONE <issues>".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/ui_qa_walk_worker.gd"))
	root.add_child(w)
