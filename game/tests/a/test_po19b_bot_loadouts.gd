## PO-19b (D-145.4): AI teammates fight with their crew-slot loadout (B PO-19: HeistLauncher options.loadouts, bot slot
## i = the i-th AI seat): the equipped gun's real stats through the bot profile (PO6-15 ai_damage_mult + aim error) and
## the armor's real armor / dodge values.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _loadout(primary: StringName, secondary: StringName, armor: StringName) -> Loadout:
	var l: Loadout = Loadout.new()
	l.primary = primary
	l.secondary = secondary
	l.armor = armor
	return l


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1919, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0),
		"skip_casing": true, "ai_teammates": 2, "loadouts": {
			1: _loadout(&"weapon.anvil_lmg", &"", &"armor.breacher_plate"),
			2: _loadout(&"weapon.ferret_9", &"", &"armor.tailored_suit")}})  # a pistol in the primary slot
	await wait_physics_frames(3)


func _bot(slot: int) -> CrewController:
	var c: CrewController = _rt.crew_controller(slot) as CrewController
	assert_true(c != null and c.is_ai, "slot %d is an AI teammate" % slot)
	return c


## Damage per second of the bot's equipped gun at `dist` (the values its shots use).
func _dps(c: CrewController, dist: float) -> float:
	var w: CrewWeapons = c.weapons
	return w.damage_at(w.equipped_slot, dist) / w._shot_interval(w._states[w.equipped_slot])


func test_bot_fires_its_loadout_gun() -> void:
	await _launch()
	var lmg: CrewController = _bot(1)
	var pistol: CrewController = _bot(2)
	assert_eq(lmg.weapons._states[lmg.weapons.equipped_slot].id, &"weapon.anvil_lmg", "slot 1 holds the LMG")
	assert_eq(pistol.weapons._states[pistol.weapons.equipped_slot].id, &"weapon.ferret_9", "slot 2 holds the pistol")
	var ai: float = Tweak.crew().ai_damage_mult
	for c: CrewController in [lmg, pistol]:
		var s: CrewWeapons.WeaponState = c.weapons._states[c.weapons.equipped_slot]
		assert_near(s.stats.damage, ContentDB.weapon(s.id).base.damage, 0.001, "%s: the def's damage" % s.id)
		assert_near(c.weapons.damage_at(c.weapons.equipped_slot, 1.0), s.stats.damage * ai, 0.01,
			"%s: real damage x the bot profile" % s.id)
	var d_lmg: float = _dps(lmg, 10.0)
	var d_pistol: float = _dps(pistol, 10.0)
	assert_true(d_lmg > d_pistol * 1.2, "LMG bot out-damages the pistol bot (%.1f vs %.1f DPS)" % [d_lmg, d_pistol])


func test_bot_wears_its_loadout_armor() -> void:
	await _launch()
	var heavy: CrewController = _bot(1)
	var suit: CrewController = _bot(2)
	assert_near(heavy.health.max_armor, ContentDB.armor(&"armor.breacher_plate").armor, 0.01, "plate armor")
	assert_near(suit.health.max_armor, ContentDB.armor(&"armor.tailored_suit").armor, 0.01, "suit armor")
	assert_near(suit.health.dodge_chance(), ContentDB.armor(&"armor.tailored_suit").dodge, 0.001, "suit dodge")
	assert_eq(heavy.health.dodge_chance(), 0.0, "plate: no dodge")
	var lost: Array[float] = []
	for c: CrewController in [heavy, suit]:
		var h0: float = c.health.health
		for i: int in range(4):  # explosion: no dodge roll; bypass the gate so the overflow reaches health
			c.health.take_hit({"amount": 15.0, "type": Enums.DamageType.EXPLOSION, "bypass_armor_gate": true})
		lost.append(h0 - c.health.health)
	assert_near(lost[0], 0.0, 0.01, "plate soaks 60 damage in armor")
	assert_near(lost[1], 40.0, 0.01, "suit (20 armor) loses 40 health to the same hits")


## LEAD ruling 2026-10-20 (D-145.4): a bot with no primary (the default AI loadout, B's Heisters.ai_loadouts / no
## options.loadouts entry) carries CombatTweak.bot_default_primary (corsair_ar, unmodded) with the pistol as its
## secondary, and holds the rifle; the human crew member's default loadout is unchanged.
func test_default_bot_carries_the_starter_rifle() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1920, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0),
		"skip_casing": true, "ai_teammates": 2, "loadouts": {2: CrewWeapons.build_loadout(null)}})
	await wait_physics_frames(3)
	var rifle: StringName = CombatTweak.data().bot_default_primary
	assert_eq(rifle, &"weapon.corsair_ar", "the ruling's starter rifle")
	for slot: int in [1, 2]:
		var c: CrewController = _bot(slot)
		assert_eq(c.loadout.primary, rifle, "bot slot %d: the starter rifle" % slot)
		assert_eq(c.loadout.primary_mods, [] as Array[StringName], "bot slot %d: unmodded" % slot)
		assert_true(c.loadout.resolved_primary != null, "bot slot %d: the rifle resolved" % slot)
		assert_eq(c.loadout.secondary, CombatTweak.data().default_secondary, "bot slot %d: the pistol as secondary" % slot)
		assert_eq(c.weapons._states[c.weapons.equipped_slot].id, rifle, "bot slot %d holds the rifle" % slot)
	var human: CrewController = _rt.crew_controller(0) as CrewController
	assert_false(human.is_ai, "slot 0 is the human")
	assert_eq(human.loadout.primary, CombatTweak.data().default_primary, "the human default loadout is unchanged")
