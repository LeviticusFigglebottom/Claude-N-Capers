## Launch scene for the D-111 animation coverage: puts anim_coverage.gd and po_observer.gd on the root (they
## outlive the runner's scene change), then hands over to ENV A's unchanged PO-5 runner. Same --po5-* arguments as
## po5_runner.tscn plus --anim-out=/abs/dir [--obs-out=/abs/dir]. Owner: ENV P.
extends Node


func _ready() -> void:
	for pair: Array in [["AnimCoverage", "res://tests/p/_review/anim_coverage.gd"],
			["POObserver", "res://tests/p/_review/po_observer.gd"]]:
		var n: Node = Node.new()
		n.name = pair[0]
		n.set_script(load(pair[1]))
		get_tree().root.add_child.call_deferred(n)
	get_tree().change_scene_to_file.call_deferred("res://tests/a/e2e/po5_runner.tscn")
