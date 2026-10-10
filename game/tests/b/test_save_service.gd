## B1-06: SaveService / PlayerProfile round trip, atomic writes, backup fallback, migration.
extends TestCase

const SLOT: int = 3


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	_clean()


func after_each() -> void:
	SaveService.delete_profile(SLOT)


func after_all() -> void:
	_clean()
	DirAccess.remove_absolute(BTestUtil.profile_root())
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_round_trip_all_fields() -> void:
	var p: PlayerProfile = _sample()
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.version, SaveService.CURRENT_VERSION)
	assert_eq(q.profile_name, "Tester")
	assert_eq(q.cash, 1234)
	assert_eq(q.stash, 98765)
	assert_eq(q.xp, 4200)
	assert_eq(q.level, 7)
	assert_near(q.banked_stealth_mult, 1.2)
	assert_eq(q.owned_weapons, p.owned_weapons)
	assert_eq(q.owned_weapons[0], &"weapon.kestrel_p9", "StringName type preserved")
	assert_eq(q.owned_mods, p.owned_mods)
	assert_eq(q.owned_masks, p.owned_masks)
	assert_eq(q.stats, {"heists_completed": 3})
	assert_eq(q.settings, {"fov": 90.0, "name_tag": "x"})
	var l: Loadout = q.loadout
	assert_eq(l.primary, &"weapon.test_rifle")
	assert_eq(l.primary_mods, p.loadout.primary_mods)
	assert_eq(l.secondary, &"weapon.kestrel_p9")
	assert_eq(l.secondary_mods, p.loadout.secondary_mods)
	assert_eq(l.melee, &"melee.folding_knife")
	assert_eq(l.throwable, &"throwable.test_frag")
	assert_eq(l.deployable, &"deployable.doctor_bag")
	assert_eq(l.deployable_secondary, &"deployable.ammo_bag")
	assert_eq(l.armor, &"armor.tailored_suit")
	assert_eq(l.mask, &"mask.test")
	assert_eq(l.perk_deck, &"perk.test")
	assert_eq(l.perk_deck_cards, 4)
	assert_eq(l.skills, {&"skill.a": 1, &"skill.b": 2})


func test_resolved_fields_not_saved() -> void:
	var p: PlayerProfile = _sample()
	p.loadout.detection_risk = 12
	p.loadout.concealment_total = 99
	p.loadout.modifiers = {&"weapon.damage_mult.all": 2.0}
	var ld: Dictionary = p.to_dict()["loadout"]
	for k: String in ["detection_risk", "concealment_total", "modifiers", "resolved_primary", "resolved_secondary"]:
		assert_false(ld.has(k), "resolved field %s saved" % k)


func test_atomic_write_leaves_no_tmp_and_keeps_bak() -> void:
	var p: PlayerProfile = _sample()
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var path: String = SaveService.profile_path(SLOT)
	assert_true(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(path + ".tmp"), "tmp removed")
	assert_false(FileAccess.file_exists(path + ".bak"), "no bak after first save")
	p.cash = 5
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	assert_false(FileAccess.file_exists(path + ".tmp"), "tmp removed")
	assert_true(FileAccess.file_exists(path + ".bak"), "bak kept")
	assert_eq(SaveService.load_profile(SLOT).cash, 5)


func test_corrupt_file_falls_back_to_bak() -> void:
	var p: PlayerProfile = _sample()
	p.cash = 111
	SaveService.save_profile(p, SLOT)
	p.cash = 222
	SaveService.save_profile(p, SLOT)
	_write(SaveService.profile_path(SLOT), "{ this is not json")
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.cash, 111, "loaded from .bak")


func test_corrupt_without_bak_gives_default() -> void:
	DirAccess.make_dir_recursive_absolute(BTestUtil.profile_root())
	_write(SaveService.profile_path(SLOT), "garbage")
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.owned_weapons, [&"weapon.kestrel_p9"] as Array[StringName])
	assert_eq(q.cash, 0)


