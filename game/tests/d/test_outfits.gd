## D1-02: outfit characters (tools/blender/characters/char_*.py). Run after `godot --import`.
## OF-D1: the Ostrander Federal officers c-d and customers c-j are checked here too.
## D-145.3 (PO-18): the Routine/Tense police duty looks show no body armour: no stab vest / plate carrier standing off
## the chest (the front of the torso sits clearly closer than on the armoured base look) and no ballistic helmet
## (Patrol, TAC Light, Stinger; the Bulwark keeps its riot helmet and shield), and the faction TAC Light duty looks
## (frd / sentinel / zero) against their armoured faction looks: no helmet, no Zero skull mask.
## Each character glb has the shared 52-bone rig_humanoid Skeleton3D (top-level, D-067b), only skinned meshes
## (Body, Hair, Outfit, Gear, Headwear) with no blend shapes (bodies are baked), every surface
## mapped to a library material res://world/materials/*.tres, and a plausible standing height.
extends TestCase

const CHARACTERS: Array[String] = [
	"char_security_officer",
	"char_security_officer_b",
	"char_security_officer_c",
	"char_security_officer_d",
	"char_security_officer_e",
	"char_security_officer_f",
	"char_security_officer_g",
	"char_security_officer_h",
	"char_security_officer_i",
	"char_security_officer_j",
	"char_security_bodyguard",
	"char_civilian_customer_a",
	"char_civilian_customer_b",
	"char_bank_officer_c",
	"char_bank_officer_d",
	"char_bank_customer_c",
	"char_bank_customer_d",
	"char_bank_customer_e",
	"char_bank_customer_f",
	"char_bank_customer_g",
	"char_bank_customer_h",
	"char_bank_customer_i",
	"char_bank_customer_j",
	"char_civilian_sales",
	"char_civilian_jeweler",
	"char_civilian_manager",
	"char_patrol_officer",
	"char_tac_light",
	"char_patrol_officer_duty",
	"char_tac_light_duty",
	"char_stinger_duty",
	"char_bulwark_duty",
	"char_tac_light_frd_duty",
	"char_tac_light_sentinel_duty",
	"char_tac_light_zero_duty",
	"char_crew_body",
	"char_crew_body_b",
]
const BONES: int = 52
const MIN_HEIGHT: float = 1.6
const MAX_HEIGHT: float = 2.0
const TRI_BUDGET: int = 35000
const ALLOWED_MESHES: Array[String] = ["Body", "Hair", "Outfit", "Gear", "Headwear"]
## D-145.3: duty look -> its armoured base look; the duty chest must sit at least ARMOUR_GAP closer (m)
const DUTY_LOOKS: Dictionary = {
	"char_patrol_officer_duty": "char_patrol_officer", "char_tac_light_duty": "char_tac_light",
	"char_stinger_duty": "char_stinger", "char_bulwark_duty": "char_bulwark",
	# the faction TAC Lights (ENV A's frd / sentinel / zero EnemyDefs) against their armoured faction look
	"char_tac_light_frd_duty": "char_tac_light_frd", "char_tac_light_sentinel_duty": "char_tac_light_sentinel",
	"char_tac_light_zero_duty": "char_tac_light_zero",
}
const ARMOUR_GAP: float = 0.02
const HELMET_MAT: String = "char_tac_helmet"
## the faction looks' helmet materials (_faction.REMAP of char_tac_helmet) and the Zero skull face mask, on Headwear
const FACTION_HELMET_MATS: Dictionary = {
	"char_tac_light_frd_duty": ["char_frd_helmet"], "char_tac_light_sentinel_duty": ["char_sen_white"],
	"char_tac_light_zero_duty": ["char_zero_armor", "char_zero_bone"],
}
## duty looks that keep a helmet by design (the Bulwark's riot helmet + visor is its silhouette with the shield)
const DUTY_KEEPS_HELMET: Array[String] = ["char_bulwark_duty"]


func _glb(id: String) -> String:
	return "res://assets/characters/%s/%s.glb" % [id, id]


func _load(id: String) -> Node3D:
	var packed: PackedScene = load(_glb(id)) as PackedScene
	if packed == null:
		fail("could not load %s (run godot --import first)" % _glb(id))
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if String(n.name) != "CrowdLod":  # D4-01 LOD2 proxy: checked by test_lod.gd
			out.append(n as MeshInstance3D)
	return out


