## P4 GATE: progression (docs/roadmap.md P4 gate: "every modifier key <= P4 has a behaviour test;
## resolver golden tests"). Owner: LEAD. Contracts: docs/contracts/modifiers.md, data_schemas.md.
##
## Part 1, coverage (test_01..test_03). For every ModifierKeys.KEYS entry with phase <= P4:
##   * HOOK: the key appears as a string literal in runtime code (res://systems, res://core,
##     res://world, res://content; comments stripped; contracts/ and the Modifiers service excluded).
##     A key nothing reads cannot change behaviour, so a "test" for it can only be a data test.
##   * BEHAVIOUR TEST: the key (bare or qualified, `weapon.damage_mult.shotgun`) appears as a string
##     literal in the code of a behaviour test file, or is listed in INDIRECT (a behaviour test that
##     reaches the key through a skill / perk grant without naming it; the gate checks that the file
##     and the test function exist). Behaviour test files = tests/a, tests/c, tests/p, tests/integration and
##     tests/b minus DATA_ONLY_TESTS (registry / resolver / UI / save tests whose key literals are
##     data, not behaviour).
##   Why scan sources rather than a hand-kept registry: ENV A and ENV B keep adding tests next to their
##   systems, and a registry the lead edits by hand goes stale both ways. Scanning code literals (not
##   comments, word-exact through ModifierKeys.base_key, not substrings) finds every test that grants
##   or queries the key; INDIRECT covers the grant-by-skill-id style. Known limit: a test that grants a
##   key only as setup (e.g. `defense.damage_taken_mult` 0 for immunity) counts as covering it; the
##   HOOK check and lead review of new keys bound that.
##   RATCHET (p4_coverage_ratchet.gd): the keys uncovered when the gate landed (UNHOOKED, UNTESTED,
##   with owners) are allowed; any other gap fails, and a listed key that gains coverage fails until it
##   is removed from the list, so the lists only shrink. Counts are printed on every run.
##
## Part 2, resolver goldens (test_10..test_14). Fixed loadouts through LoadoutResolver (ENV B) and the
## Modifiers service; every expected number is computed by hand from the .tres data and the rules in
## LoadoutResolver's header / skills.md / perk_decks.md (derivations in the comments), never
## snapshotted from the resolver's output.
extends TestCase
# LEAD D-097/D-098: goldens follow ENV B's PD2 table + PD2 mod steps, mod ADS deltas zeroed (env/b-content 26b37289).

## Keys uncovered when the gate landed (shrink-only allowlist, with owners).
const RATCHET: GDScript = preload("res://tests/integration/p4_coverage_ratchet.gd")
const CURRENT_PHASE: int = 4
const SELF_FILE: String = "test_p4_progression.gd"
const TEST_DIRS: Array[String] = ["res://tests/a", "res://tests/b", "res://tests/c", "res://tests/p", "res://tests/integration"]
const RUNTIME_DIRS: Array[String] = ["res://systems", "res://core", "res://world", "res://content"]
## Runtime files whose key literals are not hooks.
const NOT_HOOKS: Array[String] = ["res://core/modifiers.gd"]

## tests/b files whose modifier-key literals are data (grant tables, resolver output, UI, saves).
const DATA_ONLY_TESTS: Dictionary = {
	"test_perk_decks.gd": "perk deck data shape",
	"test_perk_resolver.gd": "resolver output",
	"test_perk_wiring.gd": "resolver -> Modifiers values + grep hook audit, no behaviour",
	"test_perk_ui.gd": "UI",
	"test_skill_data.gd": "skill data shape",
	"test_skill_points.gd": "skill budget + resolver output",
	"test_loadout_modifiers.gd": "resolver output",
	"test_loadout_resolver.gd": "resolver output",
	"test_modifier_push.gd": "push of resolved values into Modifiers",
	"test_content_data.gd": "data loading",
	"test_save_service.gd": "save round trip",
	"test_preplan.gd": "asset grant data / TEAM source plumbing",
	"test_preplan_result.gd": "asset grant data",
	"test_preplan_variants.gd": "asset grant data",
}

