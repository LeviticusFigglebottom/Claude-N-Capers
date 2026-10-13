## B4-16 save v5 -> B5-02 save v6 -> B7-01 save v7 (P4 gate "save v2"): golden migration fixtures (tests/b/fixtures/save/<name>.json ->
## <name>.expected.json, hand-written), round trip, future-version refusal, truncated / corrupt files,
## wrong types sanitized with a warning, unknown ids pruned, illegal skill sets reset.
extends TestCase

const FIXTURES: String = "res://tests/b/fixtures/save"
const GOLDEN: Array[String] = ["v0", "v1", "v2", "v3", "v4", "v5", "v5_damaged", "v6_damaged", "v6_heister", "v6", "v7_damaged"]
const SLOT: int = 5


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	DirAccess.make_dir_recursive_absolute(BTestUtil.profile_root())


func after_each() -> void:
	SaveService.delete_profile(SLOT)
	Log.capture = false
	Log.captured.clear()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_current_version_is_7() -> void:
	assert_eq(SaveService.CURRENT_VERSION, 7)
	assert_eq(PlayerProfile.new().version, SaveService.CURRENT_VERSION)
	assert_eq(ProfileSchema.FIELDS.size(), PlayerProfile.new_default().to_dict().size(), "schema covers every saved field")
	for f: String in PlayerProfile.new_default().to_dict():
		assert_true(ProfileSchema.FIELDS.has(f), "schema lists %s" % f)


func test_golden_fixtures_migrate_exactly() -> void:
	for fx: String in GOLDEN:
		var got: Dictionary = _norm(SaveService.profile_from_save(_fixture(fx)).to_dict())
		var want: Dictionary = _fixture(fx + ".expected")
		_assert_dict(got, want, fx)


func test_golden_fixtures_through_the_file() -> void:
	for fx: String in GOLDEN:
		_write(SaveService.profile_path(SLOT), FileAccess.get_file_as_string("%s/%s.json" % [FIXTURES, fx]))
		var got: Dictionary = _norm(SaveService.load_profile(SLOT).to_dict())
		_assert_dict(got, _fixture(fx + ".expected"), fx + " (file)")
		SaveService.delete_profile(SLOT)


## Every migration step runs in order and only adds what its version introduced.
func test_each_migration_step_kept() -> void:
	var v0: Dictionary = _fixture("v0")
	var m: Dictionary = SaveService.migrate(v0)
	assert_eq(int(m["version"]), 7)
	assert_eq(int(m["cash"]), 5000)
	assert_false(m.has("money"))
	for k: String in ["banked_stealth_mult", "skill_sets", "perk_cards", "owned_mask_parts", "custom_masks",
			"unlocks", "achievements", "pro_job_locks", "notoriety", "notoriety_xp", "notoriety_choices",
			"held_skill_sets", "music_choice", "career", "weapon_finishes"]:
		assert_true(m.has(k), "v0 gains %s" % k)
	var v4: Dictionary = _fixture("v4")
	var m4: Dictionary = SaveService.migrate(v4)
	assert_eq(m4["unlocks"], [])
	assert_eq(m4["achievements"], {})
	assert_eq(m4["pro_job_locks"], {})
	assert_eq(m4["custom_masks"], v4["custom_masks"], "4 -> 5 keeps the v4 fields")
	assert_false(v4.has("unlocks"), "input not mutated")
	var v5: Dictionary = _fixture("v5")
	var m5: Dictionary = SaveService.migrate(v5)
	assert_eq(int(m5["version"]), 7)
	assert_eq(m5["notoriety"], 0)
	assert_eq(m5["notoriety_xp"], 0)
	assert_eq(m5["notoriety_choices"], {})
	assert_eq(m5["held_skill_sets"], [])
	assert_eq(m5["music_choice"], "", "5 -> 6: the heist's default music")
	assert_eq(m5["unlocks"], v5["unlocks"], "5 -> 6 keeps the v5 fields")
	assert_false(v5.has("notoriety"), "input not mutated")
	var v6: Dictionary = _fixture("v6")
	var m6: Dictionary = SaveService.migrate(v6)
	assert_eq(int(m6["version"]), 7)
	assert_eq(m6["career"], Career.empty(), "6 -> 7: nothing counted yet")
	assert_eq(m6["weapon_finishes"], {}, "6 -> 7: every weapon on its default finish")
	assert_eq(m6["stats"], v6["stats"], "6 -> 7 keeps the v6 fields")
	assert_eq(m6["unlocks"], v6["unlocks"])
	assert_false(v6.has("career"), "input not mutated")


