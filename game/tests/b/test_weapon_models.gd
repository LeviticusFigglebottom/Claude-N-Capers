## B1-03 / B4-04: weapon + mod models: every def's model loads, every base carries every contract
## marker, mods attach at the marker for their ModType, stock parts hide, triangle budgets hold
## (per asset and for the heaviest full kit of each weapon).
extends TestCase

const WEAPON_ID: StringName = &"weapon.kestrel_p9"
const FP_WEAPON_TRI_BUDGET: int = 25000
## Stock parts each weapon must carry (Stock<ModType>, data_schemas.md §Weapons).
const STOCK_PARTS: Dictionary = {
	&"weapon.kestrel_p9": [&"StockSight", &"StockMagazine"],
	&"weapon.warden_45": [&"StockSight", &"StockMagazine"],
	&"weapon.hornet_9": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.corsair_ar": [&"StockSight", &"StockMagazine"],
	&"weapon.plowman_12": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.rampart_lmg": [&"StockSight", &"StockMagazine", &"StockBarrel"],
	&"weapon.heron_308": [&"StockSight", &"StockMagazine"],
	# B4-12
	&"weapon.drover_762": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.mastiff_45": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.anvil_lmg": [&"StockSight", &"StockMagazine", &"StockBarrel"],
	&"weapon.condor_50": [&"StockSight", &"StockMagazine"],
	&"weapon.mule_12": [&"StockSight", &"StockMagazine"],
	&"weapon.akimbo_warden_45": [&"StockSight", &"StockMagazine"],
	&"weapon.marshal_357": [&"StockSight", &"StockMagazine", &"StockBarrel", &"StockGrip"],
	&"weapon.falchion_dmr": [&"StockSight", &"StockMagazine"],
	&"weapon.wasp_pdw": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.sparrow_mp": [&"StockSight", &"StockMagazine"],
	# B4-18
	&"weapon.wren_380": [&"StockSight", &"StockMagazine"],
	&"weapon.ferret_9": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.lancet_45": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.hush_9": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.tern_556": [&"StockSight", &"StockMagazine"],
	&"weapon.bastion_br": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.lark_carbine": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.harrow_12": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.brute_12": [&"StockSight", &"StockMagazine"],
	&"weapon.reaper_db": [&"StockSight", &"StockMagazine", &"StockBarrel", &"StockStock"],
	&"weapon.gale_mg": [&"StockSight", &"StockMagazine"],
	&"weapon.osprey_762": [&"StockSight", &"StockMagazine"],
	&"weapon.shrike_44": [&"StockSight", &"StockMagazine", &"StockBarrel"],
	&"weapon.thorn_bow": [&"StockSight", &"StockMagazine"],
	&"weapon.vise_crossbow": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.thumper_40": [&"StockSight", &"StockMagazine", &"StockStock"],
	&"weapon.furnace_ft": [&"StockSight", &"StockMagazine"],
	&"weapon.rotor_saw": [&"StockSight", &"StockMagazine", &"StockForegrip"],
	&"weapon.cyclone_rotary": [&"StockSight", &"StockMagazine", &"StockBarrel"],
}
## Overall length range (Muzzle to StockMount / rear-most marker), metres.
const LENGTH_RANGE: Dictionary = {
	&"weapon.warden_45": Vector2(0.18, 0.26), &"weapon.hornet_9": Vector2(0.28, 0.40),
	&"weapon.corsair_ar": Vector2(0.62, 0.78), &"weapon.plowman_12": Vector2(0.65, 0.78),
	&"weapon.rampart_lmg": Vector2(0.72, 0.86), &"weapon.heron_308": Vector2(0.80, 0.92),
	&"weapon.drover_762": Vector2(0.66, 0.78), &"weapon.mastiff_45": Vector2(0.36, 0.46),
	&"weapon.anvil_lmg": Vector2(0.78, 0.90), &"weapon.condor_50": Vector2(1.00, 1.12),
	&"weapon.mule_12": Vector2(0.44, 0.52), &"weapon.akimbo_warden_45": Vector2(0.18, 0.26),
	&"weapon.marshal_357": Vector2(0.17, 0.25), &"weapon.falchion_dmr": Vector2(0.78, 0.90),
	&"weapon.wasp_pdw": Vector2(0.30, 0.38), &"weapon.sparrow_mp": Vector2(0.16, 0.24),
	# B4-18
	&"weapon.wren_380": Vector2(0.12, 0.16), &"weapon.ferret_9": Vector2(0.30, 0.35),
	&"weapon.lancet_45": Vector2(0.34, 0.39), &"weapon.hush_9": Vector2(0.48, 0.54),
	&"weapon.tern_556": Vector2(0.76, 0.82), &"weapon.bastion_br": Vector2(0.66, 0.72),
	&"weapon.lark_carbine": Vector2(0.41, 0.46), &"weapon.harrow_12": Vector2(0.54, 0.60),
	&"weapon.brute_12": Vector2(0.76, 0.82), &"weapon.reaper_db": Vector2(0.70, 0.75),
	&"weapon.gale_mg": Vector2(0.65, 0.71), &"weapon.osprey_762": Vector2(0.76, 0.82),
	&"weapon.shrike_44": Vector2(0.57, 0.62), &"weapon.thorn_bow": Vector2(0.55, 0.61),
	&"weapon.vise_crossbow": Vector2(0.49, 0.54), &"weapon.thumper_40": Vector2(0.33, 0.38),
	&"weapon.furnace_ft": Vector2(0.58, 0.63), &"weapon.rotor_saw": Vector2(0.58, 0.63),
	&"weapon.cyclone_rotary": Vector2(0.65, 0.70),
}
## What a magazine part shows (B4-18 adds arrows/bolts, saw blades and fuel tanks).
const MAG_SHOWS: Array[String] = ["*Round", "*Shell", "*Belt", "*Arrow", "*Blade", "*Tank"]
const WEAPONS_DIR: String = "res://assets/weapons"


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
	for id: String in _asset_ids():
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


