## D-162 further perk decks, batch 1 (PD2 values): perk.yakuza (health-scaled armor regen / move speed below a
## threshold, replicated buff, regen gate), perk.biker (any crew kill -> health / armor, rate-limited, missing-stat
## scaling), perk.maniac (damage dealt -> Hysteria stacks -> flat absorb, cap, decay, crew share), the shared
## CrewKillFeed.
extends TestCase

var _rt: HeistRuntime = null
var _victim_id: int = 7000


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1620, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "skip_casing": true})
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _grant(slot: int, key: StringName, p: Dictionary) -> PerkComponent:
	Modifiers.set_source(slot, &"deck", {key: p, &"defense.dodge_add": -1.0})
	var perks: CrewPerks = PerkHooks.of(_crew(slot))
	perks.refresh()
	return perks.component(key)


func _kill_by(c: CrewController) -> void:
	_victim_id += 1
	EventBus.npc_killed.emit(_victim_id, c.net_id, {"type": Enums.DamageType.BULLET})


func _hit(c: CrewController, amount: float) -> void:
	c.health.grace_left = 0.0
	c.health.armor = 0.0
	c.take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", c.global_position,
		Vector3.FORWARD), 0)


# --- CrewKillFeed --------------------------------------------------------------------------------

func test_crew_kill_feed_reports_any_teammate() -> void:
	var feed: CrewKillFeed = CrewKillFeed.of(_rt)
	var got: Array[int] = []
	feed.crew_kill.connect(func(slot: int, _v: int, _i: Dictionary) -> void: got.append(slot))
	_kill_by(_crew(0))
	_kill_by(_crew(1))
	EventBus.npc_killed.emit(1, 0, {})  # no crew killer
	assert_eq(got, [0, 1] as Array[int], "the human's and the bot's kills, nothing else")


# --- Yakuza ------------------------------------------------------------------------------------

func test_yakuza_scales_as_health_falls_and_replicates() -> void:
	var y: PerkYakuza = _grant(0, &"perk.yakuza", {"low_health_threshold": 0.25, "armor_regen_max_add": 0.6,
		"move_speed_max_add": 0.2, "blocks_regen": true}) as PerkYakuza
	var h: CrewHealth = _crew().health
	y.tick(0.1)
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), 1.0, 0.0001, "full health: s = 0, nothing")
	h.health = h.max_health * 0.625  # s = 0.375 / 0.75 = 0.5
	y.tick(0.1)
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), 1.1, 0.0001, "half way to the threshold: +0.2 x 0.5")
	assert_near(Modifiers.mult(0, &"defense.armor_regen_delay_mult"), 1.0 / 1.3, 0.0001,
		"the regen delay counts down 1.3x as fast")
	h.health = h.max_health * 0.1
	y.tick(0.1)
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), 1.2, 0.0001, "below the threshold: s = 1, the full bonus")
	var buffs: Dictionary = CrewBuffs.of(_rt).net_state()
	assert_true(buffs.has(0), "replicated through CrewBuffs (clients' movement prediction)")
	Modifiers.set_source(0, &"regen", {&"defense.health_regen_per_sec": 0.1})
	var before: float = h.health
	h._tick_health_regen(1.0)
	assert_near(h.health, before, 0.001, "blocks_regen: no other health regen while s > 0")
	h.health = h.max_health
	y.tick(0.1)
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), 1.0, 0.0001, "back to full health: the buff ends")
	_grant(0, &"perk.yakuza", {"low_health_threshold": 0.5, "armor_regen_max_add": 0.6, "move_speed_max_add": 0.2})
	h.health = h.max_health * 0.75  # s = 0.25 / 0.5
	y.tick(0.1)
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), 1.1, 0.0001, "card 9: peaks at 50 % health")


# --- Biker -------------------------------------------------------------------------------------

