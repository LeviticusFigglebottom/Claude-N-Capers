## GN-B1 windowed check (lead lane, round 118): Gallery Night's UI before its map exists. Walks the real
## MenuFlow (planning table -> briefing at Routine and Hazardous -> pre-planning, every floor, a point and
## bought assets -> loadout) and stages the HUD with Gallery Night's objectives, loot and contact radio
## (MockHudModel, casing and loud). The draft def must be where HeistRegistry looks, so run it on a scratch
## copy of game/ with content/_drafts/gallery_night/*.tres copied to world/heists/gallery_night/ (never
## commit that copy: world/heists is ENV A's):
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
