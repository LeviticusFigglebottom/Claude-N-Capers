## Progression pace model (LEAD 2026-10-21, PO question): levels per heist clear for the six heists x six difficulties,
## a new-player path, and clears to max level, with the real PayoutCalculator / HeistFreshness / XpCurve code and the
## current data, plus the option variants in docs/design/progression_pace.md. Prints "PACE ..." lines.
##   /opt/godot/godot --headless --path game --script res://tests/b/tools/progression_pace.gd
extends SceneTree


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/tools/progression_pace_worker.gd"))
	root.add_child(w)
