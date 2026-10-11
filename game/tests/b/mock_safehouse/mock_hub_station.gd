## Test mock of a safehouse station (C's SafehouseStation / A's hub_station prefab, QC-44). use() emits
## `station_requested(id)` (C shape) or, with `prefab_signal`, A's `station_used(id, crew)`.
extends Node3D

signal station_requested(station_id: StringName)
signal station_used(station_id: StringName, crew: Node)

@export var station_id: StringName = &""
@export var prefab_signal: bool = false


func use(crew: Node = null) -> void:
	if prefab_signal:
		station_used.emit(station_id, crew)
	else:
		station_requested.emit(station_id)
