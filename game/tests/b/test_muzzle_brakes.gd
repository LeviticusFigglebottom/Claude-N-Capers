## PO6-13 / D-114 §8: the long guns wear a muzzle brake (rifles, LMGs, snipers) or a top-ported compensator
## (pump/semi shotguns). The `MuzzleBrake` mesh carries the one `Muzzle` (front face, forward-most marker) and
## the `MuzzlePortL` / `MuzzlePortR` side-port markers (within 8 cm behind the Muzzle), each venting (local -Z)
## outward to its own side and not backwards. Pistols and SMGs carry no port markers.
extends TestCase

const BRAKED: Array[StringName] = [
	&"weapon.corsair_ar", &"weapon.bastion_br", &"weapon.drover_762", &"weapon.falchion_dmr",
	&"weapon.lark_carbine", &"weapon.osprey_762", &"weapon.tern_556",
	&"weapon.anvil_lmg", &"weapon.gale_mg", &"weapon.rampart_lmg",
	&"weapon.condor_50", &"weapon.heron_308",
	&"weapon.plowman_12", &"weapon.brute_12", &"weapon.harrow_12",
]
const PORTS: Array[StringName] = [&"MuzzlePortL", &"MuzzlePortR"]
const MAX_PORT_BEHIND_M: float = 0.08


## Transform of `c` relative to `root` (the model is not in the tree).
static func _xf(root: Node, c: Node) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var p: Node = c
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _instance(id: StringName) -> Node3D:
	var def: WeaponDef = ContentDB.weapon(id)
	assert_true(def != null and def.model != null, "%s has a model" % id)
	if def == null or def.model == null:
		return null
	return def.model.instantiate() as Node3D


func test_braked_long_guns_carry_brake_muzzle_and_ports() -> void:
	for id: StringName in BRAKED:
		var n: Node3D = _instance(id)
		if n == null:
			continue
		var brake: MeshInstance3D = n.find_child("MuzzleBrake", true, false) as MeshInstance3D
		var muzzle: Node3D = n.find_child("Muzzle", true, false) as Node3D
		assert_true(brake != null, "%s MuzzleBrake mesh" % id)
		assert_true(muzzle != null, "%s Muzzle" % id)
		if brake == null or muzzle == null:
			n.free()
			continue
		assert_true(brake.is_ancestor_of(muzzle), "%s the brake carries the Muzzle" % id)
		var mz: Vector3 = _xf(n, muzzle).origin
		# Muzzle is the forward-most (-Z) marker of the model
		for c: Node in n.find_children("*", "Node3D", true, false):
			if c is MeshInstance3D or c == muzzle:
				continue
			assert_true(_xf(n, c).origin.z >= mz.z - 0.0001, "%s Muzzle ahead of %s" % [id, c.name])
		for port: StringName in PORTS:
			var p: Node3D = n.find_child(String(port), true, false) as Node3D
			assert_true(p != null, "%s %s" % [id, port])
			if p == null:
				continue
			assert_true(brake.is_ancestor_of(p), "%s %s on the brake" % [id, port])
			var xf: Transform3D = _xf(n, p)
			var behind: float = xf.origin.z - mz.z
			assert_true(behind > 0.0 and behind <= MAX_PORT_BEHIND_M,
				"%s %s %.3f m behind the Muzzle" % [id, port, behind])
			var vent: Vector3 = -xf.basis.z.normalized()
			var side: float = -1.0 if port == &"MuzzlePortL" else 1.0
			assert_true(vent.x * side > 0.1, "%s %s vents outward (%s)" % [id, port, vent])
			assert_true(vent.dot(Vector3.FORWARD) >= 0.0, "%s %s does not vent backwards (%s)" % [id, port, vent])
			assert_true(signf(xf.origin.x) == side, "%s %s on its own side" % [id, port])
		n.free()


func test_pistols_and_smgs_have_no_ports() -> void:
	var checked: int = 0
	for w: Variant in ContentDB.all_weapons():
		var def: WeaponDef = w as WeaponDef
		if def == null or def.model == null:
			continue
		if def.weapon_class != Enums.WeaponClass.PISTOL and def.weapon_class != Enums.WeaponClass.SMG:
			continue
		checked += 1
		var n: Node3D = def.model.instantiate() as Node3D
		for port: StringName in PORTS:
			assert_true(n.find_child(String(port), true, false) == null, "%s has no %s" % [def.id, port])
		n.free()
	assert_true(checked > 5, "checked %d pistols/SMGs" % checked)
