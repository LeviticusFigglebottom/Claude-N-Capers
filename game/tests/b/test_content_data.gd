## B1-01: every content data file loads, ids are unique and match their file, P1 data exists.
extends TestCase

## data folder -> id prefix
const ID_PREFIX: Dictionary = {
	&"weapons": "weapon", &"mods": "mod", &"melee": "melee", &"armor": "armor",
	&"deployables": "deployable", &"loot": "loot", &"throwables": "throwable",
}
const DIFFICULTY_FILES: Dictionary = {
	Enums.Difficulty.ROUTINE: "routine", Enums.Difficulty.TENSE: "tense",
	Enums.Difficulty.HAZARDOUS: "hazardous", Enums.Difficulty.BRUTAL: "brutal",
	Enums.Difficulty.LETHAL: "lethal", Enums.Difficulty.CATACLYSM: "cataclysm",
}

## Canonical enemy ids, docs/contracts/groups.md (D-022 QB-9). Wrecker variants (`enemy.wrecker_g`
## ...) share the `enemy.wrecker` limit, so a variant id must never be a special_limits key.
const CANONICAL_ENEMY_IDS: Array[StringName] = [
	&"enemy.security_officer", &"enemy.camera_operator", &"enemy.patrol_officer", &"enemy.tac_light",
	&"enemy.tac_heavy", &"enemy.frd_agent", &"enemy.phantom", &"enemy.stinger", &"enemy.bulwark",
	&"enemy.wrecker", &"enemy.longshot", &"enemy.corpsman", &"enemy.brandt", &"enemy.aegis",
	&"enemy.cartel_gunman",
]


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
	assert_true(ContentDB.tweak(&"perk_points") is PerkPointTweak, "perk point rate is a tweak (D-034 QB-45)")
	assert_eq((ContentDB.tweak(&"perk_points") as PerkPointTweak).xp_per_perk_point, 500)


## Perk decks grant throwables by id (`perk.throwable` {item_id}); every one must resolve.
func test_perk_throwables_exist() -> void:
	assert_eq(ContentDB.throwable(&"throwable.steady_flask").kind, &"flask")
	assert_eq(ContentDB.throwable(&"throwable.boss_injector").kind, &"injector")
	for deck: Resource in ContentDB.all_of(ContentDB.PERKS):
		for card: Dictionary in deck.get(&"cards"):
			var grants: Dictionary = card.get("grants", {})
			if grants.has(&"perk.throwable"):
				var tid: StringName = StringName(grants[&"perk.throwable"]["item_id"])
				assert_true(ContentDB.throwable(tid) != null, "%s grants %s" % [deck.get(&"id"), tid])
				assert_eq(ContentDB.throwable(tid).count, 1, "%s count" % tid)


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
	# D-154 (LEAD r278, amended r280 after A measured Hazardous at 5 %): fewer shields on Routine / Tense only.
	var bulwarks: Array[int] = [1, 2, 4, 4, 4, 4]
	for d: int in range(bulwarks.size()):
		assert_eq(int(ContentDB.difficulty(d).special_limits[&"enemy.bulwark"]), bulwarks[d], "D-154 Bulwark cap @%d" % d)


func test_special_limits_use_canonical_enemy_ids() -> void:
	for def: DifficultyDef in ContentDB.all_difficulties():
		assert_true(def.special_limits.size() > 0, "%s has special limits" % def.display_name)
		for k: Variant in def.special_limits:
			assert_true(k is StringName, "%s key %s is a StringName" % [def.display_name, k])
			assert_has(CANONICAL_ENEMY_IDS, StringName(k), "%s special_limits key" % def.display_name)
			assert_true(int(def.special_limits[k]) >= 0, "%s %s limit >= 0" % [def.display_name, k])



## QA-31: Longshot (sniper) caps per difficulty (Routine 1, Tense 1, Hazardous 2, Brutal 3, Lethal 3, Cataclysm 4).
## LEAD D-145 DB Tense ruling: max 1 Longshot alive on Routine / Tense (was 2 on Tense).
func test_longshot_special_limits() -> void:
	var want: Array[int] = [1, 1, 2, 3, 3, 4]
	for d: int in range(want.size()):
		var def: DifficultyDef = ContentDB.difficulty(d)
		assert_eq(int(def.special_limits.get(&"enemy.longshot", -1)), want[d], "%s longshot cap" % def.display_name)


func test_breacher_plate_is_skill_gated() -> void:
	assert_eq(ContentDB.armor(&"armor.breacher_plate").unlock_skill, &"skill.juggernaut.plated")
	for a: ArmorDef in ContentDB.all_armors():
		if a.id != &"armor.breacher_plate":
			assert_eq(a.unlock_skill, &"", "%s not skill-gated" % a.id)


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


