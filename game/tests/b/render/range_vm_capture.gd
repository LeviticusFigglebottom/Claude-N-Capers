## PO6-12 windowed range clip (D-086): the firing range from the main menu with real input actions: three weapons
## (Corsair AR picked, slot-key swap to the Kestrel P9, Plowman 12 picked), each fired, reloaded and aimed; frames
## of every step. Run from the clone root:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/range_vm_capture.gd -- <out_dir>
## PNGs: <out_dir>/<NN>_<step>.png plus a log line per frame (weapon, FpViewmodel clip/action, ammo). Exits 0.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/range_vm_capture_worker.gd"))
	root.add_child(w)
