## B4-04: armory expansion data. One weapon per class plus a heavy pistol; PD2 stat shapes
## (pd2_fidelity.md L3.2 falloff, L3.4 piercing, L3.5/L3.7 suppressors, P6 mod downsides); every
## weapon resolves through LoadoutResolver with every mod; strings, cues and anim sets exist.
extends TestCase

const NEW_WEAPONS: Array[StringName] = [
	&"weapon.warden_45", &"weapon.hornet_9", &"weapon.corsair_ar", &"weapon.plowman_12",
	&"weapon.rampart_lmg", &"weapon.heron_308",
]
## Weapon families with a viewmodel anim set + fire cue pair (characters.md, audio_cues.md). B4-12 adds
## `akimbo` (pairs; D-050) and `revolver`; B4-18 requests the special sets from ENV D (they may lag: these
## tests check names only, never animation libraries).
const ANIM_SETS: Array[StringName] = [&"pistol", &"smg", &"rifle", &"shotgun", &"lmg", &"sniper", &"akimbo", &"revolver",
	&"break_action", &"lever", &"bow", &"crossbow", &"launcher", &"flamethrower", &"saw", &"minigun", &"shotgun_box"]
## Cue family per anim set where they differ: pairs fire pistol rounds (D-050).
const CUE_FAMILY: Dictionary = {&"akimbo": &"pistol"}
## B4-18: weapons that borrow another family's viewmodel set keep their own sound (a box-fed shotgun reloads
## like a rifle but fires 12-gauge).
const CUE_FAMILY_BY_WEAPON: Dictionary = {
	&"weapon.harrow_12": &"shotgun", &"weapon.brute_12": &"shotgun", &"weapon.reaper_db": &"shotgun",
	&"weapon.osprey_762": &"sniper", &"weapon.shrike_44": &"sniper",
}
## B4-18: silent without a suppressor slot (integral can, bow, crossbow): suppressed, noise <= 1 m, threat 0.
const INHERENTLY_SILENT: Array[StringName] = [&"weapon.hush_9", &"weapon.thorn_bow", &"weapon.vise_crossbow"]
## B4-18: PD2 specials are primaries except the portable saw (OVE9000: secondary).
const SECONDARY_SPECIALS: Array[StringName] = [&"weapon.rotor_saw"]
## PD2 exceptions to the class -> slot rule: short shotguns in the secondary slot (Locomotive analog) and
## akimbo pairs in the primary slot.
const SECONDARY_PRIMARY_CLASS: Array[StringName] = [&"weapon.mule_12"]
const PRIMARY_CLASSES: Array[int] = [
	Enums.WeaponClass.ASSAULT_RIFLE, Enums.WeaponClass.SHOTGUN, Enums.WeaponClass.LMG, Enums.WeaponClass.SNIPER,
]

var _strings: Dictionary = {}


