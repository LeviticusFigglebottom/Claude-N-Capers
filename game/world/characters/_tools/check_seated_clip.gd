## D-130 seated clip check (headless, numeric): CPU-skins each character through a seated clip (every 0.5 s) on the
## catalog npc office chair (prop_chair_office: cushion 0.38-0.45 m, backrest slab 0.24-0.30 m behind the pivot) with a
## desk ahead, the root on the floor under the chair pivot as sl_gameplay.npc_seat places it, and reports the skinned
## vertices inside the seat cushion, the backrest slab and the desk-top slab ([count, worst time s, depth m]) per
## mesh:material, plus back_max_z (the furthest-back torso vertex, 0.6-1.0 m up). Setups: the characters.md contract
## desk (near edge 0.22 m), SL K4 desk A and K8 pod A as built, and the chair set back 0.10 / 0.12 m (a Seat marker
## that far in front of the pivot). Owner: ENV D.
##   /opt/godot/godot --headless --path game --script res://world/characters/_tools/check_seated_clip.gd --
##     --ids=npc_km_assistant,npc_km_associate [--clip=desk_work]
extends SceneTree

const CHAIR: String = "res://world/props/office/prop_chair_office.tscn"
## [label, scene, offset in the rig's space, yaw deg]
const SETUPS: Array = [
	["contract_desk_0.22", "res://world/props/office/prop_desk_office.tscn", Vector3(0, 0, -0.57), 0.0],
	["sl_k4_desk_a", "res://world/props/office/prop_desk_office.tscn", Vector3(0, 0, -0.8), 180.0],
	["sl_k8_pod_a_s1", "res://world/props/calder/prop_workstation_pod.tscn", Vector3(0.6, 0, -1.25), 0.0],
	["k4_seat_fwd_0.10", "res://world/props/office/prop_desk_office.tscn", Vector3(0, 0, -0.7), 180.0, 0.10],
	["k8_seat_fwd_0.10", "res://world/props/calder/prop_workstation_pod.tscn", Vector3(0.6, 0, -1.15), 0.0, 0.10],
	["k4_seat_fwd_0.12", "res://world/props/office/prop_desk_office.tscn", Vector3(0, 0, -0.68), 180.0, 0.12],
]

var _ids: PackedStringArray = ["npc_km_assistant", "npc_km_associate"]
var _clip: String = "desk_work"
var _seat: AABB
var _top: AABB
var _back: AABB


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "ids":
			_ids = kv[1].split(",")
		elif kv[0] == "clip":
			_clip = kv[1]
	_run.call_deferred()


func _solid(scene: String, off: Vector3, yaw: float) -> Node3D:
	var n: Node3D = (load(scene) as PackedScene).instantiate() as Node3D
	root.add_child(n)
	n.position = off
	n.rotation.y = deg_to_rad(yaw)
	return n


## World AABB of a prop's mesh vertices with y in [y0, y1] (the seat cushion / desk-top slab).
func _slab(n: Node3D, y0: float, y1: float, z_min: float = -INF) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s: int in m.mesh.get_surface_count():
			for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				var w: Vector3 = m.global_transform * v
				if w.y < y0 - 0.002 or w.y > y1 + 0.002 or w.z - n.position.z < z_min:
					continue
				if first:
					box = AABB(w, Vector3.ZERO)
					first = false
				else:
					box = box.expand(w)
	return box


func _run() -> void:
	for setup: Array in SETUPS:
		var chair: Node3D = _solid(CHAIR, Vector3(0, 0, float(setup[4]) if setup.size() > 4 else 0.0), 0.0)
		var desk: Node3D = _solid(String(setup[1]), setup[2], float(setup[3]))
		_seat = _slab(chair, 0.37, 0.455)
		_top = _slab(desk, 0.70, 0.745)
		_back = _slab(chair, 0.56, 1.01, 0.18)
		print("SLABS seat %s back %s top %s" % [_seat, _back, _top])
		for id: String in _ids:
			var rig: Node3D = (load("res://world/characters/%s/%s.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
			root.add_child(rig)
			var ap: AnimationPlayer = rig.get_node("AnimationPlayer") as AnimationPlayer
			var skel: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
			var clip: String = "humanoid/" + _clip if ap.has_animation("humanoid/" + _clip) else _clip
			ap.play(clip)
			var length: float = ap.get_animation(clip).length
			var worst: Dictionary = {}
			var t: float = 0.0
			while t < length:
				ap.seek(t, true)
				skel.force_update_all_bone_transforms()
				for mi: Node in skel.get_children():
					if not mi is MeshInstance3D:
						continue
					var hits: Dictionary = _inside(mi as MeshInstance3D, skel)
					for k: String in hits:
						var key: String = "%s/%s" % [mi.name, k]
						var prev: Array = worst.get(key, [0, 0.0, 0.0])
						if int(hits[k][0]) > int(prev[0]):
							worst[key] = [hits[k][0], t, hits[k][1]]
				t += 0.5
			print("CLIP %s %s %s: %s" % [setup[0], id, _clip, worst if not worst.is_empty() else "clear"])
			rig.free()
		chair.free()
		desk.free()
	quit()


## {"<slab>:<material>": [count, max depth (m)], "back_max_z": [1, z]} of the mesh's skinned vertices.
func _inside(mi: MeshInstance3D, skel: Skeleton3D) -> Dictionary:
	var out: Dictionary = {}
	var skin: Skin = mi.skin
	var mats: Array[Transform3D] = []
	for b: int in skin.get_bind_count():
		var bone: int = skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		mats.append(skel.global_transform * skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	for s: int in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var per: int = bs.size() / vs.size()
		for i: int in vs.size():
			var p: Vector3 = Vector3.ZERO
			for j: int in per:
				var w: float = ws[i * per + j]
				if w > 0.0:
					p += (mats[bs[i * per + j]] * vs[i]) * w
			if p.y > 0.6 and p.y < 1.0 and absf(p.x) < 0.23 and p.z > float(out.get("back_max_z", [0, -1.0])[1]):
				out["back_max_z"] = [1, p.z]
			var which: String = ""
			var depth: float = 0.0
			if _back.has_point(p):
				which = "backrest"
				depth = p.z - _back.position.z
			elif _seat.grow(-0.01).has_point(p):
				which = "seat"
				depth = _seat.end.y - p.y
			elif _top.has_point(p):
				which = "desk_top"
				depth = _top.end.y - p.y
			if which.is_empty():
				continue
			var mat: Material = mi.get_active_material(s)
			var tag: String = which + ":" + (mat.resource_path.get_file().get_basename() if mat != null else "?")
			var cur: Array = out.get(tag, [0, 0.0])
			out[tag] = [int(cur[0]) + 1, maxf(float(cur[1]), depth)]
	return out