func test_missing_gives_default() -> void:
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.loadout.secondary, &"weapon.kestrel_p9")


func test_v0_migrates() -> void:
	var v0: Dictionary = {"profile_name": "Old", "money": 50, "xp": 10.0}
	var m: Dictionary = SaveService.migrate(v0)
	assert_eq(int(m["version"]), SaveService.CURRENT_VERSION)
	assert_eq(int(m["cash"]), 50)
	assert_false(m.has("money"))
	assert_false(v0.has("version"), "input not mutated")
	DirAccess.make_dir_recursive_absolute(BTestUtil.profile_root())
	_write(SaveService.profile_path(SLOT), JSON.stringify(v0))
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.profile_name, "Old")
	assert_eq(q.cash, 50)
	assert_eq(q.xp, 10)
	assert_eq(q.owned_weapons.size(), 0)
	assert_near(q.banked_stealth_mult, 1.0)


## D-022 QB-13: v1 -> v2 adds banked_stealth_mult = 1.0 and keeps everything else.
func test_v1_migrates_to_v2_with_empty_stealth_bank() -> void:
	assert_true(SaveService.CURRENT_VERSION >= 2)
	var v1: Dictionary = _sample().to_dict()
	v1["version"] = 1
	v1.erase("banked_stealth_mult")
	var m: Dictionary = SaveService.migrate(v1)
	assert_eq(int(m["version"]), SaveService.CURRENT_VERSION)
	assert_near(float(m["banked_stealth_mult"]), 1.0)
	assert_eq(int(m["cash"]), 1234)
	assert_false(v1.has("banked_stealth_mult"), "input not mutated")
	DirAccess.make_dir_recursive_absolute(BTestUtil.profile_root())
	_write(SaveService.profile_path(SLOT), JSON.stringify(v1))
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_near(q.banked_stealth_mult, 1.0)
	assert_eq(q.stash, 98765)
	assert_eq(q.loadout.secondary, &"weapon.kestrel_p9")
	# A v1 file that somehow already carries the field keeps its value.
	v1["banked_stealth_mult"] = 1.15
	assert_near(float(SaveService.migrate(v1)["banked_stealth_mult"]), 1.15)


## B4-03: v2 -> v3 turns the loadout's skills into skill set 0 and the equipped deck's card count into
## that deck's progress; a round trip keeps every set and the per-deck progress.
func test_v2_migrates_to_v3_skill_sets_and_perk_cards() -> void:
	assert_true(SaveService.CURRENT_VERSION >= 3)
	var v2: Dictionary = _sample().to_dict()
	v2["version"] = 2
	v2.erase("skill_sets")
	v2.erase("active_skill_set")
	v2.erase("perk_cards")
	(v2["loadout"] as Dictionary)["skills"] = {"skill.slipstream.light_step": 2}
	var m: Dictionary = SaveService.migrate(v2)
	assert_eq(int(m["version"]), SaveService.CURRENT_VERSION)
	assert_eq(int(m["active_skill_set"]), 0)
	assert_eq((m["skill_sets"] as Array).size(), 1)
	assert_eq(int(((m["skill_sets"] as Array)[0] as Dictionary)["skill.slipstream.light_step"]), 2)
	assert_eq(int((m["perk_cards"] as Dictionary)["perk.test"]), 4)
	DirAccess.make_dir_recursive_absolute(BTestUtil.profile_root())
	_write(SaveService.profile_path(SLOT), JSON.stringify(v2))
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(int(q.loadout.skills[&"skill.slipstream.light_step"]), 2)
	assert_eq(int(q.perk_cards[&"perk.test"]), 4)


