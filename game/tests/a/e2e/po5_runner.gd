## PO-5 (D-086): end-to-end windowed playthrough. Owner: ENV A (test support).
## Plays like a person: real menus clicked with InputEventMouseButton at the button's screen position,
## gameplay through PlayerInputDriver (Input.parse_input_event only). Screenshots every step.
## Run (windowed, NOT --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game res://tests/a/e2e/po5_runner.tscn \
##     -- --po5-flow=smoke --po5-out=/tmp/po5
extends Node

var out_dir: String = "user://po5"
var flow: String = "smoke"
var _shot: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--po5-out="):
			out_dir = a.substr(10)
		elif a.begins_with("--po5-flow="):
			flow = a.substr(11)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var driver: Node = Node.new()
	driver.name = "PO5Driver"
	driver.set_script(load("res://tests/a/e2e/po5_flow.gd"))
	driver.set(&"runner_out", out_dir)
	driver.set(&"runner_flow", flow)
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_file.call_deferred("res://core/boot.tscn")
