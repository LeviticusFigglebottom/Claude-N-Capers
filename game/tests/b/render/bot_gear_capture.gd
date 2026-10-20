## PO-19 (D-145.4) lead r245 ask: do the bots carry the gear the player gave them? Sets three different Bot Crew
## loadouts, goes through the real menus (keyboard) into <heist> (default ostrander_federal), then reads each AI
## crew member's live CrewWeapons / CrewHealth / Loadout / CrewView and shoots the crew from a spectator camera,
## unmasked and masked.
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1280x720 \
##       --script res://tests/b/render/bot_gear_capture.gd -- <out_dir> [heist_id]
## Prints "RUN SHOT <path>", "BOT <slot> ..." per bot, "BOT MISMATCH ..." per gear that is not what was assigned and
## "BOT DONE <mismatches>".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/bot_gear_worker.gd"))
	root.add_child(w)
