## LEAD round 276 #3: Rolling Thunder's menu flow by real input (arrow keys + Enter only; no direct calls on the menus)
## while RT is staged (tests/b/staged_heist_fixture.gd): Board -> heist select -> briefing -> pre-planning (every RT asset
## type bought once, and taken back where favors run short; the C4 drop kept on the success run) -> loadout -> launch ->
## casing -> payday. Run "success" ends the heist as a win (Routine), run "fail" as a loss (Hazardous). Windowed:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1920x1080 \
##       --script res://tests/b/render/rt_menu_walk.gd -- <out_dir> success|fail
## Prints "RTWALK SHOT <path>", "RTWALK <what> ..." and "RTWALK ISSUE <what>: ..." lines and "RTWALK DONE <issues>".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/rt_menu_walk_worker.gd"))
	root.add_child(w)
