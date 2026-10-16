## D-115 B-DB / B-SL strings audit (LEAD r228): windowed payday shots for Dockside Burn (success, failed: no pager
## chip on the loud-only job) and Shadow Ledger (stealth-only alarm failure, pager chip kept).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/db_sl_audit_capture.gd -- <out_dir>
## B-GH / B-ND (r229): `-- <out_dir> glasshouse night_deposit` shoots each named heist's success and failed payday.
## Writes <out_dir>/<heist>/NN_payday_<case>_<w>x<h>.png and prints "DBSL SHOT <path>". Never touches the player's save.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/db_sl_audit_capture_worker.gd"))
	root.add_child(w)
