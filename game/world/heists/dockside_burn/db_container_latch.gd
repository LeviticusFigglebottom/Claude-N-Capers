## Dockside Burn container door latch. Owner: ENV C (C3).
## The target of a yard container's padlock (ENV A `padlock`, QC-37): DrillPoint.open_target() calls
## open_by_device() when the padlock is picked or sawn (server). The mission listens to `opened` and
## releases that container's crates (weapons containers) or plays the "wrong box" line.
extends Node3D

signal opened

var is_open: bool = false


func open_by_device() -> void:
	if is_open:
		return
	is_open = true
	opened.emit()
