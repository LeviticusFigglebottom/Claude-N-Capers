## GN-B1 windowed check (lead lane, round 118): Gallery Night's UI before its map exists. Walks the real
## MenuFlow (planning table -> briefing at Routine and Hazardous -> pre-planning, every floor, a point and
## bought assets -> loadout) and stages the HUD with Gallery Night's objectives, loot and contact radio
## (MockHudModel, casing and loud). Since C's G1 (trunk 55ce4d2a) the def is registered; run it on the clone:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path <copy>/game \
##     --resolution 1280x720 --script res://tests/b/render/gn_capture.gd -- <out_dir>
## PNGs: <out_dir>/<NN>_<shot>_<w>x<h>.png; "GN ..." lines on stdout.
extends SceneTree
## Launcher only: the worker (uses autoloads) is loaded after the first frame.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/gn_capture_worker.gd"))
	root.add_child(w)