## data_schemas.md §Weapons: stock parts are named Stock<ModType> (D-026 QB-22).
func test_stock_part_names_follow_contract() -> void:
	assert_eq(WeaponVisual.stock_part_name(Enums.ModType.SIGHT), &"StockSight")
	assert_eq(WeaponVisual.stock_part_name(Enums.ModType.MAGAZINE), &"StockMagazine")
	assert_eq(WeaponVisual.stock_part_name(Enums.ModType.BARREL), &"StockBarrel")
	assert_eq(WeaponVisual.stock_part_name(Enums.ModType.BARREL_EXT), &"StockBarrelExt")
	assert_eq(WeaponVisual.stock_part_name(Enums.ModType.FOREGRIP), &"StockForegrip")


func _visual_for(weapon_id: StringName, mod_ids: Array[StringName]) -> WeaponVisual:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	v.setup_ids(weapon_id, mod_ids)
	return v


func _asset_ids() -> Array[String]:
	var out: Array[String] = []
	for d: String in DirAccess.get_directories_at(WEAPONS_DIR):
		if FileAccess.file_exists("%s/%s/SOURCE.txt" % [WEAPONS_DIR, d]):
			out.append(d)
	out.sort()
	return out


func _tris_of(scene: PackedScene) -> int:
	var path: String = scene.resource_path.get_base_dir().path_join("SOURCE.txt")
	return _field_int(FileAccess.get_file_as_string(path), "tris_lod0")


