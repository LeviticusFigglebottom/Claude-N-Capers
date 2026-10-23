## Door throats in a generator's nav bake (OF-C2 / LEAD round 252; ENV P ghost run 250: the pilot pinned on a jamb).
## The nav agent is 0.3 m (heist_map.md §3) but the crew capsule is 0.35 m (crew_member.tscn), and the wall cut a bake
## sees is wider than the door frame (clear half width = half the Door's effective_width()) and often off its centre,
## so a path on the throat edge puts the capsule on a jamb. For every Door under the map root this adds two carved
## (exact, not grown by the agent radius) boxes over the jambs, as deep as the frame plus the capsule, which leave a
## straight throat at the frame centre +- `half`: on the 0.1 m cell grid like the door centres so it rasterizes exactly,
## a cell narrower on wide throats for the contour simplification, and at least a cell (0.9 m singles keep a 0.2 m
## throat; there the capsule just touches at its edges). Off the throat the wall's own agent-radius margin is only
## 5-10 cm narrower, so corridors past doors keep their width. Bake only: the colliders keep their real size. Same
## numbers as ostrander_federal/greybox/of_gameplay.gd _jamb_clearance. Test: game/tests/c/test_door_clearance_maps.gd.
## Owner: ENV C.
extends RefCounted

const CREW_R: float = 0.35
const CREW_CLEAR: float = 0.05
const NAV_CELL: float = 0.1
const FRAME_D: float = 0.1
const BOX_LO: float = -0.2
const BOX_H: float = 2.6
## The bake's contour simplification tolerance (cells; Godot's default 1.3 erases a one-cell jamb notch where the
## throat edge lines up with a corridor wall beyond the door).
const EDGE_MAX_ERROR: float = 0.9


## Adds the jamb boxes of every Door under `root` (in the tree or not) to `src`, and sets `nm`'s contour tolerance to
## EDGE_MAX_ERROR (call it before bake_from_source_geometry_data). Returns how many doors it covered.
static func add(src: NavigationMeshSourceGeometryData3D, root: Node3D, nm: NavigationMesh) -> int:
	nm.edge_max_error = EDGE_MAX_ERROR
	var n_doors: int = 0
	for n: Node in root.find_children("*", "Door", true, false):
		var d: Node3D = n as Node3D
		var width: float = float(d.call(&"effective_width")) if d.has_method(&"effective_width") else 0.0
		if width <= 0.0:
			continue
		var xf: Transform3D = _xform(d, root)
		var fd: float = frame_half_depth(d)
		for box: AABB in jamb_boxes(width, _grid_shift(xf, -1.0, width), _grid_shift(xf, 1.0, width), fd):
			var pts: PackedVector3Array = PackedVector3Array()
			for c: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
				pts.append(xf * (box.position + box.size * c))
			src.add_projected_obstruction(pts, xf.origin.y + box.position.y, box.size.y, true)
		n_doors += 1
	return n_doors


## The two door-local jamb boxes for a leaf `width` (x across the opening, z across the wall); `shift_lo` / `shift_hi`
## move the -x / +x throat edge toward the centre (>= 0, see _grid_shift).
static func jamb_boxes(width: float, shift_lo: float = 0.0, shift_hi: float = 0.0, frame_d: float = FRAME_D) -> Array[AABB]:
	var w2: float = width * 0.5
	var half: float = throat_half(width)
	var depth: float = ceilf((maxf(frame_d, FRAME_D) + CREW_R) / NAV_CELL - 0.001) * NAV_CELL
	var hi: float = half - shift_hi
	var lo: float = half - shift_lo
	var reach_hi: float = w2 + CREW_R + NAV_CELL - hi   # over the jamb into the wall's own margin
	var reach_lo: float = w2 + CREW_R + NAV_CELL - lo
	return [AABB(Vector3(hi, BOX_LO, -depth), Vector3(reach_hi, BOX_H, depth * 2.0)),
		AABB(Vector3(-lo - reach_lo, BOX_LO, -depth), Vector3(reach_lo, BOX_H, depth * 2.0))]


## Half the depth of the door's frame (its visual's `Collision` bodies across the wall, door-local z), at least
## FRAME_D: a 0.4 m frame (t40, AH's hall doors in 0.4 m walls) needs a deeper throat than the 0.1 m default, or a
## path turning past the jamb's far edge puts the capsule on the frame (P r305: HallDoorsE).
static func frame_half_depth(door: Node3D) -> float:
	var out: float = _collision_half_depth(door, door)
	var vs: PackedScene = door.get(&"visual_scene") as PackedScene
	if vs != null:   # a generator bakes before the prefab instances its visual: read the visual scene itself
		var v: Node3D = vs.instantiate() as Node3D
		if v != null:
			out = maxf(out, _collision_half_depth(v, v))
			v.free()
	return out


static func _collision_half_depth(root_n: Node, top: Node) -> float:
	var out: float = FRAME_D
	for body: Node in root_n.find_children("Collision", "StaticBody3D", true, false):
		for c: Node in body.find_children("*", "CollisionShape3D", true, false):
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs.shape == null:
				continue
			var t: Transform3D = Transform3D.IDENTITY
			var n: Node = cs
			while n != null and n != top:
				if n is Node3D:
					t = (n as Node3D).transform * t
				n = n.get_parent()
			var bb: AABB = t * cs.shape.get_debug_mesh().get_aabb()
			out = maxf(out, maxf(absf(bb.position.z), absf(bb.end.z)))
	return out


## The nominal throat half width for a leaf `width`.
static func throat_half(width: float) -> float:
	return maxf(NAV_CELL, floorf((width * 0.5 - CREW_R - CREW_CLEAR - NAV_CELL) / NAV_CELL + 0.001) * NAV_CELL)


## How far the throat edge on `side` (-1 / +1 along the door's x) must move toward the centre to sit on the world cell
## grid (a door centre off the 0.1 m grid would otherwise rasterize the throat a cell wider on one side). 0 for a door
## whose x axis is not along world x or z.
static func _grid_shift(xf: Transform3D, side: float, width: float) -> float:
	var ax: Vector3 = xf.basis.x.normalized()
	var k: int = 0 if absf(ax.x) > 0.999 else (2 if absf(ax.z) > 0.999 else -1)
	if k < 0:
		return 0.0
	var edge: float = (xf * Vector3(side * throat_half(width), 0.0, 0.0))[k]
	var toward: float = -signf(ax[k] * side)   # world direction from the edge toward the centre
	var snapped: float = (ceilf(edge / NAV_CELL - 0.001) if toward > 0.0 else floorf(edge / NAV_CELL + 0.001)) * NAV_CELL
	return absf(snapped - edge)


static func _xform(n: Node3D, root: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return root.transform * t if c == root else t