func test_expected_files_round_trip() -> void:
	for fx: String in GOLDEN:
		var want: Dictionary = _fixture(fx + ".expected")
		var p: PlayerProfile = SaveService.profile_from_save(want)
		assert_eq(SaveService.save_profile(p, SLOT), OK)
		_assert_dict(_norm(SaveService.load_profile(SLOT).to_dict()), want, fx + " round trip")
		assert_eq(_norm(p.to_dict()), want, fx + " is already valid")


func test_v5_fields_round_trip() -> void:
	var p: PlayerProfile = SaveService.profile_from_save(_fixture("v4.expected"))
	p.pro_job_locks = {"2:5501": 1.98e9}
	p.unlocks = [&"unlock.achievement.cataclysm_clear"] as Array[StringName]
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_near(float(q.pro_job_locks["2:5501"]), 1.98e9, 1.0)
	assert_eq(q.unlocks, p.unlocks)
	assert_has(q.owned_masks, &"mask.oxblood_herald", "a recorded unlock owns its preset on load")


func test_v6_fields_round_trip() -> void:
	var p: PlayerProfile = SaveService.profile_from_save(_fixture("v5.expected"))
	p.cash = Notoriety.cost_for(1)
	assert_true(bool(Notoriety.rank_up(p)["ok"]))
	p.music_choice = &"track.glasshouse_alt"
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.notoriety, 1)
	assert_eq(q.notoriety_xp, 11600000)
	assert_eq(q.music_choice, &"track.glasshouse_alt")
	assert_eq(q.held_skill_sets, p.held_skill_sets, "held builds saved")
	assert_eq(q.held_skill_sets[0], {&"skill.slipstream.light_step": 2, &"skill.juggernaut.thick_skin": 2})
	assert_has(q.unlocks, &"unlock.notoriety.rank_1")
	assert_has(q.owned_mask_parts, &"mask_colors.crown_ember")
	q.notoriety_choices[5] = &"mask_colors.lantern_smoke"
	q.notoriety = 5
	assert_eq(_norm(q.to_dict())["notoriety_choices"], {"5": "mask_colors.lantern_smoke"}, "rank keys are strings in JSON")
	var back: PlayerProfile = SaveService.profile_from_save(_norm(q.to_dict()))
	assert_eq(back.notoriety_choices, {5: &"mask_colors.lantern_smoke"})


func test_v6_damage_warns_and_repairs() -> void:
	Log.capture = true
	var d: Dictionary = _fixture("v6_damaged")
	d["notoriety"] = 40
	var q: PlayerProfile = SaveService.profile_from_save(d)
	assert_eq(q.notoriety, Notoriety.max_rank(), "rank clamped to the cap")
	assert_true(_warned("notoriety: 40 clamped to 0..25"))
	assert_true(_warned("notoriety_xp: -50 clamped to 0"))
	assert_true(_warned("music_choice: expected short_id"))
	assert_true(_warned("notoriety_choices.2: 'mask_colors.bloodline' not offered"))
	assert_true(_warned("held_skill_sets[0]: 'skill.gone'"))
	assert_true(_warned("held_skill_sets: 3 entries for 2 skill sets"))
	assert_true(_warned("unlocks: 'unlock.notoriety.rank_x'"))
	assert_has(q.owned_mask_parts, &"mask_colors.heat_shimmer", "every reached rank's reward re-granted")
	assert_has(q.unlocks, &"unlock.notoriety.rank_25")
	assert_has(q.owned_masks, &"mask.last_word")
	for line: String in Log.captured:
		assert_false(line.begins_with("[ERROR]"), "no errors for damaged fields: " + line)
	var ok: Dictionary = _fixture("v6_damaged")
	ok["music_choice"] = "x".repeat(ProfileSchema.SHORT_ID_MAX_LENGTH)
	assert_eq(String(SaveService.profile_from_save(ok).music_choice).length(), 64, "64 chars is the limit, kept")
	ok["music_choice"] = 7
	assert_eq(SaveService.profile_from_save(ok).music_choice, &"", "a number is not a track id")


