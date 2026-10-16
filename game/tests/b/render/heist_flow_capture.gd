## Lead queue (D-115 "B side done"): the real menu flow for one heist, windowed (D-086): Board → heist select →
## briefing → pre-planning → loadout → load-in → a few seconds in the heist (HUD objective + markers, then masked, then
## the Tab sheet) → abort (pause → Leave) → payday → home. Run from the clone root, one heist per process:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/heist_flow_capture.gd -- <out_dir> <heist_id>
## PNGs: <out_dir>/<heist_id>/<NN>_<step>_<w>x<h>.png. Exits 0.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/heist_flow_capture_worker.gd"))
	root.add_child(w)
