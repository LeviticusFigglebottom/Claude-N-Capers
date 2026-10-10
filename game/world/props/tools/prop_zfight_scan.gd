## Scans every prop catalog scene for internal z-fighting (same rule as levelcheck `zfight`:
## coplanar < 2 mm, same-facing, different materials, overlap > 4 cm²). Run:
##   /opt/godot/godot --headless --path game --script res://world/props/tools/prop_zfight_scan.gd [-- --only=id,id]
extends SceneTree

const PLANE_EPS: float = 0.002
const MIN_AREA: float = 0.0004


func _init() -> void:
	var only: PackedStringArray = PackedStringArray()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",", false)
	var catalog: Dictionary = PropCatalog.load_catalog()
	var ids: Array = catalog.keys()
	ids.sort()
	var total: int = 0
	for id: Variant in ids:
		if not only.is_empty() and not (String(id) in only):
			continue
		var n: Node3D = (load(String((catalog[id] as Dictionary)["scene"])) as PackedScene).instantiate() as Node3D
		var hits: PackedStringArray = _scan(n)
		total += hits.size()
		for h: String in hits:
			print("%s: %s" % [id, h])
		n.free()
	print("zfight_scan: %d pair(s)" % total)
	quit(0 if total == 0 else 1)


func _xf(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p is Node3D and p.get_parent() != null:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _scan(root: Node3D) -> PackedStringArray:
	var tris: Array = []
	for c: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		var xf: Transform3D = _xf(mi)
		for s: int in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_active_material(s)
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for i: int in range(0, idx.size(), 3):
				var a: Vector3 = xf * v[idx[i]]
				var b: Vector3 = xf * v[idx[i + 1]]
				var cc: Vector3 = xf * v[idx[i + 2]]
				var cr: Vector3 = (b - a).cross(cc - a)
				if cr.length() < 1e-7:
					continue
				var nn: Vector3 = cr.normalized()
				tris.append([a, b, cc, nn, mat.resource_path.get_file() if mat else "null", "%s/%d" % [mi.name, s]])
	var bins: Dictionary = {}
	for i: int in range(tris.size()):
		var t: Array = tris[i]
		var nn2: Vector3 = t[3]
		var key: String = "%d,%d,%d" % [roundi(nn2.x * 40.0), roundi(nn2.y * 40.0), roundi(nn2.z * 40.0)]
		if not bins.has(key):
			bins[key] = []
		(bins[key] as Array).append(i)
	var out: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for key2: Variant in bins.keys():
		var l: Array = bins[key2]
		for x: int in range(l.size()):
			var t1: Array = tris[l[x]]
			for y: int in range(x + 1, l.size()):
				var t2: Array = tris[l[y]]
				if t1[4] == t2[4]:
					continue
				if (t1[3] as Vector3).dot(t2[3]) < 0.999:
					continue
				if absf((t1[3] as Vector3).dot((t2[0] as Vector3) - (t1[0] as Vector3))) >= PLANE_EPS:
					continue
				var area: float = _overlap(t1, t2)
				if area > MIN_AREA:
					var k: String = "%s|%s" % [t1[5], t2[5]]
					if seen.has(k):
						continue
					seen[k] = true
					var cen: Vector3 = ((t1[0] as Vector3) + (t1[1] as Vector3) + (t1[2] as Vector3)) / 3.0
					out.append("%s(%s) vs %s(%s) at %s n=%s area %.4f" % [t1[5], t1[4], t2[5], t2[4], cen, t1[3], area])
	return out


func _overlap(t1: Array, t2: Array) -> float:
	var n: Vector3 = t1[3]
	var u: Vector3 = (Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).cross(n).normalized()
	var w: Vector3 = n.cross(u)
	var p1: PackedVector2Array = PackedVector2Array()
	var p2: PackedVector2Array = PackedVector2Array()
	for k: int in range(3):
		p1.append(Vector2((t1[k] as Vector3).dot(u), (t1[k] as Vector3).dot(w)))
		p2.append(Vector2((t2[k] as Vector3).dot(u), (t2[k] as Vector3).dot(w)))
	return LcGeom.tri_overlap_area_2d(p1, p2)
