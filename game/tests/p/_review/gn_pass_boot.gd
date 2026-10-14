## Launch scene for gn_pass.gd (GN-P1 round 187): puts the pass driver, anim_coverage.gd and po_observer.gd on the
## root (they outlive the scene change), then boots the game to the main menu like po5_runner.tscn. Owner: ENV P.
extends Node


func _ready() -> void:
	var out_dir: String = OS.get_user_data_dir() + "/gn_pass"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--po5-out="):
			out_dir = a.substr(10)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var driver: Node = Node.new()
	driver.name = "PO5Driver"
	driver.set_script(load("res://tests/p/_review/gn_pass.gd"))
	driver.set(&"runner_out", out_dir)
	get_tree().root.add_child.call_deferred(driver)
	for pair: Array in [["AnimCoverage", "res://tests/p/_review/anim_coverage.gd"],
			["POObserver", "res://tests/p/_review/po_observer.gd"]]:
		var n: Node = Node.new()
		n.name = pair[0]
		n.set_script(load(pair[1]))
		get_tree().root.add_child.call_deferred(n)
	get_tree().change_scene_to_file.call_deferred("res://core/boot.tscn")
