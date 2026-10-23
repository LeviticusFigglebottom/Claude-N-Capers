## B's unhooked skill keys, batch 2 (game/content/docs/unhooked_skill_keys.md): crits and dodge. Every number comes
## from B's skill data (ContentDB), granted Basic (+ Aced) as the skill tree does.
extends TestCase

const CHEAP_SHOT: StringName = &"skill.quiet_professional.cheap_shot"
const AMBUSHER: StringName = &"skill.quiet_professional.ambusher"
const SLIPPERY: StringName = &"skill.slipstream.slippery"
const LIGHT_STEP: StringName = &"skill.slipstream.light_step"
const BOLT: StringName = &"skill.quiet_professional.bolt"
const CORNERED: StringName = &"skill.slipstream.cornered"
const LOW_PROFILE: StringName = &"skill.quiet_professional.low_profile"

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1202, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false})
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _skill(id: StringName) -> SkillDef:
	return ContentDB.by_id(ContentDB.SKILLS, id) as SkillDef


func _grant(slot: int, id: StringName, aced: bool = false) -> void:
	Modifiers.set_source(slot, StringName("test.%s" % id), _skill(id).grants_basic)
	if aced:
		Modifiers.set_source(slot, StringName("test.%s.aced" % id), _skill(id).grants_aced)
	else:
		Modifiers.clear_source(slot, StringName("test.%s.aced" % id))


func _p(id: StringName, key: StringName, aced: bool) -> Variant:
	return ((_skill(id).grants_aced if aced else _skill(id).grants_basic) as Dictionary).get(key)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _set_dr(slot: int, dr: int) -> void:
	if _crew(slot).loadout == null:
		_crew(slot).loadout = Loadout.new()
	_crew(slot).loadout.detection_risk = dr


## Expected per-concealment value of grant `p` at detection risk `dr`.
func _steps(p: Dictionary, dr: int) -> float:
	var under: float = maxf(float(p["threshold_dr"]) - float(dr), 0.0)
	return minf(floorf(under / float(p["points_per_step"])) * float(p["per_step"]), float(p["max"]))


func _an_enemy(pos: Vector3) -> NpcBase:
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	return dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"), Transform3D(Basis.IDENTITY, pos), null)


## weapon.crit_per_concealment + weapon.crit_chance_add: the crit chance; a crit multiplies a melee hit.
func test_crit_chance_from_concealment_and_the_roll() -> void:
	_set_dr(0, 20)
	_grant(0, CHEAP_SHOT)
	var basic: Dictionary = _p(CHEAP_SHOT, &"weapon.crit_per_concealment", false)
	assert_near(SkillTriggers.crit_chance(_crew(0)), _steps(basic, 20), 0.0001, "Basic: per 3 points under DR 35")
	_grant(0, CHEAP_SHOT, true)
	var aced: Dictionary = _p(CHEAP_SHOT, &"weapon.crit_per_concealment", true)
	assert_near(SkillTriggers.crit_chance(_crew(0)), _steps(aced, 20), 0.0001, "Aced: per point, capped at max")
	_set_dr(0, 40)
	assert_eq(SkillTriggers.crit_chance(_crew(0)), 0.0, "over the threshold DR: nothing")
	Modifiers.set_source(0, &"test.crit", {&"weapon.crit_chance_add": 1.0})
	assert_true(SkillTriggers.roll_crit(_crew(0)), "a sure crit rolls")
	var me: CrewController = _crew(0)
	var aim: Vector3 = me.aim_direction()
	var npc: NpcBase = _an_enemy(me.global_position + Vector3(aim.x, 0.0, aim.z).normalized() * 1.0)
	await wait_physics_frames(2)
	var got: Array[Dictionary] = []
	var on_hit: Callable = func(victim: int, _a: int, info: Dictionary) -> void:
		if victim == npc.net_id:
			got.append(info)
	EventBus.damage_applied.connect(on_hit)
	me.melee._strike()
	EventBus.damage_applied.disconnect(on_hit)
	assert_true(not got.is_empty() and bool(got[0].get("crit", false)), "the melee hit crits")


## weapon.unseen_strike: idle_s without damage gives +crit_add, held `duration` s past the next hit.
func test_unseen_strike_after_going_unhit() -> void:
	var p: Dictionary = _p(AMBUSHER, &"weapon.unseen_strike", false)
	_grant(0, AMBUSHER)
	var h: CrewHealth = _crew(0).health
	h.since_damage_s = 0.0
	await wait_physics_frames(2)
	assert_eq(Modifiers.add(0, &"weapon.crit_chance_add"), 0.0, "just hit: nothing")
	h.since_damage_s = float(p["idle_s"]) + 0.1
	await wait_physics_frames(2)
	assert_near(Modifiers.add(0, &"weapon.crit_chance_add"), float(p["crit_add"]), 0.0001, "unhit for idle_s: +crit")
	h.since_damage_s = 0.0
	await wait_physics_frames(2)
	assert_near(Modifiers.add(0, &"weapon.crit_chance_add"), float(p["crit_add"]), 0.0001, "held after the hit")
	assert_near(CrewBuffs.of(_rt).left(0, SkillTriggers.BUFF_UNSEEN), float(p["duration"]), 0.2, "for `duration` s")


