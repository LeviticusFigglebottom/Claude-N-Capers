## B1-01: every content data file loads, ids are unique and match their file, P1 data exists.
extends TestCase

## data folder -> id prefix
const ID_PREFIX: Dictionary = {
	&"weapons": "weapon", &"mods": "mod", &"melee": "melee", &"armor": "armor",
	&"deployables": "deployable", &"loot": "loot",
}
const DIFFICULTY_FILES: Dictionary = {
	Enums.Difficulty.ROUTINE: "routine", Enums.Difficulty.TENSE: "tense",
	Enums.Difficulty.HAZARDOUS: "hazardous", Enums.Difficulty.BRUTAL: "brutal",
	Enums.Difficulty.LETHAL: "lethal", Enums.Difficulty.CATACLYSM: "cataclysm",
}


func before_all() -> void:
	ContentDB.clear_cache()


func _files(kind: StringName) -> Array[String]:
	var out: Array[String] = []
	var dir: String = "%s/%s" % [ContentDB.DATA_ROOT, kind]
	for f: String in ResourceLoader.list_directory(dir):
		if f.ends_with(".tres"):
			out.append(dir.path_join(f))
	return out


func test_every_data_file_loads_with_unique_id_matching_file() -> void:
	for kind: StringName in ID_PREFIX:
		var files: Array[String] = _files(kind)
		assert_true(files.size() > 0, "%s has data" % kind)
		var seen: Dictionary = {}
		for path: String in files:
			var res: Resource = load(path)
			assert_true(res != null, "loads %s" % path)
			if res == null:
				continue
			var id: StringName = res.get(&"id")
			var expected: StringName = StringName("%s.%s" % [ID_PREFIX[kind], path.get_file().get_basename()])
			assert_eq(id, expected, "id matches file %s" % path)
			assert_false(seen.has(id), "duplicate id %s" % id)
			seen[id] = true
		assert_eq(ContentDB.all_of(kind).size(), files.size(), "ContentDB indexes every %s file" % kind)


func test_p1_ids_resolve() -> void:
	assert_true(ContentDB.weapon(&"weapon.kestrel_p9") != null)
	for m: StringName in [&"mod.p9_suppressor", &"mod.p9_reflex_sight", &"mod.p9_extended_mag"]:
		assert_true(ContentDB.mod(m) != null, String(m))
	assert_true(ContentDB.melee(&"melee.folding_knife") != null)
	assert_true(ContentDB.armor(&"armor.tailored_suit") != null)
	assert_true(ContentDB.armor(&"armor.patrol_vest") != null)
	for d: StringName in [&"deployable.doctor_bag", &"deployable.ammo_bag", &"deployable.body_bag_case"]:
		assert_true(ContentDB.deployable(d) != null, String(d))
	for l: StringName in [&"loot.jewelry", &"loot.cash", &"loot.body_bag"]:
		assert_true(ContentDB.loot(l) != null, String(l))
	assert_true(ContentDB.tweak(&"concealment_curve") is ConcealmentCurve)
	assert_true(ContentDB.tweak(&"display_stats") is DisplayStatTweak)


func test_unknown_id_logs_error_and_returns_null() -> void:
	Log.capture = true
	Log.captured.clear()
	assert_true(ContentDB.weapon(&"weapon.does_not_exist") == null)
	assert_true(Log.captured.size() > 0 and Log.captured[0].contains("weapon.does_not_exist"))
	Log.capture = false


func test_all_six_difficulties_exist_with_exact_multipliers() -> void:
	var payout: Array[float] = [1.0, 2.0, 2.6, 4.2, 7.2, 9.2]
	var xp: Array[float] = [1.0, 2.0, 5.0, 10.0, 11.5, 14.0]
	assert_eq(ContentDB.all_difficulties().size(), 6)
	for d: int in DIFFICULTY_FILES:
		var def: DifficultyDef = ContentDB.difficulty(d as Enums.Difficulty)
		assert_true(def != null, "difficulty %d" % d)
		if def == null:
			continue
		assert_eq(ContentDB.all_difficulties()[d], def, "sorted by enum")
		assert_eq(def.resource_path.get_file().get_basename(), DIFFICULTY_FILES[d])
		assert_eq(def.payout_mult, payout[d], "payout %s" % def.display_name)
		assert_eq(def.xp_mult, xp[d], "xp %s" % def.display_name)
		for k: String in ["revive_health_frac", "armor_invuln_s", "custody_auto_release_s", "hostage_assault_delay_s"]:
			assert_has(def.params, k, def.display_name)
	var brutal: DifficultyDef = ContentDB.difficulty(Enums.Difficulty.BRUTAL)
	assert_eq(brutal.special_limits[&"enemy.bulwark"], 4, "Overkill shield cap")
	assert_eq(brutal.special_limits[&"enemy.stinger"], 2, "Overkill taser cap")


