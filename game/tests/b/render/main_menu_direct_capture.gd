## PO r305 windowed pass: the main menu's direct entries and the contract path from them (Planning Table -> heist
## select -> briefing -> pre-planning) with no safehouse walk, then Back to the main menu.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/main_menu_direct_capture.gd -- <out_dir>
## PNGs: <out_dir>/main_direct_<NN>_<step>_<w>x<h>.png; "MAIN SHOT ..." lines on stdout.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/main_menu_direct_capture_worker.gd"))
	root.add_child(w)