## defense.dodge_per_concealment + defense.sprint_dodge_add: dodge from concealment, and while sprinting.
func test_dodge_from_concealment_and_sprinting() -> void:
	var h: CrewHealth = _crew(0).health
	_set_dr(0, 20)
	var base: float = h.dodge_chance()
	_grant(0, SLIPPERY)
	assert_near(h.dodge_chance() - base, _steps(_p(SLIPPERY, &"defense.dodge_per_concealment", false), 20), 0.0001,
		"Basic: per 3 points under DR 35")
	_grant(0, SLIPPERY, true)
	var with_conc: float = h.dodge_chance()
	assert_near(with_conc - base, _steps(_p(SLIPPERY, &"defense.dodge_per_concealment", true), 20), 0.0001,
		"Aced: per point, capped")
	_grant(0, LIGHT_STEP, true)
	_crew(0).sprinting = false
	assert_near(h.dodge_chance(), with_conc, 0.0001, "walking: no sprint dodge")
	_crew(0).sprinting = true
	assert_near(h.dodge_chance() - with_conc, float(_p(LIGHT_STEP, &"defense.sprint_dodge_add", true)), 0.0001,
		"sprinting: + sprint_dodge_add")


## defense.armor_break_speed_buff: armor breaking gives move x move_mult for `duration` s (Aced: the whole crew).
func test_second_wind_when_armor_breaks() -> void:
	var p: Dictionary = _p(BOLT, &"defense.armor_break_speed_buff", false)
	_grant(0, BOLT)
	var h: CrewHealth = _crew(0).health
	h.armor = 10.0
	h.take_hit(Damage.info(5.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO, Vector3.FORWARD, 0))
	assert_eq(Modifiers.mult(0, &"movement.speed_mult"), 1.0, "armor left: nothing")
	h.grace_left = 0.0
	h.take_hit(Damage.info(50.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO, Vector3.FORWARD, 0))
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), float(p["move_mult"]), 0.0001, "armor broke: faster")
	assert_near(CrewBuffs.of(_rt).left(0, SkillTriggers.BUFF_SECOND_WIND), float(p["duration"]), 0.1, "for `duration`")
	assert_eq(Modifiers.mult(1, &"movement.speed_mult"), 1.0, "Basic: the holder only")
	CrewBuffs.of(_rt).end(0, SkillTriggers.BUFF_SECOND_WIND)
	_grant(0, BOLT, true)
	h.armor = 10.0
	h.invuln_left = 0.0
	h.grace_left = 0.0
	h.take_hit(Damage.info(50.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO, Vector3.FORWARD, 0))
	assert_near(Modifiers.mult(1, &"movement.speed_mult"), float(p["move_mult"]), 0.0001, "Aced: the whole crew")


## defense.armor_broken_stagger: while the holder's armor is broken its hits stagger enemies (Aced: persist_s more).
func test_cornered_staggers_while_armor_is_broken() -> void:
	_grant(0, CORNERED)
	var npc: NpcBase = _an_enemy(Vector3(0, 0, -15))
	await wait_physics_frames(2)
	var h: CrewHealth = _crew(0).health
	var hit: Callable = func() -> void:
		EventBus.damage_applied.emit(npc.net_id, _crew(0).net_id, {"amount": 1.0, "zone": Enums.HitZone.BODY})
	h.armor = h.max_armor
	h.regen_delay_left = 1000.0
	await wait_physics_frames(2)
	hit.call()
	assert_false(npc.is_stunned(), "armor up: no stagger")
	h.armor = 0.0
	await wait_physics_frames(2)
	hit.call()
	assert_true(npc.is_stunned(), "armor broken: the hit staggers")
	npc.stun_left = 0.0
	h.armor = h.max_armor
	await wait_physics_frames(2)
	hit.call()
	assert_false(npc.is_stunned(), "Basic: not after the armor is back")
	_grant(0, CORNERED, true)
	h.armor = 0.0
	await wait_physics_frames(2)
	h.armor = h.max_armor
	await wait_physics_frames(2)
	hit.call()
	assert_true(npc.is_stunned(), "Aced: still %.0f s after the armor is back" % float(
		(_p(CORNERED, &"defense.armor_broken_stagger", true) as Dictionary)["persist_s"]))


## defense.target_priority_mult: enemies weigh the holder as a target x the value (PerkHooks.aggro_weight).
func test_low_profile_target_weight() -> void:
	assert_eq(PerkHooks.aggro_weight(_crew(0)), 1.0, "no skill: x1")
	_grant(0, LOW_PROFILE)
	assert_near(PerkHooks.aggro_weight(_crew(0)), float(_p(LOW_PROFILE, &"defense.target_priority_mult", false)), 0.0001,
		"Low Profile: chosen less")
