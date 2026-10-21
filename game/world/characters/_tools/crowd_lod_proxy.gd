## D-084: script on every Skeleton3D/CrowdLod proxy; makes sure the zoom watcher exists. D-146 (LEAD-approved OF cast
## audit): the proxy casts no shadow (it only shows from the switch distance on, where a crowd's shadows cost a draw
## per cascade per NPC and read as nothing). Owner: ENV D.
extends MeshInstance3D

const CrowdLodZoom: GDScript = preload("res://world/characters/_tools/crowd_lod_zoom.gd")


func _enter_tree() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	CrowdLodZoom.ensure(get_tree())