## key -> [test file (under res://tests), test function, what it shows]. Behaviour tests that grant
## the key through a skill / perk deck / call argument instead of naming it.
const INDIRECT: Dictionary = {
	&"progression.xp_mult": ["b/test_payout_calculator.gd", "test_xp_mult_joins_additive_line",
		"PayoutCalculator xp_mult 1.45 (the value of the key) joins the additive XP line"],
	&"progression.card_drop_quality_add": ["b/test_payday_cards.gd",
		"test_quality_add_comes_from_perk_deck_completion",
		"Foreman 9 cards (card 9 grants the key) raises the payday card quality"],
	&"weapon.headshot_mult": ["b/test_perk_behaviour.gd", "test_shared_cards_scale_weapon_damage_and_headshot_bonus",
		"Composure card 2 (weapon.headshot_mult.all 1.25) scales CrewWeapons.headshot_bonus"],
}

## Hook owner by path prefix (tools/ci/owners.json).
const OWNER_BY_PREFIX: Dictionary = {
	"res://systems/": "A", "res://content/": "B", "res://world/": "C", "res://core/": "LEAD",
}

## Golden loadout parts (content/data).
const CORSAIR: StringName = &"weapon.corsair_ar"
const PLOWMAN: StringName = &"weapon.plowman_12"
const KESTREL: StringName = &"weapon.kestrel_p9"
const KNIFE: StringName = &"melee.folding_knife"
const SUIT: StringName = &"armor.tailored_suit"
const LIGHT_VEST: StringName = &"armor.light_vest"


func after_each() -> void:
	Modifiers.clear_all()


# --- Part 1: modifier key coverage ---------------------------------------------------------------

func _p4_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in ModifierKeys.KEYS:
		if int((ModifierKeys.KEYS[key] as Array)[1]) <= CURRENT_PHASE:
			out.append(key)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


static func _gd_files(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		_gd_files(dir_path.path_join(sub), out)


## The code of one line with its trailing `#` comment removed (quote-aware).
static func _strip_comment(line: String) -> String:
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if quote != "":
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)
		i += 1
	return line


## Registry base keys named by string literals in the code (not comments) of `path`.
static func _keys_in_file(path: String, re: RegEx) -> Dictionary:
	var found: Dictionary = {}
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var code: String = _strip_comment(raw)
		if not code.contains("\""):
			continue
		for m: RegExMatch in re.search_all(code):
			var lit: StringName = StringName(m.get_string(1))
			var base: StringName = lit if ModifierKeys.KEYS.has(lit) else ModifierKeys.base_key(lit)
			if ModifierKeys.KEYS.has(base):
				found[base] = true
	return found


static func _literal_re() -> RegEx:
	var re: RegEx = RegEx.new()
	re.compile("\"([a-z_]+\\.[a-z_]+(?:\\.[a-z_]+)?)\"")
	return re


## base key -> Array[String] of runtime files naming it.
func _hooks() -> Dictionary:
	var re: RegEx = _literal_re()
	var files: Array[String] = []
	for d: String in RUNTIME_DIRS:
		_gd_files(d, files)
	var out: Dictionary = {}
	for path: String in files:
		if NOT_HOOKS.has(path):
			continue
		for k: Variant in _keys_in_file(path, re):
			if not out.has(k):
				out[k] = []
			(out[k] as Array).append(path)
	return out


## base key -> Array[String] of behaviour test files naming it.
func _behaviour_refs() -> Dictionary:
	var re: RegEx = _literal_re()
	var files: Array[String] = []
	for d: String in TEST_DIRS:
		_gd_files(d, files)
	var out: Dictionary = {}
	for path: String in files:
		var f: String = path.get_file()
		if f == SELF_FILE or not f.begins_with("test_"):
			continue
		if path.begins_with("res://tests/b/") and DATA_ONLY_TESTS.has(f):
			continue
		for k: Variant in _keys_in_file(path, re):
			if not out.has(k):
				out[k] = []
			(out[k] as Array).append(path.trim_prefix("res://tests/"))
	return out


func _owner(path: String) -> String:
	for prefix: String in OWNER_BY_PREFIX:
		if path.begins_with(prefix):
			return OWNER_BY_PREFIX[prefix]
	return "LEAD"


## The INDIRECT table itself must point at real test functions.
func test_01_indirect_entries_point_at_real_tests() -> void:
	for key: StringName in INDIRECT:
		var e: Array = INDIRECT[key]
		assert_true(ModifierKeys.KEYS.has(key), "INDIRECT key %s is in the registry" % key)
		var path: String = "res://tests/".path_join(String(e[0]))
		assert_true(FileAccess.file_exists(path), "INDIRECT %s: %s exists" % [key, path])
		var src: String = FileAccess.get_file_as_string(path)
		assert_true(src.contains("func %s(" % e[1]), "INDIRECT %s: %s defines %s" % [key, e[0], e[1]])
	for f: String in DATA_ONLY_TESTS:
		assert_true(FileAccess.file_exists("res://tests/b/".path_join(f)), "DATA_ONLY_TESTS entry %s exists" % f)