func test_v7_damage_warns_and_repairs() -> void:
	Log.capture = true
	var q: PlayerProfile = SaveService.profile_from_save(_fixture("v7_damaged"))
	assert_eq(Career.total(q, "kills"), -1, "a negative counter is dropped (not counted)")
	assert_eq(Career.total(q, "shots"), -1, "a string counter is dropped")
	assert_eq(Career.total(q, "hits"), 120, "a whole JSON number is an int")
	assert_eq(Career.best_difficulty(q, &"glasshouse"), 2)
	assert_near(Career.fastest_win_s(q, &"glasshouse"), 412.0, 0.001)
	assert_eq(Career.accuracy(q), -1.0, "no shots counted -> no accuracy")
	assert_true(_warned("career.trophies: unknown career section"))
	assert_true(_warned("career.totals.kills: expected a counter"))
	assert_true(_warned("career.heists.night_deposit: bad entry"))
	assert_true(_warned("career.difficulties.hard: bad entry"))
	assert_true(_warned("career.weapons: unknown weapon 'weapon.retired_blaster'"))
	assert_true(_warned("weapon_finishes.weapon.kestrel_p9x: expected a short string"))
	assert_true(_warned("weapon_finishes: unknown weapon 'weapon.retired_blaster'"))
	assert_true(_warned("weapon_finishes.weapon.brute_12: unknown finish 'finish.retired_rust'"), "lead ruling: unknown finish ids pruned")
	assert_eq(q.weapon_finishes, {&"weapon.kestrel_p9": &"finish.gunmetal_blue"})
	for line: String in Log.captured:
		assert_false(line.begins_with("[ERROR]"), "no errors for damaged fields: " + line)
	var bad: Dictionary = _fixture("v7_damaged")
	bad["career"] = "lots"
	bad["weapon_finishes"] = []
	var r: PlayerProfile = SaveService.profile_from_save(bad)
	assert_eq(r.career, Career.empty(), "a non-object career -> empty")
	assert_eq(r.weapon_finishes, {})
	assert_true(_warned("career: expected career"))


func test_v7_fields_round_trip() -> void:
	var p: PlayerProfile = SaveService.profile_from_save(_fixture("v6.expected"))
	var r: Dictionary = {"heist_id": &"glasshouse", "success": true, "stealth": true, "difficulty": 3, "time_s": 300.4,
		"loot": [{"loot_id": &"loot.cash", "value": 1}], "crew": [{"slot": 0, "kills": 2, "shots": 10, "hits": 4}]}
	Career.record(p, r, {"success": true, "stash": 100, "spending": 20, "xp_total": 900}, 0)
	p.weapon_finishes[&"weapon.kestrel_p9"] = &"finish.gunmetal_blue"
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.career, p.career, "career saved exactly")
	assert_eq(Career.total(q, "hits"), 4)
	assert_eq(Career.best_difficulty(q, &"glasshouse"), 3)
	assert_eq(q.weapon_finishes, {&"weapon.kestrel_p9": &"finish.gunmetal_blue"})


func test_future_version_refused() -> void:
	var d: Dictionary = _fixture("v4")
	d["version"] = SaveService.CURRENT_VERSION + 1
	_write(SaveService.profile_path(SLOT), JSON.stringify(d))
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.profile_name, "Crew", "default profile returned")
	assert_eq(q.cash, 0)
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(SaveService.profile_path(SLOT)))["profile_name"], "Maskmaker",
			"future file left untouched")


