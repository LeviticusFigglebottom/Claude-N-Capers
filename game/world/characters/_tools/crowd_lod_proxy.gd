## D-084: script on every Skeleton3D/CrowdLod proxy; makes sure the zoom watcher exists. Owner: ENV D.
extends MeshInstance3D

const CrowdLodZoom: GDScript = preload("res://world/characters/_tools/crowd_lod_zoom.gd")


func _enter_tree() -> void:
	CrowdLodZoom.ensure(get_tree())
