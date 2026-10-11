## Test walker stand-in for ENV A's hub crew member (QC-43): set_input_paused(), teleport(xform), a
## Camera3D child, and the LocalHudModel `interaction` / `interaction_changed` shape for the hub HUD prompt.
extends Node3D

signal interaction_changed()

var paused: bool = false
var interaction: Dictionary = {}


func set_input_paused(p: bool) -> void:
	paused = p


func teleport(xform: Transform3D) -> void:
	global_transform = xform


## Aim at station `id` (&"" = nothing focused).
func focus(id: StringName) -> void:
	interaction = {} if id == &"" else {"text_key": StringName("ui.prompt.station.%s" % id), "args": {}, "progress": 0.0,
			"blocked_reason": &""}
	interaction_changed.emit()
