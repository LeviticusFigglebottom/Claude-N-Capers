## Test mock of C's jukebox MusicDirector (hub_map.md v1.0: preview / stop_preview / set_ducked): records every call.
extends Node

var calls: Array[String] = []


func preview(track_id: StringName, stem: StringName = &"stealth") -> bool:
	calls.append("preview:%s:%s" % [track_id, stem])
	return true


func stop_preview() -> void:
	calls.append("stop")


func set_ducked(on: bool) -> void:
	calls.append("duck:%s" % on)
