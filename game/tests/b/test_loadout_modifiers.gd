## D-031: LoadoutResolver modifier output for the newly granted keys. LIST keys (weapon.kill_reload_buff,
## weapon.hit_stack_buff, weapon.kill_damage_buff, defense.post_revive_buff (D-034)) accumulate as Array[Dictionary], one `_source`-tagged
## entry per skill / perk card, ordered by `_source`; the `suppressed` concealment qualifier; and every
## skill aced plus every deck resolves cleanly with only registry keys of the right type.
extends TestCase

const RELOAD_RHYTHM: StringName = &"skill.marksman.reload_rhythm"
const RUN_AND_GUN: StringName = &"skill.gunnery.run_and_gun"
const WIND_UP: StringName = &"skill.scrapper.wind_up"
const RHYTHM: StringName = &"skill.two_gun.rhythm"
const HOT_STREAK: StringName = &"skill.two_gun.hot_streak"
const MOMENTUM: StringName = &"skill.scattergun.momentum"
const LOW_PROFILE: StringName = &"skill.quiet_professional.low_profile"
const BACK_ON_YOUR_FEET: StringName = &"skill.undying.back_on_your_feet"
const SECOND_LEASE: StringName = &"skill.undying.second_lease"
const LIST_KEYS: Array[StringName] = [
	&"weapon.kill_reload_buff", &"weapon.hit_stack_buff", &"weapon.kill_damage_buff", &"defense.post_revive_buff",
]


func before_all() -> void:
	ContentDB.clear_cache()


func after_each() -> void:
	ContentDB.clear_cache()
	Log.capture = false
	Log.captured.clear()
	Modifiers.clear_all()


func _skills(skills: Dictionary) -> Loadout:
	var l: Loadout = Loadout.new()
	l.skills = skills
	return l


func test_list_keys_are_list_typed() -> void:
	for k: StringName in LIST_KEYS:
		assert_eq(ModifierKeys.type_of(k), ModifierKeys.Type.LIST, "%s is LIST" % k)


func test_two_skills_granting_kill_reload_buff_give_two_tagged_entries() -> void:
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_skills({RELOAD_RHYTHM: 2, RUN_AND_GUN: 2}))
	var list: Variant = m[&"weapon.kill_reload_buff"]
	assert_true(list is Array, "LIST value is an Array")
	assert_eq((list as Array).get_typed_builtin(), TYPE_DICTIONARY, "Array[Dictionary]")
	var entries: Array = list
	assert_eq(entries.size(), 2)
	assert_eq(entries[0]["_source"], RUN_AND_GUN, "ordered by _source (sort_ids)")
	assert_eq(entries[1]["_source"], RELOAD_RHYTHM)
	assert_true(entries[0]["_source"] is StringName)
	assert_eq(entries[0]["trigger"], "auto_kills")
	assert_eq(entries[0]["kills"], 2)
	assert_eq(entries[1]["trigger"], "headshot_kill")
	assert_near(float(entries[1]["reload_mult"]), 2.0)


## D-034 QB-39: Back on Your Feet and Second Lease both keep their post-revive buff (no last-wins loss).
func test_post_revive_buff_keeps_one_entry_per_skill() -> void:
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_skills({BACK_ON_YOUR_FEET: 1, SECOND_LEASE: 2}))
	var list: Variant = m[&"defense.post_revive_buff"]
	assert_true(list is Array, "LIST value is an Array")
	var entries: Array = list
	assert_eq(entries.size(), 2, "one entry per skill")
	var sources: Array = entries.map(func(e: Dictionary) -> StringName: return e["_source"])
	assert_eq(sources, [BACK_ON_YOUR_FEET, SECOND_LEASE], "ordered by _source")
	assert_near(float(entries[0]["damage_taken_mult"]), 0.7)
	assert_near(float(entries[0]["reload_mult"]), 1.0)
	assert_near(float(entries[1]["reload_mult"]), 2.0)
	assert_near(float(entries[1]["move_mult"]), 1.3, 0.0001, "Second Lease aced replaces its basic entry")
	assert_near(float(entries[1]["damage_taken_mult"]), 1.0)
	var single: Array = LoadoutResolver.resolve_modifiers(_skills({SECOND_LEASE: 1}))[&"defense.post_revive_buff"]
	assert_eq(single.size(), 1)
	assert_near(float(single[0]["move_mult"]), 1.0, 0.0001, "basic only")


