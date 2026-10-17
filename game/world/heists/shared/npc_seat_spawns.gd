## D-130 (ENV D check_seated_clip): a seated NPC spawns on its chair's `Seat`, not on the chair's pivot. The office
## and task chairs' wrappers (prop_chair_office / prop_chair_task, tools/blender/props `seat_fwd`) put their Seat
## 0.12 m toward the front (-Z), so a desk_work torso (its back ~0.33 m behind the root) clears the backrest
## (+0.24..0.30); 0.10 still clips. One rule for every map: after the dressing (the kits' keep-outs saw the spawn
## where it was, so no furniture moves), each SpawnPoint with an idle activity standing on the pivot of a chair whose
## Seat is off its pivot moves onto that Seat (xz; its height and facing kept). The chair stays where it is.
## Used by the Glasshouse, Night Deposit, Gallery Night and Shadow Ledger dressings. Owner: ENV C.
extends RefCounted

## A spawn this close (xz, m) to a chair's pivot is that chair's sitter.
const ON_PIVOT_M: float = 0.05
## A Seat this far (xz, m) off its chair's pivot is a moved seat (the catalog `seat`).
const MOVED_M: float = 0.01
## Same floor: spawn and chair base within this height (m).
const FLOOR_DY: float = 0.3
## Chair kinds the rule covers (prop roots' / greybox chairs' `kind` meta).
const KINDS: Array[String] = ["chair"]


## Moves the seated spawns under `root` onto their chairs' Seats; returns one "name: old -> new" line per move.
static func snap(root: Node3D) -> PackedStringArray:
	var chairs: Array[Array] = []  # [pivot (global), seat (global)]
	var spawns: Array[SpawnPoint] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		var sp: SpawnPoint = nd as SpawnPoint
		if sp != null and sp.idle_activity != &"":
			spawns.append(sp)
		elif nd is Node3D and KINDS.has(String(nd.get_meta(&"kind", ""))):
			var seat: Node3D = nd.find_child("Seat", true, false) as Node3D
			if seat != null:
				var pv: Vector3 = _gx(root, nd as Node3D).origin
				var st: Vector3 = _gx(root, seat).origin
				if Vector2(st.x - pv.x, st.z - pv.z).length() > MOVED_M:
					chairs.append([pv, st])
		for c: Node in nd.get_children():
			stack.append(c)
	var out: PackedStringArray = []
	for sp2: SpawnPoint in spawns:
		var at: Vector3 = _gx(root, sp2).origin
		for ch: Array in chairs:
			var pv2: Vector3 = ch[0]
			if absf(pv2.y - at.y) > FLOOR_DY or Vector2(pv2.x - at.x, pv2.z - at.z).length() > ON_PIVOT_M:
				continue
			var st2: Vector3 = ch[1]
			var to: Vector3 = Vector3(st2.x, at.y, st2.z)
			var parent_xf: Transform3D = _gx(root, sp2.get_parent() as Node3D) if sp2.get_parent() is Node3D else Transform3D.IDENTITY
			sp2.position = parent_xf.affine_inverse() * to
			out.append("%s: (%.3f, %.3f, %.3f) -> (%.3f, %.3f, %.3f)" % [sp2.name, at.x, at.y, at.z, to.x, to.y, to.z])
			break
	return out


## `n`'s transform in `root`'s space (the builders' maps are not in the tree).
static func _gx(root: Node3D, n: Node3D) -> Transform3D:
	if n == root:
		return Transform3D.IDENTITY
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
