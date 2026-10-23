## B4-14: every perk deck at 9 cards pushed through the real modifier path
## (LoadoutResolver -> Modifiers.set_source(slot, &"perk", ...) + TEAM `team_perk.<deck>` sources ->
## Modifiers.mult/add/flag/params), card 1..n gating at every n, team_perk dedupe across slots, and
## the hook-coverage audit (perk_decks.md "Hook coverage"): every granted key is either hooked
## (ENV A or ENV B code that reads it) or filed as a QB.
extends TestCase

## Any weapon class qualifier: `.all` grants must answer for every class.
const Q: StringName = &"pistol"
const SLOT: int = 2

## Shared cards 2/4/6/8 + completion bonus, as seen through Modifiers (base key, qualifier, type, value).
const SHARED: Array = [
	[&"weapon.headshot_mult", Q, "mult", 1.25],
	[&"stealth.concealment_add", &"primary", "add", 1.0],
	[&"progression.xp_mult", &"", "mult", 1.45],
	[&"movement.armor_penalty_mult", &"", "mult", 0.85],
	[&"weapon.ammo_pickup_mult", Q, "mult", 1.35],
	[&"deploy.armor_bag", &"", "flag", true],
	[&"weapon.damage_mult", Q, "mult", 1.05],
	[&"interaction.doctor_bag_speed_mult", &"", "mult", 0.8333],
	[&"progression.card_drop_quality_add", &"", "add", 0.1],
]

## Per deck at 9 cards: the cumulative generic (non-PARAMS) values, personal and TEAM. Values are the
## PD2 totals from perk_decks.md (per-card MULT ratios multiply up to these).
const GENERIC: Dictionary = {
	&"perk.foreman": [
		[&"defense.health_mult", &"", "mult", 1.0909091],
		[&"defense.armor_mult", &"", "mult", 1.047619],
		[&"ability.shout_range_mult", &"", "mult", 1.25],
		[&"team.stamina_mult", &"", "mult", 1.5],
		[&"team.health_mult", &"", "mult", 1.1],
		[&"team.armor_mult", &"", "mult", 1.05],
	],
	&"perk.bulk": [[&"defense.health_mult", &"", "mult", 2.0]],
	&"perk.ironclad": [
		[&"defense.armor_mult", &"", "mult", 1.35],
		[&"defense.armor_regen_delay_mult", &"", "mult", 0.9],
		[&"team.armor_regen_delay_mult", &"", "mult", 0.9],
	],
	&"perk.slipper": [
		[&"defense.dodge_add", &"", "add", 0.45],
		[&"weapon.armor_pierce_add", Q, "add", 0.25],
		[&"weapon.swap_speed_mult", Q, "mult", 1.8],
	],
	&"perk.hustler": [
		[&"defense.dodge_add", &"", "add", 0.15],
		[&"defense.armor_regen_delay_mult", &"", "mult", 0.9],
	],
	&"perk.clean_sweep": [
		[&"defense.armor_mult", &"", "mult", 1.2],
		[&"defense.armor_regen_delay_mult", &"", "mult", 0.9],
	],
	&"perk.prowler": [
		[&"defense.dodge_add", &"", "add", 0.3],
		[&"stealth.body_bag_speed_mult", &"", "mult", 0.8],
		[&"interaction.lockpick_speed_mult", &"", "mult", 0.8],
		[&"stealth.pager_answer_speed_mult", &"", "mult", 0.9],
		[&"movement.crouch_speed_mult", &"", "mult", 1.1],
	],
	&"perk.knuckles": [],
	&"perk.bloodletter": [
		[&"defense.health_mult", &"", "mult", 1.4],
		[&"weapon.armor_pierce_add", Q, "add", 0.2],
	],
	&"perk.composure": [],
	&"perk.overclock": [],
	&"perk.incumbent": [
		[&"defense.health_mult", &"", "mult", 1.4],
		[&"defense.dodge_add", &"", "add", 0.15],
	],
	&"perk.long_odds": [[&"defense.health_mult", &"", "mult", 1.4]],
	&"perk.overlord": [[&"defense.health_mult", &"", "mult", 1.8]],
	&"perk.hacker": [[&"defense.health_mult", &"", "mult", 1.2], [&"defense.dodge_add", &"", "add", 0.3]],
	&"perk.inkwork": [],
	&"perk.road_crew": [],
	&"perk.frenzy": [],
}