func before_all() -> void:
	ContentDB.clear_cache()
	var f: FileAccess = FileAccess.open("res://content/data/strings/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 2:
			_strings[row[0]] = row[1]


func after_each() -> void:
	Log.capture = false
	Log.captured.clear()


func _weapon_of_class(c: Enums.WeaponClass) -> Array[WeaponDef]:
	var out: Array[WeaponDef] = []
	for w: WeaponDef in ContentDB.all_weapons():
		if w.weapon_class == c:
			out.append(w)
	return out


## Non-default mods of a weapon, by slot (ModType -> Array[StringName]).
func _optional_mods(w: WeaponDef) -> Dictionary:
	var out: Dictionary = {}
	for slot: Variant in w.mod_slots:
		var ids: Array[StringName] = []
		for mid: Variant in w.mod_slots[slot]:
			if StringName(mid) != StringName(w.default_mods.get(slot, &"")):
				ids.append(StringName(mid))
		out[int(slot)] = ids
	return out


## Base stats with the weapon's default (stock) mods applied: what the workshop compares against.
func _stock_stats(w: WeaponDef) -> WeaponStats:
	return LoadoutResolver.resolve_weapon(w.id, [] as Array[StringName])


func test_one_new_weapon_per_class_plus_a_heavy_pistol() -> void:
	for id: StringName in NEW_WEAPONS:
		assert_true(ContentDB.weapon(id) != null, "%s exists" % id)
	assert_true(_weapon_of_class(Enums.WeaponClass.PISTOL).size() >= 2, "at least two pistols")
	for c: int in [Enums.WeaponClass.SMG, Enums.WeaponClass.ASSAULT_RIFLE, Enums.WeaponClass.SHOTGUN,
			Enums.WeaponClass.LMG, Enums.WeaponClass.SNIPER]:
		assert_true(_weapon_of_class(c as Enums.WeaponClass).size() >= 1, "class %s" % Enums.WeaponClass.keys()[c])
	var p9: WeaponDef = ContentDB.weapon(&"weapon.kestrel_p9")
	var w45: WeaponDef = ContentDB.weapon(&"weapon.warden_45")
	assert_true(w45.base.damage > p9.base.damage * 1.5, "heavy pistol hits much harder")
	assert_true(w45.base.mag_size < p9.base.mag_size, "heavy pistol holds fewer rounds")
	assert_true(w45.base.concealment < p9.base.concealment, "heavy pistol is harder to hide")


func test_makers_are_original_and_set() -> void:
	for id: StringName in NEW_WEAPONS:
		var w: WeaponDef = ContentDB.weapon(id)
		assert_true(w.manufacturer != "", "%s maker" % id)
		assert_ne(w.manufacturer, "Halvard Arms", "%s uses a new maker" % id)
		assert_true(w.display_name != "", "%s name" % id)


func test_slots_follow_pd2() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		if SECONDARY_PRIMARY_CLASS.has(w.id):
			assert_eq(w.slot, Enums.WeaponSlot.SECONDARY, "%s is a secondary (PD2 short shotgun)" % w.id)
		elif w.anim_set == &"akimbo":
			assert_eq(w.slot, Enums.WeaponSlot.PRIMARY, "%s: PD2 akimbo pairs are primaries" % w.id)
		elif w.weapon_class == Enums.WeaponClass.SPECIAL:
			var want: int = Enums.WeaponSlot.SECONDARY if SECONDARY_SPECIALS.has(w.id) else Enums.WeaponSlot.PRIMARY
			assert_eq(int(w.slot), want, "%s: PD2 special slot" % w.id)
		elif PRIMARY_CLASSES.has(int(w.weapon_class)):
			assert_eq(w.slot, Enums.WeaponSlot.PRIMARY, "%s is a primary" % w.id)
		else:
			# PD2: pistols and SMGs are secondaries
			assert_eq(w.slot, Enums.WeaponSlot.SECONDARY, "%s is a secondary" % w.id)


## L3.2: ARs none; shotguns heavy past close range; SMG/LMG past medium; pistols moderate; snipers
## gain damage at long range.
func test_class_falloff_shapes() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		var s: WeaponStats = w.base
		match w.weapon_class:
			Enums.WeaponClass.ASSAULT_RIFLE:
				assert_true(s.falloff_start_m >= 9999.0 and s.falloff_end_m == s.falloff_start_m, "%s no falloff" % w.id)
				assert_near(s.falloff_min_mult, 1.0, 0.0001, "%s min mult" % w.id)
			Enums.WeaponClass.SNIPER:
				assert_true(s.falloff_min_mult > 1.0, "%s gains damage with range" % w.id)
				assert_true(s.falloff_end_m > s.falloff_start_m, "%s ramp" % w.id)
			Enums.WeaponClass.SHOTGUN:
				assert_true(s.pellets > 1, "%s fires pellets" % w.id)
				assert_true(s.falloff_start_m <= 10.0 and s.falloff_min_mult <= 0.25, "%s heavy falloff" % w.id)
			Enums.WeaponClass.SMG, Enums.WeaponClass.LMG:
				assert_true(s.falloff_start_m >= 15.0 and s.falloff_min_mult < 1.0, "%s medium-range falloff" % w.id)
			Enums.WeaponClass.PISTOL:
				assert_true(s.falloff_min_mult >= 0.4 and s.falloff_min_mult < 1.0, "%s moderate falloff" % w.id)
		if w.weapon_class != Enums.WeaponClass.SHOTGUN:
			assert_eq(s.pellets, 1, "%s single projectile" % w.id)
		assert_near(s.headshot_mult, 1.0, 0.0001, "%s headshot bonus 1.0 (D-026)" % w.id)


## L3.4: snipers pierce body armor, shields and thin walls; nothing else does yet. Bolt action, lever action
## (B4-18 Shrike, D-057) or semi-auto (B4-18 Osprey, like PD2's semi-automatic snipers).
func test_sniper_pierces() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		var sniper: bool = w.weapon_class == Enums.WeaponClass.SNIPER
		assert_eq(w.base.shield_pierce, sniper, "%s shield pierce" % w.id)
		assert_eq(w.base.wall_pierce, sniper, "%s wall pierce" % w.id)
		if sniper:
			assert_near(w.base.armor_pierce, 1.0, 0.0001, "%s armor pierce" % w.id)
			assert_true(w.fire_modes.has(&"bolt") or w.fire_modes.has(&"lever") \
					or w.fire_modes == ([&"semi"] as Array[StringName]), "%s bolt, lever or semi-auto" % w.id)


func test_class_stat_shapes() -> void:
	var lmg: WeaponStats = ContentDB.weapon(&"weapon.rampart_lmg").base
	var ar: WeaponStats = ContentDB.weapon(&"weapon.corsair_ar").base
	var sniper: WeaponStats = ContentDB.weapon(&"weapon.heron_308").base
	var smg: WeaponStats = ContentDB.weapon(&"weapon.hornet_9").base
	assert_true(lmg.mag_size >= 100, "LMG big magazine")
	assert_true(lmg.reload_time_s > 2.0 * ar.reload_time_s, "LMG slow reload")
	assert_true(lmg.concealment < 10 and sniper.concealment < 10, "LMG and sniper are hard to hide")
	assert_true(sniper.mag_size <= 10 and sniper.damage > 3.0 * ar.damage, "sniper: few, heavy rounds")
	assert_true(smg.fire_rate_rpm > ar.fire_rate_rpm and smg.concealment > ar.concealment, "SMG fast and concealable")
	for w: WeaponDef in ContentDB.all_weapons():
		if w.id != &"weapon.kestrel_p9":
			assert_true(w.price > 0 and w.unlock_level > 0, "%s has a price and an unlock level" % w.id)
		assert_true(w.base.total_ammo > w.base.mag_size, "%s carries spare ammo" % w.id)
		assert_true(w.base.ammo_pickup_max >= w.base.ammo_pickup_min, "%s pickup range" % w.id)


## D-034 QB-43 / D-045: shell-by-shell reload. Only weapons that load single rounds set the per-round
## fields (Plowman 12 tube); detachable-magazine weapons (Heron .308's 5-round box) keep a magazine
## reload (all 0). For a shell-loaded weapon the resolver derives, after every mod (data_schemas.md
## "Shell-by-shell reload timing"):
##   reload_time_s       = start + mag x per_round + end
##   reload_empty_time_s = start + mag x per_round + end_empty
## and no mod adds raw reload time (a tube mod changes the totals through mag_size only).
func test_shell_by_shell_reload_fields() -> void:
	const SHELL_LOADED: Array[StringName] = [&"weapon.plowman_12", &"weapon.mule_12", &"weapon.shrike_44"]
	for w: WeaponDef in ContentDB.all_weapons():
		var b: WeaponStats = w.base
		var shell: bool = SHELL_LOADED.has(w.id)
		assert_eq(b.reload_per_round_s > 0.0, shell, "%s shell-by-shell = %s" % [w.id, shell])
		if not shell:
			assert_eq([b.reload_start_s, b.reload_end_s, b.reload_end_empty_s], [0.0, 0.0, 0.0], "%s magazine reload" % w.id)
			continue
		var mods: Array[StringName] = [&""]
		for slot: Variant in w.mod_slots:
			for mid: Variant in w.mod_slots[slot]:
				mods.append(StringName(mid))
		for mid: StringName in mods:
			var picked: Array[StringName] = []
			if mid != &"":
				picked.append(mid)
				var d: WeaponStats = ContentDB.mod(mid).delta
				for f: String in ["reload_time_s", "reload_empty_time_s", "reload_per_round_s", "reload_start_s", "reload_end_s", "reload_end_empty_s"]:
					assert_eq(float(d.get(f)), 0.0, "%s adds no raw %s to a shell-fed weapon" % [mid, f])
			var s: WeaponStats = LoadoutResolver.resolve_weapon(w.id, picked)
			var load_s: float = s.reload_start_s + s.mag_size * s.reload_per_round_s
			assert_near(s.reload_time_s, load_s + s.reload_end_s, 0.001, "%s +%s tactical reload" % [w.id, mid])
			assert_near(s.reload_empty_time_s, load_s + s.reload_end_empty_s, 0.001, "%s +%s empty reload" % [w.id, mid])
			var disp: Dictionary = StatCalculator.display(s)
			assert_near(float(disp["reload"]), s.reload_time_s, 0.001, "%s +%s display reload" % [w.id, mid])
			assert_near(float(disp["reload_empty"]), s.reload_empty_time_s, 0.001, "%s +%s display empty reload" % [w.id, mid])
	assert_eq(ContentDB.weapon(&"weapon.heron_308").base.reload_per_round_s, 0.0, "Heron: detachable mag")


## D-044/D-045 Plowman timings: 0.4 / 0.4333 / 0.4 (1.2 empty) -> 3.4 s / 4.2 s with the 6-shell tube.
func test_plowman_reload_timings() -> void:
	var b: WeaponStats = ContentDB.weapon(&"weapon.plowman_12").base
	assert_near(b.reload_start_s, 0.4, 0.0001, "start")
	assert_near(b.reload_per_round_s, 0.4333, 0.0001, "per shell")
	assert_near(b.reload_end_s, 0.4, 0.0001, "end")
	assert_near(b.reload_end_empty_s, 1.2, 0.0001, "end empty")
	var s: WeaponStats = LoadoutResolver.resolve_weapon(&"weapon.plowman_12", [] as Array[StringName])
	assert_eq(s.mag_size, 6, "stock tube")
	assert_near(s.reload_time_s, 3.4, 0.001, "tactical 3.4 s")
	assert_near(s.reload_empty_time_s, 4.2, 0.001, "empty 4.2 s")
	var ext: WeaponStats = LoadoutResolver.resolve_weapon(&"weapon.plowman_12", [&"mod.plowman_extended_tube"] as Array[StringName])
	assert_near(ext.reload_time_s - s.reload_time_s, (ext.mag_size - s.mag_size) * s.reload_per_round_s, 0.001, "tube adds shells only")


func test_cues_and_anim_sets_follow_the_contract_pattern() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		assert_has(ANIM_SETS, w.anim_set, "%s anim set" % w.id)
		var family: StringName = CUE_FAMILY_BY_WEAPON.get(w.id, CUE_FAMILY.get(w.anim_set, w.anim_set))
		assert_eq(w.fire_cue, StringName("cue.weapon_%s_fire" % family), "%s fire cue" % w.id)
		# A suppressed cue only where a suppressor can be fitted (ENV C: no orphan _suppressed cues).
		var want_sup: StringName = &""
		if w.mod_slots.has(Enums.ModType.SUPPRESSOR):
			want_sup = StringName("cue.weapon_%s_fire_suppressed" % family)
		assert_eq(w.fire_cue_suppressed, want_sup, "%s suppressed cue" % w.id)


func test_every_weapon_has_three_optional_mods_and_stock_defaults() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		var n: int = 0
		var opt: Dictionary = _optional_mods(w)
		for slot: int in opt:
			n += (opt[slot] as Array).size()
		assert_true(n >= 3, "%s has %d optional mods" % [w.id, n])
		assert_true(w.default_mods.has(Enums.ModType.SIGHT), "%s stock sight" % w.id)
		assert_true(w.default_mods.has(Enums.ModType.MAGAZINE), "%s stock magazine" % w.id)


## Each mod alone, and one of every optional slot together, resolves without a rejection.
func test_every_weapon_resolves_with_every_mod() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		var opt: Dictionary = _optional_mods(w)
		var all: Array[StringName] = []
		for slot: int in opt:
			for mid: StringName in opt[slot]:
				Log.capture = true
				Log.captured.clear()
				var s: WeaponStats = LoadoutResolver.resolve_weapon(w.id, [mid] as Array[StringName])
				assert_true(s != null, "%s + %s resolves" % [w.id, mid])
				assert_eq(Log.captured.size(), 0, "%s + %s accepted: %s" % [w.id, mid, Log.captured])
				var applied: Array[WeaponModDef] = LoadoutResolver.applied_mods(w, [mid] as Array[StringName])
				assert_true(applied.has(ContentDB.mod(mid)), "%s applied on %s" % [mid, w.id])
			# one per slot, skipping mods that conflict with ones already picked
			for mid: StringName in opt[slot]:
				if not _conflicts_with(mid, all):
					all.append(mid)
					break
		Log.capture = true
		Log.captured.clear()
		var full: WeaponStats = LoadoutResolver.resolve_weapon(w.id, all)
		assert_eq(Log.captured.size(), 0, "%s full kit accepted: %s" % [w.id, Log.captured])
		assert_true(full != null and full.mag_size >= 1, "%s full kit resolves" % w.id)
		assert_eq(LoadoutResolver.applied_mods(w, all).size(), w.mod_slots.size() - _empty_slots(w, all),
			"%s one mod per filled slot" % w.id)
		Log.capture = false


func _conflicts_with(mid: StringName, picked: Array[StringName]) -> bool:
	var m: WeaponModDef = ContentDB.mod(mid)
	for other: StringName in picked:
		if m.conflicts.has(other) or ContentDB.mod(other).conflicts.has(mid):
			return true
	return false


func _empty_slots(w: WeaponDef, picked: Array[StringName]) -> int:
	var n: int = 0
	for slot: Variant in w.mod_slots:
		var filled: bool = w.default_mods.has(slot)
		for mid: StringName in picked:
			if int(ContentDB.mod(mid).mod_type) == int(slot):
				filled = true
		if not filled:
			n += 1
	return n


func test_declared_conflict_is_rejected() -> void:
	Log.capture = true
	Log.captured.clear()
	var mods: Array[StringName] = [&"mod.w45_suppressor", &"mod.w45_compensator"]
	var applied: Array[WeaponModDef] = LoadoutResolver.applied_mods(ContentDB.weapon(&"weapon.warden_45"), mods)
	assert_true(applied.has(ContentDB.mod(&"mod.w45_suppressor")), "first mod kept")
	assert_false(applied.has(ContentDB.mod(&"mod.w45_compensator")), "conflicting mod rejected")
	assert_true(Log.captured.size() > 0 and Log.captured[0].contains("conflicts"), "logged")


## L3.5 + L3.7: suppressed weapons are silent (noise <= 1 m) and have zero threat once resolved.
func test_suppressors_silence_and_zero_threat() -> void:
	var found: int = 0
	for w: WeaponDef in ContentDB.all_weapons():
		for mid: Variant in w.mod_slots.get(Enums.ModType.SUPPRESSOR, []):
			found += 1
			var s: WeaponStats = LoadoutResolver.resolve_weapon(w.id, [StringName(mid)] as Array[StringName])
			assert_true(s.suppressed, "%s on %s suppressed" % [mid, w.id])
			assert_true(s.noise_radius_m <= 1.0, "%s noise %f" % [mid, s.noise_radius_m])
			assert_near(s.suppression, 0.0, 0.0001, "%s on %s threat 0" % [mid, w.id])
			assert_eq(StatCalculator.display(s)["threat"], 0, "%s displays threat 0" % mid)
		var stock: WeaponStats = _stock_stats(w)
		if INHERENTLY_SILENT.has(w.id):
			assert_true(stock.suppressed and stock.noise_radius_m <= 1.0, "%s silent out of the box" % w.id)
			assert_near(stock.suppression, 0.0, 0.0001, "%s threat 0" % w.id)
			assert_false(w.mod_slots.has(Enums.ModType.SUPPRESSOR), "%s takes no suppressor" % w.id)
		else:
			assert_false(stock.suppressed, "%s loud by default" % w.id)
	assert_true(found >= 5, "suppressors for every weapon that takes one (%d)" % found)


## P6: every non-stock mod has at least one downside ON ITS OWN WEAPON (red stat, slower ADS/equip).
func test_every_mod_has_a_downside_on_its_weapon() -> void:
	for w: WeaponDef in ContentDB.all_weapons():
		var stock: WeaponStats = _stock_stats(w)
		var opt: Dictionary = _optional_mods(w)
		for slot: int in opt:
			for mid: StringName in opt[slot]:
				var m: WeaponModDef = ContentDB.mod(mid)
				var modded: WeaponStats = LoadoutResolver.resolve_weapon(w.id, [mid] as Array[StringName])
				var d: Dictionary = StatCalculator.delta(stock, modded)
				var worse: bool = m.delta.ads_time_s > 0.0 or m.delta.equip_time_s > 0.0
				var better: bool = m.delta.suppressed or modded.magnification > stock.magnification
				for k: String in d:
					if d[k]["changed"]:
						if d[k]["better"]:
							better = true
						else:
							worse = true
				assert_true(worse, "%s on %s needs a downside" % [mid, w.id])
				assert_true(better, "%s on %s needs an upside" % [mid, w.id])


## A sniper's stock scope supplies its magnification; the 10x scope goes higher.
func test_scopes_magnify() -> void:
	var heron: WeaponStats = _stock_stats(ContentDB.weapon(&"weapon.heron_308"))
	assert_true(heron.magnification >= 4.0, "stock scope 4x")
	var ten: WeaponStats = LoadoutResolver.resolve_weapon(&"weapon.heron_308", [&"mod.heron_scope_10x"] as Array[StringName])
	assert_true(ten.magnification > heron.magnification, "10x scope")
	var prism: WeaponStats = LoadoutResolver.resolve_weapon(&"weapon.corsair_ar", [&"mod.rail_prism_scope"] as Array[StringName])
	assert_true(prism.magnification >= 3.0, "prism 3x")


func _loadout(primary: StringName, secondary: StringName, armor: StringName) -> Loadout:
	var l: Loadout = Loadout.new()
	l.primary = primary
	l.secondary = secondary
	l.melee = &"melee.folding_knife"
	l.armor = armor
	return l


## Every primary pairs with every secondary; concealment sums both guns; DR follows PD2 intuition.
func test_full_loadouts_resolve_and_detection_risk_makes_sense() -> void:
	var primaries: Array[StringName] = []
	var secondaries: Array[StringName] = []
	for w: WeaponDef in ContentDB.all_weapons():
		if w.slot == Enums.WeaponSlot.PRIMARY:
			primaries.append(w.id)
		else:
			secondaries.append(w.id)
	assert_true(primaries.size() >= 4 and secondaries.size() >= 3, "pools")
	for p: StringName in primaries:
		for s: StringName in secondaries:
			var r: Loadout = LoadoutResolver.resolve(_loadout(p, s, &"armor.tailored_suit"))
			assert_true(r.resolved_primary != null and r.resolved_secondary != null, "%s + %s resolve" % [p, s])
			var want: int = r.resolved_primary.concealment + r.resolved_secondary.concealment + 30 + 30
			assert_eq(r.concealment_total, want, "%s + %s concealment" % [p, s])
	var stealthy: Loadout = LoadoutResolver.resolve(_loadout(&"weapon.corsair_ar", &"weapon.kestrel_p9", &"armor.tailored_suit"))
	var heavy: Loadout = LoadoutResolver.resolve(_loadout(&"weapon.rampart_lmg", &"weapon.warden_45", &"armor.heavy_vest"))
	assert_true(stealthy.detection_risk < 30, "AR + P9 + suit stays low (%d)" % stealthy.detection_risk)
	assert_true(heavy.detection_risk >= 69, "LMG + heavy pistol + vest is loud (%d)" % heavy.detection_risk)
	var sniper: Loadout = LoadoutResolver.resolve(_loadout(&"weapon.heron_308", &"weapon.hornet_9", &"armor.tailored_suit"))
	assert_true(sniper.detection_risk > stealthy.detection_risk, "sniper is harder to hide than the carbine")


func test_strings_exist_for_every_weapon_and_mod() -> void:
	var stock: Dictionary = {}
	for w: WeaponDef in ContentDB.all_weapons():
		assert_has(_strings, "item.%s.name" % w.id)
		assert_has(_strings, "item.%s.desc" % w.id)
		for slot: Variant in w.default_mods:
			stock[StringName(w.default_mods[slot])] = true
	for m: WeaponModDef in ContentDB.all_mods():
		assert_has(_strings, "item.%s.name" % m.id)
		if not stock.has(m.id):
			assert_has(_strings, "item.%s.desc" % m.id)