func test_every_weapon_has_markers_and_stock_parts() -> void:
	assert_true(ContentDB.all_weapons().size() >= 7, "P9 + the B4-04 armory")
	for w: WeaponDef in ContentDB.all_weapons():
		assert_true(w.model != null, "%s model" % w.id)
		if w.model == null:
			continue
		var inst: Node3D = w.model.instantiate() as Node3D
		for m: StringName in WeaponVisual.MARKERS:
			assert_true(inst.find_child(String(m), true, false) is Node3D, "%s marker %s" % [w.id, m])
		assert_true(inst.find_child("AimPoint", true, false) is Node3D, "%s AimPoint" % w.id)
		for part: StringName in STOCK_PARTS.get(w.id, []):
			assert_true(inst.find_child(String(part), true, false) is Node3D, "%s stock part %s" % [w.id, part])
		for t: int in w.mod_slots:
			if not WeaponVisual.MARKER_FOR_MOD_TYPE.has(t):
				continue  # AMMO (D-118) and other marker-less types never attach a model
			var marker: StringName = WeaponVisual.MARKER_FOR_MOD_TYPE.get(t, &"")
			assert_true(inst.find_child(String(marker), true, false) != null, "%s has %s for type %d" % [w.id, marker, t])
		inst.free()


func test_every_weapon_marker_layout_is_sane() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		var v: WeaponVisual = _visual_for(w.id, [] as Array[StringName])
		var muzzle: Node3D = v.get_marker(&"Muzzle")
		var sight: Node3D = v.get_marker(&"SightRail")
		var magwell: Node3D = v.get_marker(&"Magwell")
		var stock: Node3D = v.get_marker(&"StockMount")
		var aim: Node3D = v.get_marker(&"AimPoint")
		assert_true(muzzle.global_position.z < -0.1, "%s muzzle in front of the hand" % w.id)
		assert_near(muzzle.global_basis.z.normalized().dot(Vector3.BACK), 1.0, 0.001, "%s muzzle -Z forward" % w.id)
		assert_true(sight.global_position.y > muzzle.global_position.y, "%s sight rail above the bore" % w.id)
		assert_true(aim.global_position.y > sight.global_position.y - 0.001, "%s AimPoint on/above the rail" % w.id)
		assert_true(magwell.global_position.y < sight.global_position.y, "%s magwell below the rail" % w.id)
		assert_true(stock.global_position.z > muzzle.global_position.z, "%s stock mount behind the muzzle" % w.id)
		assert_near(v.get_marker(&"GripMount").global_position.length(), 0.0, 0.0001, "%s origin = grip" % w.id)
		if LENGTH_RANGE.has(w.id):
			var r: Vector2 = LENGTH_RANGE[w.id]
			var length: float = absf(muzzle.global_position.z - stock.global_position.z)
			assert_true(length > r.x and length < r.y, "%s muzzle-to-stock-mount %f in %s" % [w.id, length, r])
		var eject: Node3D = v.get_marker(&"Eject")
		assert_true(eject.global_basis.z.normalized().dot(Vector3.LEFT) > 0.99, "%s Eject -Z points right" % w.id)
		v.queue_free()


## Every non-default mod snaps onto its marker, hides the matching stock part and owns the markers it
## must (muzzle devices: Muzzle; sights: AimPoint).
func test_every_mod_attaches_on_every_weapon() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		for slot: Variant in w.mod_slots:
			for mid: Variant in w.mod_slots[slot]:
				var mod: WeaponModDef = ContentDB.mod(StringName(mid))
				var is_default: bool = StringName(w.default_mods.get(slot, &"")) == mod.id
				var v: WeaponVisual = _visual_for(w.id, [mod.id] as Array[StringName])
				if is_default:
					assert_eq(v.attached.size(), 0, "%s default %s uses the stock part" % [w.id, mid])
					v.queue_free()
					continue
				if not WeaponVisual.MARKER_FOR_MOD_TYPE.has(mod.mod_type):
					# AMMO (D-118): the model is an icon only, nothing goes on the gun
					assert_eq(v.attached.size(), 0, "%s: %s attaches nothing" % [w.id, mid])
					v.queue_free()
					continue
				var inst: Node3D = v.attached.get(mod.mod_type)
				assert_true(inst != null, "%s attaches %s" % [w.id, mid])
				if inst == null:
					v.queue_free()
					continue
				assert_eq(inst.get_parent().name, WeaponVisual.MARKER_FOR_MOD_TYPE[mod.mod_type], "%s parent" % mid)
				assert_eq(inst.position, Vector3.ZERO, "%s snaps onto the marker" % mid)
				var stock: Node3D = v.stock_part(mod.mod_type)
				if stock != null:
					assert_false(stock.visible, "%s hides %s" % [mid, stock.name])
				match mod.mod_type:
					Enums.ModType.SUPPRESSOR, Enums.ModType.BARREL_EXT, Enums.ModType.BARREL:
						var own: Node3D = v.get_marker(&"Muzzle")
						assert_true(inst.is_ancestor_of(own), "%s owns the effective Muzzle" % mid)
						if mod.mod_type != Enums.ModType.BARREL:
							assert_true(own.global_position.z < v.get_base_marker(&"Muzzle").global_position.z,
								"%s muzzle further forward" % mid)
					Enums.ModType.SIGHT:
						assert_true(inst.is_ancestor_of(v.get_marker(&"AimPoint")), "%s owns the AimPoint" % mid)
					Enums.ModType.MAGAZINE:
						var shows: bool = false
						for pat: String in MAG_SHOWS:
							shows = shows or inst.find_child(pat, true, false) != null
						assert_true(shows, "%s shows a round" % mid)
				v.queue_free()


