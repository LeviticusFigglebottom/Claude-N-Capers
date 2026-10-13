## A1-08 survival: L2.1 health, L2.2 armor first + gating + invuln + regen (defense.* modifiers),
## L2.5 bleedout, L2.6 downs -> custody, L2.7 revive through the InteractionSystem.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(1)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _hit(c: CrewController, amount: float, bypass: bool = false) -> Dictionary:
	var info: Dictionary = CombatSystem.make_damage_info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY,
		&"weapon.npc_pistol", c.global_position, Vector3.FORWARD, bypass)
	return c.take_hit(info, 0)


func _down(c: CrewController) -> void:
	c.health.armor = 0.0
	_hit(c, 10000.0)


func test_l2_1_base_health_and_armor() -> void:
	var h: CrewHealth = _crew().health
	assert_near(h.health, 230.0, 0.001, "230 health")
	assert_near(h.max_health, Tweak.crew().base_health, 0.001)
	assert_near(h.max_armor, ContentDB.armor(&"armor.tailored_suit").armor, 0.001, "armor from the suit ArmorDef")
	assert_eq(h.downs_left, 3, "3 downs")


func test_l2_2_armor_absorbs_first() -> void:
	var c: CrewController = _crew()
	var h: CrewHealth = c.health
	var out: Dictionary = _hit(c, 8.0)
	assert_near(h.armor, h.max_armor - 8.0, 0.001, "armor took it")
	assert_near(h.health, h.max_health, 0.001, "health untouched")
	assert_near(float(out["armor_damage"]), 8.0, 0.001)


func test_l2_2_armor_gate_caps_hit_and_grants_invuln() -> void:
	var c: CrewController = _crew()
	var h: CrewHealth = c.health
	_hit(c, 150.0)
	assert_near(h.armor, 0.0, 0.001, "armor broken")
	assert_near(h.health, h.max_health, 0.001, "gated: overflow discarded")
	var inv: float = Tweak.crew().armor_gate_invuln_s[Enums.Difficulty.ROUTINE]
	assert_near(h.invuln_left, inv, 0.001, "post-gate invulnerability")
	_hit(c, 50.0)
	assert_near(h.health, h.max_health, 0.001, "invulnerable")
	await wait_seconds(inv + 0.1)
	_hit(c, 50.0)
	assert_near(h.health, h.max_health - 50.0, 0.001, "health takes it once armor is gone")


func test_l2_2_bypass_armor_gate_overflows_to_health() -> void:
	var c: CrewController = _crew()
	var h: CrewHealth = c.health
	_hit(c, 100.0, true)
	assert_near(h.armor, 0.0, 0.001)
	assert_near(h.health, h.max_health - (100.0 - h.max_armor), 0.001, "sniper overflow reaches health")


func test_l2_2_armor_regen_after_delay_and_modifier() -> void:
	var c: CrewController = _crew()
	var h: CrewHealth = c.health
	var tw: CrewTweak = Tweak.crew()
	_hit(c, 10.0)
	await wait_seconds(tw.armor_regen_delay_s - 0.3)
	assert_near(h.armor, h.max_armor - 10.0, 0.001, "no regen during the delay")
	await wait_seconds(0.3 + tw.armor_regen_full_time_s + 0.2)
	assert_near(h.armor, h.max_armor, 0.001, "full after delay + refill time")
	Modifiers.set_source(0, &"test", {&"defense.armor_regen_delay_mult": 0.5})
	_hit(c, 10.0)
	assert_near(h.regen_delay_left, tw.armor_regen_delay_s * 0.5, 0.001, "delay halved")
	await wait_seconds(tw.armor_regen_delay_s * 0.5 + tw.armor_regen_full_time_s + 0.2)
	assert_near(h.armor, h.max_armor, 0.001, "regenerated sooner")


func test_l2_1_health_and_armor_mult_modifiers() -> void:
	var c: CrewController = _crew()
	Modifiers.set_source(0, &"test", {&"defense.health_mult": 1.5, &"defense.armor_mult": 2.0})
	await wait_physics_frames(2)
	assert_near(c.health.max_health, 230.0 * 1.5, 0.01, "defense.health_mult")
	assert_near(c.health.max_armor, c.health.compute_max_armor(), 0.01)
	assert_near(c.health.max_armor, ContentDB.armor(&"armor.tailored_suit").armor * 2.0, 0.01, "defense.armor_mult")
	assert_near(c.health.health, c.health.max_health, 0.01, "full stays full")


func test_l2_1_no_health_regen() -> void:
	var c: CrewController = _crew()
	c.health.armor = 0.0
	_hit(c, 30.0)
	await wait_seconds(Tweak.crew().armor_regen_delay_s + 1.5)
	assert_near(c.health.health, 200.0, 0.001, "health does not regenerate")


func test_l2_1_health_regen_modifier() -> void:
	var c: CrewController = _crew()
	c.health.armor = 0.0
	_hit(c, 30.0)
	Modifiers.set_source(0, &"test", {&"defense.health_regen_per_sec": 0.02})
	await wait_seconds(1.0)
	assert_true(c.health.health > 200.5, "regen heals: %f" % c.health.health)
	await wait_seconds(6.0)
	assert_near(c.health.health, c.health.max_health, 0.001, "regen caps at max health")


