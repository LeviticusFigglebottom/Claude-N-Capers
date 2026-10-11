## QB-62 (P4): perk-deck PARAMS keys driven by dealing damage, kills or the deck throwable:
## perk.grinder, perk.kingpin, perk.infiltrator, perk.throwable. One behaviour test per key
## (schemas: game/systems/modifiers_params.md, perk_decks.md). Also: every perk.* key has a
## component and a tweak default.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 64, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "skip_casing": true})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _grant(grants: Dictionary) -> CrewController:
	var g: Dictionary = grants.duplicate()
	g[&"defense.dodge_add"] = -1.0
	Modifiers.set_source(0, &"perk", g)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.health.reset_full()
	return c


func _hit(c: CrewController, amount: float) -> void:
	c.take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", c.global_position,
		Vector3.FORWARD), 0)


func _tick(c: CrewController, seconds: float, step: float = 0.125) -> void:
	var t: float = 0.0
	while t < seconds - 0.0001:
		c.health.server_tick(step)
		t += step


func _spawn(c: CrewController, offset: Vector3) -> NpcBase:
	return _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, c.global_position + offset))


func _deal(c: CrewController, npc: NpcBase, amount: float, type: int = Enums.DamageType.BULLET) -> void:
	npc.take_hit(Damage.info(amount, type, Enums.HitZone.BODY, &"test", npc.global_position, Vector3.FORWARD, c.net_id),
		c.net_id)


func test_p4_perk_every_key_has_a_component_and_defaults() -> void:
	var scripts: Dictionary[StringName, GDScript] = CrewPerks.scripts()
	for key: StringName in ModifierKeys.KEYS:
		if not String(key).begins_with("perk."):
			continue
		assert_true(scripts.has(key), "%s has a perk component" % key)
		assert_true(PerkTweak.data().defaults.has(key), "%s has tweak defaults" % key)


func test_p4_perk_grinder_damage_dealt_heals_over_time_in_light_armor() -> void:
	var c: CrewController = _grant({&"perk.grinder": {"allowed_armor_ids": [&"armor.tailored_suit", &"armor.light_vest"],
		"heal_per_tick": 2.0, "tick_s": 0.25, "duration_s": 2.0, "stack_cooldown_s": 1.5}})
	if c.loadout == null:
		fail("crew has no loadout")
		return
	c.loadout.armor = &"armor.tailored_suit"
	c.health.reset_full()
	var m: float = c.health.max_health
	c.health.health = m - 50.0
	var npc: NpcBase = _spawn(c, Vector3(5, 0.05, 0))
	_deal(c, npc, 1.0)
	_deal(c, npc, 1.0)  # stack cooldown: still one stack
	_tick(c, 2.5)
	assert_near(c.health.health, m - 50.0 + 16.0, 0.01, "one stack: 8 ticks x 2 HP")
	c.loadout.armor = &"armor.heavy_vest"
	c.health.reset_full()
	c.health.health = c.health.max_health - 50.0
	_deal(c, npc, 1.0)
	_tick(c, 2.5)
	assert_near(c.health.health, c.health.max_health - 50.0, 0.01, "heavy vest: no stacks")