const ARMOR_IDS: Array = [&"armor.tailored_suit", &"armor.light_vest", &"armor.patrol_vest", &"armor.heavy_vest",
	&"armor.flak_rig", &"armor.tactical_plate", &"armor.breacher_plate"]

## Per deck at 9 cards: every PARAMS key -> the full dict of the approved schema (perk_decks.md
## "Proposed PARAMS schemas", D-031), final values. Exact field set: no missing or extra fields.
const PARAMS: Dictionary = {
	&"perk.foreman": {
		&"perk.crew_chief": {"team_dr": 0.08, "self_low_health_threshold": 0.5, "self_low_health_dr_mult": 2.0,
			"close_range_m": 18.0, "close_range_dr": 0.08, "hostage_health_per": 0.06,
			"hostage_stamina_per": 0.12, "hostage_max_count": 4},
		&"team.damage_reduction_hostage": {"absorb_per_hostage": 5.0, "max_hostages": 4},
	},
	&"perk.bulk": {&"perk.muscle": {"aggro_near_crew_mult": 1.15, "near_crew_m": 8.0, "panic_chance": 0.1,
		"panic_radius_m": 6.0, "regen_fraction": 0.03, "regen_interval_s": 5.0}},
	&"perk.ironclad": {&"perk.armorer": {"break_immunity_s": 2.0, "break_immunity_cooldown_s": 15.0}},
	&"perk.slipper": {&"perk.rogue_dodge_stack": {"aggro_near_crew_mult": 0.85, "near_crew_m": 8.0}},
	&"perk.hustler": {&"perk.crook": {"vest_armor_ids": [&"armor.light_vest", &"armor.patrol_vest", &"armor.heavy_vest"],
		"vest_dodge_add": 0.25, "vest_armor_mult": 1.65}},
	&"perk.clean_sweep": {&"perk.sociopath": {"kill_armor": 30.0, "kill_armor_cooldown_s": 1.0, "close_range_m": 18.0,
		"close_range_dr": 0.08, "melee_kill_health_fraction": 0.1, "melee_kill_cooldown_s": 1.0,
		"close_kill_armor": 30.0, "close_kill_panic_chance": 0.75, "close_kill_panic_cooldown_s": 1.0,
		"panic_radius_m": 6.0, "forced_regen_after_break_s": 1.5}},
	&"perk.prowler": {&"perk.burglar": {"still_aggro_mult": 0.8, "still_regen_delay_mult": 0.8}},
	&"perk.knuckles": {&"perk.infiltrator": {"surrounded_min_enemies": 3, "surrounded_radius_m": 6.0,
		"surrounded_dr": 0.12, "melee_chain_mult": 10.0, "melee_chain_window_s": 7.0, "close_range_m": 18.0,
		"close_range_dr": 0.24, "melee_hit_heal_fraction": 0.2, "melee_hit_heal_cooldown_s": 10.0}},
	&"perk.bloodletter": {&"perk.grinder": {"allowed_armor_ids": [&"armor.tailored_suit", &"armor.light_vest"],
		"heal_per_tick": 4.0, "tick_s": 0.3, "duration_s": 4.2, "stack_cooldown_s": 1.5}},
	&"perk.composure": {
		&"perk.stoic": {"delayed_fraction": 0.75, "dot_duration_s": 12.0, "flask_cooldown_s": 10.0,
			"kill_cooldown_reduction_s": 1.0, "armor_to_health": 1.0, "auto_negate_after_s": 4.0,
			"low_health_threshold": 0.35, "low_health_kill_cooldown_reduction_s": 2.0, "negate_heal_fraction": 0.5},
		&"perk.throwable": {"item_id": &"throwable.steady_flask"},
	},
	&"perk.overclock": {&"perk.anarchist": {"tick_by_armor": {&"armor.tailored_suit": [1.0, 2.0],
		&"armor.light_vest": [1.5, 3.0], &"armor.patrol_vest": [2.0, 4.0], &"armor.heavy_vest": [3.5, 6.0],
		&"armor.flak_rig": [4.0, 7.0], &"armor.tactical_plate": [4.5, 8.0], &"armor.breacher_plate": [6.0, 10.0]},
		"break_immunity_s": 2.0, "break_immunity_cooldown_s": 15.0, "health_to_armor_fraction": 0.5,
		"health_to_armor_ratio": 1.2, "damage_dealt_armor": 30.0, "damage_dealt_armor_cooldown_s": 1.5}},
	&"perk.incumbent": {&"perk.ex_president": {"store_per_kill": 12.0, "max_store_by_armor": {
		&"armor.tailored_suit": 24.0, &"armor.light_vest": 30.0, &"armor.patrol_vest": 36.0,
		&"armor.heavy_vest": 42.0, &"armor.flak_rig": 48.0, &"armor.tactical_plate": 54.0,
		&"armor.breacher_plate": 60.0}, "max_store_mult": 1.5, "kill_regen_speedup_fraction": 0.1}},
	&"perk.long_odds": {&"perk.gambler": {"heal_min": 16.0, "heal_max": 24.0, "heal_bonus": 16.0, "cooldown_s": 3.0,
		"lowest_health_bonus_per_ally": 0.2, "lowest_health_max_stacks": 3, "team_ammo_share": 0.5,
		"team_ammo_share_cooldown_s": 5.0, "team_heal_fraction": 0.5}},
	&"perk.overlord": {
		&"perk.kingpin": {"heal_fraction": 0.75, "duration_s": 6.0, "cooldown_s": 30.0, "kill_cooldown_reduction_s": 1.0,
			"draws_aggro": true, "low_health_threshold": 0.5, "low_health_heal_bonus": 0.25,
			"overheal_per_cooldown_s": 50.0},
		&"perk.throwable": {"item_id": &"throwable.boss_injector"},
	},
	&"perk.hacker": {  # D-161: A's pocket ECM reads stealth.pocket_ecm
		&"stealth.pocket_ecm": {"charges": 2, "duration_s": 6.0, "cooldown_s": 100.0, "kill_cooldown_reduction_s": 6.0,
			"kill_heal": 20.0, "kill_dodge_add": 0.2, "kill_dodge_s": 30.0, "crew_kill_heal": 10.0},
		&"perk.throwable": {"item_id": &"throwable.pocket_ecm"},
	},
	&"perk.inkwork": {  # D-162: A's perk.yakuza
		&"perk.yakuza": {"low_health_threshold": 0.5, "armor_regen_max_add": 0.6, "move_speed_max_add": 0.2,
			"blocks_regen": true},
	},
	&"perk.road_crew": {  # D-162: A's perk.biker
		&"perk.biker": {"heal": 5.0, "armor": 5.0, "max_procs": 4, "window_s": 4.0, "armor_per_missing_health": 1.0,
			"window_cut_per_missing_health": 0.1, "heal_per_missing_armor": 1.0, "window_cut_per_missing_armor": 0.1},
	},
	&"perk.frenzy": {  # D-162: A's perk.maniac
		&"perk.maniac": {"conversion": 1.0, "gain_cap": 240.0, "gain_window_s": 4.0, "max_stacks": 600.0,
			"stacks_per_absorb": 25.0, "decay_fraction": 0.6, "decay_flat": 40.0, "decay_interval_s": 8.0, "team": true,
			"self_absorb_mult": 2.0},
	},
}

