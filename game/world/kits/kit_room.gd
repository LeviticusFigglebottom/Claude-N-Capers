## A room as KitPlacer sees it (C1-07, ENV C): the clear interior (inner wall faces, floor to
## ceiling) in a room-local frame, its wall openings, keep-out zones and designer anchors.
##
## Room-local frame: origin = floor centre of the clear interior, +Y up, axes along the walls.
## Walls: 0 = north (-Z face, inward normal +Z), 1 = east (+X, normal -X), 2 = south (+Z, normal -Z),
## 3 = west (-X, normal +X). A wall's `u` coordinate runs along it from its left end as seen from
## inside the room.
class_name KitRoom
extends RefCounted

## Local frame -> world (yaw-only basis).
var xform: Transform3D = Transform3D.IDENTITY
## Clear interior size: x width, y ceiling height, z depth.
var size: Vector3 = Vector3(4.0, 3.0, 4.0)
## { wall: int, u: float (centre along the wall), width: float, bottom: float, top: float,
##   door: bool, swing: float (keep-out depth into the room, 0 for windows) }
var openings: Array[Dictionary] = []
## Room-local AABBs nothing may overlap (gameplay prefabs, stairs, walkways...).
var keep_out: Array[AABB] = []
## Walls that exist (false = open side, e.g. a room open to a corridor). Index = wall id.
var walls: Array[bool] = [true, true, true, true]
## Designer overrides placed first: { "asset": StringName or "kind": StringName,
## "transform": Transform3D (room-local, pivot) }.
var anchors: Array[Dictionary] = []
## Stable id used in the seed (room_id), so equal kits still vary per room.
var id: StringName = &""


## Room from an axis-aligned world AABB of the clear interior (bottom = finished floor).
static func from_aabb(box: AABB, room_id: StringName = &"") -> KitRoom:
	var r := KitRoom.new()
	r.xform = Transform3D(Basis.IDENTITY, Vector3(box.get_center().x, box.position.y, box.get_center().z))
	r.size = box.size
	r.id = room_id
	return r


## Room from a RoomVolume: union of its BoxShape3D children (world, axis-aligned), shrunk by
## `wall_inset` on X/Z (RoomVolumes drawn on wall centre lines: 0.1 interior, 0.2 exterior).
static func from_volume(rv: RoomVolume, wall_inset: float = 0.1) -> KitRoom:
	var box := AABB()
	var first: bool = true
	for c: Node in rv.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c as CollisionShape3D
		var bs: BoxShape3D = cs.shape as BoxShape3D
		if bs == null:
			continue
		var xf: Transform3D = cs.global_transform if cs.is_inside_tree() else _chain(cs)
		var b: AABB = xf * AABB(-bs.size * 0.5, bs.size)
		box = b if first else box.merge(b)
		first = false
	box.position += Vector3(wall_inset, 0.0, wall_inset)
	box.size -= Vector3(wall_inset * 2.0, 0.0, wall_inset * 2.0)
	return from_aabb(box, rv.room_id)


static func _chain(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func area() -> float:
	return size.x * size.z


func to_local(world: Vector3) -> Vector3:
	return xform.affine_inverse() * world


## Wall nearest to a room-local point and the point's `u` on it.
func nearest_wall(local: Vector3) -> Vector2:
	var d: Array[float] = [local.z + size.z * 0.5, size.x * 0.5 - local.x, size.z * 0.5 - local.z, local.x + size.x * 0.5]
	var best: int = 0
	for i: int in range(1, 4):
		if absf(d[i]) < absf(d[best]):
			best = i
	return Vector2(best, wall_u(best, local))


## Length of wall `w`.
func wall_length(w: int) -> float:
	return size.x if w % 2 == 0 else size.z


## Inward normal of wall `w` (room-local).
static func wall_normal(w: int) -> Vector3:
	return [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)][w]


## Point on wall `w` (floor level) at `u`, and `u` of a local point.
func wall_point(w: int, u: float) -> Vector3:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	match w:
		0:
			return Vector3(-hx + u, 0.0, -hz)
		1:
			return Vector3(hx, 0.0, -hz + u)
		2:
			return Vector3(hx - u, 0.0, hz)
		_:
			return Vector3(-hx, 0.0, hz - u)


func wall_u(w: int, local: Vector3) -> float:
	match w:
		0:
			return local.x + size.x * 0.5
		1:
			return local.z + size.z * 0.5
		2:
			return size.x * 0.5 - local.x
		_:
			return size.z * 0.5 - local.z


## Yaw that turns a prop's front (-Z) to face away from wall `w` (into the room).
static func wall_yaw(w: int) -> float:
	return [PI, PI * 0.5, 0.0, -PI * 0.5][w]


## Register a door opening at a world position on the floor (centre of the opening). `width` is
## the leaf width (0.9 single, 1.8 double, 1.1 service). `frame_pad` (m per side) keeps the frame's
## architraves clear: the GSR door frames (prop_door_*) reach 0.125 (single/service) to 0.175
## (double) beyond the leaf on each side; the default 0.18 covers all of them. `swing_depth`:
## -1 = the leaf swings into the room (keep-out width + 0.15, >= 1 m), 0 = swings out (0.3 m threshold).
func add_door(world_pos: Vector3, width: float, swing_depth: float = -1.0, top: float = 2.2,
		frame_pad: float = 0.18) -> void:
	var l: Vector3 = to_local(world_pos)
	var wu: Vector2 = nearest_wall(l)
	openings.append({"wall": int(wu.x), "u": wu.y, "width": width, "bottom": 0.0, "top": top, "door": true, "pad": frame_pad,
		"swing": 0.3 if swing_depth == 0.0 else maxf(swing_depth if swing_depth > 0.0 else width + 0.15, 1.0)})


## Register a window: world position of the sill centre, width and the sill/head heights above
## the floor.
func add_window(world_pos: Vector3, width: float, sill: float, head: float, frame_pad: float = 0.06) -> void:
	var l: Vector3 = to_local(world_pos)
	var wu: Vector2 = nearest_wall(l)
	openings.append({"wall": int(wu.x), "u": wu.y, "width": width, "bottom": sill, "top": head, "door": false, "swing": 0.0,
		"pad": frame_pad})


## Register a world-space keep-out box.
func add_keep_out(world_box: AABB) -> void:
	keep_out.append(xform.affine_inverse() * world_box)


## Designer anchor: force `asset_id` (or a kit pick of `kind`) at a world transform (pivot).
func add_anchor(world_xform: Transform3D, asset_id: StringName = &"", kind: StringName = &"") -> void:
	anchors.append({"asset": asset_id, "kind": kind, "transform": xform.affine_inverse() * world_xform})
