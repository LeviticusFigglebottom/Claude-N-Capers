## D-118 item 2 (after round 222): shotgun AMMO mods in the UI numbers. AmmoStats.apply mirrors A's runtime
## (ShotgunAmmo.pellets / pellet_damage_mult, range_mult on the falloff, armor pierce), so the workshop and
## loadout stat panels and the firing range readout / falloff graph agree with a real shot.
extends TestCase

const PLOWMAN: StringName = &"weapon.plowman_12"
const MULE: StringName = &"weapon.mule_12"
const SLUG: StringName = &"mod.shotgun_slug"
const HE: StringName = &"mod.shotgun_he"
const FLECHETTE: StringName = &"mod.shotgun_flechette"
const DRAGON: StringName = &"mod.shotgun_dragons_breath"


func _mods(ids: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in ids:
		out.append(StringName(id))
	return out


func _stats(weapon: StringName, mods: Array[StringName]) -> WeaponStats:
	return LoadoutResolver.resolve_weapon(weapon, mods)


func _need(ids: Array) -> bool:
	for id: Variant in ids:
		if ContentDB.mod(StringName(id)) == null:
			skip("no %s in this tree" % id)
			return false
	return true


func test_buckshot_is_unchanged() -> void:
	var s: WeaponStats = _stats(PLOWMAN, _mods([]))
	assert_true(AmmoStats.apply(s, ContentDB.weapon(PLOWMAN), _mods([])) == s, "no ammo type: the same object")
	var pistol: StringName = &"weapon.kestrel_p9"
	var p: WeaponStats = _stats(pistol, _mods([]))
	assert_true(AmmoStats.apply(p, ContentDB.weapon(pistol), _mods([])) == p, "not a shotgun")


func test_each_ammo_keeps_the_shot_and_changes_the_pellets() -> void:
	if not _need([SLUG, HE, FLECHETTE, DRAGON]):
		return
	var def: WeaponDef = ContentDB.weapon(PLOWMAN)
	for id: StringName in [SLUG, HE, FLECHETTE, DRAGON]:
		var mods: Array[StringName] = _mods([id])
		var s: WeaponStats = _stats(PLOWMAN, mods)
		var a: WeaponStats = AmmoStats.apply(s, def, mods)
		var prof: Dictionary = ShotgunAmmo.profile(SpecialWeapons.params_of(def, mods))
		assert_eq(a.pellets, ShotgunAmmo.pellets(s.pellets, prof), "%s pellets as CrewWeapons fires them" % id)
		assert_near(a.damage * a.pellets, s.damage * s.pellets, 0.01, "%s: per-shot total kept (LEAD ruling)" % id)
		assert_near(StatCalculator.display(a)["damage"], StatCalculator.display(s)["damage"], 0.11,
				"%s: the panel's per-shot damage is the stock one" % id)
		var rm: float = float(prof["range_mult"])
		assert_near(a.falloff_start_m, s.falloff_start_m * rm, 0.001, "%s falloff start x range_mult" % id)
		assert_near(a.falloff_end_m, s.falloff_end_m * rm, 0.001, "%s falloff end x range_mult" % id)
		assert_true(a.armor_pierce >= s.armor_pierce, "%s never lowers armor pierce" % id)
	var slug: WeaponStats = AmmoStats.apply(_stats(PLOWMAN, _mods([SLUG])), def, _mods([SLUG]))
	assert_eq(slug.pellets, 1, "a slug is one ray")
	assert_near(slug.armor_pierce, 1.0, 0.001, "slug pierces armor")
	var fl: WeaponStats = AmmoStats.apply(_stats(PLOWMAN, _mods([FLECHETTE])), def, _mods([FLECHETTE]))
	assert_true(fl.pellets > 10, "flechette fires more, smaller pellets (%d)" % fl.pellets)


## The range readout's per-pellet damage at any distance equals CrewWeapons.damage_at's body damage (no skills).
func test_range_math_matches_the_runtime_formula() -> void:
	if not _need([DRAGON, SLUG]):
		return
	var def: WeaponDef = ContentDB.weapon(PLOWMAN)
	for id: StringName in [DRAGON, SLUG]:
		var mods: Array[StringName] = _mods([id])
		var s: WeaponStats = _stats(PLOWMAN, mods)
		var a: WeaponStats = AmmoStats.apply(s, def, mods)
		var prof: Dictionary = ShotgunAmmo.profile(SpecialWeapons.params_of(def, mods))
		var rm: float = maxf(float(prof["range_mult"]), 0.01)
		var pellets: int = ShotgunAmmo.pellets(s.pellets, prof)
		for d: float in [0.0, s.falloff_start_m * 0.9, (s.falloff_start_m + s.falloff_end_m) * 0.5, s.falloff_end_m * 1.2]:
			var runtime: float = s.damage * float(maxi(s.pellets, 1)) / float(pellets) * CombatSystem.falloff_mult(s, d / rm)
			assert_near(RangeMath.pellet_damage(a, d), runtime, 0.001, "%s at %.1f m" % [id, d])


func test_workshop_damage_row_shows_the_pellet_split() -> void:
	assert_eq(WorkshopScreen.damage_text({"shown": {"damage": 35.0}, "pellets": 1, "ammo": &""}), "35",
			"a rifle shows the plain number")
	var t: String = WorkshopScreen.damage_text({"shown": {"damage": 160.0}, "pellets": 10, "ammo": &""})
	assert_true(t.begins_with("160") and t.contains("10") and t.contains("16"), t)
	var slug: String = WorkshopScreen.damage_text({"shown": {"damage": 160.0}, "pellets": 1, "ammo": &"slug"})
	assert_true(slug.contains("(1 ") and slug.contains("160)"), "slug: one ray carries the shot (%s)" % slug)


func test_workshop_model_reads_the_loaded_ammo() -> void:
	if not _need([SLUG]):
		return
	var m: WorkshopModel = WorkshopModel.new(PlayerProfile.new_default())
	m.select_weapon(PLOWMAN)
	m.pick(int(ContentDB.mod(SLUG).mod_type), SLUG)
	var rows: Dictionary = m.stat_rows()
	assert_eq(int(rows.get("pellets", 0)), 1, "the preview fires one slug")
	assert_eq(StringName(rows.get("ammo", &"")), &"slug")


func test_firing_range_readout_uses_the_ammo() -> void:
	if not _need([SLUG]):
		return
	var r: FiringRange = (load("res://content/range/firing_range.tscn") as PackedScene).instantiate() as FiringRange
	add_child(r)
	await wait_frames(2)
	r.select_weapon(PLOWMAN)
	r.set_mod(int(ContentDB.mod(SLUG).mod_type), SLUG)
	await wait_frames(2)
	assert_eq(r.weapon_stats.pellets, 1, "the range simulates one slug, not 10 pellets")
	assert_near(r.weapon_stats.armor_pierce, 1.0, 0.001)
	r.queue_free()
	await wait_frames(2)
