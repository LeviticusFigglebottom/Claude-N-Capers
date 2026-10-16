## D-126: windowed shots of the secondary slot (pistols, SMGs, shotguns): the loadout's secondary picker from a fresh
## profile, and the Workshop list scrolled to SECONDARY WEAPONS with its class sub-headers.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/secondaries_capture.gd -- <out_dir>
## Prints "SEC SHOT <path>" per frame. Never touches the player's save (a per-process profile root).
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/secondaries_capture_worker.gd"))
	root.add_child(w)
