## LEAD r245 OF queue (1) + (2): a real Ostrander Federal run with the in-heist HUD and payday spawned as MenuFlow
## does (_spawn_in_heist_ui), played by ENV A's X-4 harness: the stealth ghost line (X4StealthRoutes, seed 18) and
## the loud line (X4OfLoud, seed 5; its stated shortcuts and the D-133 dev option). Mid-heist HUD shots at 1280x720 and
## 1920x1080 when chosen objectives turn ACTIVE and when each device kind starts, each scanned for clipped / off-screen /
## overlapping labels; then the payday the real HeistResult builds (fresh scratch profile), its lines, bags, stealth
## bonus, freshness and the achievements it fires. Mode `pager`: the pager row (one real pager started on a live guard,
## a stated shortcut).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/of_run_capture.gd -- <out_dir> [pager|stealth|loud]
## Prints "OFRUN SHOT <path>", "OFRUN HUD ...", "OFRUN PAYDAY ...", "QA ISSUE ..." and "OFRUN DONE <issues>".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/of_run_capture_worker.gd"))
	root.add_child(w)
