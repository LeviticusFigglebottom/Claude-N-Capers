## D-116 long-dress drape check (headless, numeric): CPU-skins each character (Body + Outfit) through sampled frames
## of the knee-bend clips and counts the leg skin vertices that poke through the skirt. A leg vertex counts when the
## dress covers it at rest (a ray along its rest normal hits the Outfit, and it sits 5 cm or more above the skirt hem)
## and in the posed frame the same ray (along the skinned normal, 0.5 m) misses the posed Outfit: the leg is outside the
## cloth (a knee or shin through the skirt, a hole). Rays pointing down (normal.y < -0.6: the underside of a lifted
## thigh, which a real skirt shows too) are skipped. Also counts skirt triangles turned inside out (skinned normal
## against its rest normal carried by its dominant bone). Owner: ENV D. The static `measure` is reused by
## tests/d/test_skirt_drape.gd.
##   /opt/godot/godot --headless --path game --script res://world/characters/_tools/check_skirt_drape.gd --
##     --ids=gallery_patron_e,civilian_sales [--clips=walk,run,cower] [--samples=8]
extends SceneTree

const CLIPS: Array[String] = ["walk", "run", "flee", "flee_b", "crouch_walk", "cower", "cower_b", "cower_c",
	"sit_chair", "desk_work"]
const LEG_BONES: Array[String] = ["thigh.L", "thigh.R", "shin.L", "shin.R"]
## a leg vertex this far above the skirt hem (m, rest) or more is one the skirt must cover
const HEM_MARGIN: float = 0.05
const RAY: float = 0.5
## a covered leg vertex has the cloth over it within this distance at rest (not the far side of the skirt between the legs)
const REST_HIT: float = 0.12
const DOWN_SKIP: float = -0.6
## m: Outfit vertices below this are shoes, not a skirt hem
const SHOE_TOP: float = 0.2

var _ids: PackedStringArray = []
var _clips: PackedStringArray = []
var _samples: int = 8
var _verbose: bool = false


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "ids":
			_ids = kv[1].split(",")
		elif kv[0] == "clips":
			_clips = kv[1].split(",")
		elif kv[0] == "verbose":
			_verbose = true
		elif kv[0] == "samples":
			_samples = int(kv[1])
	if _clips.is_empty():
		_clips = PackedStringArray(CLIPS)
	_run.call_deferred()


