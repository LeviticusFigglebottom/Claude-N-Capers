## AH in-heist UI pass (LEAD r308): the civilian start, the gear prompt, the objective tracker through the stealth line,
## a pager prompt, the camera operator, the loud switch, the van wait and the payday, windowed. Menus by real input;
## in the heist the state is driven (stated shortcuts: the crew is placed facing a prop and is never seen, objectives
## are completed through the mission, the alarm is raised through the StealthDirector, the heist ends through the
## runtime).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/ah_hud_capture.gd -- <out_dir>
## Needs Afterhours offered (the un-hide). PNGs <out_dir>/afterhours/NN_<step>_<w>x<h>.png; "AH ..." lines on stdout.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/ah_hud_capture_worker.gd"))
	root.add_child(w)
