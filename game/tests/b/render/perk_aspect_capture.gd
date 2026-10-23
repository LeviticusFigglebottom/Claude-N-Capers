## D-162..164 perk decks windowed audit (LEAD r292 queue (3)): the perk deck screen (Understudy with picks, Lifeline,
## Veil), the loadout screen's perk line and the HUD perk_item states, at whatever window size it is run with:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x800 \
##       --script res://tests/b/render/perk_aspect_capture.gd -- <out_dir>
## (16:10 = 1280x800, 21:9 = 1680x720.) PNGs: <out_dir>/<NN>_<shot>_<w>x<h>.png. Exits 0.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/perk_aspect_capture_worker.gd"))
	root.add_child(w)