func test_every_model_asset_is_within_budget() -> void:
	var ids: Array[String] = _asset_ids()
	assert_true(ids.size() >= 40, "B4-04 assets built (%d)" % ids.size())
	for id: String in ids:
		var text: String = FileAccess.get_file_as_string("%s/%s/SOURCE.txt" % [WEAPONS_DIR, id])
		var tris: int = _field_int(text, "tris_lod0")
		var budget: int = _field_int(text, "tri_budget")
		assert_true(tris > 0 and budget > 0 and budget <= FP_WEAPON_TRI_BUDGET, "%s budget" % id)
		assert_true(tris <= budget, "%s: %d tris <= %d" % [id, tris, budget])


## The heaviest kit (largest mod per slot) still fits the 25k first-person budget. An akimbo model
## (`Offhand` marker) is drawn twice with the same kit, so its kit counts double (D-050).
func test_heaviest_full_kit_fits_the_fp_budget() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		var total: int = _tris_of(w.model)
		for slot: Variant in w.mod_slots:
			if not WeaponVisual.MARKER_FOR_MOD_TYPE.has(int(slot)):
				continue  # AMMO icons (D-118) are never drawn on the gun
			var worst: int = 0
			for mid: Variant in w.mod_slots[slot]:
				var m: WeaponModDef = ContentDB.mod(StringName(mid))
				if StringName(w.default_mods.get(slot, &"")) != m.id:
					worst = maxi(worst, _tris_of(m.model))
			total += worst
		var inst: Node = w.model.instantiate()
		if inst.find_child(String(WeaponVisual.OFFHAND_MARKER), true, false) != null:
			total *= 2
		inst.free()
		assert_true(total <= FP_WEAPON_TRI_BUDGET, "%s full kit %d tris" % [w.id, total])


## D-044 (visual_slots.md): the Rampart LMG carries a hinged `FeedCover`: its origin is the REAR hinge
## (closed = rotation 0; ENV A opens it 78 deg about local X), so the whole cover lies in front of the
## pivot, and the optics rail (SightRail) rides on it.
func test_rampart_feed_cover_hinge() -> void:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	v.setup_ids(&"weapon.rampart_lmg", [] as Array[StringName])
	var cover: Node3D = v.model.find_child("FeedCover", true, false) as Node3D
	assert_true(cover != null, "FeedCover node")
	if cover == null:
		v.queue_free()
		return
	assert_true(cover.rotation.is_zero_approx(), "closed = rotation 0")
	# hinge axis: Blender (0, COVER_Y0 - 0.004, REC_TOP_Z + 0.002) = Godot (0, 0.120, 0.024)
	var hinge: Vector3 = v.model.global_transform.affine_inverse() * cover.global_position
	assert_near(hinge.x, 0.0, 0.0005, "hinge on the centre plane")
	assert_near(hinge.y, 0.120, 0.0005, "hinge at the receiver top")
	assert_near(hinge.z, 0.024, 0.0005, "hinge at the cover's rear")
	var mesh: MeshInstance3D = cover as MeshInstance3D
	if mesh != null:
		var box: AABB = mesh.get_aabb()
		assert_true(box.end.z < 0.012, "cover body is in front of (or on) the rear hinge: %s" % box)
		assert_true(box.position.z < -0.15, "cover reaches forward: %s" % box)
	var sight: Node3D = v.get_marker(&"SightRail")
	assert_true(cover.is_ancestor_of(sight), "SightRail rides on the feed cover")
	var before: Vector3 = sight.global_position
	cover.rotation.x = deg_to_rad(78.0)
	assert_true(sight.global_position.y > before.y + 0.03, "opening lifts the rail (front edge up)")
	v.queue_free()


