## D-115: the shared rail foregrip `mod.rail_vertical_grip` is offered in FOREGRIP by every weapon that has an
## `Underbarrel` rail but no grip of its own, steadies the weapon through LoadoutResolver, and attaches under
## the base model's `Underbarrel` (hiding a `StockForegrip`, when there is one). Like the per-weapon
## vertical grips it carries its own `LeftHandIK` at the palm contact (lead vgrip plan), so the hand holds the grip.
extends TestCase

const GRIP: StringName = &"mod.rail_vertical_grip"
const WEAPONS: Array[StringName] = [
	&"weapon.drover_762", &"weapon.lark_carbine", &"weapon.ferret_9",
	&"weapon.hornet_9", &"weapon.hush_9", &"weapon.wasp_pdw",
]


func before_all() -> void:
	ContentDB.clear_cache()


func test_grip_def_shape() -> void:
	var mod: WeaponModDef = ContentDB.mod(GRIP)
	assert_true(mod != null, "rail grip def exists")
	if mod == null:
		return
	assert_eq(mod.mod_type, Enums.ModType.FOREGRIP)
	assert_true(mod.model != null, "has a model")
	assert_true(mod.delta.recoil_kick_deg < 0.0 and mod.delta.recoil_horizontal_deg < 0.0, "steadier")
	assert_true(mod.delta.concealment < 0 and mod.delta.concealment >= -2, "small concealment cost")
	assert_ne(UiText.t(&"item.mod.rail_vertical_grip.name"), "item.mod.rail_vertical_grip.name", "name string")
	assert_ne(UiText.t(&"item.mod.rail_vertical_grip.desc"), "item.mod.rail_vertical_grip.desc", "desc string")


func test_each_weapon_offers_the_grip_in_foregrip() -> void:
	for wid: StringName in WEAPONS:
		var def: WeaponDef = ContentDB.weapon(wid)
		assert_true(def != null, "%s exists" % wid)
		if def == null:
			continue
		var slot: Array = def.mod_slots.get(Enums.ModType.FOREGRIP, [])
		assert_true(slot.has(GRIP), "%s offers the rail grip in FOREGRIP" % wid)


func test_grip_resolves_steadier() -> void:
	for wid: StringName in WEAPONS:
		var stock: WeaponStats = LoadoutResolver.resolve_weapon(wid, [] as Array[StringName])
		var grip: WeaponStats = LoadoutResolver.resolve_weapon(wid, [GRIP] as Array[StringName])
		assert_true(grip.recoil_kick_deg < stock.recoil_kick_deg, "%s: less vertical kick" % wid)
		assert_true(grip.recoil_horizontal_deg < stock.recoil_horizontal_deg, "%s: less horizontal kick" % wid)
		assert_eq(grip.concealment, stock.concealment - 1, "%s: concealment -1" % wid)


func test_grip_attaches_under_underbarrel() -> void:
	for wid: StringName in WEAPONS:
		var v: WeaponVisual = WeaponVisual.new()
		add_child(v)
		v.setup_ids(wid, [] as Array[StringName])
		var had_stock_foregrip: bool = v.stock_part(Enums.ModType.FOREGRIP) != null
		v.setup_ids(wid, [GRIP] as Array[StringName])
		var inst: Node3D = v.attached.get(Enums.ModType.FOREGRIP)
		assert_true(inst != null, "%s: grip attached" % wid)
		if inst != null:
			assert_eq(inst.get_parent(), v.get_base_marker(&"Underbarrel"), "%s: under Underbarrel" % wid)
			assert_eq(inst.position, Vector3.ZERO, "%s: snaps onto the marker" % wid)
			assert_true(inst.find_child("Foregrip", true, false) != null, "%s: grip mesh" % wid)
		if had_stock_foregrip:
			assert_false(v.stock_part(Enums.ModType.FOREGRIP).visible, "%s: StockForegrip hidden" % wid)
		# lead vgrip plan: the grip's own LeftHandIK wins over the base marker (the hand holds the grip)
		var hand: Node3D = v.get_marker(&"LeftHandIK")
		assert_true(hand != null and inst != null and inst.is_ancestor_of(hand), "%s: hand target is the grip's" % wid)
		var base_hand: Node3D = v.get_base_marker(&"LeftHandIK")
		assert_true(base_hand != null and not inst.is_ancestor_of(base_hand), "%s: base marker is the weapon's own" % wid)
		v.queue_free()


## Lead vgrip plan: EVERY vertical-grip mod carries a LeftHandIK at the palm contact, below the rail.
func test_every_vertical_grip_carries_a_hand_marker() -> void:
	var ids: Array[StringName] = [&"mod.corsair_vertical_grip", &"mod.tern_vertical_grip", &"mod.lancet_vertical_grip",
			&"mod.mastiff_vertical_grip", &"mod.thumper_vertical_grip", &"mod.rail_vertical_grip"]
	for id: StringName in ids:
		var m: WeaponModDef = ContentDB.mod(id)
		if m == null:
			fail("missing %s" % id)
			continue
		var inst: Node3D = m.model.instantiate() as Node3D
		var hand: Node3D = inst.find_child("LeftHandIK", true, false) as Node3D
		assert_true(hand != null, "%s has a LeftHandIK" % id)
		if hand != null:
			var p: Vector3 = inst.to_local(hand.global_position) if inst.is_inside_tree() else hand.position
			assert_true(p.y < -0.02, "%s hand marker hangs on the grip (y %.3f)" % [id, p.y])
		inst.free()
