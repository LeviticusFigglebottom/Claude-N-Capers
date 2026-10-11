## QB-62 (P4): perk-deck PARAMS keys that reshape health / armor: perk.stoic, perk.anarchist,
## perk.armorer, perk.crook, perk.ex_president, perk.sociopath. One behaviour test per key
## (schemas: game/systems/modifiers_params.md, perk_decks.md).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 62, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "skip_casing": true})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


## Grant `grants` as the perk source of slot 0 (dodge off so hits are deterministic) and reset.
func _grant(grants: Dictionary, no_dodge: bool = true) -> CrewController:
	var g: Dictionary = grants.duplicate()
	if no_dodge:
		g[&"defense.dodge_add"] = -1.0
	Modifiers.set_source(0, &"perk", g)
	var c: CrewController = _crew()
	c.health.reset_full()
	return c


func _hit(c: CrewController, amount: float, extra: Dictionary = {}) -> Dictionary:
	var info: Dictionary = Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test",
		c.global_position, Vector3.FORWARD)
	info.merge(extra, true)
	return c.take_hit(info, 0)


func _tick(c: CrewController, seconds: float, step: float = 0.05) -> void:
	var t: float = 0.0
	while t < seconds - 0.0001:
		c.health.server_tick(step)
		t += step


func _spawn(c: CrewController, offset: Vector3) -> NpcBase:
	return _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, c.global_position + offset))


func _kill(c: CrewController, npc: NpcBase) -> void:
	npc.take_hit(Damage.info(100000.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", npc.global_position,
		Vector3.FORWARD, c.net_id), c.net_id)


func test_p4_perk_stoic_armor_to_health_dot_and_flask() -> void:
	var c: CrewController = _grant({
		&"perk.stoic": {"delayed_fraction": 0.75, "dot_duration_s": 12.0, "flask_cooldown_s": 10.0,
			"kill_cooldown_reduction_s": 1.0, "armor_to_health": 1.0, "auto_negate_after_s": 4.0,
			"negate_heal_fraction": 0.5},
		&"perk.throwable": {"item_id": &"throwable.steady_flask"},
	})
	assert_near(c.health.max_armor, 0.0, 0.001, "armor_to_health 1.0: no armor")
	assert_near(c.health.max_health, PerkHooks.raw_health(c) + PerkHooks.raw_armor(c), 0.001, "armor moved to health")
	var st: PerkStoic = PerkHooks.of(c).component(&"perk.stoic") as PerkStoic
	assert_true(st != null, "component active")
	var m: float = c.health.max_health
	c.health.health = m - 100.0
	_hit(c, 40.0)
	assert_near(c.health.health, m - 110.0, 0.01, "25% applies now")
	assert_near(st.pending_damage(), 30.0, 0.01, "75% delayed")
	_tick(c, 1.0)
	assert_near(c.health.health, m - 112.5, 0.05, "DoT: 30 over 12 s")
	assert_true(PerkHooks.use_throwable(c), "flask used")
	assert_near(st.pending_damage(), 0.0, 0.001, "flask cancels the DoT")
	assert_near(c.health.health, m - 112.5 + 0.5 * 27.5, 0.1, "negate_heal_fraction heals half the rest")
	assert_false(PerkHooks.use_throwable(c), "flask on cooldown")
	assert_near(st.flask_cooldown_left, 10.0, 0.001)
	var npc: NpcBase = _spawn(c, Vector3(4, 0.05, 0))
	_kill(c, npc)
	assert_near(st.flask_cooldown_left, 9.0, 0.001, "a kill cuts the flask cooldown")
	_hit(c, 40.0)
	assert_true(st.pending_damage() > 0.0)
	_tick(c, 4.1)
	assert_near(st.pending_damage(), 0.0, 0.001, "auto_negate_after_s cancels the DoT")


func test_p4_perk_anarchist_converts_health_and_ticks_armor_without_delay() -> void:
	var c: CrewController = _grant({&"perk.anarchist": {
		"tick_by_armor": {&"armor.tailored_suit": [5.0, 1.0]}, "break_immunity_s": 2.0,
		"break_immunity_cooldown_s": 15.0, "health_to_armor_fraction": 0.5, "health_to_armor_ratio": 1.0,
		"damage_dealt_armor": 10.0, "damage_dealt_armor_cooldown_s": 1.5}})
	if c.loadout != null:
		c.loadout.armor = &"armor.tailored_suit"
	c.health.reset_full()
	var rh: float = PerkHooks.raw_health(c)
	assert_near(c.health.max_health, rh * 0.5, 0.01, "half the health removed")
	assert_near(c.health.max_armor, PerkHooks.raw_armor(c) + rh * 0.5, 0.01, "added to armor")
	c.health.armor = 0.0
	c.health.regen_delay_left = 3.0
	_tick(c, 1.05)
	assert_near(c.health.armor, 5.0, 0.001, "one armor tick, the regen delay is ignored")
	c.health.armor = 5.0
	_hit(c, 50.0)
	assert_near(c.health.armor, 0.0, 0.001, "armor broken")
	assert_true(c.health.invuln_left >= 1.999, "break immunity (%.2f)" % c.health.invuln_left)
	c.health.invuln_left = 0.0
	c.health.armor = 0.0
	var npc: NpcBase = _spawn(c, Vector3(4, 0.05, 0))
	npc.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", npc.global_position,
		Vector3.FORWARD, c.net_id), c.net_id)
	assert_near(c.health.armor, 10.0, 0.001, "damage dealt restores armor")
	npc.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", npc.global_position,
		Vector3.FORWARD, c.net_id), c.net_id)
	assert_near(c.health.armor, 10.0, 0.001, "on cooldown")