## Hook coverage (perk_decks.md "Hook coverage"): base key -> file that reads it with
## `&"<base key>"`. ENV A hooks are under res://systems, ENV B's (progression) under res://content.
const HOOKED: Dictionary = {
	&"weapon.headshot_mult": "res://systems/combat/crew_weapons.gd",
	&"weapon.damage_mult": "res://systems/combat/crew_weapons.gd",
	&"weapon.swap_speed_mult": "res://systems/combat/crew_weapons.gd",
	&"weapon.armor_pierce_add": "res://systems/combat/combat_system.gd",
	&"defense.health_mult": "res://systems/combat/crew_health.gd",
	&"defense.armor_mult": "res://systems/combat/crew_health.gd",
	&"defense.dodge_add": "res://systems/combat/crew_health.gd",
	&"defense.armor_regen_delay_mult": "res://systems/combat/crew_health.gd",
	&"stealth.body_bag_speed_mult": "res://systems/loot/loot_manager.gd",
	&"interaction.lockpick_speed_mult": "res://systems/prefabs/door/door.gd",
	&"stealth.pager_answer_speed_mult": "res://systems/stealth/pager_system.gd",
	&"movement.crouch_speed_mult": "res://systems/player/crew_controller.gd",
	&"ability.shout_range_mult": "res://systems/ai/police/police_surrender.gd",
	&"stealth.concealment_add": "res://content/progression/loadout_resolver.gd",
	&"progression.xp_mult": "res://content/ui/results/payday.gd",
	&"progression.card_drop_quality_add": "res://content/progression/payday_cards.gd",
	# QB-56..62 (A3-08, D-056)
	&"movement.armor_penalty_mult": "res://systems/player/crew_controller.gd",
	&"weapon.ammo_pickup_mult": "res://systems/combat/ammo_pickup_system.gd",
	&"deploy.armor_bag": "res://systems/deployables/deployable_system.gd",
	&"interaction.doctor_bag_speed_mult": "res://systems/prefabs/deployable/deployable.gd",
	&"team.health_mult": "res://systems/combat/crew_health.gd",
	&"team.armor_mult": "res://systems/combat/crew_health.gd",
	&"team.stamina_mult": "res://systems/combat/team_modifiers.gd",
	&"team.damage_reduction_hostage": "res://systems/combat/team_modifiers.gd",
	&"team.armor_regen_delay_mult": "res://systems/combat/crew_health.gd",
	&"perk.crew_chief": "res://systems/combat/perks/perk_crew_chief.gd",
	&"perk.muscle": "res://systems/combat/perks/perk_muscle.gd",
	&"perk.armorer": "res://systems/combat/perks/perk_armorer.gd",
	&"perk.crook": "res://systems/combat/perks/perk_crook.gd",
	&"perk.sociopath": "res://systems/combat/perks/perk_sociopath.gd",
	&"perk.burglar": "res://systems/combat/perks/perk_burglar.gd",
	&"perk.infiltrator": "res://systems/combat/perks/perk_infiltrator.gd",
	&"perk.grinder": "res://systems/combat/perks/perk_grinder.gd",
	&"perk.stoic": "res://systems/combat/perks/perk_stoic.gd",
	&"perk.anarchist": "res://systems/combat/perks/perk_anarchist.gd",
	&"perk.ex_president": "res://systems/combat/perks/perk_ex_president.gd",
	&"perk.gambler": "res://systems/combat/perks/perk_gambler.gd",
	&"perk.kingpin": "res://systems/combat/perks/perk_kingpin.gd",
	&"perk.throwable": "res://systems/combat/perks/perk_throwable.gd",
	&"perk.rogue_dodge_stack": "res://systems/combat/perks/perk_rogue.gd",
	&"stealth.pocket_ecm": "res://systems/combat/perks/perk_pocket_ecm.gd",  # D-161 (A 5f09d31a)
	&"perk.yakuza": "res://systems/combat/perks/perk_yakuza.gd",  # D-162 (A 3668b28c)
	&"perk.biker": "res://systems/combat/perks/perk_biker.gd",
	&"perk.maniac": "res://systems/combat/perks/perk_maniac.gd",
}
## Granted keys with no hook yet: filed as QBs (perk_decks.md "Hook coverage"). Empty again since D-161 / D-162.
const MISSING: Array = []