func _run() -> void:
	for id: String in _ids:
		var rig: Node3D = (load("res://world/characters/%s/%s.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
		root.add_child(rig)
		var total: int = 0
		var line: PackedStringArray = []
		for clip: String in _clips:
			var times: Array[float] = []
			var ap: AnimationPlayer = rig.get_node("AnimationPlayer") as AnimationPlayer
			var name: String = "humanoid/" + clip if ap.has_animation("humanoid/" + clip) else clip
			if not ap.has_animation(name):
				line.append("%s=missing" % clip)
				continue
			var length: float = ap.get_animation(name).length
			for i: int in _samples:
				times.append(length * float(i) / float(_samples))
			var r: Dictionary = measure(rig, clip, times)
			total += int(r["poke"])
			line.append("%s=%d@%.2f(inv %d)" % [clip, r["poke"], r["time"], r["inv"]])
			if _verbose:
				line.append(str(r["where"]) + " inv " + str(r.get("inv_where", {})))
		print("DRAPE %s covered=%d total=%d | %s" % [id, _covered_count(rig), total, " ".join(line)])
		rig.free()
	quit()


static func _covered_count(rig: Node3D) -> int:
	return (_prep(rig)["legs"] as PackedInt32Array).size()


static func _mesh(rig: Node3D, n: String) -> MeshInstance3D:
	return rig.get_node_or_null("Skeleton3D/" + n) as MeshInstance3D


## Bind matrices of ``mi`` against the skeleton's current pose.
static func _mats(mi: MeshInstance3D, skel: Skeleton3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var skin: Skin = mi.skin
	for b: int in skin.get_bind_count():
		var bone: int = skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		out.append(skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	return out


## Skinned positions and normals of every surface of ``mi`` (concatenated): [positions, normals, dominant bind].
static func _skin(mi: MeshInstance3D, mats: Array[Transform3D]) -> Array:
	var ps: PackedVector3Array = []
	var ns: PackedVector3Array = []
	var dom: PackedInt32Array = []
	for s: int in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var per: int = bs.size() / vs.size()
		for i: int in vs.size():
			var p: Vector3 = Vector3.ZERO
			var n: Vector3 = Vector3.ZERO
			var best: int = 0
			var best_w: float = -1.0
			for j: int in per:
				var w: float = ws[i * per + j]
				if w > 0.0:
					var m: Transform3D = mats[bs[i * per + j]]
					p += (m * vs[i]) * w
					n += (m.basis * nn[i]) * w
					if w > best_w:
						best_w = w
						best = bs[i * per + j]
			ps.append(p)
			ns.append(n.normalized())
			dom.append(best)
	return [ps, ns, dom]


## Triangle soup of the skinned Outfit (surface by surface, the same order as ``_skin``).
static func _faces(mi: MeshInstance3D, ps: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = []
	var base: int = 0
	for s: int in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for i: int in idx:
			out.append(ps[base + i])
		base += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return out


## Rest data: the leg vertices the skirt covers, the skirt (Outfit triangles on the hips/legs) and their rest normals.
static func _prep(rig: Node3D) -> Dictionary:
	if rig.has_meta(&"drape_prep"):
		return rig.get_meta(&"drape_prep")
	var body: MeshInstance3D = _mesh(rig, "Body")
	var outfit: MeshInstance3D = _mesh(rig, "Outfit")
	var ident: Array[Transform3D] = []
	for b: int in maxi(body.skin.get_bind_count(), outfit.skin.get_bind_count()):
		ident.append(Transform3D.IDENTITY)
	var bsk: Array = _skin(body, ident)
	var osk: Array = _skin(outfit, ident)
	var ops: PackedVector3Array = osk[0]
	var odom: PackedInt32Array = osk[2]
	var leg_binds: Dictionary = {}
	for b: int in body.skin.get_bind_count():
		if String(body.skin.get_bind_name(b)) in LEG_BONES:
			leg_binds[b] = true
	var skirt_binds: Dictionary = {}
	for b: int in outfit.skin.get_bind_count():
		var bn: String = String(outfit.skin.get_bind_name(b))
		if bn in LEG_BONES or bn == "hips":
			skirt_binds[b] = true
	# the skirt hem: the lowest Outfit vertex on the hips/thighs/shins above the shoes (a shoe collar can ride the shin)
	var hem: float = INF
	for i: int in ops.size():
		if skirt_binds.has(odom[i]) and ops[i].y > SHOE_TOP:
			hem = minf(hem, ops[i].y)
	var tm: TriangleMesh = TriangleMesh.new()
	tm.create_from_faces(_faces(outfit, ops))
	var legs: PackedInt32Array = []
	var bone_of: Dictionary = {}
	var face_of: Dictionary = {}
	var bps: PackedVector3Array = bsk[0]
	var bns: PackedVector3Array = bsk[1]
	var bdom: PackedInt32Array = bsk[2]
	for i: int in bps.size():
		if not leg_binds.has(bdom[i]) or bps[i].y < hem + HEM_MARGIN or bns[i].y < DOWN_SKIP:
			continue
		var hit: Dictionary = tm.intersect_segment(bps[i] + bns[i] * 0.002, bps[i] + bns[i] * RAY)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(bps[i]) < REST_HIT:
			legs.append(i)
			bone_of[i] = String(body.skin.get_bind_name(bdom[i])).get_slice(".", 0)
			face_of[i] = "front" if bns[i].z < -0.4 else ("back" if bns[i].z > 0.4 else "side")
	# skirt triangles (all three corners on hips/legs, below the hips joint) with their rest normals
	var tris: PackedInt32Array = []
	var rest_n: PackedVector3Array = []
	var base: int = 0
	var hips_y: float = rig.get_node("Skeleton3D").get_bone_global_rest(
		(rig.get_node("Skeleton3D") as Skeleton3D).find_bone("hips")).origin.y
	for s: int in outfit.mesh.get_surface_count():
		var a: Array = outfit.mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for t: int in idx.size() / 3:
			var c: Array[int] = [base + idx[t * 3], base + idx[t * 3 + 1], base + idx[t * 3 + 2]]
			var ok: bool = true
			for v: int in c:
				if not skirt_binds.has(odom[v]) or ops[v].y > hips_y:
					ok = false
			if not ok:
				continue
			var n: Vector3 = (ops[c[1]] - ops[c[0]]).cross(ops[c[2]] - ops[c[0]])
			if n.length() < 1e-9:
				continue
			tris.append_array(PackedInt32Array(c))
			rest_n.append(n.normalized())
		base += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var out: Dictionary = {"legs": legs, "bone": bone_of, "face": face_of, "hem": hem, "tris": tris, "rest_n": rest_n}
	rig.set_meta(&"drape_prep", out)
	return out


## Poses ``rig`` (a character scene instance in the tree) at each time of ``clip`` and returns
## {"poke": worst count of leg vertices through the skirt, "time": its time, "inv": worst inverted skirt triangles,
## "covered": leg vertices the skirt covers at rest}.
static func measure(rig: Node3D, clip: String, times: Array[float]) -> Dictionary:
	var prep: Dictionary = _prep(rig)
	var legs: PackedInt32Array = prep["legs"]
	var tris: PackedInt32Array = prep["tris"]
	var rest_n: PackedVector3Array = prep["rest_n"]
	var ap: AnimationPlayer = rig.get_node("AnimationPlayer") as AnimationPlayer
	var skel: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
	var body: MeshInstance3D = _mesh(rig, "Body")
	var outfit: MeshInstance3D = _mesh(rig, "Outfit")
	var name: String = "humanoid/" + clip if ap.has_animation("humanoid/" + clip) else clip
	ap.play(name)
	var out: Dictionary = {"poke": 0, "time": 0.0, "inv": 0, "covered": legs.size(), "where": {}}
	for t: float in times:
		ap.seek(t, true)
		skel.force_update_all_bone_transforms()
		var bsk: Array = _skin(body, _mats(body, skel))
		var osk: Array = _skin(outfit, _mats(outfit, skel))
		var ops: PackedVector3Array = osk[0]
		var tm: TriangleMesh = TriangleMesh.new()
		tm.create_from_faces(_faces(outfit, ops))
		var bps: PackedVector3Array = bsk[0]
		var bns: PackedVector3Array = bsk[1]
		var poke: int = 0
		var where: Dictionary = {}
		for i: int in legs:
			if bns[i].y < DOWN_SKIP:
				continue
			if tm.intersect_segment(bps[i] + bns[i] * 0.002, bps[i] + bns[i] * RAY).is_empty():
				poke += 1
				var key: String = "%s_%s@%.2f" % [prep["bone"][i], prep["face"][i], snappedf(bps[i].y, 0.05)]
				where[key] = int(where.get(key, 0)) + 1
		var inv: int = 0
		var inv_where: Dictionary = {}
		var odom: PackedInt32Array = osk[2]
		for k: int in tris.size() / 3:
			var a: Vector3 = ops[tris[k * 3]]
			var n: Vector3 = (ops[tris[k * 3 + 1]] - a).cross(ops[tris[k * 3 + 2]] - a)
			var ns: PackedVector3Array = osk[1]
			# Godot winds front faces clockwise: the cross product points inside on a face that is not folded over
			if n.dot(ns[tris[k * 3]] + ns[tris[k * 3 + 1]] + ns[tris[k * 3 + 2]]) > 0.0:
				inv += 1
				var side: String = "front" if rest_n[k].z < -0.4 else ("back" if rest_n[k].z > 0.4 else "side")
				var ikey: String = "%s@%.1f" % [side, snappedf(ops[tris[k * 3]].y, 0.1)]
				inv_where[ikey] = int(inv_where.get(ikey, 0)) + 1
		if poke > int(out["poke"]):
			out["poke"] = poke
			out["time"] = t
			out["where"] = where
		if inv > int(out["inv"]):
			out["inv"] = inv
			out["inv_where"] = inv_where
	return out
