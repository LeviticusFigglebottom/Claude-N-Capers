## Fallback node for a pre-planning drop asset whose kind has no registered prefab yet (C3, A2-07).
## Owner: ENV A. Spawned by PreplanAssets at the asset's PREPLAN_POINT; findable with
## HeistRuntime.find_by_tag(&"asset.<id>") or the `preplan_drop` group. The owning system (e.g. the
## deployables) replaces it by calling PreplanAssets.register_drop(kind, scene_or_factory).
class_name PreplanDrop
extends Node3D

var asset_id: StringName = &""
var kind: StringName = &""
var params: Dictionary = {}
var objective_tag: StringName = &""
var net_id: int = 0


func _ready() -> void:
	add_to_group(PreplanAssets.DROP_GROUP)
	NetIds.claim(self)
