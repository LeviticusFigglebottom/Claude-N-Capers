## B's unhooked skill keys, batch 3 (game/content/docs/unhooked_skill_keys.md): revives and medic support. Every
## number comes from B's skill data (ContentDB), granted Basic (+ Aced) as the skill tree does.
extends TestCase

const NUMBING: StringName = &"skill.field_medic.numbing_agent"
const TRIAGE: StringName = &"skill.field_medic.triage"
const BOYF: StringName = &"skill.undying.back_on_your_feet"
const SECOND_LEASE: StringName = &"skill.undying.second_lease"
const FIELD_KIT: StringName = &"skill.field_medic.field_kit"
const BEDSIDE: StringName = &"skill.field_medic.bedside_manner"
const POSSUM: StringName = &"skill.undying.playing_possum"

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1203, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false})
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _skill(id: StringName) -> SkillDef:
	return ContentDB.by_id(ContentDB.SKILLS, id) as SkillDef


## Basic, or (aced) the Aced part over it as the resolver does (one entry per skill for LIST keys).
func _grant(slot: int, id: StringName, aced: bool = false) -> void:
	var g: Dictionary = (_skill(id).grants_basic as Dictionary).duplicate()
	if aced:
		g.merge(_skill(id).grants_aced, true)
	Modifiers.set_source(slot, StringName("test.%s" % id), g)


func _p(id: StringName, key: StringName, aced: bool) -> Variant:
	return ((_skill(id).grants_aced if aced else _skill(id).grants_basic) as Dictionary).get(key)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


## ability.revive_target_buff (the reviver's): the revived teammate takes damage x damage_taken_mult for duration s;
## ability.revive_target_health_mult (Triage Aced): it gets up with x the revive health.
func test_numbing_agent_and_triage_on_the_revived() -> void:
	var plain: CrewHealth = _crew(1).health
	plain.go_down()
	plain.revive(0)
	var base_hp: float = plain.health
	_grant(0, NUMBING, true)
	_grant(0, TRIAGE, true)
	plain.go_down()
	plain.revive(0)
	assert_near(plain.health, minf(base_hp * float(_p(TRIAGE, &"ability.revive_target_health_mult", true)),
		plain.max_health), 0.01, "Triage Aced: more revive health")
	var p: Dictionary = _p(NUMBING, &"ability.revive_target_buff", true)
	assert_near(Modifiers.mult(1, &"defense.damage_taken_mult"), float(p["damage_taken_mult"]), 0.0001,
		"Numbing Agent: the revived takes less damage")
	assert_near(CrewBuffs.of(_rt).left(1, SkillTriggers.BUFF_REVIVE_TARGET), float(p["duration"]), 0.1, "for duration")
	assert_eq(Modifiers.mult(0, &"defense.damage_taken_mult"), 1.0, "not the reviver")


## defense.reviving_damage_taken_mult (Triage Basic): while holding a revive and linger_s after, damage x mult.
func test_triage_cuts_damage_while_reviving() -> void:
	var p: Dictionary = _p(TRIAGE, &"defense.reviving_damage_taken_mult", false)
	_grant(0, TRIAGE)
	var t: SkillTriggers = SkillTriggers.of(_rt)
	assert_eq(SkillTriggers.reviving_mult(_crew(0)), 1.0, "not reviving: x1")
	_crew(1).health.go_down()
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, _crew(1).global_position + Vector3(0.8, 0, 0)))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, _crew(1).net_id)
	var holding: bool = await wait_until(func() -> bool: return t._reviving_left.get(0, 0.0) > 0.0, 2.0)
	assert_true(holding, "the revive hold is seen")
	assert_near(SkillTriggers.reviving_mult(_crew(0)), float(p["mult"]), 0.0001, "reviving: x mult")
	t._reviving_left[0] = float(p["linger_s"]) * 0.5
	_rt.set_bot_intent(0, CrewIntent.new())
	_rt.interaction.cancel(0)
	await wait_physics_frames(2)
	assert_near(SkillTriggers.reviving_mult(_crew(0)), float(p["mult"]), 0.0001, "still x mult inside linger_s")
	t._reviving_left[0] = 0.0
	await wait_physics_frames(2)
	assert_eq(SkillTriggers.reviving_mult(_crew(0)), 1.0, "after the linger: x1")