func test_biker_heals_on_any_crew_kill_rate_limited() -> void:
	var b: PerkBiker = _grant(0, &"perk.biker", {"heal": 5.0, "armor": 5.0, "max_procs": 4, "window_s": 4.0})
	b.tick(0.0)
	var h: CrewHealth = _crew().health
	h.health = h.max_health - 100.0
	h.armor = 0.0
	_kill_by(_crew(1))
	assert_near(h.health, h.max_health - 95.0, 0.01, "a teammate's kill: +5 health")
	assert_near(h.armor, 5.0, 0.01, "+5 armor")
	for _i: int in 4:
		_kill_by(_crew(0))
	assert_near(h.health, h.max_health - 80.0, 0.01, "at most 4 per window (4 of 5 kills)")
	b.tick(4.1)
	_kill_by(_crew(0))
	assert_near(h.health, h.max_health - 75.0, 0.01, "the window passed: again")


func test_biker_missing_stat_scaling() -> void:
	var b: PerkBiker = _grant(0, &"perk.biker", {"heal": 5.0, "armor": 5.0, "max_procs": 4, "window_s": 4.0,
		"armor_per_missing_health": 1.0, "window_cut_per_missing_health": 0.1,
		"heal_per_missing_armor": 1.0, "window_cut_per_missing_armor": 0.1}) as PerkBiker
	b.tick(0.0)
	var h: CrewHealth = _crew().health
	h.health = h.max_health * 0.5
	h.armor = 0.0
	assert_near(b.window_s(), 4.0 - 0.5 - 1.0, 0.0001, "window -0.1 s per 10 % missing health and armor")
	_kill_by(_crew(0))
	assert_near(h.armor, 10.0, 0.01, "Tail Gunner: 5 + 5 armor at 50 % health missing")
	assert_near(h.health, h.max_health * 0.5 + 5.0 + 10.0, 0.01, "Sgt-at-Arms: 5 + 10 health (armor 100 % missing)")


# --- Maniac ------------------------------------------------------------------------------------

func test_maniac_stacks_absorb_share_and_decay() -> void:
	var m: PerkManiac = _grant(0, &"perk.maniac", {"conversion": 1.0, "gain_cap": 240.0, "gain_window_s": 4.0,
		"max_stacks": 600.0, "stacks_per_absorb": 30.0, "decay_fraction": 0.75, "decay_flat": 30.0, "decay_interval_s": 8.0,
		"team": false, "self_absorb_mult": 1.0}) as PerkManiac
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var npc: NpcBase = dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -20)), null)
	EventBus.damage_applied.emit(npc.net_id, _crew().net_id, {"amount": 100.0})
	assert_near(m.stacks, 100.0, 0.01, "100 damage -> 100 stacks")
	EventBus.damage_applied.emit(npc.net_id, _crew().net_id, {"amount": 300.0})
	assert_near(m.stacks, 240.0, 0.01, "capped at 240 per window")
	assert_near(PerkHooks.absorb(_crew()), 8.0, 0.001, "240 / 30 = 8 absorb")
	var h: CrewHealth = _crew().health
	h.health = h.max_health
	_hit(_crew(), 20.0)
	assert_near(h.health, h.max_health - 12.0, 0.01, "a 20 hit takes 12")
	assert_near(PerkHooks.absorb(_crew(1)), 0.0, 0.001, "no Outburst: the teammate gets nothing")
	_grant(0, &"perk.maniac", {"team": true, "self_absorb_mult": 2.0})
	assert_near(PerkHooks.absorb(_crew(1)), 8.0, 0.001, "Outburst: the teammate gets the holder's 8")
	assert_near(PerkHooks.absorb(_crew()), 16.0, 0.001, "Insanity: x2 on the holder")
	assert_near(PerkManiac.stacks_of(_crew()), 240.0, 0.01, "stacks published for replication")
	m.tick(8.1)
	assert_near(m.stacks, 0.0, 0.01, "card-1 decay (B's 80 % + 120 every 8 s) empties 240 stacks")
	_grant(0, &"perk.maniac", {"decay_fraction": 0.6, "decay_flat": 40.0})
	m.stacks = 240.0
	m.tick(8.1)
	assert_near(m.stacks, 240.0 - 144.0 - 40.0, 0.01, "Fervor: -60 % - 40")