func before_all() -> void:
	ContentDB.clear_cache()


func after_each() -> void:
	Modifiers.clear_all()


func after_all() -> void:
	ContentDB.clear_cache()


func _loadout(deck: StringName, cards: int) -> Loadout:
	var l: Loadout = Loadout.new()
	l.perk_deck = deck
	l.perk_deck_cards = cards
	return l


func _deck(id: StringName) -> PerkDeckDef:
	return ContentDB.by_id(ContentDB.PERKS, id) as PerkDeckDef


## The real path: the slot's personal perk source and the loadout's TEAM sources.
func _push(slot: int, l: Loadout) -> void:
	Modifiers.set_source(slot, &"perk", LoadoutResolver.resolve(l).modifiers)
	var team: Dictionary = LoadoutResolver.team_modifier_sources(l)
	for s: Variant in team:
		Modifiers.set_source(Modifiers.TEAM, StringName(s), team[s])


func _query(slot: int, row: Array) -> Variant:
	match String(row[2]):
		"mult":
			return Modifiers.mult(slot, row[0], row[1])
		"add":
			return Modifiers.add(slot, row[0], row[1])
		_:
			return Modifiers.flag(slot, row[0], row[1])


func _assert_row(slot: int, row: Array, ctx: String) -> void:
	var got: Variant = _query(slot, row)
	if row[3] is bool:
		assert_eq(got, row[3], "%s %s" % [ctx, row[0]])
	else:
		assert_near(float(got), float(row[3]), 0.0001, "%s %s" % [ctx, row[0]])


