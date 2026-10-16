## D-115: windowed shots of each heist's first-time card on the HUD (mock model, no level).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1920x1080 \
##       --script res://tests/b/render/heist_tips_capture.gd -- <out_dir>
## Prints "TIP SHOT <path>" per heist. Never touches the player's save (OnboardingTips.persist = false).
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/heist_tips_capture_worker.gd"))
	root.add_child(w)