## defense.post_revive_buff (the revived one's; Back on Your Feet + Second Lease): the entries multiply for duration s.
func test_post_revive_buffs_stack() -> void:
	_grant(1, BOYF)
	_grant(1, SECOND_LEASE, true)
	_crew(1).health.go_down()
	_crew(1).health.revive(0)
	var b: Dictionary = _p(BOYF, &"defense.post_revive_buff", false)
	var s: Dictionary = _p(SECOND_LEASE, &"defense.post_revive_buff", true)
	assert_near(Modifiers.mult(1, &"defense.damage_taken_mult"), float(b["damage_taken_mult"]) * float(s["damage_taken_mult"]),
		0.0001, "damage taken (BoYF)")
	assert_near(Modifiers.mult(1, &"weapon.reload_speed_mult"), float(b["reload_mult"]) * float(s["reload_mult"]), 0.0001,
		"reload (Second Lease)")
	assert_near(Modifiers.mult(1, &"movement.speed_mult"), float(b["move_mult"]) * float(s["move_mult"]), 0.0001,
		"Second Lease Aced: move")
	assert_near(CrewBuffs.of(_rt).left(1, SkillTriggers.BUFF_POST_REVIVE), maxf(float(b["duration"]), float(s["duration"])),
		0.1, "for duration s")


## deploy.fak_auto_revive (Field Kit Aced): a downed crew member within radius of the holder's kit is revived by it;
## deploy.medical_user_buff (Bedside Manner Aced): a user of the holder's kit takes less damage for duration s.
func test_field_kit_auto_revive_and_bedside_manner() -> void:
	var ds: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	ds.give(0, &"deployable.fak")
	var kit: DeployablePrefab = ds.place(_crew(0)) as DeployablePrefab
	assert_true(kit != null, "a first-aid kit placed")
	if kit == null:
		return
	var p: Dictionary = _p(FIELD_KIT, &"deploy.fak_auto_revive", true)
	_crew(1).health.go_down()
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, kit.global_position + Vector3(float(p["radius"]) + 3.0, 0, 0)))
	await wait_physics_frames(3)
	assert_eq(_crew(1).crew_state, Enums.CrewState.DOWNED, "no skill / out of radius: stays down")
	_grant(0, FIELD_KIT, true)
	await wait_physics_frames(3)
	assert_eq(_crew(1).crew_state, Enums.CrewState.DOWNED, "out of radius: stays down")
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, kit.global_position + Vector3(float(p["radius"]) * 0.5, 0, 0)))
	var up: bool = await wait_until(func() -> bool: return _crew(1).crew_state == Enums.CrewState.NORMAL, 2.0)
	assert_true(up, "inside the radius: the kit revives")
	assert_true(not is_instance_valid(kit) or kit.uses_left <= 0, "the kit is used")
	ds.give(0, &"deployable.fak")
	var kit2: DeployablePrefab = ds.place(_crew(0)) as DeployablePrefab
	if kit2 == null:
		return
	var m: Dictionary = _p(BEDSIDE, &"deploy.medical_user_buff", true)
	_grant(0, BEDSIDE, true)
	SkillTriggers.medical_used(kit2, _crew(1))
	assert_near(Modifiers.mult(1, &"defense.damage_taken_mult"), float(m["damage_taken_mult"]), 0.0001, "the user is tougher")
	assert_near(CrewBuffs.of(_rt).left(1, SkillTriggers.BUFF_MEDICAL), float(m["duration"]), 0.1, "for duration s")


## defense.bleedout_pause_unseen (Playing Possum): the bleedout holds while no enemy sees the downed holder.
func test_playing_possum_pauses_unseen_bleedout() -> void:
	_grant(0, POSSUM)
	assert_true(Modifiers.flag(0, &"defense.bleedout_pause_unseen"), "granted")
	var h: CrewHealth = _crew(0).health
	h.go_down()
	var b0: float = h.bleedout_left
	await wait_seconds(0.5)
	assert_near(h.bleedout_left, b0, 0.001, "nobody sees: the bleedout holds")
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var npc: NpcBase = dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"),
		Transform3D(Basis.IDENTITY, _crew(0).global_position + Vector3(0, 0, -8)), null)
	await wait_physics_frames(2)
	assert_true(SkillTriggers.seen_by_enemy(_crew(0)), "an enemy in sight")
	var b1: float = h.bleedout_left
	await wait_seconds(0.5)
	assert_true(h.bleedout_left < b1 - 0.3, "seen: it runs (%.2f -> %.2f)" % [b1, h.bleedout_left])
	npc.die()
	Modifiers.clear_source(0, StringName("test.%s" % POSSUM))
	var b2: float = h.bleedout_left
	await wait_seconds(0.5)
	assert_true(h.bleedout_left < b2 - 0.3, "without the skill it runs unseen too")