## Deep equality with float tolerance (PARAMS dicts hold floats, ints, ids, arrays and dicts).
func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int) and not (a is bool or b is bool):
		return absf(float(a) - float(b)) < 0.0001
	if a is Dictionary and b is Dictionary:
		return _same_dict(a as Dictionary, b as Dictionary)
	if a is Array and b is Array:
		return _same_array(a as Array, b as Array)
	if (a is StringName or a is String) and (b is StringName or b is String):
		return String(a) == String(b)
	return typeof(a) == typeof(b) and a == b


func _same_dict(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k: Variant in a:
		if not b.has(k) or not _same(a[k], b[k]):
			return false
	return true


func _same_array(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if not _same(a[i], b[i]):
			return false
	return true


# --- Full deck through the real path ---------------------------------------------------------------

func test_every_deck_at_nine_cards_reaches_modifiers() -> void:
	assert_eq(GENERIC.size(), 18, "expectations cover 18 decks")
	for deck_id: StringName in GENERIC:
		assert_true(_deck(deck_id) != null, "%s exists" % deck_id)
		Modifiers.clear_all()
		_push(SLOT, _loadout(deck_id, 9))
		var ctx: String = String(deck_id)
		for row: Array in SHARED:
			_assert_row(SLOT, row, ctx)
		for row: Array in GENERIC[deck_id]:
			_assert_row(SLOT, row, ctx)
		for key: StringName in PARAMS[deck_id]:
			var got: Dictionary = Modifiers.params(SLOT, key)
			var want: Dictionary = PARAMS[deck_id][key]
			assert_true(_same(got, want), "%s %s params\n got  %s\n want %s" % [ctx, key, got, want])
			for f: Variant in want:
				assert_true(got.has(f), "%s %s field %s granted" % [ctx, key, f])
			for f: Variant in got:
				assert_true(want.has(f), "%s %s field %s is in the approved schema" % [ctx, key, f])
		# Nothing granted beyond the table, and no other slot is touched.
		var expected_keys: Dictionary = {}
		for row: Array in SHARED + GENERIC[deck_id]:
			expected_keys[row[0]] = true
		for key: StringName in PARAMS[deck_id]:
			expected_keys[key] = true
		for key: Variant in LoadoutResolver.resolve_modifiers(_loadout(deck_id, 9)):
			assert_true(expected_keys.has(ModifierKeys.base_key(key)), "%s grants unexpected key %s" % [ctx, key])
		assert_near(Modifiers.mult(0, &"weapon.damage_mult", Q), 1.0, 0.0001, "%s: slot 0 untouched" % ctx)


func test_team_keys_only_reach_modifiers_through_team() -> void:
	_push(SLOT, _loadout(&"perk.foreman", 9))
	var personal: Dictionary = LoadoutResolver.resolve_modifiers(_loadout(&"perk.foreman", 9))
	for key: Variant in personal:
		assert_false(String(key).begins_with("team."), "team key %s not personal" % key)
	for slot: int in range(4):
		assert_near(Modifiers.mult(slot, &"team.health_mult"), 1.1, 0.0001, "slot %d team health" % slot)
		assert_near(Modifiers.mult(slot, &"team.stamina_mult"), 1.5, 0.0001, "slot %d team stamina" % slot)
		assert_eq(Modifiers.params(slot, &"team.damage_reduction_hostage"), {"absorb_per_hostage": 5.0, "max_hostages": 4})
	# Personal part stays on the holder: health 1.0909091 x team 1.1 = PD2's +20%.
	assert_near(Modifiers.mult(SLOT, &"defense.health_mult") * Modifiers.mult(SLOT, &"team.health_mult"), 1.2, 0.0001)
	assert_near(Modifiers.mult(0, &"defense.health_mult") * Modifiers.mult(0, &"team.health_mult"), 1.1, 0.0001)
	assert_near(Modifiers.mult(SLOT, &"defense.armor_mult") * Modifiers.mult(SLOT, &"team.armor_mult"), 1.1, 0.0001)


func test_perk_throwable_ids_and_armor_ids_exist() -> void:
	for deck_id: StringName in PARAMS:
		for key: StringName in PARAMS[deck_id]:
			var p: Dictionary = PARAMS[deck_id][key]
			if p.has("item_id"):
				assert_true(ContentDB.by_id(ContentDB.THROWABLES, p["item_id"]) != null, "%s throwable" % p["item_id"])
			for f: String in ["vest_armor_ids", "allowed_armor_ids"]:
				for id: Variant in p.get(f, []):
					assert_true(ContentDB.armor(id) != null, "%s %s %s" % [deck_id, f, id])
			for f: String in ["tick_by_armor", "max_store_by_armor"]:
				if p.has(f):
					assert_eq((p[f] as Dictionary).size(), ARMOR_IDS.size(), "%s %s covers every armor" % [deck_id, f])
					for id: Variant in ARMOR_IDS:
						assert_true((p[f] as Dictionary).has(id), "%s %s has %s" % [deck_id, f, id])


# --- Cards 1..n gating -----------------------------------------------------------------------------

## For every deck and n in 0..9, Modifiers answers exactly the merge of cards 1..n (independent oracle
## over the raw card data: MULT product, ADD sum, FLAG or, PARAMS last card wins), TEAM keys included.
func test_cards_one_to_n_gate_every_key() -> void:
	for deck_id: StringName in GENERIC:
		var deck: PerkDeckDef = _deck(deck_id)
		for n: int in range(10):
			Modifiers.clear_all()
			_push(SLOT, _loadout(deck_id, n))
			var oracle: Dictionary = {}
			for i: int in range(n):
				var grants: Dictionary = deck.cards[i].get("grants", {})
				for key: Variant in grants:
					var k: StringName = StringName(key)
					var v: Variant = grants[key]
					if not oracle.has(k):
						oracle[k] = v
					else:
						match ModifierKeys.type_of(k):
							ModifierKeys.Type.MULT:
								oracle[k] = float(oracle[k]) * float(v)
							ModifierKeys.Type.ADD:
								oracle[k] = float(oracle[k]) + float(v)
							ModifierKeys.Type.FLAG:
								oracle[k] = bool(oracle[k]) or bool(v)
							_:
								oracle[k] = v
			var ctx: String = "%s @%d" % [deck_id, n]
			# Every key any card of the deck grants: present iff a card <= n grants it.
			for i: int in range(deck.cards.size()):
				for key: Variant in deck.cards[i].get("grants", {}):
					var k: StringName = StringName(key)
					var base: StringName = ModifierKeys.base_key(k)
					var q: StringName = Q if base != k else &""
					if base == &"stealth.concealment_add":
						q = &"primary"
					match ModifierKeys.type_of(k):
						ModifierKeys.Type.MULT:
							assert_near(Modifiers.mult(SLOT, base, q), float(oracle.get(k, 1.0)), 0.0001, "%s %s" % [ctx, k])
						ModifierKeys.Type.ADD:
							assert_near(Modifiers.add(SLOT, base, q), float(oracle.get(k, 0.0)), 0.0001, "%s %s" % [ctx, k])
						ModifierKeys.Type.FLAG:
							assert_eq(Modifiers.flag(SLOT, base, q), bool(oracle.get(k, false)), "%s %s" % [ctx, k])
						ModifierKeys.Type.PARAMS:
							assert_true(_same(Modifiers.params(SLOT, k), oracle.get(k, {})), "%s %s" % [ctx, k])
						_:
							fail("%s grants LIST key %s: extend this test" % [ctx, k])


func test_card_count_out_of_range_is_clamped() -> void:
	_push(SLOT, _loadout(&"perk.bulk", 42))
	assert_near(Modifiers.mult(SLOT, &"defense.health_mult"), 2.0, 0.0001, "above 9 = 9")
	Modifiers.clear_all()
	_push(SLOT, _loadout(&"perk.bulk", -3))
	assert_near(Modifiers.mult(SLOT, &"defense.health_mult"), 1.0, 0.0001, "below 0 = none")
	assert_true(Modifiers.params(SLOT, &"perk.muscle").is_empty())


# --- team_perk dedupe ------------------------------------------------------------------------------

func test_same_deck_on_two_slots_counts_once() -> void:
	_push(0, _loadout(&"perk.foreman", 9))
	_push(1, _loadout(&"perk.foreman", 9))
	for slot: int in range(4):
		assert_near(Modifiers.mult(slot, &"team.health_mult"), 1.1, 0.0001, "slot %d: team health once" % slot)
		assert_near(Modifiers.mult(slot, &"team.armor_mult"), 1.05, 0.0001, "slot %d: team armor once" % slot)
		assert_near(Modifiers.mult(slot, &"team.stamina_mult"), 1.5, 0.0001, "slot %d: team stamina once" % slot)
	# Personal parts stay per slot (one each, not stacked onto other slots).
	assert_near(Modifiers.mult(0, &"defense.health_mult"), 1.0909091, 0.0001)
	assert_near(Modifiers.mult(1, &"defense.health_mult"), 1.0909091, 0.0001)
	assert_near(Modifiers.mult(3, &"defense.health_mult"), 1.0, 0.0001)


func test_different_decks_team_sources_both_apply() -> void:
	_push(0, _loadout(&"perk.foreman", 9))
	_push(1, _loadout(&"perk.ironclad", 9))
	assert_near(Modifiers.mult(3, &"team.health_mult"), 1.1, 0.0001, "Foreman aura")
	assert_near(Modifiers.mult(3, &"team.armor_regen_delay_mult"), 0.9, 0.0001, "Ironclad aura")
	assert_near(Modifiers.mult(1, &"defense.armor_regen_delay_mult"), 0.9, 0.0001, "Ironclad personal")
	assert_near(Modifiers.mult(0, &"defense.armor_regen_delay_mult"), 1.0, 0.0001, "not on the Foreman")


## Two Foremen with different card counts: the crew helper keeps the strongest copy whatever the
## slot order (setting each loadout's sources in turn would keep the last one: a 4-card Foreman
## after a 9-card one would drop team.health_mult).
func test_crew_team_sources_keep_the_strongest_copy() -> void:
	var strong: Loadout = _loadout(&"perk.foreman", 9)
	var weak: Loadout = _loadout(&"perk.foreman", 4)
	for order: Array in [[strong, weak], [weak, strong], [null, weak, strong, weak]]:
		Modifiers.clear_all()
		var team: Dictionary = LoadoutResolver.crew_team_modifier_sources(order)
		assert_eq(team.keys(), [&"team_perk.foreman"], "one source")
		for s: Variant in team:
			Modifiers.set_source(Modifiers.TEAM, StringName(s), team[s])
		for slot: int in range(4):
			assert_near(Modifiers.mult(slot, &"team.health_mult"), 1.1, 0.0001, "strongest copy kept")
			assert_near(Modifiers.mult(slot, &"team.stamina_mult"), 1.5, 0.0001, "counted once")
		assert_eq(Modifiers.params(0, &"team.damage_reduction_hostage"), {"absorb_per_hostage": 5.0, "max_hostages": 4})
	# Weak copy alone: only card 3's aura.
	var only_weak: Dictionary = LoadoutResolver.crew_team_modifier_sources([weak])
	assert_eq(only_weak, {&"team_perk.foreman": {&"team.stamina_mult": 1.5}})
	# Mixed decks keep both sources.
	var mixed: Dictionary = LoadoutResolver.crew_team_modifier_sources([weak, _loadout(&"perk.ironclad", 9)])
	assert_true(mixed.has(&"team_perk.foreman") and mixed.has(&"team_perk.ironclad"), "both decks")


# --- Hook coverage audit ---------------------------------------------------------------------------

func test_every_granted_key_is_hooked_or_filed() -> void:
	var granted: Dictionary = {}
	for deck: Variant in ContentDB.all_of(ContentDB.PERKS):
		for card: Dictionary in (deck as PerkDeckDef).cards:
			for key: Variant in card.get("grants", {}):
				granted[ModifierKeys.base_key(StringName(key))] = true
	for key: StringName in granted:
		assert_true(HOOKED.has(key) or MISSING.has(key), "%s is neither hooked nor filed as a QB" % key)
		assert_false(HOOKED.has(key) and MISSING.has(key), "%s listed twice" % key)
	for key: StringName in HOOKED:
		var code: String = FileAccess.get_file_as_string(HOOKED[key])
		assert_true(code.contains("&\"%s\"" % key), "%s read in %s" % [key, HOOKED[key]])
	var missing: Array = []
	for key: StringName in MISSING:
		if granted.has(key):
			missing.append(String(key))
	if not missing.is_empty():
		skip("no ENV A hook yet (QB, perk_decks.md Hook coverage): %s" % ", ".join(missing))