## The ratchet lists name real keys <= P4, each in one list only, each with an owner.
func test_01b_ratchet_lists_are_well_formed() -> void:
	for list: Dictionary in [RATCHET.UNHOOKED, RATCHET.UNTESTED]:
		for key: Variant in list:
			var k: StringName = StringName(key)
			assert_true(ModifierKeys.KEYS.has(k), "ratchet key %s is in the registry" % k)
			if ModifierKeys.KEYS.has(k):
				assert_true(int((ModifierKeys.KEYS[k] as Array)[1]) <= CURRENT_PHASE, "ratchet key %s is <= P4" % k)
			assert_true(String(list[key]) != "", "ratchet key %s has an owner" % k)
	for key: Variant in RATCHET.UNHOOKED:
		assert_false(RATCHET.UNTESTED.has(key), "%s is in both ratchet lists" % key)


## Every key <= P4 is read by runtime code (a hook), except the shrinking RATCHET.UNHOOKED list.
func test_02_every_p4_key_has_a_runtime_hook() -> void:
	var hooks: Dictionary = _hooks()
	var missing: Array[String] = []
	var stale: Array[String] = []
	for key: StringName in _p4_keys():
		var listed: bool = RATCHET.UNHOOKED.has(key)
		if not hooks.has(key) and not listed:
			missing.append("%s (phase %d)" % [key, (ModifierKeys.KEYS[key] as Array)[1]])
		elif hooks.has(key) and listed:
			stale.append("%s  [hook: %s]" % [key, ", ".join(_short_paths(hooks[key]))])
	print("P4 gate ratchet: %d keys <= P4 still have no runtime hook (p4_coverage_ratchet.gd UNHOOKED)"
		% RATCHET.UNHOOKED.size())
	if not missing.is_empty():
		fail("%d keys <= P4 lost or never had a runtime hook and are not in the ratchet (owner ENV A):\n       %s"
			% [missing.size(), "\n       ".join(missing)])
	if not stale.is_empty():
		fail(("%d keys in UNHOOKED are now hooked: remove them from p4_coverage_ratchet.gd UNHOOKED (move"
			+ " to UNTESTED if they still lack a behaviour test):\n       %s")
			% [stale.size(), "\n       ".join(stale)])


## Every key <= P4 has a behaviour test, except the shrinking RATCHET lists.
func test_03_every_p4_key_has_a_behaviour_test() -> void:
	var hooks: Dictionary = _hooks()
	var refs: Dictionary = _behaviour_refs()
	var new_gaps: Array[String] = []
	var stale: Array[String] = []
	var covered: int = 0
	for key: StringName in _p4_keys():
		if refs.has(key) or INDIRECT.has(key):
			covered += 1
			if RATCHET.UNTESTED.has(key):
				stale.append(String(key))
			continue
		if not hooks.has(key):
			if not RATCHET.UNHOOKED.has(key):
				new_gaps.append("%s  [no hook, no behaviour test; owner ENV A]" % key)
			continue
		if RATCHET.UNTESTED.has(key):
			continue
		if RATCHET.UNHOOKED.has(key):
			continue  # test_02 reports it: hooked now, move it to UNTESTED.
		var owners: Dictionary = {}
		for p: String in hooks[key]:
			owners[_owner(p)] = true
		new_gaps.append("%s  [owner %s; hook: %s]" % [key, "/".join(owners.keys()), ", ".join(_short_paths(hooks[key]))])
	print("P4 gate coverage: %d of %d keys <= P4 have a behaviour test; ratchet: %d UNHOOKED + %d UNTESTED remain"
		% [covered, _p4_keys().size(), RATCHET.UNHOOKED.size(), RATCHET.UNTESTED.size()])
	if not new_gaps.is_empty():
		fail("%d keys <= P4 have no behaviour test and are not in the ratchet:\n       %s"
			% [new_gaps.size(), "\n       ".join(new_gaps)])
	if not stale.is_empty():
		fail("%d keys in UNTESTED now have a behaviour test: remove them from p4_coverage_ratchet.gd UNTESTED:\n       %s"
			% [stale.size(), "\n       ".join(stale)])


