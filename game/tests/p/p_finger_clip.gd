## PO-13 / D-111 support-hand review: how far the first-person LEFT hand's finger skin goes INTO the equipped gun,
## measured in the real game pose (FpViewmodel with the left-hand IK and HandRestore applied: sampled inside
## Skeleton3D.skeleton_updated, the only moment modifier results are in the pose). The Arms mesh is skinned on the
## CPU (bone global pose x bind pose, up to 8 weights); every vertex whose strongest bone is a left finger / thumb
## bone is tested against the gun's triangles near the hand: the nearest face's side gives "inside" candidates,
## confirmed by ray parity along three axes (majority), depth = distance to the nearest face (so at most half the
## part's thickness: "inside" counts are the measure, depth only says how far past the skin). Owner: ENV P.
class_name PFingerClip
extends RefCounted

const FINGERS: PackedStringArray = ["thumb", "index", "middle", "ring", "pinky"]
## Gun triangles farther than this from the hand's vertex box are ignored by the nearest-face search (m).
const NEAR_PAD_M: float = 0.03


## {finger: {"verts": n, "inside": n, "max_mm": f}, "_total": {...}, "_ok": bool} for the current pose of `fp`
## holding `gun` (the WeaponVisual root). Call while the scene runs (it awaits one skeleton update).
static func measure(fp: FpViewmodel, gun: Node3D) -> Dictionary:
	var sk: Skeleton3D = fp.skeleton
	var arms: MeshInstance3D = sk.get_node_or_null(^"Arms") as MeshInstance3D if sk != null else null
	if arms == null or arms.skin == null or gun == null:
		return {"_ok": false}
	var got: Array[Dictionary] = [{}]
	var cb: Callable = func() -> void:
		if got[0].is_empty():
			got[0] = _measure_now(sk, arms, gun)
	sk.skeleton_updated.connect(cb)
	for _i: int in 4:
		if not got[0].is_empty():
			break
		await sk.get_tree().process_frame
	sk.skeleton_updated.disconnect(cb)
	return got[0] if not got[0].is_empty() else {"_ok": false}


static func _finger_of(bone_name: String) -> String:
	if not bone_name.ends_with(".L"):
		return ""
	for f: String in FINGERS:
		if bone_name.begins_with(f):
			return f
	return ""


