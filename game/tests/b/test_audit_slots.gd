## D-118 weapon audit (slot gaps): the new PD2-style options are offered on their weapons, each has a model,
## non-zero deltas and strings; the stocks hide the base `StockMount/StockStock` in a WeaponVisual, and the
## muzzle devices / suppressor own the effective (outermost) `Muzzle`, ahead of the base model's. Side-ported
## devices also own the effective `MuzzlePortL`/`MuzzlePortR`, venting outward and not backwards (D-114 §8).
extends TestCase

## mod id -> [weapon id, ModType]
const NEW_MODS: Dictionary = {
	&"mod.bastion_collapsed_stock": [&"weapon.bastion_br", Enums.ModType.STOCK],
	&"mod.bastion_precision_stock": [&"weapon.bastion_br", Enums.ModType.STOCK],
	&"mod.lancet_collapsed_stock": [&"weapon.lancet_45", Enums.ModType.STOCK],
	&"mod.lancet_tactical_stock": [&"weapon.lancet_45", Enums.ModType.STOCK],
	&"mod.mastiff_collapsed_stock": [&"weapon.mastiff_45", Enums.ModType.STOCK],
	&"mod.mastiff_heavy_stock": [&"weapon.mastiff_45", Enums.ModType.STOCK],
	&"mod.harrow_collapsed_stock": [&"weapon.harrow_12", Enums.ModType.STOCK],
	&"mod.harrow_padded_stock": [&"weapon.harrow_12", Enums.ModType.STOCK],
	&"mod.brute_full_choke": [&"weapon.brute_12", Enums.ModType.BARREL_EXT],
	&"mod.mule_breacher_brake": [&"weapon.mule_12", Enums.ModType.BARREL_EXT],
	&"mod.gale_barrage_brake": [&"weapon.gale_mg", Enums.ModType.BARREL_EXT],
	&"mod.shrike_suppressor": [&"weapon.shrike_44", Enums.ModType.SUPPRESSOR],
}
## Devices with their own side ports (they carry MuzzlePortL/R).
const PORTED: Array[StringName] = [&"mod.mule_breacher_brake", &"mod.gale_barrage_brake"]
const PORTS: Array[StringName] = [&"MuzzlePortL", &"MuzzlePortR"]
const LIGHT_STOCKS: Array[StringName] = [
	&"mod.bastion_collapsed_stock", &"mod.lancet_collapsed_stock", &"mod.mastiff_collapsed_stock",
	&"mod.harrow_collapsed_stock",
]


func before_all() -> void:
	ContentDB.clear_cache()


func _visual(wid: StringName, mid: StringName) -> WeaponVisual:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	v.setup_ids(wid, [mid] as Array[StringName])
	return v


func test_each_new_mod_is_offered_in_its_slot() -> void:
	for mid: StringName in NEW_MODS:
		var wid: StringName = NEW_MODS[mid][0]
		var t: int = NEW_MODS[mid][1]
		var w: WeaponDef = ContentDB.weapon(wid)
		assert_true(w != null, "%s exists" % wid)
		if w == null:
			continue
		var slot: Array = w.mod_slots.get(t, [])
		assert_true(slot.has(mid), "%s offers %s in slot %d" % [wid, mid, t])
		assert_false(w.default_mods.values().has(mid), "%s is optional" % mid)


func test_each_new_mod_has_model_deltas_and_strings() -> void:
	for mid: StringName in NEW_MODS:
		var m: WeaponModDef = ContentDB.mod(mid)
		assert_true(m != null, "%s def" % mid)
		if m == null:
			continue
		assert_eq(int(m.mod_type), int(NEW_MODS[mid][1]), "%s type" % mid)
		assert_true(m.model != null, "%s model" % mid)
		assert_true(m.price > 0 and m.unlock == &"", "%s priced, unlocked like its siblings" % mid)
		var d: WeaponStats = m.delta
		assert_true(d != null, "%s delta" % mid)
		if d == null:
			continue
		var nonzero: bool = d.concealment != 0 or d.damage != 0.0 or d.recoil_kick_deg != 0.0 \
				or d.recoil_horizontal_deg != 0.0 or d.spread_deg_ads != 0.0 or d.spread_deg_hip != 0.0
		assert_true(nonzero, "%s has non-zero deltas" % mid)
		for suffix: String in [".name", ".desc"]:
			var key: String = "item." + String(mid) + suffix
			assert_ne(UiText.t(StringName(key)), key, "%s string" % key)


