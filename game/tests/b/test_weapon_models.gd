## B1-03: Kestrel P9 + mod models: every def's model loads, the base carries every contract marker,
## mods attach at the marker for their ModType, stock parts hide, triangle budgets hold.
extends TestCase

const WEAPON_ID: StringName = &"weapon.kestrel_p9"
const FP_WEAPON_TRI_BUDGET: int = 25000
## asset folder -> generated asset ids built by tools/blender/weapons/
const ASSETS: Array[String] = [
	"wpn_kestrel_p9", "mod_p9_suppressor", "mod_p9_reflex_sight", "mod_p9_iron_sights",
	"mod_p9_standard_mag", "mod_p9_extended_mag",
]


func before_all() -> void:
	ContentDB.clear_cache()


func _visual(mod_ids: Array[StringName]) -> WeaponVisual:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	v.setup_ids(WEAPON_ID, mod_ids)
	return v


func test_every_weapon_and_mod_model_loads() -> void:
	var defs: Array = ContentDB.all_weapons() + ContentDB.all_mods()
	assert_true(defs.size() >= 6, "P1 weapon + mods exist")
	for def: Resource in defs:
		var scene: PackedScene = def.get(&"model")
		assert_true(scene != null, "%s has a model" % def.get(&"id"))
		if scene == null:
			continue
		var inst: Node = scene.instantiate()
		assert_true(inst is Node3D, "%s model root is Node3D" % def.get(&"id"))
		inst.free()


func test_base_model_has_all_contract_markers() -> void:
	var w: WeaponDef = ContentDB.weapon(WEAPON_ID)
	var inst: Node3D = w.model.instantiate() as Node3D
	for m: StringName in WeaponVisual.MARKERS:
		assert_true(inst.find_child(String(m), true, false) is Node3D, "marker %s" % m)
	inst.free()


func test_marker_placement_is_sane() -> void:
	var v: WeaponVisual = _visual([] as Array[StringName])
	var muzzle: Node3D = v.get_marker(&"Muzzle")
	var magwell: Node3D = v.get_marker(&"Magwell")
	var sight: Node3D = v.get_marker(&"SightRail")
	# -Z forward: the muzzle is ahead of the grip pivot and points along -Z
	assert_true(muzzle.global_position.z < -0.1, "muzzle in front (z=%f)" % muzzle.global_position.z)
	assert_near(muzzle.global_basis.z.normalized().dot(Vector3.BACK), 1.0, 0.001, "muzzle -Z forward")
	assert_true(magwell.global_position.y < -0.05, "magwell at the bottom of the grip")
	assert_true(sight.global_position.y > muzzle.global_position.y, "sight rail above the bore")
	var length: float = absf(muzzle.global_position.z - v.get_marker(&"StockMount").global_position.z)
	assert_true(length > 0.16 and length < 0.21, "about 18 cm long (%f)" % length)
	v.queue_free()


func test_stock_loadout_uses_stock_parts() -> void:
	var w: WeaponDef = ContentDB.weapon(WEAPON_ID)
	var ids: Array[StringName] = []
	for t: int in w.default_mods:
		ids.append(w.default_mods[t])
	var v: WeaponVisual = _visual(ids)
	assert_eq(v.attached.size(), 0, "default mods instance nothing extra")
	assert_true(v.stock_part(Enums.ModType.SIGHT).visible, "stock sight visible")
	assert_true(v.stock_part(Enums.ModType.MAGAZINE).visible, "stock magazine visible")
	assert_true(v.get_marker(&"AimPoint") != null, "stock sight has an AimPoint")
	v.queue_free()


func test_mods_attach_at_marker_for_their_type() -> void:
	var ids: Array[StringName] = [&"mod.p9_suppressor", &"mod.p9_reflex_sight", &"mod.p9_extended_mag"]
	var v: WeaponVisual = _visual(ids)
	assert_eq(v.attached.size(), 3, "three mods attached")
	for id: StringName in ids:
		var mod: WeaponModDef = ContentDB.mod(id)
		var inst: Node3D = v.attached.get(mod.mod_type)
		assert_true(inst != null, "%s attached" % id)
		if inst == null:
			continue
		assert_eq(inst.get_parent().name, WeaponVisual.MARKER_FOR_MOD_TYPE[mod.mod_type], "%s parent marker" % id)
		assert_eq(inst.position, Vector3.ZERO, "%s snaps onto the marker" % id)
	assert_false(v.stock_part(Enums.ModType.SIGHT).visible, "reflex hides the stock sight")
	assert_false(v.stock_part(Enums.ModType.MAGAZINE).visible, "extended mag hides the stock magazine")
	# the suppressor's own Muzzle replaces the barrel muzzle; the reflex dot is the AimPoint
	var base_muzzle: Node3D = v.get_base_marker(&"Muzzle")
	var muzzle: Node3D = v.get_marker(&"Muzzle")
	assert_ne(muzzle, base_muzzle, "suppressor muzzle wins")
	assert_true(muzzle.global_position.z < base_muzzle.global_position.z - 0.1, "suppressed muzzle further forward")
	var aim: Node3D = v.get_marker(&"AimPoint")
	assert_true(aim != null and v.attached[Enums.ModType.SIGHT].is_ancestor_of(aim), "reflex AimPoint")
	# swapping back to stock restores the stock parts
	v.setup_ids(WEAPON_ID, [&"mod.p9_iron_sights", &"mod.p9_standard_mag"] as Array[StringName])
	assert_eq(v.attached.size(), 0, "stock again")
	assert_true(v.stock_part(Enums.ModType.SIGHT).visible, "stock sight back")
	v.queue_free()


func test_every_mod_type_maps_to_a_base_marker() -> void:
	var w: WeaponDef = ContentDB.weapon(WEAPON_ID)
	var inst: Node3D = w.model.instantiate() as Node3D
	for t: int in w.mod_slots:
		assert_true(WeaponVisual.MARKER_FOR_MOD_TYPE.has(t), "mod type %d has a marker" % t)
		var marker: StringName = WeaponVisual.MARKER_FOR_MOD_TYPE.get(t, &"")
		assert_true(inst.find_child(String(marker), true, false) != null, "base has %s" % marker)
	inst.free()


func test_triangle_budgets_from_source_txt() -> void:
	for id: String in ASSETS:
		var path: String = "res://assets/weapons/%s/SOURCE.txt" % id
		var text: String = FileAccess.get_file_as_string(path)
		assert_true(not text.is_empty(), "%s exists" % path)
		var tris: int = _field_int(text, "tris_lod0")
		var budget: int = _field_int(text, "tri_budget")
		assert_true(tris > 0, "%s records tris_lod0" % id)
		assert_true(budget > 0 and budget <= FP_WEAPON_TRI_BUDGET, "%s budget within FP limit" % id)
		assert_true(tris <= budget, "%s: %d tris <= %d" % [id, tris, budget])


func _field_int(text: String, key: String) -> int:
	for line: String in text.split("\n"):
		if line.begins_with(key + ":"):
			return line.substr(key.length() + 1).strip_edges().to_int()
	return -1