static func _short_paths(paths: Array) -> Array[String]:
	var out: Array[String] = []
	for p: Variant in paths:
		out.append(String(p).trim_prefix("res://"))
	return out


# --- Part 2: resolver goldens ----------------------------------------------------------------------

func _loadout(primary: StringName, primary_mods: Array[StringName], armor: StringName) -> Loadout:
	var l: Loadout = Loadout.new()
	l.primary = primary
	l.primary_mods = primary_mods
	l.secondary = KESTREL
	l.melee = KNIFE
	l.armor = armor
	return l


func _assert_stats(s: WeaponStats, expected: Dictionary, label: String) -> void:
	assert_true(s != null, "%s resolved" % label)
	if s == null:
		return
	for field: String in expected:
		var want: Variant = expected[field]
		var got: Variant = s.get(field)
		if want is float:
			assert_near(float(got), want, 0.0001, "%s.%s" % [label, field])
		else:
			assert_eq(got, want, "%s.%s" % [label, field])


## Compares a resolved modifier dictionary with the hand-derived one: same key set, numbers within
## 1e-4, everything else (FLAG, PARAMS / LIST dictionaries) equal.
func _assert_mods(got: Dictionary, expected: Dictionary, label: String) -> void:
	for k: Variant in expected:
		if not got.has(k):
			fail("%s: missing modifier %s" % [label, k])
			continue
		var want: Variant = expected[k]
		if want is float or want is int:
			assert_near(float(got[k]), float(want), 0.0001, "%s %s" % [label, k])
		else:
			assert_eq(str(got[k]), str(want), "%s %s" % [label, k])
	for k: Variant in got:
		if not expected.has(k):
			fail("%s: unexpected modifier %s = %s" % [label, k, got[k]])


