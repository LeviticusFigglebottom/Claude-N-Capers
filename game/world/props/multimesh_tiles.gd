@tool
## A baked MultiMeshInstance3D whose instances live in `instances` and are written into the MultiMesh when the node
## enters the tree (OF-C2, ENV C). The map generators run headless, and the dummy renderer keeps no MultiMesh buffer,
## so a MultiMesh filled at generation saves empty; this node carries the data in the scene instead.
## `instances`: 4 floats per instance, the origin (x, y, z) and the yaw (radians) of an upright, unscaled transform
## (wall tiles, fixtures). Set `custom_aabb` to the instances' bounds (culling never waits for the buffer).
extends MultiMeshInstance3D

@export var instances: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	fill()


func fill() -> void:
	if multimesh == null or instances.size() < 4:
		return
	var n: int = instances.size() / 4
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n * 12)
	for i: int in range(n):
		var c: float = cos(instances[i * 4 + 3])
		var s: float = sin(instances[i * 4 + 3])
		var j: int = i * 12
		# TRANSFORM_3D buffer rows (basis row with the origin): Basis(UP, yaw) = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
		buf[j] = c
		buf[j + 2] = s
		buf[j + 3] = instances[i * 4]
		buf[j + 5] = 1.0
		buf[j + 7] = instances[i * 4 + 1]
		buf[j + 8] = -s
		buf[j + 10] = c
		buf[j + 11] = instances[i * 4 + 2]
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = n
	multimesh.buffer = buf