func test_stock_pairs_trade_concealment_for_stability() -> void:
	for mid: StringName in NEW_MODS:
		if int(NEW_MODS[mid][1]) != Enums.ModType.STOCK:
			continue
		var d: WeaponStats = ContentDB.mod(mid).delta
		if LIGHT_STOCKS.has(mid):
			assert_true(d.concealment > 0 and d.recoil_kick_deg > 0.0 and d.spread_deg_ads > 0.0,
				"%s: lighter = hides better, less stable/accurate" % mid)
		else:
			assert_true(d.concealment < 0 and d.recoil_kick_deg < 0.0 and d.spread_deg_ads < 0.0,
				"%s: heavier = steadier and more accurate, hides worse" % mid)


func test_suppressor_silences_and_conflicts_with_the_carbine_barrel() -> void:
	var m: WeaponModDef = ContentDB.mod(&"mod.shrike_suppressor")
	assert_true(m.delta.suppressed and m.delta.noise_radius_m <= 1.0, "suppressed")
	assert_true(m.delta.damage < 0.0 and m.delta.concealment < 0, "PD2 cost: damage and concealment")
	var s: WeaponStats = LoadoutResolver.resolve_weapon(&"weapon.shrike_44", [&"mod.shrike_suppressor"] as Array[StringName])
	assert_near(s.suppression, 0.0, 0.0001, "threat 0 once suppressed")
	assert_eq(ContentDB.weapon(&"weapon.shrike_44").fire_cue_suppressed, &"cue.weapon_sniper_fire_suppressed")
	assert_true(m.conflicts.has(&"mod.shrike_carbine_barrel"), "the can sits on the long barrel only")


func test_stock_mods_hide_stock_stock() -> void:
	for mid: StringName in NEW_MODS:
		if int(NEW_MODS[mid][1]) != Enums.ModType.STOCK:
			continue
		var v: WeaponVisual = _visual(NEW_MODS[mid][0], mid)
		var stock: Node3D = v.stock_part(Enums.ModType.STOCK)
		assert_true(stock != null, "%s: base has StockStock" % mid)
		if stock != null:
			assert_eq(String(stock.name), "StockStock", "%s: stock part name" % mid)
			assert_eq(stock.get_parent(), v.get_base_marker(&"StockMount"), "%s: under StockMount" % mid)
			assert_false(stock.visible, "%s hides StockStock" % mid)
		var inst: Node3D = v.attached.get(Enums.ModType.STOCK)
		assert_true(inst != null and inst.get_parent() == v.get_base_marker(&"StockMount"), "%s at StockMount" % mid)
		v.queue_free()


func test_muzzle_mods_own_the_outermost_muzzle() -> void:
	for mid: StringName in NEW_MODS:
		var t: int = NEW_MODS[mid][1]
		if t != Enums.ModType.BARREL_EXT and t != Enums.ModType.SUPPRESSOR:
			continue
		var v: WeaponVisual = _visual(NEW_MODS[mid][0], mid)
		var inst: Node3D = v.attached.get(t)
		var base: Node3D = v.get_base_marker(&"Muzzle")
		var own: Node3D = v.get_marker(&"Muzzle")
		assert_true(inst != null and own != null and base != null, "%s attached with markers" % mid)
		if inst == null or own == null or base == null:
			v.queue_free()
			continue
		assert_eq(inst.get_parent(), base, "%s attaches at the base Muzzle" % mid)
		assert_true(inst.is_ancestor_of(own), "%s owns the effective Muzzle" % mid)
		assert_true(own.global_position.z < base.global_position.z - 0.02, "%s Muzzle further forward" % mid)
		# outermost: no mesh of the device reaches past its own Muzzle by more than a millimetre
		for c: Node in inst.find_children("*", "Node3D", true, false):
			if c is Node3D and not (c is MeshInstance3D) and c != own:
				assert_true((c as Node3D).global_position.z >= own.global_position.z - 0.0001,
					"%s Muzzle ahead of %s" % [mid, c.name])
		if PORTED.has(mid):
			for port: StringName in PORTS:
				var p: Node3D = v.get_marker(port)
				assert_true(p != null and inst.is_ancestor_of(p), "%s owns %s" % [mid, port])
				if p == null:
					continue
				var vent: Vector3 = -p.global_transform.basis.z.normalized()
				var side: float = -1.0 if port == &"MuzzlePortL" else 1.0
				assert_true(vent.x * side > 0.1, "%s %s vents outward (%s)" % [mid, port, vent])
				assert_true(vent.dot(Vector3.FORWARD) >= 0.0, "%s %s does not vent backwards" % [mid, port])
				var behind: float = p.global_position.z - own.global_position.z
				assert_true(behind > 0.0 and behind <= 0.08, "%s %s %.3f m behind the Muzzle" % [mid, port, behind])
		v.queue_free()
