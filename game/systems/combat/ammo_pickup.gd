## An ammo box on the floor (QB-57): dropped by a killed enemy, picked up by walking over it.
## Owner: ENV A. Spawned by AmmoPickupSystem under HeistRuntime.dynamic_root with a net_id, so
## HeistNetSync replicates its spawn and removal by script path (clients only render it).
## Visual: an original placeholder box (no assets).
class_name AmmoPickup
extends Node3D

const GROUP: StringName = &"ammo_pickup"
const PLACEHOLDER_SIZE: Vector3 = Vector3(0.24, 0.12, 0.16)
const PLACEHOLDER_COLOR: Color = Color(0.36, 0.42, 0.2)

var net_id: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	if get_node_or_null(^"Visual") == null:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = PLACEHOLDER_SIZE
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = PLACEHOLDER_COLOR
		mesh.material = mat
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Visual"
		mi.mesh = mesh
		mi.position = Vector3(0.0, PLACEHOLDER_SIZE.y * 0.5, 0.0)
		add_child(mi)
