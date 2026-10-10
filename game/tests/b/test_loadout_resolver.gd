## B1-02 golden tests: concealment curve, DR, resolved weapon stats, mod validation.
extends TestCase

const ANCHORS: Dictionary = {
	119: 3, 116: 7, 113: 12, 110: 16, 107: 20, 104: 26, 101: 35,
	100: 43, 97: 49, 94: 58, 93: 63, 92: 69, 91: 75,
}
const PISTOL: StringName = &"weapon.kestrel_p9"


func before_all() -> void:
	ContentDB.clear_cache()


func after_each() -> void:
	Log.capture = false
	Log.captured.clear()


func _stock_loadout() -> Loadout:
	var l: Loadout = Loadout.new()
	l.secondary = PISTOL
	l.melee = &"melee.folding_knife"
	l.armor = &"armor.tailored_suit"
	return l


func _curve() -> ConcealmentCurve:
	return LoadoutResolver.curve_tweak()


func test_curve_anchor_points() -> void:
	for total: int in ANCHORS:
		assert_eq(LoadoutResolver.detection_risk_for_total(total), ANCHORS[total], "total %d" % total)


func test_curve_bounds_and_monotonic() -> void:
	var c: ConcealmentCurve = _curve()
	assert_eq(c.dr_by_total.size(), 29, "91..119 inclusive")
	assert_eq(c.max_total(), 119)
	assert_eq(c.dr_for_total(0), 75)
	assert_eq(c.dr_for_total(91), 75)
	assert_eq(c.dr_for_total(119), 3)
	assert_eq(c.dr_for_total(150), 3)
	for t: int in range(92, 120):
		assert_true(c.dr_for_total(t) < c.dr_for_total(t - 1), "strictly decreasing at %d" % t)


func test_detection_mult_table() -> void:
	var c: ConcealmentCurve = _curve()
	assert_near(c.detection_mult(3), 1.55)
	assert_near(c.detection_mult(35), 1.0)
	assert_near(c.detection_mult(75), 0.3)
	assert_near(c.detection_mult(63), 0.5)
	assert_near(c.detection_mult(5), 1.5125)
	assert_near(c.detection_mult(1), 1.55, 0.0001, "clamped low")
	assert_near(c.detection_mult(90), 0.3, 0.0001, "clamped high")


## Research §3.3: suit 30 + 30-concealment melee + 2 (Inner Pockets) + 1 (perk card) = 63; 56 from
## the two guns reaches 119 -> DR 3; 55 gives 118 -> DR above 3.
func test_research_worked_example() -> void:
	var base: int = 30 + 30 + 2 + 1
	assert_eq(base, 63)
	assert_eq(LoadoutResolver.detection_risk_for_total(base + 56), 3)
	assert_true(LoadoutResolver.detection_risk_for_total(base + 55) > 3)
	assert_eq(LoadoutResolver.detection_risk_for_total(base + 55), 4)


func test_stock_suit_knife_pistol_loadout() -> void:
	var r: Loadout = LoadoutResolver.resolve(_stock_loadout())
	var bd: Dictionary = LoadoutResolver.concealment_breakdown(_stock_loadout())
	assert_eq(bd["primary"], 30, "P1 rule: empty primary = empty_slot_concealment")
	assert_eq(bd["secondary"], 30)
	assert_eq(bd["melee"], 30)
	assert_eq(bd["armor"], 30)
	assert_eq(bd["bonus"], 0)
	assert_eq(bd["total"], 120)
	assert_eq(r.concealment_total, 120)
	assert_eq(r.detection_risk, 3)
	assert_eq(bd["detection_risk"], 3)
	assert_true(r.resolved_primary == null, "no primary in P1")
	assert_true(r.resolved_secondary != null)
	assert_eq(r.modifiers, {})


func test_patrol_vest_raises_detection_risk() -> void:
	var l: Loadout = _stock_loadout()
	l.armor = &"armor.patrol_vest"
	var r: Loadout = LoadoutResolver.resolve(l)
	assert_eq(r.concealment_total, 113)
	assert_eq(r.detection_risk, 12)
	assert_true(r.detection_risk > LoadoutResolver.resolve(_stock_loadout()).detection_risk)


func test_suppressor_lowers_concealment_and_silences() -> void:
	var l: Loadout = _stock_loadout()
	l.secondary_mods = [&"mod.p9_suppressor"] as Array[StringName]
	var r: Loadout = LoadoutResolver.resolve(l)
	var base: WeaponStats = ContentDB.weapon(PISTOL).base
	assert_false(base.suppressed)
	assert_true(r.resolved_secondary.suppressed)
	assert_true(r.resolved_secondary.noise_radius_m <= 1.0, "suppressed noise radius ~0-1 m (L3.7)")
	assert_eq(r.resolved_secondary.concealment, 28)
	assert_eq(r.concealment_total, 118)
	assert_eq(r.detection_risk, 4)


