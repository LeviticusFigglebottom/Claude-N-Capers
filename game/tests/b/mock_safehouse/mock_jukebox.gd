## Test mock of C's SafehouseJukebox (positional MusicDirector.preview, QC-48): records every call.
extends Node

var calls: Array[String] = []


func preview(track_id: StringName, stem: StringName = &"stealth") -> bool:
	calls.append("preview:%s:%s" % [track_id, stem])
	return true


func stop_preview() -> void:
	calls.append("stop")
