## L1.7 audit: a windowed shot of the HUD's assault banner with the difficulty skulls (Lethal = 4) and the Last Breath
## tag, on the mock HUD model.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/assault_banner_capture.gd -- <out_dir>
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/assault_banner_capture_worker.gd"))
	root.add_child(w)
