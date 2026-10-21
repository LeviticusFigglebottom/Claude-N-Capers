## LEAD r270: Rolling Thunder's in-heist HUD through A's mission (stage 1), launched direct through MenuFlow.launch (RT is
## staged: the same test-only fixture as test_heist_screens_text puts C's WIP def at the convention path and un-hides
## the cached heist list; nothing in data). Shots and a log of the HUD's own state: the objective line in casing,
## masked, at the convoy's stop (stated shortcut: the mission's convoy arrives now, not at its ETA), loud after the
## ambush, the truck saw timers (stated shortcut: each truck's runner is placed as the saw interaction would), the
## Tab sheet, an assault event's marker (a director event as A's PO6-17 runs it), then a won payday with the RT
## achievements (scripted result: 4 gold + 2 cash, signals rigged, Hazardous, no downs).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/rt_hud_capture.gd -- <out_dir> [stub_trucks]
## Headless (`--headless` instead of xvfb-run) logs the same HUD state without saving frames (llvmpipe: the windowed
## loud part takes > 25 min; the GPU box takes the shots).
## Prints "RTHUD SHOT <path>", "RTHUD <state>" lines and "RTHUD DONE <issues>".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/rt_hud_capture_worker.gd"))
	root.add_child(w)
