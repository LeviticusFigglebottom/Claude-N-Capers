## D-145.4 / PO-19 windowed check: the hub's Bot Crew button, the Bot Crew screen (bot 1 geared, bot 2 default; keyboard
## and pad focus) and a hosted lobby whose AI seats show the bots' loadouts, at 1280x720 and 1920x1080. Each screen is
## scanned for clipped / off-screen / overlapping labels.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/crew_capture.gd -- <out_dir>
## Prints "CREW SHOT <path>", "QA ISSUE ..." and "CREW DONE <issues>".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/crew_capture_worker.gd"))
	root.add_child(w)