## Golden 1: suppressed Corsair AR + a Shade/Ringleader stealth build (weapon mods, suppressed
## concealment qualifier, skill MULT merging, multi-qualifier runtime query).
## Corsair base (weapons/corsair_ar.tres) + suppressor + reflex (replaces default iron sights) +
## vertical grip + extended mag (replaces default standard mag):
##   damage 55 - 4 = 51; spread_ads 0.8 - 0.1 = 0.7; recoil_kick 0.9 - 0.1 - 0.2 = 0.6;
##   recoil_h 0.45 - 0.1 = 0.35; mag 30 + 10 = 40; total 150 + 30 = 180; reload 2.4 + 0.3 = 2.7,
##   empty 3.1 + 0.4 = 3.5; concealment 20 - 3 - 1 - 1 - 2 = 13; suppression 12 - 12 = 0;
##   ads_time 0.28 + 0.06 + 0.02 + 0.03 = 0.39; magnification max(1, 1.15); suppressed, noise
##   min(70, 1) = 1. Falloff and fire rate unchanged (deltas 0).
## Concealment: 13 + Kestrel 30 (default mods are zero deltas) + knife 30 + suit 30 = 103; bonus =
##   Low Profile aced 3 x 1 suppressed weapon + Deep Pockets basic melee 2 + aced armor 4 = 9;
##   total 112 -> concealment_curve dr_by_total[112 - 91 = 21] = 13.
func test_10_golden_suppressed_ar_stealth_build() -> void:
	var l: Loadout = _loadout(CORSAIR, [&"mod.corsair_suppressor", &"mod.rail_reflex_sight",
		&"mod.corsair_vertical_grip", &"mod.corsair_extended_mag"], SUIT)
	l.skills = {
		&"skill.quiet_professional.low_profile": 2, &"skill.slipstream.deep_pockets": 2,
		&"skill.quiet_professional.hushed_hands": 2, &"skill.marksman.steady_aim": 2,
		&"skill.gunnery.firm_grip": 2,
	}
	var r: Loadout = LoadoutResolver.resolve(l)
	_assert_stats(r.resolved_primary, {
		"damage": 51.0, "pellets": 1, "fire_rate_rpm": 700.0, "spread_deg_hip": 3.16, "spread_deg_ads": 2.508,
		"recoil_kick_deg": 0.84, "recoil_horizontal_deg": 1.2, "falloff_start_m": 9999.0,
		"falloff_end_m": 9999.0, "mag_size": 40, "total_ammo": 180, "reload_time_s": 2.7,
		"reload_empty_time_s": 3.5, "equip_time_s": 0.55, "ads_time_s": 0.25, "concealment": 13,
		"suppression": 0.0, "suppressed": true, "noise_radius_m": 1.0, "magnification": 1.15,
	}, "corsair")
	var bd: Dictionary = LoadoutResolver.concealment_breakdown(l)
	assert_eq(bd, {"primary": 13, "secondary": 30, "melee": 30, "armor": 30, "bonus": 9, "total": 112,
		"detection_risk": 13}, "concealment breakdown")
	assert_eq(r.concealment_total, 112)
	assert_eq(r.detection_risk, 13)
	# Firm Grip aced (spread.all 0.92 basic, recoil.all 0.84 aced) x Steady Aim (recoil.all 0.92 basic,
	# still_spread.all 0.84 aced): recoil.all = 0.84 x 0.92 = 0.7728 (MULT multiplies, D-031 QB-34).
	# Hushed Hands: recoil.suppressed 0.92, ads.suppressed 2.0, spread.suppressed 0.88 (aced).
	# Low Profile: target_priority 0.65 + concealment_add.suppressed 3. Deep Pockets: melee 2, armor 4.
	_assert_mods(r.modifiers, {
		&"weapon.recoil_mult.all": 0.7728, &"weapon.spread_mult.all": 0.92,
		&"weapon.still_spread_mult.all": 0.84, &"weapon.recoil_mult.suppressed": 0.92,
		&"weapon.ads_speed_mult.suppressed": 2.0, &"weapon.spread_mult.suppressed": 0.88,
		&"defense.target_priority_mult": 0.65, &"stealth.concealment_add.suppressed": 3,
		&"stealth.concealment_add.melee": 2, &"stealth.concealment_add.armor": 4,
	}, "golden 1")
	assert_eq(LoadoutResolver.team_modifier_sources(l), {}, "no team.* grants")
	# Runtime query of the resolved grants on slot 2 (never assume slot 0 / a single player):
	# AR + suppressed combines .all with both qualifiers: recoil 0.7728 x 0.92 = 0.710976,
	# spread 0.92 x 0.88 = 0.8096; an unsuppressed pistol gets only .all.
	Modifiers.set_source(2, &"skills", r.modifiers)
	assert_near(Modifiers.mult(2, &"weapon.recoil_mult", [&"assault_rifle", &"suppressed"]), 0.710976, 0.0001)
	assert_near(Modifiers.mult(2, &"weapon.spread_mult", [&"assault_rifle", &"suppressed"]), 0.8096, 0.0001)
	assert_near(Modifiers.mult(2, &"weapon.recoil_mult", &"pistol"), 0.7728, 0.0001)
	assert_near(Modifiers.mult(0, &"weapon.recoil_mult", &"pistol"), 1.0, 0.0001, "slot 0 untouched")