func test_armor_tiers_match_research_table() -> void:
	var suit: ArmorDef = ContentDB.armor(&"armor.tailored_suit")
	assert_eq(suit.armor, 20.0)
	assert_eq(suit.concealment, 30)
	assert_near(suit.dodge, 0.05)
	assert_near(suit.move_speed_mult, 1.0)
	assert_near(suit.stamina_mult, 1.0)
	var vest: ArmorDef = ContentDB.armor(&"armor.patrol_vest")
	assert_eq(vest.armor, 60.0)
	assert_eq(vest.concealment, 23)
	assert_near(vest.dodge, -0.10)
	assert_near(vest.move_speed_mult, 35.0 / 36.8, 0.001)
	assert_near(vest.stamina_mult, 47.5 / 51.3, 0.001)
	assert_eq(vest.unlock_level, 1)
	assert_eq(ContentDB.all_armors().size(), 7, "seven tiers")


func test_deployable_uses() -> void:
	assert_eq(ContentDB.deployable(&"deployable.doctor_bag").uses, 2)
	assert_eq(ContentDB.deployable(&"deployable.ammo_bag").uses, 4)
	assert_eq(ContentDB.deployable(&"deployable.body_bag_case").kind, &"body_bag_case")


func test_weapon_mod_slots_reference_existing_mods_of_matching_type() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		assert_true(w.base != null, "%s has base stats" % w.id)
		for slot: Variant in w.mod_slots:
			for mid: Variant in w.mod_slots[slot]:
				var m: WeaponModDef = ContentDB.mod(StringName(mid))
				assert_true(m != null, "%s lists %s" % [w.id, mid])
				if m != null:
					assert_eq(int(m.mod_type), int(slot), "%s slot type" % mid)
		for slot: Variant in w.default_mods:
			assert_true(w.mod_slots.has(slot), "%s default slot listed" % w.id)
			assert_true((w.mod_slots[slot] as Array).has(w.default_mods[slot]), "%s default allowed" % w.id)


## WeaponStats.plus adds pellets/falloff/equip/ads; their non-zero schema defaults must be zeroed in
## every delta resource or each mod would silently add a pellet and 20 m of falloff.
func test_mod_deltas_zero_non_zero_defaults() -> void:
	for m: WeaponModDef in ContentDB.all_mods():
		assert_true(m.delta != null, "%s has delta" % m.id)
		if m.delta == null:
			continue
		assert_eq(m.delta.pellets, 0, "%s pellets" % m.id)
		assert_eq(m.delta.falloff_start_m, 0.0, "%s falloff_start" % m.id)
		assert_eq(m.delta.falloff_end_m, 0.0, "%s falloff_end" % m.id)
		assert_true(m.delta.equip_time_s >= 0.0 and m.delta.equip_time_s < 0.3, "%s equip" % m.id)
		assert_true(m.delta.ads_time_s >= 0.0 and m.delta.ads_time_s < 0.3, "%s ads" % m.id)


## P6: every non-stock mod has at least one downside (red stat or slower ADS/equip).
func test_every_non_stock_mod_has_a_downside() -> void:
	var stock: Dictionary = {}
	for w: WeaponDef in ContentDB.all_weapons():
		for slot: Variant in w.default_mods:
			stock[StringName(w.default_mods[slot])] = true
	var w0: WeaponDef = ContentDB.weapon(&"weapon.kestrel_p9")
	for m: WeaponModDef in ContentDB.all_mods():
		if stock.has(m.id):
			continue
		var d: Dictionary = StatCalculator.delta(w0.base, w0.base.plus(m.delta))
		var worse: bool = m.delta.ads_time_s > 0.0 or m.delta.equip_time_s > 0.0
		for k: String in d:
			if d[k]["changed"] and not d[k]["better"]:
				worse = true
		assert_true(worse, "%s needs a downside" % m.id)


func test_loot_weights_and_values() -> void:
	assert_eq(ContentDB.loot(&"loot.body_bag").weight, Enums.LootWeight.MEDIUM)
	assert_eq(ContentDB.loot(&"loot.body_bag").value, 0)
	assert_true(ContentDB.loot(&"loot.jewelry").value > 0)
	assert_true(ContentDB.loot(&"loot.cash").value > 0)
