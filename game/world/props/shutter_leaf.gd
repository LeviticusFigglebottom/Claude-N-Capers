## Roll-up shutter / roller door leaf (GN-C2). Visual only (visual_slots.md: visual-only scripts allowed under world/).
## The `door` prefab opens a leaf by turning `Leaf` about its Y axis (0 = closed .. door_open_angle_deg = open). A
## lockdown shutter must not swing: this script sits on `Leaf` (the wrapper scene sets it, _scenes.py `leaf_script`)
## and, whenever the leaf's transform changes, cancels the yaw on its children and turns the open fraction into a
## roll-up: `Curtain` (origin at the curtain top) shortens toward the hood, `BottomBar` rises under it. At rotation 0
## the children sit exactly at their rest pose, so validators that close the leaves see a closed shutter.
extends Node3D

const CURTAIN: NodePath = ^"Curtain"
const BOTTOM_BAR: NodePath = ^"BottomBar"
const FITTINGS: NodePath = ^"BarFittings"
## The rolled-up curtain keeps this fraction of its height visible under the hood.
const MIN_SCALE: float = 0.03
## Fallback when InteractionTweak is not available (door.gd's default).
const DEFAULT_OPEN_DEG: float = 90.0

var _rest: Dictionary[Node3D, Transform3D] = {}
var _curtain: Node3D = null
var _lift_m: float = 0.0


func _ready() -> void:
	# D-111 twin rollers (doors.py roller_twin): `Leaf2` carries the same parts with the suffix "2" (glb node names
	# are unique per asset).
	var suffix: String = "2" if name == "Leaf2" else ""
	for p: NodePath in [CURTAIN, BOTTOM_BAR, FITTINGS]:
		var c: Node3D = get_node_or_null(NodePath(String(p) + suffix)) as Node3D
		if c != null:
			_rest[c] = c.transform
	_curtain = get_node_or_null(NodePath(String(CURTAIN) + suffix)) as Node3D
	if _curtain != null:
		_lift_m = _curtain.position.y * (1.0 - MIN_SCALE)
	set_notify_local_transform(true)
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		_apply()


static func open_angle_rad() -> float:
	var tw: InteractionTweak = Tweak.interaction()
	return deg_to_rad(tw.door_open_angle_deg if tw != null else DEFAULT_OPEN_DEG)


## Open fraction 0 (closed) .. 1 (rolled up) from the leaf's yaw.
func open_fraction() -> float:
	return clampf(absf(rotation.y) / maxf(open_angle_rad(), 0.001), 0.0, 1.0)


func _apply() -> void:
	if _rest.is_empty():
		return
	var f: float = open_fraction()
	var undo: Basis = Basis(Vector3.UP, -rotation.y)
	for c: Node3D in _rest:
		var rest: Transform3D = _rest[c]
		if c == _curtain:
			var sc: Basis = rest.basis * Basis.from_scale(Vector3(1.0, maxf(MIN_SCALE, 1.0 - f), 1.0))
			c.transform = Transform3D(undo * sc, undo * rest.origin)
		else:
			c.transform = Transform3D(undo * rest.basis, undo * (rest.origin + Vector3.UP * (_lift_m * f)))
