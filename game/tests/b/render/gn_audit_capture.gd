## D-115 GN strings audit (LEAD r228, B-GN) windowed evidence: Gallery Night's briefing through the real MenuFlow
## (Routine, Hazardous), the HUD objective line + Tab scoreboard list in the mission's own objective order (stealth start,
## stealth mid-run, loud as the mission leaves it today), and the payday header for a GN result.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/gn_audit_capture.gd -- <out_dir>
## PNGs: <out_dir>/<NN>_<shot>_<w>x<h>.png; "GNA ..." lines on stdout.
extends SceneTree
## Launcher only: the worker (uses autoloads) is loaded after the first frame.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/gn_audit_capture_worker.gd"))
	root.add_child(w)
