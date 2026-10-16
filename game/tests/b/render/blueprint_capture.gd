## D-115 review: the pre-planning screen of one heist through the real menu flow (Board → heist select →
## briefing → pre-planning), one PNG per blueprint floor. Windowed (D-086), one heist per process:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1920x1080 --script res://tests/b/render/blueprint_capture.gd -- <out_dir> <heist_id>
## PNGs: <out_dir>/<heist_id>_floor<N>_<w>x<h>.png. Exits 0.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/blueprint_capture_worker.gd"))
	root.add_child(w)