## B2-03: v3 -> v4 adds the mask customisation fields (no extra parts, empty custom slots); the
## equipped preset mask survives; custom slots and owned parts round-trip.
func test_v3_migrates_to_v4_mask_fields() -> void:
	assert_eq(SaveService.CURRENT_VERSION, 4)
	var v3: Dictionary = _sample().to_dict()
	v3["version"] = 3
	v3.erase("owned_mask_parts")
	v3.erase("custom_masks")
	var m: Dictionary = SaveService.migrate(v3)
	assert_eq(int(m["version"]), 4)
	assert_eq(m["owned_mask_parts"], [])
	assert_eq(m["custom_masks"], [])
	assert_eq(String((m["loadout"] as Dictionary)["mask"]), "mask.test")
	var p: PlayerProfile = _sample()
	p.owned_mask_parts = [&"mask_pattern.dots"] as Array[StringName]
	p.custom_masks = [{}, {"base": "mask_base.owl", "material": "mask_material.gilt",
		"colors": "mask_colors.bone_ink", "pattern": "mask_pattern.dots"}] as Array[Dictionary]
	p.loadout.mask = &"mask.custom.1"
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.owned_mask_parts, p.owned_mask_parts)
	assert_eq(q.custom_masks.size(), 2)
	assert_true(q.custom_masks[0].is_empty())
	assert_eq(String(q.custom_masks[1]["pattern"]), "mask_pattern.dots")
	assert_eq(q.loadout.mask, &"mask.custom.1")


func test_skill_sets_round_trip_and_switch() -> void:
	var p: PlayerProfile = _sample()
	p.loadout.skills = {&"skill.slipstream.light_step": 1}
	p.switch_skill_set(2)
	assert_eq(p.active_skill_set, 2)
	assert_eq(p.loadout.skills.size(), 0, "new set starts empty")
	p.loadout.skills[&"skill.juggernaut.thick_skin"] = 2
	p.perk_cards[&"perk.bulk"] = 9
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.active_skill_set, 2)
	assert_eq(q.skill_sets.size(), 3)
	assert_eq(int(q.loadout.skills[&"skill.juggernaut.thick_skin"]), 2)
	assert_eq(int(q.skill_set(0)[&"skill.slipstream.light_step"]), 1)
	assert_eq(int(q.perk_cards[&"perk.bulk"]), 9)
	q.switch_skill_set(0)
	assert_eq(int(q.loadout.skills[&"skill.slipstream.light_step"]), 1)
	assert_eq(int(q.skill_set(2)[&"skill.juggernaut.thick_skin"]), 2, "previous active set kept")


func test_future_version_refused() -> void:
	DirAccess.make_dir_recursive_absolute(BTestUtil.profile_root())
	var d: Dictionary = _sample().to_dict()
	d["version"] = SaveService.CURRENT_VERSION + 1
	d["cash"] = 999999
	_write(SaveService.profile_path(SLOT), JSON.stringify(d))
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.cash, 0, "default returned")
	assert_eq(q.profile_name, "Crew")
	assert_true(FileAccess.file_exists(SaveService.profile_path(SLOT)), "future file left untouched")


func test_default_profile_from_data() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(p.cash, 0)
	assert_eq(p.stash, 0)
	assert_eq(p.level, 0)
	assert_eq(p.version, SaveService.CURRENT_VERSION, "default_profile.json is current")
	assert_near(p.banked_stealth_mult, 1.0)
	assert_eq(p.loadout.secondary, &"weapon.kestrel_p9")
	assert_eq(p.loadout.melee, &"melee.folding_knife")
	assert_eq(p.loadout.armor, &"armor.tailored_suit")
	assert_eq(p.loadout.deployable, &"deployable.doctor_bag")
	assert_eq(p.loadout.primary, &"")
	assert_eq(p.owned_weapons, [&"weapon.kestrel_p9"] as Array[StringName])
	assert_has(p.owned_mods, &"mod.p9_suppressor")
	assert_has(p.owned_mods, &"mod.p9_reflex_sight")
	assert_has(p.owned_mods, &"mod.p9_extended_mag")


