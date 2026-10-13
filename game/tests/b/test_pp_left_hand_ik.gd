## PP-B-9 (P report: the brute_12 support hand floats at hip fire): for every two-handed weapon model
## (not a pistol-class weapon; anim set not pistol / akimbo / bow, which skip the left-hand IK), the `LeftHandIK` marker sits on
## the fore-end: inside (2 cm) a non-barrel mesh's bounds, at least 6 cm ahead of the grip and at
## least 8 cm behind the muzzle, and no more than MAX_REACH_M ahead of the grip.
extends TestCase

const ONE_HANDED_SETS: Array[StringName] = [&"pistol", &"akimbo", &"bow"]
const TOL: float = 0.02
const MIN_FROM_GRIP_M: float = 0.06
const MIN_FROM_MUZZLE_M: float = 0.08
const MAX_REACH_M: float = 0.46
## Barrel-end meshes a support hand must not hold.
const BARREL_PARTS: Array[String] = ["Barrel", "Barrels", "BarrelsBead", "Brake", "FlashHider", "MuzzleNut", "Can"]


static func offsets(def: WeaponDef) -> Dictionary:
	var n: Node3D = def.model.instantiate() as Node3D
	var ik: Node3D = n.find_child("LeftHandIK", true, false) as Node3D
	var mz: Node3D = n.find_child("Muzzle", true, false) as Node3D
	var grip: Node3D = n.find_child("GripMount", true, false) as Node3D
	var out: Dictionary = {"ik": null}
	if ik == null or mz == null:
		n.free()
		return out
	var ikp: Vector3 = _local(n, ik)
	var gz: float = _local(n, grip).z if grip != null else 0.0
	var on: Array[String] = []
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if BARREL_PARTS.has(String(mi.name)):
			continue
		var ab: AABB = (_xf(n, mi) * mi.get_aabb()).grow(TOL)
		if ab.has_point(ikp):
			on.append(String(mi.name))
	out = {"ik": ikp, "from_grip": gz - ikp.z, "to_muzzle": ikp.z - _local(n, mz).z, "on": on}
	n.free()
	return out


static func _xf(root: Node3D, c: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var p: Node = c
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


static func _local(root: Node3D, c: Node3D) -> Vector3:
	return _xf(root, c).origin


func test_left_hand_ik_on_fore_end_for_two_handed_weapons() -> void:
	var bad: Array[String] = []
	var n: int = 0
	for w: Variant in ContentDB.all_weapons():
		var def: WeaponDef = w as WeaponDef
		if def == null or def.model == null or ONE_HANDED_SETS.has(def.anim_set) \
				or def.weapon_class == Enums.WeaponClass.PISTOL:
			continue
		n += 1
		var o: Dictionary = offsets(def)
		if o["ik"] == null:
			bad.append("%s: no LeftHandIK / Muzzle" % def.id)
			continue
		var tag: String = "%s ik=%s from_grip=%.3f to_muzzle=%.3f on=%s" % [def.id, o["ik"], o["from_grip"], o["to_muzzle"], o["on"]]
		if (o["on"] as Array).is_empty():
			bad.append(tag + ": not on a fore-end mesh")
		elif float(o["from_grip"]) < MIN_FROM_GRIP_M or float(o["from_grip"]) > MAX_REACH_M:
			bad.append(tag + ": not between %.2f and %.2f m ahead of the grip" % [MIN_FROM_GRIP_M, MAX_REACH_M])
		elif float(o["to_muzzle"]) < MIN_FROM_MUZZLE_M:
			bad.append(tag + ": within %.2f m of the muzzle" % MIN_FROM_MUZZLE_M)
	assert_true(n > 20, "checked %d two-handed weapons" % n)
	assert_eq(bad.size(), 0, "LeftHandIK off the fore-end:\n" + "\n".join(bad))
