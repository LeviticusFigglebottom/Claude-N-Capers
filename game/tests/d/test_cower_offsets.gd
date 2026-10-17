## QC-67 (OF G1 probe): civilians cower 0.21 m in front of a wall (cower_stand, characters.md). Every civilian look of
## world/characters/p5_cast.json is CPU-skinned through cower_stand; its furthest-back vertex (above 0.3 m, root space)
## minus its cower_offsets.json offset must stay within max_back_m (the clip leans on the wall: <= 3 cm of cloth into it),
## and every listed offset must be needed (no stale or oversized entry). Backpack / back-bag looks are the ones that need
## one.
extends TestCase

const CAST: String = "res://world/characters/p5_cast.json"
const OFFSETS: String = "res://world/characters/cower_offsets.json"
const CLIP: String = "humanoid/cower_stand"
## sample times (s): the hold and both flinch peaks
const TIMES: Array[float] = [0.0, 0.8, 1.3, 1.5, 2.5, 3.6]
## P5 generic roles that are civilians (the D-115 heists and tag maps use civ_ / staff_ spawn tags)
const CIV_ROLES: Array[String] = ["bank_teller", "bank_manager", "bank_officer", "bank_customer", "gallery_curator",
	"gallery_attendant", "gallery_conservator", "gallery_admin", "gallery_patron", "gallery_waitstaff", "club_bartender",
	"club_dj", "club_patron", "street_civilian"]
## an offset may exceed the need by at most this much (m)
const SLACK: float = 0.03

var _offsets: Dictionary = {}
var _max_back: float = 0.24
var _civ: Array[String] = []


func before_all() -> void:
	var off: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OFFSETS)) as Dictionary
	_offsets = off.get("offsets", {}) as Dictionary
	_max_back = float(off.get("max_back_m", 0.205))
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAST)) as Dictionary
	for heist: String in cast["heists"]:
		var roles: Dictionary = cast["heists"][heist] as Dictionary
		for role: String in roles:
			if role.begins_with("civ_") or role.begins_with("staff_") or CIV_ROLES.has(role):
				_add(roles[role] as Array)
	for heist: String in cast.get("tag_map", {}):
		var tags: Dictionary = cast["tag_map"][heist] as Dictionary
		for tag: String in tags:
			if tag.begins_with("civ_") or tag.begins_with("staff_"):
				_add(tags[tag] as Array)


func test_offsets_parse() -> void:
	assert_true(_max_back > 0.20 and _max_back <= 0.24, "max_back_m within 3 cm of the 0.21 m wall (%.3f)" % _max_back)
	assert_true(_civ.size() >= 40, "civilian looks found in p5_cast.json (%d)" % _civ.size())
	for id: String in _offsets:
		assert_true(_civ.has(id), "%s: an offset only for a civilian look" % id)


func test_civilian_backs_clear_the_wall() -> void:
	for id: String in _civ:
		var back: float = _back_depth(id)
		if back < 0.0:
			continue
		var off: float = float(_offsets.get(id, 0.0))
		assert_true(back - off <= _max_back, "%s: back %.3f m - offset %.2f > %.3f (cower_offsets.json)" % [id, back, off,
				_max_back])
		if off > 0.0:
			assert_true(back - off >= _max_back - SLACK, "%s: offset %.2f larger than needed (back %.3f)" % [id, off, back])


func _add(ids: Array) -> void:
	for cid: Variant in ids:
		if not _civ.has(String(cid)):
			_civ.append(String(cid))


## The furthest-back skinned vertex (root space +Z, above 0.3 m) through cower_stand, or -1 when the scene is missing.
func _back_depth(id: String) -> float:
	var path: String = "res://world/characters/%s/%s.tscn" % [id, id]
	if not ResourceLoader.exists(path):
		assert_true(false, "%s: scene exists" % id)
		return -1.0
	var rig: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	add_child(rig)
	var ap: AnimationPlayer = rig.get_node("AnimationPlayer") as AnimationPlayer
	var skel: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
	ap.play(CLIP)
	var back: float = 0.0
	for t: float in TIMES:
		ap.seek(t, true)
		skel.force_update_all_bone_transforms()
		for mi: Node in skel.get_children():
			if mi is MeshInstance3D and (mi as MeshInstance3D).skin != null and String(mi.name) != "CrowdLod":
				back = maxf(back, _mesh_back(mi as MeshInstance3D, skel))
	rig.free()
	return back


func _mesh_back(mi: MeshInstance3D, skel: Skeleton3D) -> float:
	var skin: Skin = mi.skin
	var mats: Array[Transform3D] = []
	for b: int in skin.get_bind_count():
		var bone: int = skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		mats.append(skel.transform * skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	var m: float = 0.0
	for s: int in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var per: int = bs.size() / vs.size()
		for i: int in range(0, vs.size(), 2):
			var p: Vector3 = Vector3.ZERO
			for j: int in per:
				var w: float = ws[i * per + j]
				if w > 0.0:
					p += (mats[bs[i * per + j]] * vs[i]) * w
			if p.y > 0.3:
				m = maxf(m, p.z)
	return m
