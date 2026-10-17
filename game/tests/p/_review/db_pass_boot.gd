## Launch scene for db_pass.gd (DB-P1): puts the pass driver and po_observer.gd on the root (they outlive the scene
## change), then boots the game to the main menu like po5_runner.tscn. Owner: ENV P.
extends Node


func _ready() -> void:
	var out_dir: String = OS.get_user_data_dir() + "/db_pass"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--po5-out="):
			out_dir = a.substr(10)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var driver: Node = Node.new()
	driver.name = "PO5Driver"
	driver.set_script(load("res://tests/p/_review/db_pass.gd"))
	driver.set(&"runner_out", out_dir)
	get_tree().root.add_child.call_deferred(driver)
	var obs: Node = Node.new()
	obs.name = "POObserver"
	obs.set_script(load("res://tests/p/_review/po_observer.gd"))
	get_tree().root.add_child.call_deferred(obs)
	get_tree().change_scene_to_file.call_deferred("res://core/boot.tscn")
