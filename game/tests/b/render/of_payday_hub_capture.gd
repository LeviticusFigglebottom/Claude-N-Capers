## LEAD r262 OF done check: a still of the payday and the safehouse hub for the PO, with D-148 XP. A fresh profile gets a
## first Ostrander Federal stealth clear (4 cash + 2 bond bags, crew of 4 alive, the default seed) through the real
## PaydayScreen (payout, freshness, XP bar, level-ups, achievements), then the HubMenu shows that profile (level, XP
## bar, cash, stash, points). One clear per difficulty given (default 2 = Hazardous).
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game --resolution 1920x1080 \
##       --script res://tests/b/render/of_payday_hub_capture.gd -- <out_dir> [difficulty]
## Prints "OFPH SHOT <path>", "OFPH PAYDAY ..." and "OFPH DONE".
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/of_payday_hub_capture_worker.gd"))
	root.add_child(w)
