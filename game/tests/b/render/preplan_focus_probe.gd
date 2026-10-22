## Pre-planning focus graph probe (RT walk follow-up): builds the pre-planning screen of a heist, then for each state
## (crew list, each point's list) walks the arrow-key graph with Control.find_valid_focus_neighbor from the crew tab
## and lists the focusable controls it never reaches and the groups focus cannot leave. Windowed or headless:
##   /opt/godot/godot --path game --resolution 1920x1080 --script res://tests/b/render/preplan_focus_probe.gd -- <heist>
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/preplan_focus_probe_worker.gd"))
	root.add_child(w)
