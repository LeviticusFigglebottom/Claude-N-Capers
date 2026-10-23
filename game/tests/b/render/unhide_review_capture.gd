## RT / AH un-hide review (LEAD r307): with both heists offered, the Board (each one's contract card), the planning
## table's heist pane and each briefing intro, through the real MenuFlow from the main menu's direct entries.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1920x1080 --script res://tests/b/render/unhide_review_capture.gd -- <out_dir> [heist_id ...]
## PNGs: <out_dir>/unhide_<step>_<w>x<h>.png; "UNHIDE ..." lines on stdout. Needs the heists offered (un-hidden).
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/unhide_review_capture_worker.gd"))
	root.add_child(w)