## Golden 2: shell-fed shotgun + Bruiser/Ringleader skills + Foreman at 5 cards (D-045 derived reload,
## skill basic x aced MULT, skill x perk card MULT on one key, card gating, PARAMS last card wins,
## team.* split into TEAM sources).
## Plowman base + choke + pistol grip + extended tube (replaces default standard tube):
##   spread_hip 4.0 - 0.5 - 0.3 = 3.2; spread_ads 2.0 - 0.5 + 0.5 = 2.0; recoil 2.6 + 0.8 = 3.4;
##   recoil_h 0.9 + 0.3 = 1.2; mag 6 + 2 = 8; total 48 + 8 = 56; concealment 21 - 1 + 5 - 2 = 23;
##   ads_time 0.3 + 0.02 = 0.32; D-045: reload = 0.4 + 8 x 0.4333 + 0.4 = 4.2664,
##   empty = 0.4 + 8 x 0.4333 + 1.2 = 5.0664.
## Concealment: 23 + 30 + 30 + light vest 26 + Foreman card 4 concealment_add.all 1 = 110 ->
##   dr_by_total[19] = 16.
func test_11_golden_shotgun_foreman_five_cards() -> void:
	var l: Loadout = _loadout(PLOWMAN, [&"mod.plowman_choke", &"mod.plowman_pistol_grip",
		&"mod.plowman_extended_tube"], LIGHT_VEST)
	l.skills = {
		&"skill.scattergun.heavy_shot": 2, &"skill.scattergun.pump_action": 2,
		&"skill.persuader.zip_and_tie": 2, &"skill.scrapper.nothing_to_lose": 1,
	}
	l.perk_deck = &"perk.foreman"
	l.perk_deck_cards = 5
	var r: Loadout = LoadoutResolver.resolve(l)
	_assert_stats(r.resolved_primary, {
		"damage": 16.0, "pellets": 10, "fire_rate_rpm": 70.0, "spread_deg_hip": 2.58, "spread_deg_ads": 2.9,
		"recoil_kick_deg": 4.885, "recoil_horizontal_deg": 0.51, "falloff_start_m": 8.0, "falloff_end_m": 22.0,
		"falloff_min_mult": 0.15, "mag_size": 8, "total_ammo": 56, "reload_time_s": 4.2664,
		"reload_empty_time_s": 5.0664, "ads_time_s": 0.23, "concealment": 23, "suppressed": false,
		"noise_radius_m": 80.0,
	}, "plowman")
	assert_eq(r.concealment_total, 110)
	assert_eq(r.detection_risk, 16)
	# Heavy Shot: recoil.shotgun 0.92; damage.shotgun 1.05 x 1.095 = 1.14975 (skills.md: basic x aced =
	# PD2 total). Pump Action: reload.shotgun 1.15 x 1.174 = 1.3501, ads.shotgun 2.25. Zip & Tie: ties
	# +4, tie speed 0.25 (aced team key goes to TEAM). Nothing to Lose basic: health 0.3, damage taken
	# 0.9, healing 0.25. Foreman cards 1..5: crew_chief (card 3 dict replaces card 1), headshot.all 1.25,
	# shout range 1.25, concealment.all 1, xp 1.45, armor penalty 0.85, health 1.0909091 (card 5) ->
	# defense.health_mult = 0.3 x 1.0909091 = 0.3272727. Cards 6..9 (ammo pickup, armor bag,
	# damage.all, card drop quality) are locked.
	_assert_mods(r.modifiers, {
		&"weapon.recoil_mult.shotgun": 0.92, &"weapon.damage_mult.shotgun": 1.14975,
		&"weapon.reload_speed_mult.shotgun": 1.3501, &"weapon.ads_speed_mult.shotgun": 2.25,
		&"stealth.cable_ties_extra": 4, &"stealth.cable_tie_speed_mult": 0.25,
		&"defense.health_mult": 0.3272727, &"defense.damage_taken_mult": 0.9,
		&"defense.healing_received_mult": 0.25,
		&"perk.crew_chief": {"team_dr": 0.08, "self_low_health_threshold": 0.5, "self_low_health_dr_mult": 2.0,
			"close_range_m": 18.0, "close_range_dr": 0.08},
		&"weapon.headshot_mult.all": 1.25, &"ability.shout_range_mult": 1.25,
		&"stealth.concealment_add.all": 1, &"progression.xp_mult": 1.45, &"movement.armor_penalty_mult": 0.85,
	}, "golden 2")
	var team: Dictionary = LoadoutResolver.team_modifier_sources(l)
	assert_eq(team.keys().size(), 2, "one TEAM source per team skill / deck: %s" % [team.keys()])
	_assert_mods(team.get(&"team_skill.skill.persuader.zip_and_tie", {}), {
		&"team.damage_reduction_hostage": {"absorb_per_hostage": 5.0, "max_hostages": 8},
	}, "team_skill zip_and_tie")
	_assert_mods(team.get(&"team_perk.foreman", {}), {&"team.stamina_mult": 1.5, &"team.health_mult": 1.1},
		"team_perk.foreman at 5 cards")
	# Runtime: damage vs shotgun is the skill value only (card 8's damage.all is locked).
	Modifiers.set_source(1, &"skills", r.modifiers)
	assert_near(Modifiers.mult(1, &"weapon.damage_mult", &"shotgun"), 1.14975, 0.0001)
	assert_near(Modifiers.mult(1, &"weapon.headshot_mult", &"shotgun"), 1.25, 0.0001)
	assert_near(Modifiers.add(1, &"stealth.cable_ties_extra"), 4.0, 0.0001)