func test_basic_only_grants_no_aced_list_entry() -> void:
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_skills({RELOAD_RHYTHM: 1, RUN_AND_GUN: 2, WIND_UP: 2}))
	var entries: Array = m[&"weapon.kill_reload_buff"]
	var sources: Array = entries.map(func(e: Dictionary) -> StringName: return e["_source"])
	assert_eq(sources, [RUN_AND_GUN, WIND_UP], "Reload Rhythm basic has no kill_reload_buff")


## Aced re-grants the whole dict: one entry per skill, the aced values.
func test_aced_replaces_basic_entry_of_the_same_skill() -> void:
	var basic: Array = LoadoutResolver.resolve_modifiers(_skills({HOT_STREAK: 1}))[&"weapon.hit_stack_buff"]
	var aced: Array = LoadoutResolver.resolve_modifiers(_skills({HOT_STREAK: 2}))[&"weapon.hit_stack_buff"]
	assert_eq(basic.size(), 1)
	assert_eq(aced.size(), 1)
	assert_near(float(basic[0]["duration"]), 2.0)
	assert_near(float(aced[0]["duration"]), 4.0)
	var both: Array = LoadoutResolver.resolve_modifiers(_skills({HOT_STREAK: 2, RHYTHM: 1}))[&"weapon.hit_stack_buff"]
	assert_eq(both.size(), 2, "Rhythm (accuracy) and Hot Streak (damage) are independent")
	assert_eq([both[0]["stat"], both[1]["stat"]], ["damage", "accuracy"])
	var mom: Array = LoadoutResolver.resolve_modifiers(_skills({MOMENTUM: 2}))[&"weapon.kill_damage_buff"]
	assert_eq(mom.size(), 1)
	assert_eq(mom[0]["all_weapons"], true)


## A perk card granting a LIST key adds its own entry, tagged `<deck id>.card<n>`.
func test_perk_card_list_entry_is_tagged_with_card_source() -> void:
	const BUFF: Dictionary = {"trigger_class": "smg", "damage_mult": 1.1, "duration": 3.0, "all_weapons": false}
	var deck: PerkDeckDef = PerkDeckDef.new()
	deck.id = &"perk.test_list"
	deck.cards = [
		{"name": "a", "desc": "", "cost": 0, "grants": {}},
		{"name": "b", "desc": "", "cost": 0, "grants": {&"weapon.kill_damage_buff": BUFF}},
	] as Array[Dictionary]
	ContentDB.inject(ContentDB.PERKS, deck.id, deck)
	var l: Loadout = _skills({MOMENTUM: 1})
	l.perk_deck = deck.id
	l.perk_deck_cards = 2
	var entries: Array = LoadoutResolver.resolve_modifiers(l)[&"weapon.kill_damage_buff"]
	assert_eq(entries.size(), 2)
	assert_eq(entries[0]["_source"], &"perk.test_list.card2")
	assert_eq(entries[1]["_source"], MOMENTUM)
	l.perk_deck_cards = 1
	assert_eq((LoadoutResolver.resolve_modifiers(l)[&"weapon.kill_damage_buff"] as Array).size(), 1, "card 2 locked")


func test_hip_fire_and_run_and_gun_flags_seen_by_qualified_query() -> void:
	var hip: Dictionary = LoadoutResolver.resolve_modifiers(_skills({&"skill.scattergun.hip_fire": 1}))
	Modifiers.set_source(0, &"skills", hip)
	assert_true(Modifiers.flag(0, &"movement.shoot_while_sprinting", &"shotgun"))
	assert_false(Modifiers.flag(0, &"movement.shoot_while_sprinting", &"smg"))
	var rg: Dictionary = LoadoutResolver.resolve_modifiers(_skills({RUN_AND_GUN: 1}))
	Modifiers.set_source(1, &"skills", rg)
	assert_true(Modifiers.flag(1, &"movement.shoot_while_sprinting", &"smg"), "Run and Gun grants .all")