func _tris(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func test_skeleton_is_rig_humanoid() -> void:
	for id: String in CHARACTERS:
		var root: Node3D = _load(id)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node_or_null("Skeleton3D") as Skeleton3D
		assert_true(skel != null, "%s: Skeleton3D directly under the glb root (remove_armature)" % id)
		if skel != null:
			assert_eq(skel.get_bone_count(), BONES, "%s: bone count" % id)
			for b: String in ["hips", "chest", "head", "hand.R", "hand.L", "foot.L", "toe.R"]:
				assert_true(skel.find_bone(b) >= 0, "%s: bone %s" % [id, b])
		root.queue_free()


func test_meshes_are_skinned_without_blend_shapes() -> void:
	for id: String in CHARACTERS:
		var root: Node3D = _load(id)
		if root == null:
			continue
		var meshes: Array[MeshInstance3D] = _meshes(root)
		var names: Array[String] = []
		var tris: int = 0
		for mi: MeshInstance3D in meshes:
			names.append(String(mi.name))
			assert_has(ALLOWED_MESHES, String(mi.name), "%s: unexpected mesh %s" % [id, mi.name])
			assert_true(mi.get_parent() is Skeleton3D, "%s/%s: child of the Skeleton3D" % [id, mi.name])
			assert_true(mi.skin != null, "%s/%s: has a skin" % [id, mi.name])
			for s: int in range(mi.mesh.get_surface_count()):
				var bones: Variant = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_BONES]
				assert_true(bones != null and (bones as PackedInt32Array).size() > 0,
						"%s/%s surface %d: bone weights" % [id, mi.name, s])
			var am: ArrayMesh = mi.mesh as ArrayMesh
			if am != null:
				assert_eq(am.get_blend_shape_count(), 0, "%s/%s: no blend shapes (baked)" % [id, mi.name])
			tris += _tris(mi.mesh)
		for need: String in ["Body", "Outfit"]:
			assert_has(names, need, "%s: has %s" % [id, need])
		assert_true(tris <= TRI_BUDGET, "%s: %d triangles within %d" % [id, tris, TRI_BUDGET])
		root.queue_free()


func test_every_surface_uses_a_library_material() -> void:
	for id: String in CHARACTERS:
		var root: Node3D = _load(id)
		if root == null:
			continue
		for mi: MeshInstance3D in _meshes(root):
			for s: int in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(s)
				assert_true(m != null, "%s/%s surface %d has a material" % [id, mi.name, s])
				if m == null:
					continue
				var path: String = m.resource_path
				var ok: bool = path.begins_with("res://world/materials/") and path.ends_with(".tres")
				assert_true(ok, "%s/%s surface %d: %s (%s)" % [id, mi.name, s, path, m.resource_name])
		root.queue_free()


func test_height_and_facing_are_plausible() -> void:
	for id: String in CHARACTERS:
		var root: Node3D = _load(id)
		if root == null:
			continue
		var box: AABB = AABB()
		var first: bool = true
		for mi: MeshInstance3D in _meshes(root):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var h: float = box.end.y
		assert_true(h >= MIN_HEIGHT and h <= MAX_HEIGHT, "%s: height %.3f m in %.1f..%.1f" % [id, h, MIN_HEIGHT, MAX_HEIGHT])
		assert_true(box.position.y > -0.02 and box.position.y < 0.02, "%s: feet at y = 0 (%.3f)" % [id, box.position.y])
		assert_near(box.get_center().x, 0.0, 0.08, "%s: roughly centred in x" % id)
		var skel: Skeleton3D = root.get_node_or_null("Skeleton3D") as Skeleton3D
		if skel != null:
			var toe: Vector3 = skel.get_bone_global_rest(skel.find_bone("toe.R")).origin
			var heel: Vector3 = skel.get_bone_global_rest(skel.find_bone("foot.R")).origin
			assert_true(toe.z < heel.z, "%s: faces -Z (toe in front of the ankle)" % id)
		root.queue_free()


## D-145.3: in the rest pose, the furthest-forward clothing/gear vertex across the chest (1.10-1.40 m up, within
## 0.15 m of the centre line) of each duty look sits >= ARMOUR_GAP behind its armoured base look's; no helmet material
## (except DUTY_KEEPS_HELMET).
func test_duty_police_show_no_body_armour() -> void:
	for duty: String in DUTY_LOOKS:
		var d_front: float = _chest_front(duty)
		var a_front: float = _chest_front(String(DUTY_LOOKS[duty]))
		assert_true(d_front > 0.0 and a_front > 0.0, "%s: chest measured" % duty)
		assert_true(d_front <= a_front - ARMOUR_GAP,
				"%s: chest %.3f m forward vs %.3f m on %s (no vest / carrier)" % [duty, d_front, a_front, DUTY_LOOKS[duty]])
		if DUTY_KEEPS_HELMET.has(duty):
			continue
		var root: Node3D = _load(duty)
		if root == null:
			continue
		for mi: MeshInstance3D in _meshes(root):
			for si: int in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(si)
				var mname: String = mat.resource_path.get_file().get_basename() if mat != null else ""
				assert_false(mname == HELMET_MAT or mi.mesh.surface_get_name(si).contains(HELMET_MAT),
						"%s: no ballistic helmet (%s)" % [duty, mi.name])
				for fm: String in FACTION_HELMET_MATS.get(duty, []):   # (the insignia on Gear share these colours)
					assert_false(String(mi.name) == "Headwear" and mname == fm,
							"%s: no faction helmet / face mask %s on Headwear" % [duty, fm])
		root.queue_free()


## Furthest-forward (-Z, Godot facing) Outfit/Gear vertex across the chest, in metres from the root.
func _chest_front(id: String) -> float:
	var root: Node3D = _load(id)
	if root == null:
		return -1.0
	var best: float = -1.0
	for mi: MeshInstance3D in _meshes(root):
		if not (String(mi.name) in ["Outfit", "Gear"]):
			continue
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		for si: int in range(mi.mesh.get_surface_count()):
			for v: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				var p: Vector3 = xf * v
				if p.y > 1.10 and p.y < 1.40 and absf(p.x) < 0.15:
					best = maxf(best, -p.z)
	root.queue_free()
	return best
