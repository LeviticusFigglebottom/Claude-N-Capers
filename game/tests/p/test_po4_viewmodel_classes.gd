## PO-4: every weapon's first-person hip pose keeps the whole gun in front of the lens (an authored rig with the
## stock behind the camera fills the screen corner and reads huge and canted). Sweeps every WeaponDef in
## content/data/weapons, one launch each; prints a camera-space table (grip, rear, front) per anim_set.
extends TestCase

const WEAPON_DIR: String = "res://content/data/weapons/"
## Sets the viewmodel IK/clips skip or that have no gun in the right hand.
const SKIP_SETS: Array[StringName] = [&"akimbo", &"bow"]

const MAX_REAR_M: float = 0.10
const MIN_GRIP_FORWARD_M: float = 0.30

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _weapon_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for f: String in DirAccess.get_files_at(WEAPON_DIR):
		if not f.ends_with(".tres"):
			continue
		var d: WeaponDef = load(WEAPON_DIR + f) as WeaponDef
		if d != null and d.id != &"" and not SKIP_SETS.has(d.anim_set):
			out.append(d.id)
	out.sort()
	return out


func _measure(id: StringName) -> Dictionary:
	var def: WeaponDef = ContentDB.weapon(id)
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	var primary: bool = def.slot == Enums.WeaponSlot.PRIMARY
	if primary:
		l.primary = id
		l.resolved_primary = LoadoutResolver.resolve_weapon(id, l.primary_mods)
	else:
		l.secondary = id
		l.resolved_secondary = LoadoutResolver.resolve_weapon(id, l.secondary_mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	_inp = PInputDriver.new(self)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await _inp.tap(&"slot_primary" if primary else &"slot_secondary")
	await wait_seconds(2.0)
	var out: Dictionary = {"set": def.anim_set}
	var cam: Camera3D = CrewView.of(c).camera()
	var vm: FpViewmodel = FpViewmodel.of(cam)
	if vm != null and vm.weapon_visual != null:
		var inv: Transform3D = cam.global_transform.affine_inverse()
		var ab: AABB = AABB()
		var first: bool = true
		for n: Node in vm.weapon_visual.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
			ab = b if first else ab.merge(b)
			first = false
		out["grip"] = (inv * vm.weapon_visual.global_transform).origin
		out["rear"] = ab.end.z
		out["front"] = ab.position.z
		out["set"] = vm.anim_set
	_inp.release_all()
	_rt.teardown()
	_rt = null
	await wait_frames(1)
	return out


func test_every_weapon_hip_in_front_of_lens() -> void:
	var bad: PackedStringArray = []
	for id: StringName in _weapon_ids():
		var m: Dictionary = await _measure(id)
		if not m.has("rear"):
			print("[PO4] %-24s set=%-12s no viewmodel" % [id, m["set"]])
			continue
		print("[PO4] %-24s set=%-12s grip=%s rear=%.3f front=%.3f" % [id, m["set"], m["grip"], m["rear"],
			m["front"]])
		# PD2 framing: grip well forward of the eye; at most the butt pad of a long stock behind the lens.
		if float(m["rear"]) > MAX_REAR_M or -(m["grip"] as Vector3).z < MIN_GRIP_FORWARD_M:
			bad.append("%s (%s) rear %.3f grip z %.3f" % [id, m["set"], m["rear"], (m["grip"] as Vector3).z])
	assert_true(bad.is_empty(), "guns too close to the lens at hip: %s" % ", ".join(bad))
