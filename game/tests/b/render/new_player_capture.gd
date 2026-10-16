## D-115 new-player flow, windowed (D-086), on a FRESH temporary profile and settings folder (never the player's
## save): main menu -> 2D hub + 3D safehouse with START HERE -> Golden Hour (Routine) via the real menu flow ->
## the first cards (casing, heist, after a rebind interact E / mask Q / dismiss J, stealth) -> abort -> payday ->
## home (START HERE gone). Run from the clone root:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/new_player_capture.gd -- <out_dir> [mock]
## `mock` (or a heist that does not load in time) shoots the in-heist cards on the HUD over a MockHudModel instead.
## PNGs: <out_dir>/<NN>_<step>_<w>x<h>.png; prints "NPF SHOT <path>", "NPF CARDS <order>", "NPF DISK <seen ids>".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/new_player_capture_worker.gd"))
	root.add_child(w)