## Golden 3: LIST keys (D-031 / D-034) and the full Foreman deck.
## Run and Gun aced + Reload Rhythm aced each add a kill_reload_buff entry (aced dict replaces basic
## inside a skill), ordered by _source text: "skill.gunnery..." < "skill.marksman...". Back on Your
## Feet basic + Second Lease aced each add a post_revive_buff entry. Foreman 9 cards: crew_chief =
## card 9 dict; generic keys at 9 cards per perk_decks.md.
func test_12_golden_list_keys_and_full_foreman() -> void:
	var l: Loadout = _loadout(CORSAIR, [], SUIT)
	l.skills = {
		&"skill.gunnery.run_and_gun": 2, &"skill.marksman.reload_rhythm": 2,
		&"skill.undying.second_lease": 2, &"skill.undying.back_on_your_feet": 1,
	}
	l.perk_deck = &"perk.foreman"
	l.perk_deck_cards = 9
	var m: Dictionary = LoadoutResolver.resolve_modifiers(l)
	var krb: Array = [
		{"trigger": "auto_kills", "kills": 2, "classes": ["smg", "lmg", "assault_rifle", "special"],
			"reload_mult": 2.0, "duration": 0.0, "min_mult": 1.4, "mag_falloff": 0.01, "mag_falloff_from": 20,
			"_source": &"skill.gunnery.run_and_gun"},
		{"trigger": "headshot_kill", "kills": 1, "classes": ["smg", "assault_rifle", "sniper"],
			"reload_mult": 2.0, "duration": 4.0, "min_mult": 2.0, "mag_falloff": 0.0, "mag_falloff_from": 0,
			"_source": &"skill.marksman.reload_rhythm"},
	]
	var prb: Array = [
		{"duration": 10.0, "reload_mult": 1.0, "swap_mult": 1.0, "move_mult": 1.0, "damage_taken_mult": 0.7,
			"_source": &"skill.undying.back_on_your_feet"},
		{"duration": 10.0, "reload_mult": 2.0, "swap_mult": 2.0, "move_mult": 1.3, "damage_taken_mult": 1.0,
			"_source": &"skill.undying.second_lease"},
	]
	_assert_mods(m, {
		&"weapon.kill_reload_buff": krb, &"defense.post_revive_buff": prb,
		&"movement.shoot_while_sprinting.all": true,
		&"weapon.reload_speed_mult.smg": 1.15, &"weapon.reload_speed_mult.assault_rifle": 1.15,
		&"weapon.reload_speed_mult.sniper": 1.15,
		&"perk.crew_chief": {"team_dr": 0.08, "self_low_health_threshold": 0.5, "self_low_health_dr_mult": 2.0,
			"close_range_m": 18.0, "close_range_dr": 0.08, "hostage_health_per": 0.06,
			"hostage_stamina_per": 0.12, "hostage_max_count": 4},
		&"weapon.headshot_mult.all": 1.25, &"ability.shout_range_mult": 1.25,
		&"stealth.concealment_add.all": 1, &"progression.xp_mult": 1.45, &"movement.armor_penalty_mult": 0.85,
		&"defense.health_mult": 1.0909091, &"weapon.ammo_pickup_mult.all": 1.35, &"deploy.armor_bag": true,
		&"defense.armor_mult": 1.047619, &"weapon.damage_mult.all": 1.05,
		&"interaction.doctor_bag_speed_mult": 0.8333, &"progression.card_drop_quality_add": 0.1,
	}, "golden 3")
	# Through the service: one entry per source, `_source` kept.
	Modifiers.set_source(3, &"skills", m)
	var got: Array[Dictionary] = Modifiers.list(3, &"weapon.kill_reload_buff")
	assert_eq(got.size(), 2, "two kill_reload_buff effects")
	if got.size() == 2:
		assert_eq(got[0]["_source"], &"skill.gunnery.run_and_gun")
		assert_eq(got[1]["_source"], &"skill.marksman.reload_rhythm")
	assert_true(Modifiers.flag(3, &"movement.shoot_while_sprinting", &"lmg"), ".all flag answers per class")
	assert_true(Modifiers.list(0, &"weapon.kill_reload_buff").is_empty(), "slot 0 has no LIST entries")