## QB-5 (D-022): every mod delta must start from WeaponStats.make_delta(). `.tres` deltas can't call
## it, so they spell its zeros out. For each field make_delta() zeroes (its value differs from the
## schema default), the delta must hold make_delta()'s value or an intentional change; a value still
## equal to the schema default means the zero was forgotten (plus() would add a pellet, 20 m of
## falloff, 0.5 s equip ...). Pellets and falloff are never changed by P1 mods.
func test_mod_deltas_start_from_make_delta() -> void:
	var zero: WeaponStats = WeaponStats.make_delta()
	var schema: WeaponStats = WeaponStats.new()
	var zeroed: Array[StringName] = []
	for p: Dictionary in zero.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: StringName = p["name"]
		if zero.get(n) != schema.get(n):
			zeroed.append(n)
	assert_true(zeroed.has(&"pellets") and zeroed.has(&"noise_radius_m"), "make_delta zeroes defaults: %s" % [zeroed])
	for m: WeaponModDef in ContentDB.all_mods():
		assert_true(m.delta != null, "%s has delta" % m.id)
		if m.delta == null:
			continue
		for n: StringName in zeroed:
			var v: Variant = m.delta.get(n)
			if v == zero.get(n):
				continue
			assert_ne(v, schema.get(n), "%s.%s left at schema default %s (start from make_delta)" % [m.id, n, v])
		assert_eq(m.delta.pellets, zero.pellets, "%s pellets" % m.id)
		assert_eq(m.delta.falloff_start_m, zero.falloff_start_m, "%s falloff_start" % m.id)
		assert_eq(m.delta.falloff_end_m, zero.falloff_end_m, "%s falloff_end" % m.id)
		assert_eq(m.delta.headshot_mult, zero.headshot_mult, "%s headshot_mult (plus() ignores it)" % m.id)
		if not m.delta.suppressed:
			assert_eq(m.delta.noise_radius_m, zero.noise_radius_m, "%s noise only on suppressors" % m.id)
		assert_true(m.delta.equip_time_s >= 0.0 and m.delta.equip_time_s < 0.3, "%s equip" % m.id)
		assert_true(m.delta.ads_time_s >= 0.0 and m.delta.ads_time_s < 0.3, "%s ads" % m.id)


## make_delta() is a neutral element: base.plus(make_delta()) == base for every stored field.
func test_make_delta_is_neutral() -> void:
	var zero: WeaponStats = WeaponStats.make_delta()
	for f: StringName in [&"reload_per_round_s", &"reload_start_s", &"reload_end_s"]:
		assert_eq(zero.get(f), 0.0, "make_delta zeroes %s (QB-43)" % f)
	for wid: StringName in [&"weapon.kestrel_p9", &"weapon.plowman_12"]:
		var base: WeaponStats = (ContentDB.weapon(wid).base as WeaponStats).duplicate(true) as WeaponStats
		var got: WeaponStats = base.plus(zero)
		for p: Dictionary in base.get_property_list():
			if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var n: StringName = p["name"]
			assert_eq(got.get(n), base.get(n), "%s %s" % [wid, n])


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
		# r230 order-dependent red: WeaponStats.plus() shares its source's gadgets array (shallow duplicate), so
		# plus() on the cached base wrote the rail gadgets into kestrel_p9 for every later test. Work on a copy.
		var base: WeaponStats = w0.base.duplicate(true) as WeaponStats
		var d: Dictionary = StatCalculator.delta(base, base.duplicate(true).plus(m.delta))
		var worse: bool = m.delta.ads_time_s > 0.0 or m.delta.equip_time_s > 0.0
		for k: String in d:
			if d[k]["changed"] and not d[k]["better"]:
				worse = true
		assert_true(worse, "%s needs a downside" % m.id)


func test_loot_weights_and_values() -> void:
	assert_eq(ContentDB.loot(&"loot.body_bag").weight, Enums.LootWeight.HEAVY, "body bags are HEAVY (S6.3, D-032)")
	assert_eq(ContentDB.loot(&"loot.body_bag").value, 0)
	assert_true(ContentDB.loot(&"loot.jewelry").value > 0)
	assert_true(ContentDB.loot(&"loot.cash").value > 0)


## D-026: ids sort by TEXT, never by interned StringName pointer. The ids are interned in
## reverse-alphabetical order so a pointer-order sort would likely invert them.
func test_sort_ids_sorts_by_text_not_intern_order() -> void:
	var stamp: int = Time.get_ticks_usec()
	var zz: StringName = StringName("zz_sort_test_b_%d" % stamp)
	var mm: StringName = StringName("mm_sort_test_b_%d" % stamp)
	var aa: StringName = StringName("aa_sort_test_a_%d" % stamp)
	var typed: Array[StringName] = [zz, mm, aa]
	ContentDB.sort_ids(typed)
	assert_eq(typed, [aa, mm, zz] as Array[StringName], "typed StringName array sorted by text")
	var untyped: Array = [zz, aa, mm]
	ContentDB.sort_ids(untyped)
	assert_eq(untyped, [aa, mm, zz], "untyped array sorted by text")
	assert_true(ContentDB.id_less(aa, zz))
	assert_false(ContentDB.id_less(zz, aa))
	var ints: Array = [10, 2, 1]
	ContentDB.sort_ids(ints)
	assert_eq(ints, [1, 2, 10], "int keys sort numerically")


func test_all_of_is_sorted_by_id_text() -> void:
	var prev: String = ""
	for w: WeaponDef in ContentDB.all_of(ContentDB.WEAPONS):
		assert_true(prev <= String(w.id), "all_of order by text: %s after %s" % [w.id, prev])
		prev = String(w.id)
