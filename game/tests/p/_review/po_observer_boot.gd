## Launch scene for po_observer.gd: puts the observer on the root (it outlives the runner's scene change),
## then hands over to ENV A's unchanged PO-5 runner. Owner: ENV P.
extends Node


func _ready() -> void:
	var obs: Node = Node.new()
	obs.name = "POObserver"
	obs.set_script(load("res://tests/p/_review/po_observer.gd"))
	get_tree().root.add_child.call_deferred(obs)
	get_tree().change_scene_to_file.call_deferred("res://tests/a/e2e/po5_runner.tscn")