func test_p4_perk_armorer_break_immunity_with_cooldown() -> void:
	var c: CrewController = _grant({&"perk.armorer": {"break_immunity_s": 2.0, "break_immunity_cooldown_s": 15.0}})
	c.health.armor = 5.0
	_hit(c, 50.0)
	assert_true(c.health.invuln_left >= 1.999, "2 s immunity on break (%.2f)" % c.health.invuln_left)
	var hp: float = c.health.health
	var out: Dictionary = _hit(c, 30.0, {"pierced_armor": true})
	assert_near(float(out["amount"]), 0.0, 0.001, "immune")
	assert_near(c.health.health, hp, 0.001)
	_tick(c, 2.1)
	assert_near(c.health.invuln_left, 0.0, 0.001)
	c.health.armor = 5.0
	_hit(c, 50.0)
	assert_true(c.health.invuln_left < 1.0, "cooldown: only the armor gate (%.2f)" % c.health.invuln_left)


func test_p4_perk_crook_vest_dodge_and_armor() -> void:
	var c: CrewController = _crew()
	if c.loadout == null:
		fail("crew has no loadout")
		return
	c.loadout.armor = &"armor.light_vest"
	c.health.reset_full()
	var base_armor: float = c.health.max_armor
	var base_dodge: float = ContentDB.armor(&"armor.light_vest").dodge + Modifiers.add(0, &"defense.dodge_add")
	var p: Dictionary = {"vest_armor_ids": [&"armor.light_vest", &"armor.patrol_vest", &"armor.heavy_vest"],
		"vest_dodge_add": 0.25, "vest_armor_mult": 1.65}
	_grant({&"perk.crook": p}, false)
	assert_near(c.health.max_armor, base_armor * 1.65, 0.01, "vest armor bonus")
	assert_near(c.health.dodge_chance(), clampf(base_dodge + 0.25, 0.0, 1.0), 0.001, "vest dodge bonus")
	c.loadout.armor = &"armor.tailored_suit"
	c.health.reset_full()
	Modifiers.clear_source(0, &"perk")
	var suit_armor: float = c.health.compute_max_armor()
	var suit_dodge: float = c.health.dodge_chance()
	_grant({&"perk.crook": p}, false)
	assert_near(c.health.max_armor, suit_armor, 0.01, "suit: no bonus")
	assert_near(c.health.dodge_chance(), suit_dodge, 0.001, "suit: no dodge")


func test_p4_perk_ex_president_banks_kills_and_pays_on_regen() -> void:
	var c: CrewController = _grant({&"perk.ex_president": {"store_per_kill": 10.0,
		"max_store_by_armor": {&"armor.tailored_suit": 25.0, &"armor.light_vest": 30.0}, "max_store_mult": 1.0}})
	if c.loadout != null:
		c.loadout.armor = &"armor.tailored_suit"
	c.health.reset_full()
	var ex: PerkExPresident = PerkHooks.of(c).component(&"perk.ex_president") as PerkExPresident
	for i: int in range(3):
		_kill(c, _spawn(c, Vector3(3 + i, 0.05, 0)))
	assert_near(ex.stored, 25.0, 0.001, "banked, capped by armor")
	var m: float = c.health.max_health
	c.health.health = m - 60.0
	_hit(c, 100.0)
	assert_near(c.health.armor, 0.0, 0.001, "armor broken")
	_tick(c, 0.1)
	assert_near(c.health.health, m - 60.0, 0.001, "no payout during the regen delay")
	c.health.regen_delay_left = 0.0
	_tick(c, 0.05)
	assert_near(c.health.health, m - 35.0, 0.001, "bank paid out as armor regenerates")
	assert_near(ex.stored, 0.0, 0.001)


func test_p4_perk_sociopath_kill_armor_dr_and_forced_regen() -> void:
	var c: CrewController = _grant({&"perk.sociopath": {"kill_armor": 5.0, "kill_armor_cooldown_s": 1.0,
		"close_range_m": 18.0, "close_range_dr": 0.1, "close_kill_armor": 3.0, "forced_regen_after_break_s": 1.5}})
	c.health.armor = 0.0
	c.health.regen_delay_left = 100.0
	_kill(c, _spawn(c, Vector3(3, 0.05, 0)))
	assert_near(c.health.armor, 8.0, 0.001, "kill armor + close kill armor")
	_kill(c, _spawn(c, Vector3(4, 0.05, 0)))
	assert_near(c.health.armor, 8.0, 0.001, "cooldowns")
	_tick(c, 1.05)
	_kill(c, _spawn(c, Vector3(5, 0.05, 0)))
	assert_near(c.health.armor, 16.0, 0.001, "after the cooldown")
	_spawn(c, Vector3(3, 0.05, 2))  # alive, within close range
	c.health.armor = 0.0
	var hp: float = c.health.health
	_hit(c, 50.0)
	assert_near(c.health.health, hp - 45.0, 0.01, "close-range damage reduction")
	c.health.reset_full()
	_hit(c, 100.0)
	assert_near(c.health.armor, 0.0, 0.001, "armor broken")
	assert_true(c.health.regen_delay_left <= 1.5001, "forced regen 1.5 s after break (%.2f)" % c.health.regen_delay_left)
	_tick(c, 0.5)
	_hit(c, 10.0)
	assert_true(c.health.regen_delay_left <= 1.0001, "damage does not push it back (%.2f)" % c.health.regen_delay_left)
