## PO-4 windowed UI audit (D-086): walks the real flow in the game WINDOW (not a SubViewport, not
## --headless) and saves a PNG of every screen and HUD state. Run from the clone root, one at a time:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/ui_audit_capture.gd -- <out_dir> [only_prefix] [expand|-] [heist_id]
## PNGs: <out_dir>/<NN>_<shot>_<w>x<h>.png. Exits 0.
extends SceneTree
## Launcher only: the worker (uses autoloads) is loaded after the first frame.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/ui_audit_worker.gd"))
	root.add_child(w)