static func _measure_now(sk: Skeleton3D, arms: MeshInstance3D, gun: Node3D) -> Dictionary:
	var skin: Skin = arms.skin
	var bind_mats: Array[Transform3D] = []
	var bind_finger: PackedStringArray = []
	var bind_origin: PackedVector3Array = []
	for i: int in skin.get_bind_count():
		var b: int = skin.get_bind_bone(i)
		if b < 0:
			b = sk.find_bone(skin.get_bind_name(i))
		bind_mats.append(sk.global_transform * sk.get_bone_global_pose(b) * skin.get_bind_pose(i) if b >= 0
			else Transform3D.IDENTITY)
		bind_finger.append(_finger_of(sk.get_bone_name(b)) if b >= 0 else "")
		bind_origin.append(sk.global_transform * sk.get_bone_global_pose(b).origin if b >= 0 else Vector3.ZERO)
	var pts: PackedVector3Array = []
	var pt_finger: PackedStringArray = []
	var bone_d: float = 0.0
	for s: int in arms.mesh.get_surface_count():
		var arr: Array = arms.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		if verts.is_empty() or bones.is_empty():
			continue
		var k: int = bones.size() / verts.size()
		for v: int in verts.size():
			var best: int = -1
			var best_w: float = 0.0
			for j: int in k:
				if weights[v * k + j] > best_w:
					best_w = weights[v * k + j]
					best = bones[v * k + j]
			if best < 0 or bind_finger[best] == "":
				continue
			var p: Vector3 = Vector3.ZERO
			var wsum: float = 0.0
			for j: int in k:
				var w: float = weights[v * k + j]
				if w > 0.0:
					p += (bind_mats[bones[v * k + j]] * verts[v]) * w
					wsum += w
			pts.append(p / maxf(wsum, 1e-6))
			bone_d += pts[pts.size() - 1].distance_to(bind_origin[best])
			pt_finger.append(bind_finger[best])
	var box: AABB = AABB(pts[0], Vector3.ZERO) if not pts.is_empty() else AABB()
	for p: Vector3 in pts:
		box = box.expand(p)
	var all_tris: PackedVector3Array = _gun_triangles(gun)
	var near: PackedVector3Array = []
	var grown: AABB = box.grow(NEAR_PAD_M)
	for t: int in range(0, all_tris.size(), 3):
		var tb: AABB = AABB(all_tris[t], Vector3.ZERO).expand(all_tris[t + 1]).expand(all_tris[t + 2])
		if tb.intersects(grown):
			near.append_array([all_tris[t], all_tris[t + 1], all_tris[t + 2]])
	var out: Dictionary = {}
	for f: String in FINGERS:
		out[f] = {"verts": 0, "inside": 0, "max_mm": 0.0}
	for i: int in pts.size():
		var e: Dictionary = out[pt_finger[i]]
		e["verts"] = int(e["verts"]) + 1
		var hit: Array = _nearest(pts[i], near)
		if hit.is_empty() or float(hit[1]) >= 0.0:
			continue  # outside the nearest face (or no gun near)
		if not _inside_parity(pts[i], all_tris):
			continue
		e["inside"] = int(e["inside"]) + 1
		e["max_mm"] = maxf(float(e["max_mm"]), float(hit[0]) * 1000.0)
	var tot: Dictionary = {"verts": pts.size(), "inside": 0, "max_mm": 0.0}
	for f: String in FINGERS:
		tot["inside"] = int(tot["inside"]) + int(out[f]["inside"])
		tot["max_mm"] = maxf(float(tot["max_mm"]), float(out[f]["max_mm"]))
	out["_total"] = tot
	out["_ok"] = not pts.is_empty() and not all_tris.is_empty()
	out["_gun_tris"] = all_tris.size() / 3
	out["_mean_bone_m"] = bone_d / maxf(float(pts.size()), 1.0)  # sanity: skin sits around its bones
	return out


## World-space triangles of every visible mesh of the gun.
static func _gun_triangles(gun: Node3D) -> PackedVector3Array:
	var out: PackedVector3Array = []
	var meshes: Array[Node] = gun.find_children("*", "MeshInstance3D", true, false)
	if gun is MeshInstance3D:
		meshes.append(gun)
	for n: Node in meshes:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf: Transform3D = mi.global_transform
		for s: int in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for i: int in v.size():
					out.append(xf * v[i])
			else:
				for i: int in idx:
					out.append(xf * v[i])
	return out


## [distance, signed side] of the nearest triangle (side < 0 = behind its face normal); [] without triangles.
static func _nearest(p: Vector3, tris: PackedVector3Array) -> Array:
	var best_d: float = INF
	var best_side: float = 0.0
	for t: int in range(0, tris.size(), 3):
		var a: Vector3 = tris[t]
		var b: Vector3 = tris[t + 1]
		var c: Vector3 = tris[t + 2]
		var q: Vector3 = _closest_on_tri(p, a, b, c)
		var d: float = p.distance_to(q)
		if d < best_d:
			var n: Vector3 = (c - a).cross(b - a)  # Godot front faces wind clockwise: this is the outward normal
			if n.length_squared() < 1e-14:
				continue
			best_d = d
			best_side = (p - q).dot(n.normalized()) if d > 1e-6 else 0.0
	return [] if best_d == INF else [best_d, best_side]


## Ray parity along +X, +Y, +Z: inside when at least two rays cross the surface an odd number of times.
static func _inside_parity(p: Vector3, tris: PackedVector3Array) -> bool:
	var odd: int = 0
	for dir: Vector3 in [Vector3(1, 0.0013, 0.0007), Vector3(0.0011, 1, 0.0009), Vector3(0.0008, 0.0012, 1)]:
		var hits: int = 0
		for t: int in range(0, tris.size(), 3):
			if Geometry3D.ray_intersects_triangle(p, dir, tris[t], tris[t + 1], tris[t + 2]) != null:
				hits += 1
		if hits % 2 == 1:
			odd += 1
	return odd >= 2


static func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	# Ericson, Real-Time Collision Detection 5.1.5
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = p - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = p - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp: Vector3 = p - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom: float = 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
