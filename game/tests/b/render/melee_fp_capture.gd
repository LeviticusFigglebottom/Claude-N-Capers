## P5 melee roster in first person (D-086 windowed): the firing range from the main menu with the melee in the
## profile loadout, then real input: hold melee (charge), release (charged swing), tap (quick swing). One run per
## melee id (default: one per FP set: sledgehammer, fire axe, combat dagger).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/melee_fp_capture.gd -- <out_dir> [melee.id ...]
## Prints "MELEE FP SHOT <path> ..." per frame (FpViewmodel clip / action, CrewMelee state).
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/melee_fp_capture_worker.gd"))
	root.add_child(w)