func test_truncated_json_falls_back_to_bak_then_default() -> void:
	var p: PlayerProfile = SaveService.profile_from_save(_fixture("v3"))
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	p.cash = 1
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var text: String = FileAccess.get_file_as_string(SaveService.profile_path(SLOT))
	_write(SaveService.profile_path(SLOT), text.substr(0, text.length() / 2))
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.cash, 8800, "truncated file -> .bak")
	assert_eq(q.profile_name, "Planner")
	_write(SaveService.profile_path(SLOT) + ".bak", text.substr(0, 10))
	q = SaveService.load_profile(SLOT)
	assert_eq(q.profile_name, "Crew", "both truncated -> default")


func test_wrong_types_warn_and_sanitize() -> void:
	Log.capture = true
	var q: PlayerProfile = SaveService.profile_from_save(_fixture("v5_damaged"))
	assert_eq(q.cash, 0, "string cash -> default")
	assert_eq(q.stash, 5000, "valid neighbours kept")
	assert_true(_warned("cash: expected int"), "cash warning logged")
	assert_true(_warned("owned_weapons: unknown id 'weapon.retired_blaster'"))
	assert_true(_warned("loadout.skills: illegal set"))
	assert_true(_warned("loadout.skills: unknown skill 'skill.not_a_skill'"))
	assert_true(_warned("perk_cards: unknown deck 'perk.unknown_deck'"))
	assert_true(_warned("achievements: unknown id 'achievement.deleted'"))
	for line: String in Log.captured:
		assert_false(line.begins_with("[ERROR]"), "no errors for damaged fields: " + line)


func test_non_dict_root_and_odd_version() -> void:
	_write(SaveService.profile_path(SLOT), "[1, 2, 3]")
	assert_eq(SaveService.load_profile(SLOT).profile_name, "Crew", "array root -> default")
	var d: Dictionary = _fixture("v0")
	d["version"] = "three"
	var q: PlayerProfile = SaveService.profile_from_save(d)
	assert_eq(q.cash, 5000, "a non-numeric version reads as v0")
	assert_eq(q.version, SaveService.CURRENT_VERSION)


func test_validator_keeps_a_valid_default() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(ProfileValidator.validate(p), [] as Array[String])


func test_unknown_ids_never_crash_and_skill_sets_reset() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 1
	p.loadout.skills = {&"skill.juggernaut.plated": 2}
	p.skill_sets = [{}, {&"skill.juggernaut.thick_skin": 1}] as Array[Dictionary]
	p.owned_weapons.append(&"weapon.gone")
	p.loadout.primary = &"weapon.gone"
	p.loadout.mask = &"mask.oxblood_herald"  # locked, not owned
	var notes: Array[String] = ProfileValidator.validate(p)
	assert_eq(p.loadout.skills, {}, "illegal active set reset")
	assert_eq(p.skill_sets[1], {&"skill.juggernaut.thick_skin": 1}, "legal set kept")
	assert_false(p.owned_weapons.has(&"weapon.gone"))
	assert_eq(p.loadout.primary, &"", "default primary")
	assert_eq(p.loadout.mask, &"mask.gilded_heron", "locked mask -> default mask")
	assert_eq(notes.size(), 4)


func _warned(fragment: String) -> bool:
	for line: String in Log.captured:
		if line.begins_with("[WARN]") and fragment in line:
			return true
	return false


func _assert_dict(got: Dictionary, want: Dictionary, label: String) -> void:
	assert_eq(got.keys().size(), want.keys().size(), "%s: field count" % label)
	for k: Variant in want:
		assert_eq(got.get(k), want[k], "%s: field %s" % [label, k])
	assert_eq(got, want, label)


func _fixture(fx: String) -> Dictionary:
	var path: String = "%s/%s.json" % [FIXTURES, fx]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "fixture %s parses" % path)
	var d: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	d.erase("_doc")
	return d


## JSON-normalised copy (ints become floats, like a parsed fixture).
func _norm(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d)) as Dictionary


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
