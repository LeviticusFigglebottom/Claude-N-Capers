## LEAD r229 item 3: a real-input (keyboard + mouse-free) windowed run of main menu -> hub -> Planning -> <heist> (default Golden Hour) ->
## briefing -> pre-planning -> loadout (the D-126 secondary picker) -> launch -> casing -> mask up (held key) -> Tab
## sheet (held key) -> heist end (setup: HeistRuntime.end_heist) -> payday -> card -> hub, one shot per screen.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1920x1080 \
##       --script res://tests/b/render/real_input_run_capture.gd -- <out_dir> [heist_id]
## Prints "RUN SHOT <path>" per frame and "RUN NOTE ..." for anything that did not go as expected.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/real_input_run_worker.gd"))
	root.add_child(w)
