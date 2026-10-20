## LEAD r245 OF queue (3): the briefing's "Known security" against what the map actually rolls. For 10 seeds
## (difficulty = (seed - 1) % 6, so every difficulty twice but Lethal/Cataclysm), launches Ostrander Federal
## headless, counts the live security per briefing line (prefab categories as BriefingIntel.categories_of, door locks,
## code safes; guards = the guards spawned at load) and checks each count is inside the line's range and each item's
## room is one of the rooms the line names. Prints "OFINTEL seed ..." per seed, "QA ISSUE ..." and "OFINTEL DONE <n>".
##   /opt/godot/godot --headless --audio-driver Dummy --path game --script res://tests/b/render/of_intel_seeds.gd
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/of_intel_seeds_worker.gd"))
	root.add_child(w)
