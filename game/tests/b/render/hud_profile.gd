## Lead perf finding: the HUD's per-frame cost in a REAL masked Glasshouse run (A's gh_stealth harness saw
## 7-20 s process frames after masking up on llvmpipe). Headless, real MenuFlow + HeistRuntime + LocalHudModel:
## masks the local crew up, then samples Performance.TIME_PROCESS over SAMPLE frames with the whole HUD on,
## with the HUD off (process disabled + hidden), and with each HUD child off in turn (its share).
##   /opt/godot/godot --headless --audio-driver Dummy --path game --script res://tests/b/render/hud_profile.gd
## Prints "HUDPROF ..." lines. Exits 0.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/hud_profile_worker.gd"))
	root.add_child(w)