func test_apply_heist_payout() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var payout: Dictionary = {"stash": 8000, "spending": 2000, "xp_total": 1500}
	SaveService.apply_heist_payout(p, payout)
	assert_eq(p.stash, 8000)
	assert_eq(p.cash, 2000)
	assert_eq(p.xp, 1500)
	assert_eq(p.level, 0, "no curve -> level untouched")
	SaveService.apply_heist_payout(p, payout, func(x: int) -> int: return floori(x / 1000.0))
	assert_eq(p.stash, 16000)
	assert_eq(p.cash, 4000)
	assert_eq(p.xp, 3000)
	assert_eq(p.level, 3)
	assert_near(p.banked_stealth_mult, 1.0, 0.0001, "payout without stealth keys leaves the bank")


## D-022 QB-13: bank on a stealth success, spend it on the next success, keep it on a failure.
func test_apply_heist_payout_stealth_bank() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var tw: PayoutTweak = PayoutTweak.new()
	var diff: DifficultyDef = DifficultyDef.new()
	var stealth_win: Dictionary = {"success": true, "stealth": true, "contract_pay": 1000, "loot": [], "crew": []}
	var loud_win: Dictionary = {"success": true, "stealth": false, "contract_pay": 1000, "loot": [], "crew": []}
	var loss: Dictionary = {"success": false, "stealth": true, "crew": []}
	# 1. Stealth win, nothing banked yet: no stealth XP, bank x1.2.
	var out: Dictionary = PayoutCalculator.compute(stealth_win, diff, tw, false, -1, p.banked_stealth_mult)
	assert_eq(int(out["xp_total"]), 2000)
	SaveService.apply_heist_payout(p, out)
	assert_near(p.banked_stealth_mult, 1.2)
	# 2. Failure: bank kept.
	out = PayoutCalculator.compute(loss, diff, tw, false, -1, p.banked_stealth_mult)
	SaveService.apply_heist_payout(p, out)
	assert_near(p.banked_stealth_mult, 1.2, 0.0001, "failure keeps the bank")
	# 3. Loud win: bank spent (+20%), nothing new banked.
	out = PayoutCalculator.compute(loud_win, diff, tw, false, -1, p.banked_stealth_mult)
	assert_eq(int(out["xp_total"]), 2400)
	SaveService.apply_heist_payout(p, out)
	assert_near(p.banked_stealth_mult, 1.0)
	# 4. Stealth win with a bank: spent and re-banked.
	p.banked_stealth_mult = 1.2
	out = PayoutCalculator.compute(stealth_win, diff, tw, false, -1, p.banked_stealth_mult)
	assert_eq(int(out["xp_total"]), 2400)
	SaveService.apply_heist_payout(p, out)
	assert_near(p.banked_stealth_mult, 1.2)


func _sample() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new()
	p.profile_name = "Tester"
	p.cash = 1234
	p.stash = 98765
	p.xp = 4200
	p.level = 7
	p.banked_stealth_mult = 1.2
	p.owned_weapons = [&"weapon.kestrel_p9", &"weapon.test_rifle"] as Array[StringName]
	p.owned_mods = [&"mod.p9_suppressor", &"mod.p9_extended_mag"] as Array[StringName]
	p.owned_masks = [&"mask.test"] as Array[StringName]
	p.stats = {"heists_completed": 3}
	p.settings = {"fov": 90.0, "name_tag": "x"}
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.test_rifle"
	l.primary_mods = [&"mod.rifle_a"] as Array[StringName]
	l.secondary = &"weapon.kestrel_p9"
	l.secondary_mods = [&"mod.p9_suppressor", &"mod.p9_extended_mag"] as Array[StringName]
	l.melee = &"melee.folding_knife"
	l.throwable = &"throwable.test_frag"
	l.deployable = &"deployable.doctor_bag"
	l.deployable_secondary = &"deployable.ammo_bag"
	l.armor = &"armor.tailored_suit"
	l.mask = &"mask.test"
	l.perk_deck = &"perk.test"
	l.perk_deck_cards = 4
	l.skills = {&"skill.a": 1, &"skill.b": 2}
	p.loadout = l
	return p


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean() -> void:
	for s: int in range(0, 8):
		SaveService.delete_profile(s)