func test_resolved_stats_equal_base_plus_deltas() -> void:
	var mods: Array[StringName] = [&"mod.p9_extended_mag", &"mod.p9_reflex_sight", &"mod.p9_suppressor"]
	var got: WeaponStats = LoadoutResolver.resolve_weapon(PISTOL, mods)
	var def: WeaponDef = ContentDB.weapon(PISTOL)
	var want: WeaponStats = def.base
	# Ordered by ModType: SUPPRESSOR(2), SIGHT(3), MAGAZINE(7).
	for mid: StringName in [&"mod.p9_suppressor", &"mod.p9_reflex_sight", &"mod.p9_extended_mag"]:
		want = want.plus(ContentDB.mod(mid).delta)
	for p: Dictionary in want.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE) or p["name"] == "script":
			continue
		var n: StringName = p["name"]
		if want.get(n) is float:
			assert_near(got.get(n), want.get(n), 0.0001, String(n))
		else:
			assert_eq(got.get(n), want.get(n), String(n))
	assert_eq(got.mag_size, 25)
	assert_eq(got.total_ammo, 170)
	assert_eq(got.concealment, 25)
	assert_near(got.magnification, 1.1)
	assert_near(got.damage, 33.0)
	assert_near(got.reload_time_s, 1.8)
	assert_eq(got.pellets, 1, "deltas must not add pellets")
	assert_near(got.falloff_start_m, 15.0, 0.0001, "deltas must not shift falloff")
	assert_eq(LoadoutResolver.detection_risk_for_total(30 + 30 + 30 + got.concealment), 9)


func test_stock_mods_do_not_change_base() -> void:
	var got: WeaponStats = LoadoutResolver.resolve_weapon(PISTOL, [] as Array[StringName])
	var base: WeaponStats = ContentDB.weapon(PISTOL).base
	assert_eq(got.mag_size, base.mag_size)
	assert_near(got.damage, base.damage)
	assert_near(got.ads_time_s, base.ads_time_s)
	assert_eq(got.concealment, base.concealment)
	assert_ne(got, base, "resolved stats are a copy")


func test_equipped_mod_replaces_default_in_slot() -> void:
	var def: WeaponDef = ContentDB.weapon(PISTOL)
	var applied: Array[WeaponModDef] = LoadoutResolver.applied_mods(def, [&"mod.p9_reflex_sight"] as Array[StringName])
	var ids: Array[StringName] = []
	for m: WeaponModDef in applied:
		ids.append(m.id)
	assert_eq(ids, [&"mod.p9_reflex_sight", &"mod.p9_standard_mag"] as Array[StringName])


func test_illegal_mods_rejected() -> void:
	Log.capture = true
	# Second SIGHT in the same slot.
	var got: WeaponStats = LoadoutResolver.resolve_weapon(
		PISTOL, [&"mod.p9_reflex_sight", &"mod.p9_iron_sights"] as Array[StringName])
	assert_near(got.magnification, 1.1, 0.0001, "first sight kept")
	assert_true(_logged("slot SIGHT already holds"), "duplicate slot logged")
	# Mod type the weapon has no slot for.
	Log.captured.clear()
	var def: WeaponDef = ContentDB.weapon(PISTOL).duplicate() as WeaponDef
	def.mod_slots = {Enums.ModType.SIGHT: [&"mod.p9_reflex_sight"]}
	def.default_mods = {}
	var applied: Array[WeaponModDef] = LoadoutResolver.applied_mods(def, [&"mod.p9_suppressor"] as Array[StringName])
	assert_eq(applied.size(), 0)
	assert_true(_logged("no slot for mod type SUPPRESSOR"))
	# Mod type has a slot but the mod is not in its list.
	Log.captured.clear()
	def.mod_slots = {Enums.ModType.SUPPRESSOR: []}
	applied = LoadoutResolver.applied_mods(def, [&"mod.p9_suppressor"] as Array[StringName])
	assert_eq(applied.size(), 0)
	assert_true(_logged("not allowed in slot SUPPRESSOR"))
	# Unknown id.
	Log.captured.clear()
	got = LoadoutResolver.resolve_weapon(PISTOL, [&"mod.nope"] as Array[StringName])
	assert_eq(got.concealment, 30)
	assert_true(_logged("mod.nope"))


func test_conflicting_mods_rejected() -> void:
	Log.capture = true
	var def: WeaponDef = ContentDB.weapon(PISTOL)
	var sight: WeaponModDef = ContentDB.mod(&"mod.p9_reflex_sight")
	var saved: Array[StringName] = sight.conflicts.duplicate()
	sight.conflicts = [&"mod.p9_suppressor"] as Array[StringName]
	var applied: Array[WeaponModDef] = LoadoutResolver.applied_mods(
		def, [&"mod.p9_suppressor", &"mod.p9_reflex_sight"] as Array[StringName])
	sight.conflicts = saved
	var ids: Array[StringName] = []
	for m: WeaponModDef in applied:
		ids.append(m.id)
	assert_false(ids.has(&"mod.p9_reflex_sight"))
	assert_true(ids.has(&"mod.p9_suppressor"))
	assert_true(_logged("conflicts with mod.p9_suppressor"))


func test_resolve_returns_copy() -> void:
	var l: Loadout = _stock_loadout()
	l.armor = &"armor.patrol_vest"
	var r: Loadout = LoadoutResolver.resolve(l)
	assert_ne(r, l)
	assert_eq(l.detection_risk, 75, "input untouched")
	assert_true(l.resolved_secondary == null, "input untouched")
	assert_eq(r.secondary, l.secondary)


func test_unknown_skill_is_logged_and_grants_nothing() -> void:
	Log.capture = true
	var l: Loadout = _stock_loadout()
	l.skills = {&"skill.shade.not_real": 2}
	assert_eq(LoadoutResolver.resolve_modifiers(l), {})
	assert_true(_logged("skill.shade.not_real"))


func _logged(fragment: String) -> bool:
	for line: String in Log.captured:
		if line.contains(fragment):
			return true
	return false
