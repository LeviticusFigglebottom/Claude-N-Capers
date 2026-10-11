## Test mock of ENV C's SafehouseMap root (B6-06; docs/design/heists/safehouse.md "Contract deviations"):
## signal station_requested(id), `jukebox` (preview target), set_jukebox_track(id), spawn_transform(id).
## Stations live under Stations/ (named by id, group hub_station); markers under Spawns/; a walker
## stand-in (group hub_walker) replaces ENV A's spawn_for_hub crew.
class_name MockSafehouseMap
extends Node3D

signal station_requested(station_id: StringName)

var jukebox: Node = null
## Every set_jukebox_track() call, in order.
var jukebox_tracks: Array[StringName] = []


func _ready() -> void:
	jukebox = get_node_or_null(^"Audio/Jukebox")


func set_jukebox_track(track_id: StringName) -> void:
	jukebox_tracks.append(track_id)


func spawn_transform(return_id: StringName) -> Transform3D:
	var m: Node3D = get_node_or_null(NodePath("Spawns/%s" % return_id)) as Node3D
	return m.global_transform if m != null else Transform3D.IDENTITY