func test_p4_perk_kingpin_injector_heals_damage_taken() -> void:
	var c: CrewController = _grant({
		&"perk.kingpin": {"heal_fraction": 0.75, "duration_s": 6.0, "cooldown_s": 30.0,
			"kill_cooldown_reduction_s": 1.0, "draws_aggro": true},
		&"perk.throwable": {"item_id": &"throwable.boss_injector"},
	})
	var kp: PerkKingpin = PerkHooks.of(c).component(&"perk.kingpin") as PerkKingpin
	var m: float = c.health.max_health
	c.health.armor = 0.0
	c.health.regen_delay_left = 100.0
	c.health.health = m - 100.0
	_hit(c, 40.0)
	assert_near(c.health.health, m - 140.0, 0.01, "no injector: full damage")
	var near: NpcBase = _spawn(c, Vector3(5, 0.05, 0))
	assert_near(PerkHooks.aggro_weight(c, near), 1.0, 0.001, "no aggro before the injector")
	assert_true(PerkHooks.use_throwable(c), "injector used")
	_hit(c, 40.0)
	assert_near(c.health.health, m - 150.0, 0.01, "75% of the damage healed back")
	assert_false(PerkHooks.use_throwable(c), "on cooldown")
	assert_near(PerkHooks.aggro_weight(c, near), PerkTweak.data().kingpin_aggro_mult, 0.001, "draws aggro while active")
	_deal(c, near, 100000.0)
	assert_near(kp.cooldown_left, 29.0, 0.001, "a kill cuts the cooldown")
	_tick(c, 6.125)
	assert_false(kp.is_active(), "effect over")
	c.health.armor = 0.0
	c.health.regen_delay_left = 100.0
	_hit(c, 40.0)
	assert_near(c.health.health, m - 190.0, 0.01, "after the effect: full damage")


func test_p4_perk_infiltrator_close_range_dr_and_melee() -> void:
	var c: CrewController = _grant({&"perk.infiltrator": {"surrounded_min_enemies": 3, "surrounded_radius_m": 6.0,
		"surrounded_dr": 0.12, "melee_chain_mult": 10.0, "melee_chain_window_s": 1.0, "close_range_m": 18.0,
		"close_range_dr": 0.08, "melee_hit_heal_fraction": 0.2, "melee_hit_heal_cooldown_s": 10.0}})
	c.health.armor = 0.0
	c.health.regen_delay_left = 100.0
	var hp: float = c.health.health
	_hit(c, 100.0)
	assert_near(c.health.health, hp - 100.0, 0.01, "no enemies: no reduction")
	var npcs: Array[NpcBase] = []
	for i: int in range(3):
		npcs.append(_spawn(c, Vector3(2 + i, 0.05, 1)))
	hp = c.health.health
	_hit(c, 100.0)
	assert_near(c.health.health, hp - 80.0, 0.01, "surrounded 12% + close range 8%")
	var m: float = c.health.max_health
	c.health.health = m * 0.5
	assert_near(PerkHooks.melee_damage_mult(c), 1.0, 0.001, "no chain yet")
	_deal(c, npcs[0], 1.0, Enums.DamageType.MELEE)
	assert_near(c.health.health, m * 0.7, 0.01, "melee hit heals 20%")
	assert_near(PerkHooks.melee_damage_mult(c), 10.0, 0.001, "chain open")
	_tick(c, 1.125)
	assert_near(PerkHooks.melee_damage_mult(c), 1.0, 0.001, "window closed")
	_deal(c, npcs[1], 1.0, Enums.DamageType.MELEE)
	PerkHooks.on_melee_miss(c)
	assert_near(PerkHooks.melee_damage_mult(c), 1.0, 0.001, "a miss resets the chain")


func test_p4_perk_throwable_replaces_the_throwable_and_uses_it_on_throw() -> void:
	var c: CrewController = _grant({})
	assert_eq(PerkHooks.throwable_id(c), &"", "no deck throwable")
	c = _grant({&"perk.throwable": {"item_id": &"throwable.steady_flask"},
		&"perk.stoic": {"delayed_fraction": 0.75, "dot_duration_s": 12.0, "flask_cooldown_s": 10.0}})
	assert_eq(PerkHooks.throwable_id(c), &"throwable.steady_flask", "deck throwable replaces the slot")
	var st: PerkStoic = PerkHooks.of(c).component(&"perk.stoic") as PerkStoic
	c.health.armor = 0.0
	_hit(c, 40.0)
	assert_true(st.pending_damage() > 0.0)
	c.intent.throw_item = true
	c.health.server_tick(0.05)
	assert_near(st.pending_damage(), 0.0, 0.001, "throw_item edge drinks the flask")
	assert_near(st.flask_cooldown_left, 10.0, 0.06)
	_hit(c, 40.0)
	c.health.server_tick(0.05)
	assert_true(st.pending_damage() > 0.0, "held throw_item: no second use")
	c.intent.throw_item = false