## Golden 4: crew-wide non-stacking (modifiers.md, D-031 QB-35, B4-14). Two players with Foreman
## (5 and 9 cards) and Zip & Tie (aced and basic): one team_perk.foreman source, the 9-card copy
## (team.stamina 1.5, team.health 1.1, team.armor 1.05 + card 9's damage_reduction_hostage {5, 4});
## one team_skill.zip_and_tie source from the aced holder ({5, 8}; basic grants no team key).
## Pushed as TEAM sources, team.health_mult is 1.1 for every slot (not 1.1^2), granters included.
func test_13_golden_team_keys_do_not_stack_across_the_crew() -> void:
	var a: Loadout = _loadout(CORSAIR, [], SUIT)
	a.perk_deck = &"perk.foreman"
	a.perk_deck_cards = 5
	a.skills = {&"skill.persuader.zip_and_tie": 2}
	var b: Loadout = _loadout(PLOWMAN, [], LIGHT_VEST)
	b.perk_deck = &"perk.foreman"
	b.perk_deck_cards = 9
	b.skills = {&"skill.persuader.zip_and_tie": 1}
	var crew: Dictionary = LoadoutResolver.crew_team_modifier_sources([a, b])
	assert_eq(crew.keys().size(), 2, "sources: %s" % [crew.keys()])
	_assert_mods(crew.get(&"team_perk.foreman", {}), {
		&"team.stamina_mult": 1.5, &"team.health_mult": 1.1, &"team.armor_mult": 1.05,
		&"team.damage_reduction_hostage": {"absorb_per_hostage": 5.0, "max_hostages": 4},
	}, "strongest Foreman copy")
	_assert_mods(crew.get(&"team_skill.skill.persuader.zip_and_tie", {}), {
		&"team.damage_reduction_hostage": {"absorb_per_hostage": 5.0, "max_hostages": 8},
	}, "aced Zip & Tie")
	# Same result with the crew in the other order (ties aside, the strongest copy wins).
	var reversed: Dictionary = LoadoutResolver.crew_team_modifier_sources([b, a])
	assert_eq(reversed.keys().size(), crew.keys().size(), "order independent: same sources")
	for source: Variant in crew:
		assert_eq(str(reversed.get(source, {})), str(crew[source]), "order independent: %s" % source)
	for source: Variant in crew:
		Modifiers.set_source(Modifiers.TEAM, StringName(source), crew[source])
	for slot: int in [0, 1, 2, 3]:
		assert_near(Modifiers.mult(slot, &"team.health_mult"), 1.1, 0.0001, "slot %d team health" % slot)
		assert_near(Modifiers.mult(slot, &"team.stamina_mult"), 1.5, 0.0001, "slot %d team stamina" % slot)
	assert_eq(Modifiers.list(2, &"team.damage_reduction_hostage").size(), 2,
		"both hostage-absorption sources reach the service (TeamModifiers reads every source)")
	# Personal modifiers never carry team.* keys.
	for key: Variant in LoadoutResolver.resolve_modifiers(b):
		assert_false(String(key).begins_with("team."), "team key %s kept out of personal modifiers" % key)


## Golden 5: mod legality and clamps (data_schemas.md). An illegal mod (another weapon's part, a
## second magazine) is rejected and the stock default stays; the stock Kestrel and stock Corsair
## resolve to their base stats exactly (default mods are zero deltas).
func test_14_golden_illegal_mods_rejected_stock_stats_kept() -> void:
	Log.capture = true
	var s: WeaponStats = LoadoutResolver.resolve_weapon(CORSAIR,
		[&"mod.plowman_choke", &"mod.corsair_extended_mag", &"mod.corsair_standard_mag"])
	Log.capture = false
	Log.captured.clear()
	# plowman_choke: not in Corsair's slots -> rejected; extended mag taken, standard mag rejected
	# (slot already filled): mag 40, total 180, concealment 18, reload 2.7 / 3.5, rest stock.
	_assert_stats(s, {"damage": 55.0, "mag_size": 40, "total_ammo": 180, "concealment": 18,
		"reload_time_s": 2.7, "reload_empty_time_s": 3.5, "spread_deg_hip": 3.4, "spread_deg_ads": 2.7,
		"suppressed": false, "noise_radius_m": 70.0}, "corsair illegal mods")
	_assert_stats(LoadoutResolver.resolve_weapon(CORSAIR, []), {"damage": 55.0, "mag_size": 30,
		"total_ammo": 150, "concealment": 20, "reload_time_s": 2.4, "ads_time_s": 0.25}, "corsair stock")
	# Stock Plowman: D-045 derived 0.4 + 6 x 0.4333 + 0.4 = 3.3998, empty 0.4 + 2.5998 + 1.2 = 4.1998.
	_assert_stats(LoadoutResolver.resolve_weapon(PLOWMAN, []), {"mag_size": 6, "total_ammo": 48,
		"concealment": 21, "reload_time_s": 3.3998, "reload_empty_time_s": 4.1998}, "plowman stock")
	_assert_stats(LoadoutResolver.resolve_weapon(KESTREL, []), {"concealment": 30, "mag_size": 17},
		"kestrel stock")
