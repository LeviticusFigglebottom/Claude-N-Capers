## Lead queue (co-op playability, D-086 windowed): two game WINDOWS over loopback, host + client, walking
## the real MenuFlow: lobby -> host / join -> both ready -> Start -> Glasshouse with HUDs on both -> the
## client leaves -> the host leaves -> payday on both. Run the two from the clone root at the same time:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/coop_capture.gd -- <out_dir> host <port>
##   (same with `client`). PNGs: <out_dir>/<role>_<NN>_<shot>_<w>x<h>.png; "COOP <role> ..." lines on stdout.
## A 4th argument `success` (both peers) secures two bags through the real loot path and ends the heist won;
## `success2` does that twice on one kept session (payday Continue -> crew lobby -> ready -> next heist, C11).
## `fail`: the host ends the heist failed (all in custody); both get the failure payday, then the kept lobby.
## A 5th argument names the heist (default glasshouse), e.g. `success night_deposit`.
extends SceneTree
## Launcher only: the worker (uses autoloads) is loaded after the first frame.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/coop_worker.gd"))
	root.add_child(w)
