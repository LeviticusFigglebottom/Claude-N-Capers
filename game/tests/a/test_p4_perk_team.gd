## QB-62 (P4): perk-deck PARAMS keys that involve teammates or enemy targeting: perk.crew_chief,
## perk.gambler, perk.rogue_dodge_stack, perk.muscle, perk.burglar. One behaviour test per key
## (schemas: game/systems/modifiers_params.md, perk_decks.md).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 63, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "skip_casing": true})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _grant(grants: Dictionary) -> CrewController:
	Modifiers.set_source(0, &"perk", grants)
	for s: int in [0, 1]:
		Modifiers.set_source(s, &"test", {&"defense.dodge_add": -1.0})
		_crew(s).health.reset_full()
	return _crew(0)


func _hit(c: CrewController, amount: float) -> void:
	c.take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", c.global_position,
		Vector3.FORWARD), 0)


func _tick(c: CrewController, seconds: float, step: float = 0.05) -> void:
	var t: float = 0.0
	while t < seconds - 0.0001:
		c.health.server_tick(step)
		t += step


func _place(c: CrewController, pos: Vector3) -> void:
	c.global_position = pos
	c.velocity = Vector3.ZERO


func test_p4_perk_crew_chief_team_dr_and_hostage_health() -> void:
	var holder: CrewController = _grant({&"perk.crew_chief": {"team_dr": 0.08, "self_low_health_threshold": 0.5,
		"self_low_health_dr_mult": 2.0, "close_range_m": 18.0, "close_range_dr": 0.0,
		"hostage_health_per": 0.06, "hostage_stamina_per": 0.12, "hostage_max_count": 4}})
	var mate: CrewController = _crew(1)
	mate.health.armor = 0.0
	var hp: float = mate.health.health
	_hit(mate, 100.0)
	assert_near(mate.health.health, hp - 92.0, 0.01, "teammate gets team_dr")
	holder.health.armor = 0.0
	holder.health.health = holder.health.max_health * 0.4
	hp = holder.health.health
	_hit(holder, 100.0)
	assert_near(holder.health.health, hp - 84.0, 0.01, "holder below half health: team_dr x2")
	var raw: float = mate.health.compute_max_health()
	CivilianTargets.ensure(_rt).hostage_count = 2
	assert_near(mate.health.compute_max_health(), raw * 1.12, 0.01, "+6% max health per hostage")
	assert_near(PerkHooks.stamina_mult(mate), 1.24, 0.001, "+12% stamina per hostage")
	CivilianTargets.ensure(_rt).hostage_count = 9
	assert_near(mate.health.compute_max_health(), raw * 1.24, 0.01, "capped at hostage_max_count")


func test_p4_perk_gambler_ammo_pickup_heals_holder_and_team() -> void:
	var holder: CrewController = _grant({&"perk.gambler": {"heal_min": 20.0, "heal_max": 20.0, "heal_bonus": 0.0,
		"cooldown_s": 3.0, "lowest_health_bonus_per_ally": 0.5, "lowest_health_max_stacks": 3,
		"team_ammo_share": 0.5, "team_ammo_share_cooldown_s": 5.0, "team_heal_fraction": 0.5}})
	var mate: CrewController = _crew(1)
	holder.health.health = holder.health.max_health - 100.0
	mate.health.health = mate.health.max_health - 50.0
	var ws: int = mate.weapons.equipped_slot
	assert_true(mate.weapons.stats(ws) != null, "teammate has a weapon")
	mate.weapons.set_ammo(ws, mate.weapons.mag(ws), 0)
	var svc: Node = _rt.service(CrewPerks.AMMO_SERVICE)
	if svc != null and svc.has_signal(CrewPerks.AMMO_SIGNAL):
		svc.emit_signal(CrewPerks.AMMO_SIGNAL, holder, 10)  # the AmmoPickupSystem hook signal
	else:
		PerkHooks.on_ammo_picked(holder, 10)
	assert_near(holder.health.health, holder.health.max_health - 70.0, 0.01, "20 x (1 + 0.5 per healthier ally)")
	assert_near(mate.health.health, mate.health.max_health - 35.0, 0.01, "team heals half")
	assert_eq(mate.weapons.reserve(ws), 5, "teammate gets half the rounds")
	PerkHooks.on_ammo_picked(holder, 10)
	assert_near(holder.health.health, holder.health.max_health - 70.0, 0.01, "heal on cooldown")
	assert_eq(mate.weapons.reserve(ws), 5, "ammo share on cooldown")
	_tick(holder, 3.05)
	PerkHooks.on_ammo_picked(holder, 10)
	assert_true(holder.health.health > holder.health.max_health - 70.0, "after the cooldown")


func test_p4_perk_rogue_dodge_stack_less_aggro_near_crew() -> void:
	var holder: CrewController = _grant({&"perk.rogue_dodge_stack": {"aggro_near_crew_mult": 0.85, "near_crew_m": 8.0}})
	var mate: CrewController = _crew(1)
	_place(mate, holder.global_position + Vector3(2, 0, 0))
	assert_near(PerkHooks.aggro_weight(holder), 0.85, 0.001, "near a teammate")
	assert_near(PerkHooks.aggro_weight(mate), 1.0, 0.001, "teammate without the perk")
	_place(mate, holder.global_position + Vector3(50, 0, 0))
	assert_near(PerkHooks.aggro_weight(holder), 1.0, 0.001, "alone")


func test_p4_perk_muscle_regen_aggro_and_panic() -> void:
	var holder: CrewController = _grant({&"perk.muscle": {"aggro_near_crew_mult": 1.15, "near_crew_m": 8.0,
		"panic_chance": 1.0, "panic_radius_m": 6.0, "regen_fraction": 0.03, "regen_interval_s": 5.0}})
	var m: float = holder.health.max_health
	holder.health.health = m - 50.0
	_tick(holder, 5.05)
	assert_near(holder.health.health, m - 50.0 + 0.03 * m, 0.01, "3% health per 5 s")
	_place(_crew(1), holder.global_position + Vector3(2, 0, 0))
	assert_near(PerkHooks.aggro_weight(holder), 1.15, 0.001, "draws aggro near crew")
	var a: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, holder.global_position + Vector3(10, 0.05, 0)))
	var b: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, holder.global_position + Vector3(12, 0.05, 0)))
	a.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", a.global_position,
		Vector3.FORWARD, holder.net_id), holder.net_id)
	assert_true(a.is_stunned() and b.is_stunned(), "a firearm hit panics enemies around the target")
	_tick(holder, PerkTweak.data().panic_stun_s + 0.1)
	assert_false(a.is_stunned() or b.is_stunned(), "panic wears off")


func test_p4_perk_burglar_still_aggro_and_regen() -> void:
	var holder: CrewController = _grant({&"perk.burglar": {"still_aggro_mult": 0.8, "still_regen_delay_mult": 0.8}})
	_place(holder, holder.global_position)
	assert_near(PerkHooks.aggro_weight(holder), 0.8, 0.001, "standing still: less aggro")
	holder.health.armor = 0.0
	holder.health.regen_delay_left = 3.0
	_tick(holder, 1.0)
	assert_near(holder.health.regen_delay_left, 1.75, 0.01, "regen delay runs 1/0.8 as fast")
	holder.velocity = Vector3(5, 0, 0)
	assert_near(PerkHooks.aggro_weight(holder), 1.0, 0.001, "moving: normal aggro")
	holder.health.regen_delay_left = 3.0
	_tick(holder, 1.0)
	assert_near(holder.health.regen_delay_left, 2.0, 0.01, "moving: normal delay")
