## D-115: the shared rail foregrip `mod.rail_vertical_grip` is offered in FOREGRIP by every weapon that has an
## `Underbarrel` rail but no grip of its own, steadies the weapon through LoadoutResolver, and attaches under
## the base model's `Underbarrel` (hiding a `StockForegrip`, when there is one). Like the per-weapon
## vertical grips it carries no `LeftHandIK`, so the support-hand target stays the base model's.
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
		# no own LeftHandIK: the support hand keeps the base marker (like the per-weapon vertical grips)
		assert_true(v.get_base_marker(&"LeftHandIK") != null, "%s: base LeftHandIK" % wid)
		assert_eq(v.get_marker(&"LeftHandIK"), v.get_base_marker(&"LeftHandIK"), "%s: hand target unchanged" % wid)
		v.queue_free()
