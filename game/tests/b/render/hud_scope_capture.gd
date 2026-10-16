## LEAD r228 (P's ui_hud v1.16 windowed check): the drill-jammed moment at hip and scoped on the real HUD (mock model +
## a tiny 3D world). Scoped draws a stand-in black mask outside P's ring (x 465..1459 on the 1920x1080 canvas).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/hud_scope_capture.gd -- <out_dir>
## Saves scope_<hip|scoped>_<w>x<h>.png and prints "SCOPE SHOT <path>" per shot.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/hud_scope_capture_worker.gd"))
	root.add_child(w)
