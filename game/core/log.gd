## Leveled, channel-tagged logging. Owner: LEAD.
## Tests may set `capture = true` and inspect `captured`.
extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

var min_level: Level = Level.INFO
var capture: bool = false
var captured: Array[String] = []


func debug(channel: StringName, msg: String) -> void:
	_write(Level.DEBUG, channel, msg)


func info(channel: StringName, msg: String) -> void:
	_write(Level.INFO, channel, msg)


func warn(channel: StringName, msg: String) -> void:
	_write(Level.WARN, channel, msg)


func error(channel: StringName, msg: String) -> void:
	_write(Level.ERROR, channel, msg)


func _write(level: Level, channel: StringName, msg: String) -> void:
	if level < min_level:
		return
	var peer: int = 0
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		peer = multiplayer.get_unique_id()
	var line: String = "[%s][%s][p%d] %s" % [Level.keys()[level], channel, peer, msg]
	if capture:
		captured.append(line)
	match level:
		Level.ERROR:
			push_error(line)
		Level.WARN:
			push_warning(line)
		_:
			print(line)
