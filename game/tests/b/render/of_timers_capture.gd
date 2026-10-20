## OF HUD timers (lead r245 pass: "incl. the HUD time-lock and escape timers"): real menus (keyboard) into Ostrander
## Federal, then two stated setup shortcuts on the live mission: the time lock starts (_start_time_lock, as the
## console code does) -> "TIME LOCK mm:ss" on the objective line; the alarm goes off and the escape is called
## (_call_escape, as [secure] does) -> "ESCAPE mm:ss". A full loud run is too slow under xvfb to get there (~30 min
## per shot). Shots: <out_dir>/ostrander_federal/NN_<tag>_<w>x<h>.png.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/of_timers_capture.gd -- <out_dir>
## Prints "RUN SHOT <path>", "TIMERS <objective line text>" and "TIMERS DONE".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/of_timers_worker.gd"))
	root.add_child(w)
