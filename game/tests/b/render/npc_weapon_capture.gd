## LEAD r244 (b) windowed check of the merged NPC weapons: per NPC-carried gun, the full stock model (left) and the
## baked one-surface model (right), close up (frame 1) and at NPC fight distance, perspective at ~3 m (frame 2).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/npc_weapon_capture.gd -- <out_dir>
## Prints "NPCW SHOT <path>" per frame.
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/npc_weapon_capture_worker.gd"))
	root.add_child(w)