func _model_of(weapon_id: StringName) -> WeaponVisual:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	v.setup_ids(weapon_id, [] as Array[StringName])
	return v


func _local(v: WeaponVisual, n: Node3D) -> Vector3:
	return v.model.global_transform.affine_inverse() * n.global_position


## B4-12: animated parts. Pump guns carry `Pump`; bolt guns carry a `Bolt` whose origin is ON the bore
## axis (ENV A lifts it about local Z, then slides it +Z), the Heron .308 included (fixed in B4-12).
func test_animated_parts_and_pivots() -> void:
	for id: StringName in [&"weapon.plowman_12", &"weapon.mule_12"]:
		var v: WeaponVisual = _model_of(id)
		assert_true(v.model.find_child("Pump", true, false) is Node3D, "%s Pump" % id)
		v.queue_free()
	for id: StringName in [&"weapon.heron_308", &"weapon.condor_50"]:
		var v: WeaponVisual = _model_of(id)
		var bolt: Node3D = v.model.find_child("Bolt", true, false) as Node3D
		assert_true(bolt != null, "%s Bolt" % id)
		if bolt != null:
			var p: Vector3 = _local(v, bolt)
			var bore: Vector3 = _local(v, v.get_base_marker(&"Muzzle"))
			assert_near(p.x, 0.0, 0.0005, "%s bolt pivot on the centre plane" % id)
			assert_near(p.y, bore.y, 0.0005, "%s bolt pivot at bore height" % id)
			assert_true(p.z > -0.05 and p.z < 0.06, "%s bolt pivot at the receiver rear (%f)" % [id, p.z])
		v.queue_free()


## D-044 rule for every belt-fed LMG: a rear-hinged `FeedCover` carrying the optics rail.
func test_anvil_feed_cover_hinge() -> void:
	var v: WeaponVisual = _model_of(&"weapon.anvil_lmg")
	var cover: Node3D = v.model.find_child("FeedCover", true, false) as Node3D
	assert_true(cover != null, "FeedCover node")
	if cover == null:
		v.queue_free()
		return
	assert_true(cover.rotation.is_zero_approx(), "closed = rotation 0")
	var mesh: MeshInstance3D = cover as MeshInstance3D
	if mesh != null:
		var box: AABB = mesh.get_aabb()
		assert_true(box.end.z < 0.012 and box.position.z < -0.15, "cover lies in front of the rear hinge: %s" % box)
	var sight: Node3D = v.get_marker(&"SightRail")
	assert_true(cover.is_ancestor_of(sight), "SightRail rides on the feed cover")
	var before: Vector3 = sight.global_position
	cover.rotation.x = deg_to_rad(78.0)
	assert_true(sight.global_position.y > before.y + 0.03, "opening lifts the rail")
	v.queue_free()