func test_l2_5_zero_health_downs_then_bleedout_custody() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var downs: Array[int] = []
	var custody: Array[int] = []
	var dcb: Callable = func(s: int, used: int) -> void: downs.append(s * 10 + used)
	var ccb: Callable = func(s: int) -> void: custody.append(s)
	EventBus.crew_downed.connect(dcb)
	EventBus.crew_custody.connect(ccb)
	_down(c)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "downed")
	assert_eq(downs, [1] as Array[int], "crew_downed(0, 1)")
	assert_near(c.health.bleedout_left, Tweak.crew().bleedout_time_s, 0.05, "30 s bleedout")
	assert_eq(c.health.downs_left, 2)
	# Can't move while downed, but can shoot (L2.5).
	var p0: Vector3 = c.global_position
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	_rt.set_bot_intent(0, i)
	await wait_seconds(0.4)
	assert_true(c.global_position.distance_to(p0) < 0.1, "no movement while downed")
	var f: CrewIntent = CrewIntent.new()
	f.look_pitch = deg_to_rad(60.0)
	f.fire = true
	_rt.set_bot_intent(0, f)
	await wait_physics_frames(2)
	_rt.clear_bot_intent(0)
	assert_eq(c.weapons.shots_fired, 1, "shoots in bleedout")
	assert_true(c.weapons.is_shooting(), "counts as shooting")
	c.health.bleedout_left = 0.2  # skip the 30 s wait
	await wait_seconds(0.4)
	assert_eq(c.crew_state, Enums.CrewState.CUSTODY, "bleedout expiry -> custody")
	assert_eq(custody, [0] as Array[int], "crew_custody(0)")
	EventBus.crew_downed.disconnect(dcb)
	EventBus.crew_custody.disconnect(ccb)


func test_l2_6_fourth_zero_health_goes_to_custody() -> void:
	var c: CrewController = _crew()
	var h: CrewHealth = c.health
	for k: int in range(3):
		_down(c)
		assert_eq(c.crew_state, Enums.CrewState.DOWNED, "down %d" % (k + 1))
		h.revive(1)
		assert_eq(c.crew_state, Enums.CrewState.NORMAL)
	assert_eq(h.downs_left, 0, "no downs left")
	_down(c)
	assert_eq(c.crew_state, Enums.CrewState.CUSTODY, "4th zero health -> custody")
	assert_near(_hit(c, 50.0)["amount"], 0.0, 0.001, "no damage in custody")


func test_l2_6_downs_extra_modifier() -> void:
	Modifiers.set_source(0, &"test", {&"defense.downs_extra": 1})
	assert_eq(_crew().health.downs_left, 4, "defense.downs_extra")


func test_l2_7_revive_by_teammate_via_interaction() -> void:
	var c: CrewController = _crew(0)
	var r: CrewController = _crew(1)
	c.set_masked()
	r.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.05, 0)))
	await wait_physics_frames(2)
	_down(c)
	var revived: Array[int] = []
	var cb: Callable = func(s: int, by: int) -> void: revived.append(s * 10 + by)
	EventBus.crew_revived.connect(cb)
	var i: CrewIntent = CrewIntent.new()
	i.interact = true
	i.interact_target_net_id = c.net_id
	_rt.set_bot_intent(1, i)
	await wait_seconds(Tweak.crew().revive_time_s - 0.5)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "not yet (6 s hold)")
	assert_true(_rt.interaction.progress(1) > 0.8, "revive in progress")
	await wait_seconds(0.8)
	_rt.clear_bot_intent(1)
	EventBus.crew_revived.disconnect(cb)
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "revived")
	assert_eq(revived, [1] as Array[int], "crew_revived(0, by 1)")
	assert_near(c.health.health, c.health.max_health * 0.4, 0.01, "40% health on Routine")


func test_l2_7_revive_speed_mult_halves_time() -> void:
	var c: CrewController = _crew(0)
	var r: CrewController = _crew(1)
	c.set_masked()
	r.set_masked()
	Modifiers.set_source(1, &"test", {&"interaction.revive_speed_mult": 0.5})
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.05, 0)))
	await wait_physics_frames(2)
	_down(c)
	var i: CrewIntent = CrewIntent.new()
	i.interact = true
	i.interact_target_net_id = c.net_id
	_rt.set_bot_intent(1, i)
	await wait_seconds(Tweak.crew().revive_time_s * 0.5 + 0.3)
	_rt.clear_bot_intent(1)
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "revived in half the time")


func test_l2_7_downed_cannot_revive_self_and_damage_interrupts() -> void:
	var c: CrewController = _crew(0)
	c.set_masked()
	_down(c)
	var i: CrewIntent = CrewIntent.new()
	i.interact = true
	i.interact_target_net_id = c.net_id
	_rt.set_bot_intent(0, i)
	await wait_seconds(0.5)
	_rt.clear_bot_intent(0)
	assert_true(_rt.interaction.session(0).is_empty(), "no self revive")
	# Damage interrupts the victim's interaction (S9.1).
	var r: CrewController = _crew(1)
	r.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.05, 0)))
	await wait_physics_frames(2)
	_rt.set_bot_intent(1, i)
	await wait_seconds(1.0)
	assert_false(_rt.interaction.session(1).is_empty(), "reviving")
	_hit(r, 5.0)
	assert_true(_rt.interaction.session(1).is_empty(), "damage interrupted the revive")
	_rt.clear_bot_intent(1)
