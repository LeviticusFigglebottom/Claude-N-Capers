## Sliding door leaf (D-111, Dockside Burn cold-store doors, tools/blender/props/doors.py `slide`). Visual only
## (visual_slots.md: visual-only scripts allowed under world/). The `door` prefab opens a leaf by turning `Leaf` /
## `Leaf2` about Y (0 = closed .. door_open_angle_deg = open). A sliding leaf must not swing: this script sits on the
## leaf (the wrapper scene sets it, _scenes.py `leaf_script` + `leaf2`), cancels the yaw on its children and turns
## the open fraction into a slide along the wall line, away from the meeting edge, into the wall pocket beside the
## opening. At rotation 0 the children sit exactly at their rest pose, so validators that close the leaves see a
## closed door.
extends Node3D

## Fallback when InteractionTweak is not available (door.gd's default).
const DEFAULT_OPEN_DEG: float = 90.0

var _rest: Dictionary[Node3D, Transform3D] = {}
## Slide travel (m) along leaf-local X at full open: the leaf width, away from the meeting edge.
var _travel: Vector3 = Vector3.ZERO


func _ready() -> void:
	var lo: float = INF
	var hi: float = -INF
	for c: Node in get_children():
		var n3: Node3D = c as Node3D
		if n3 == null:
			continue
		_rest[n3] = n3.transform
		var mi: MeshInstance3D = n3 as MeshInstance3D
		if mi != null and mi.mesh != null:
			var bb: AABB = n3.transform * mi.mesh.get_aabb()
			lo = minf(lo, bb.position.x)
			hi = maxf(hi, bb.end.x)
	if hi > lo:
		# children on +X (Leaf, hinge at the -X jamb) slide toward -X; children on -X (Leaf2) toward +X
		var toward: float = -1.0 if (lo + hi) > 0.0 else 1.0
		_travel = Vector3(toward * (hi - lo), 0.0, 0.0)
	set_notify_local_transform(true)
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		_apply()


static func open_angle_rad() -> float:
	var tw: InteractionTweak = Tweak.interaction()
	return deg_to_rad(tw.door_open_angle_deg if tw != null else DEFAULT_OPEN_DEG)


## Open fraction 0 (closed) .. 1 (slid open) from the leaf's yaw.
func open_fraction() -> float:
	return clampf(absf(rotation.y) / maxf(open_angle_rad(), 0.001), 0.0, 1.0)


func _apply() -> void:
	if _rest.is_empty():
		return
	var f: float = open_fraction()
	var undo: Basis = Basis(Vector3.UP, -rotation.y)
	for c: Node3D in _rest:
		var rest: Transform3D = _rest[c]
		c.transform = Transform3D(undo * rest.basis, undo * (rest.origin + _travel * f))