## Revolver (B4-12): `Crane` (hinge pivot) swings the `Cylinder` out to the left with a positive rotation
## about local Z; the cylinder turns about its own axis; the speedloader `Magwell` rides on the cylinder.
func test_revolver_crane_and_cylinder() -> void:
	var v: WeaponVisual = _model_of(&"weapon.marshal_357")
	var crane: Node3D = v.model.find_child("Crane", true, false) as Node3D
	var cyl: Node3D = v.model.find_child("Cylinder", true, false) as Node3D
	assert_true(crane != null and cyl != null and crane.is_ancestor_of(cyl), "Crane/Cylinder")
	if crane == null or cyl == null:
		v.queue_free()
		return
	var magwell: Node3D = v.get_base_marker(&"Magwell")
	assert_true(cyl.is_ancestor_of(magwell), "Magwell rides on the cylinder")
	# Magwell convention: the insertion axis is the marker's up axis (Blender +Z = Godot +Y)
	assert_true(magwell.global_basis.y.normalized().dot(Vector3.FORWARD) > 0.99, "speedloader goes in forward (-Z)")
	var bore: Vector3 = _local(v, v.get_base_marker(&"Muzzle"))
	var c0: Vector3 = _local(v, cyl)
	assert_near(c0.x, 0.0, 0.0005, "cylinder axis on the centre plane")
	assert_true(c0.y < bore.y - 0.008, "cylinder axis below the bore (top chamber in line)")
	crane.rotation.z = deg_to_rad(80.0)
	var c1: Vector3 = _local(v, cyl)
	assert_true(c1.x < c0.x - 0.015, "crane swings the cylinder out to the left (%s -> %s)" % [c0, c1])
	crane.rotation.z = 0.0
	cyl.rotation.z = deg_to_rad(60.0)
	assert_true(_local(v, cyl).distance_to(c0) < 0.0001, "the cylinder turns about its own axis")
	v.queue_free()


## D-050 akimbo: the model is one gun plus an `Offhand` marker; WeaponVisual adds the second gun at
## that pose and mirrors every mod (and stock-part hiding) onto it.
func test_akimbo_offhand_mirrors_the_kit() -> void:
	var single: WeaponVisual = _model_of(&"weapon.warden_45")
	assert_false(single.is_akimbo(), "a single pistol has no offhand")
	assert_true(single.get_offhand_marker(&"Muzzle") == null, "no offhand marker")
	single.queue_free()
	var mods: Array[StringName] = [&"mod.akimbo_w45_suppressor", &"mod.akimbo_w45_reflex_sight",
		&"mod.akimbo_w45_extended_mag"]
	var v: WeaponVisual = _visual_for(&"weapon.akimbo_warden_45", mods)
	assert_true(v.is_akimbo() and v.offhand != null, "offhand gun")
	if v.offhand == null:
		v.queue_free()
		return
	assert_true(v.offhand.position.x < -0.1, "offhand gun sits to the left (%s)" % v.offhand.position)
	assert_false(v.model.is_ancestor_of(v.offhand), "offhand is a sibling, so base markers stay unique")
	assert_eq(v.attached.size(), 3, "three mods on the right gun")
	assert_eq(v.attached_offhand.size(), 3, "three mods on the left gun")
	for t: int in [Enums.ModType.SIGHT, Enums.ModType.MAGAZINE]:
		assert_false(v.stock_part(t as Enums.ModType).visible, "right stock part %d hidden" % t)
		assert_false(v.offhand_stock_part(t as Enums.ModType).visible, "left stock part %d hidden" % t)
	var left_muzzle: Node3D = v.get_offhand_marker(&"Muzzle")
	assert_true(v.attached_offhand[Enums.ModType.SUPPRESSOR].is_ancestor_of(left_muzzle), "left can owns its Muzzle")
	assert_ne(left_muzzle, v.get_marker(&"Muzzle"), "two muzzles")
	assert_true(left_muzzle.global_position.x < v.get_marker(&"Muzzle").global_position.x - 0.1, "left muzzle is left")
	v.setup_ids(&"weapon.akimbo_warden_45", [] as Array[StringName])
	assert_eq(v.attached_offhand.size(), 0, "rebuilt stock")
	assert_true(v.offhand_stock_part(Enums.ModType.SIGHT).visible, "left stock sight back")
	v.queue_free()