## Low Profile aced: +3 concealment per suppressed weapon (+1, and the suppressor costs 2 less).
func test_suppressed_concealment_counts_per_suppressed_weapon() -> void:
	var l: Loadout = _skills({LOW_PROFILE: 2})
	l.secondary = &"weapon.kestrel_p9"
	l.melee = &"melee.folding_knife"
	l.armor = &"armor.tailored_suit"
	assert_eq(LoadoutResolver.suppressed_weapon_count(l), 0)
	assert_eq(LoadoutResolver.concealment_bonus(l), 0, "no suppressor, no bonus")
	l.secondary_mods = [&"mod.p9_suppressor"] as Array[StringName]
	assert_eq(LoadoutResolver.suppressed_weapon_count(l), 1)
	assert_eq(LoadoutResolver.concealment_bonus(l), 3)
	l.skills = {LOW_PROFILE: 1}
	assert_eq(LoadoutResolver.concealment_bonus(l), 0, "basic has no concealment part")


func test_every_skill_aced_and_deck_resolves_with_typed_known_keys() -> void:
	var l: Loadout = Loadout.new()
	for sid: StringName in SkillPoints.tree_def().all_skill_ids():
		l.skills[sid] = 2
	Log.capture = true
	var decks: Array = ContentDB.all_of(ContentDB.PERKS)
	assert_eq(decks.size(), 22)
	for d: Variant in decks:
		l.perk_deck = (d as PerkDeckDef).id
		l.perk_deck_cards = 9
		var m: Dictionary = LoadoutResolver.resolve_modifiers(l)
		var team: Dictionary = LoadoutResolver.team_modifier_sources(l)
		for key: Variant in m:
			_assert_typed(StringName(key), m[key], String(l.perk_deck))
		for src: Variant in team:
			for key: Variant in team[src]:
				assert_true(String(key).begins_with("team."), "%s holds %s" % [src, key])
				_assert_typed(StringName(key), team[src][key], String(src))
		for k: StringName in LIST_KEYS:
			assert_has(m, k)
	var m90: Dictionary = LoadoutResolver.resolve_modifiers(l)
	assert_eq((m90[&"weapon.kill_reload_buff"] as Array).size(), 3, "Reload Rhythm, Run and Gun, Wind Up")
	assert_eq((m90[&"weapon.hit_stack_buff"] as Array).size(), 2, "Rhythm, Hot Streak")
	assert_eq((m90[&"weapon.kill_damage_buff"] as Array).size(), 1, "Momentum")
	assert_eq((m90[&"defense.post_revive_buff"] as Array).size(), 2, "Back on Your Feet, Second Lease")
	var errors: Array = Log.captured.filter(func(line: String) -> bool: return line.begins_with("[ERROR]"))
	assert_eq(errors.size(), 0, "no errors: %s" % [errors])


func _assert_typed(key: StringName, v: Variant, where: String) -> void:
	assert_true(ModifierKeys.is_known(key), "%s: unknown key %s" % [where, key])
	match ModifierKeys.type_of(key):
		ModifierKeys.Type.LIST:
			assert_true(v is Array and not (v as Array).is_empty(), "%s: %s is a non-empty Array" % [where, key])
			if v is Array:
				for e: Variant in v:
					assert_true(e is Dictionary and (e as Dictionary).has("_source"), "%s: %s entry %s" % [where, key, e])
		ModifierKeys.Type.PARAMS:
			assert_true(v is Dictionary, "%s: %s is a Dictionary" % [where, key])
		ModifierKeys.Type.FLAG:
			assert_true(v is bool, "%s: %s is a bool" % [where, key])
		_:
			assert_true(v is float or v is int, "%s: %s is a number" % [where, key])
