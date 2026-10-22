## B's unhooked skill keys, batch 1 (game/content/docs/unhooked_skill_keys.md): the core loud-build pillars. Every
## number comes from B's skill data (ContentDB), granted Basic (+ Aced) as the skill tree does.
extends TestCase

const RALLY_CRY: StringName = &"skill.field_medic.rally_cry"
const LAST_STAND: StringName = &"skill.undying.last_stand"
const RED_MIST: StringName = &"skill.scrapper.red_mist"
const MOMENTUM: StringName = &"skill.scattergun.momentum"
const LEAD_RAIN: StringName = &"skill.quartermaster.lead_rain"
const CLEAN_SHOT: StringName = &"skill.juggernaut.clean_shot"
const PERCUSSIVE: StringName = &"skill.breacher.percussive_maintenance"
const COMEBACK: StringName = &"skill.undying.comeback"

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1201, Enums.Difficulty.ROUTINE, self,
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


## The skill's Basic part on `slot`, and its Aced part too with `aced`.
func _grant(slot: int, id: StringName, aced: bool = false) -> void:
	Modifiers.set_source(slot, &"test.basic", _skill(id).grants_basic)
	if aced:
		Modifiers.set_source(slot, &"test.aced", _skill(id).grants_aced)
	else:
		Modifiers.clear_source(slot, &"test.aced")


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _p(id: StringName, key: StringName, aced: bool) -> Dictionary:
	return ((_skill(id).grants_aced if aced else _skill(id).grants_basic) as Dictionary).get(key, {})


## Teammate `slot` standing `m` metres along crew 0's aim (on the ground).
func _mate_in_front(slot: int, m: float) -> CrewController:
	var me: CrewController = _crew(0)
	var aim: Vector3 = me.aim_direction()
	var flat: Vector3 = Vector3(aim.x, 0.0, aim.z).normalized()
	_rt.teleport_crew(slot, Transform3D(Basis.IDENTITY, me.global_position + flat * m))
	me.look_pitch = 0.0
	return _crew(slot)


## Crew 0 looks at `point` (yaw, then the pitch sign that points the aim at it).
func _aim_at(point: Vector3) -> void:
	var me: CrewController = _crew(0)
	var to: Vector3 = point - me.eye_position()
	var pitch: float = atan2(to.y, Vector2(to.x, to.z).length())
	var best: float = INF
	for sgn: float in [1.0, -1.0]:
		me.look_pitch = sgn * pitch
		var ang: float = me.aim_direction().angle_to(to)
		if ang < best:
			best = ang
	if best != me.aim_direction().angle_to(to):
		me.look_pitch = -me.look_pitch


func _an_enemy() -> NpcBase:
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var pts: Array[Node3D] = dir.valid_spawn_points()
	var xf: Transform3D = pts[0].global_transform if not pts.is_empty() else Transform3D(Basis.IDENTITY, Vector3(0, 0, -20))
	return dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"), xf, null)


## ability.inspire: Basic buffs a standing teammate (move / reload) for buff_duration; Aced revives a downed one in
## range, then not again within the cooldown.
func test_inspire_buff_then_shout_revive() -> void:
	var shouts: ShoutSystem = ShoutSystem.ensure(_rt)
	var mate: CrewController = _mate_in_front(1, 4.0)
	await wait_physics_frames(2)
	var basic: Dictionary = _p(RALLY_CRY, &"ability.inspire", false)
	_grant(0, RALLY_CRY)
	assert_eq(shouts.shout(_crew(0)), [mate] as Array[Node], "the shout reached the teammate")
	assert_near(Modifiers.mult(1, &"movement.speed_mult"), float(basic["buff_move_mult"]), 0.001, "move buff")
	assert_near(Modifiers.mult(1, &"weapon.reload_speed_mult"), float(basic["buff_reload_mult"]), 0.001, "reload")
	var buffs: CrewBuffs = CrewBuffs.of(_rt)
	assert_near(buffs.left(1, &"inspire"), float(basic["buff_duration"]), 0.1, "for buff_duration s")
	assert_eq(Modifiers.mult(0, &"movement.speed_mult"), 1.0, "not on the shouter")
	mate.health.go_down()
	assert_true(shouts.shout(_crew(0)).is_empty(), "Basic: no shout revive")
	var aced: Dictionary = _p(RALLY_CRY, &"ability.inspire", true)
	_grant(0, RALLY_CRY, true)
	_aim_at(mate.global_position + Vector3(0, 0.4, 0))  # looking down at the downed teammate
	assert_eq(shouts.shout(_crew(0)), [mate] as Array[Node], "Aced: the shout reached the downed teammate")
	assert_eq(mate.crew_state, Enums.CrewState.NORMAL, "revived (%.0f m <= %.0f m)" % [4.0, float(aced["range"])])
	mate.health.go_down()
	shouts.shout(_crew(0))
	assert_eq(mate.crew_state, Enums.CrewState.DOWNED, "not again inside the %.0f s cooldown" % float(aced["cooldown"]))
	_mate_in_front(1, float(aced["range"]) + 2.0)
	await wait_physics_frames(2)
	_aim_at(mate.global_position + Vector3(0, 0.4, 0))
	shouts._inspire_cd[0] = 0.0
	shouts.shout(_crew(0))
	assert_eq(mate.crew_state, Enums.CrewState.DOWNED, "not beyond range")


## defense.swan_song: zero health keeps the member up for `duration` s, slowed, taking no damage (Aced: no ammo used),
## then the down.
func test_swan_song_holds_off_the_down() -> void:
	var p: Dictionary = _p(LAST_STAND, &"defense.swan_song", true)
	_grant(0, LAST_STAND, true)
	var h: CrewHealth = _crew(0).health
	h.armor = 0.0
	h.take_hit(Damage.info(h.health + 50.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO, Vector3.FORWARD, 0))
	assert_eq(_crew(0).crew_state, Enums.CrewState.SWAN_SONG, "up in Swan Song at zero health")
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), 1.0 - float(p["speed_penalty"]), 0.001, "slowed")
	assert_true(CrewBuffs.free_ammo(_crew(0)), "Aced: no ammo used")
	var out: Dictionary = h.take_hit(Damage.info(50.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO,
		Vector3.FORWARD, 0))
	assert_eq(float(out["amount"]), 0.0, "no damage taken")
	Engine.time_scale = 4.0
	var down: bool = await wait_until(func() -> bool: return _crew(0).crew_state == Enums.CrewState.DOWNED,
		float(p["duration"]) + 2.0)
	Engine.time_scale = 1.0
	assert_true(down, "down after %.0f s" % float(p["duration"]))
	assert_eq(Modifiers.mult(0, &"movement.speed_mult"), 1.0, "the slow ends")
	assert_false(CrewBuffs.free_ammo(_crew(0)), "and the free ammo")
	_grant(1, LAST_STAND)
	var h1: CrewHealth = _crew(1).health
	h1.armor = 0.0
	h1.take_hit(Damage.info(h1.health + 50.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO,
		Vector3.FORWARD, 0))
	assert_eq(_crew(1).crew_state, Enums.CrewState.SWAN_SONG, "Basic: Swan Song too")
	assert_false(CrewBuffs.free_ammo(_crew(1)), "Basic: ammo is used")


## defense.berserk: below the threshold, melee (Aced: ranged too) damage rises linearly to its max at zero health.
func test_berserk_scales_with_missing_health() -> void:
	var p: Dictionary = _p(RED_MIST, &"defense.berserk", true)
	_grant(0, RED_MIST, true)
	var h: CrewHealth = _crew(0).health
	var thr: float = float(p["threshold"])
	h.health = h.max_health * 0.9
	assert_eq(SkillTriggers.berserk_mult(_crew(0), false), 1.0, "above the threshold: x1")
	h.health = h.max_health * thr * 0.5
	assert_near(SkillTriggers.berserk_mult(_crew(0), false), lerpf(1.0, float(p["max_damage_mult"]), 0.5), 0.001,
		"melee halfway to its max")
	assert_near(SkillTriggers.berserk_mult(_crew(0), true), lerpf(1.0, float(p["ranged_max_damage_mult"]), 0.5),
		0.001, "Aced: ranged halfway to its max")
	var full: float = _crew(0).weapons.damage_at(Enums.WeaponSlot.PRIMARY, 1.0) / SkillTriggers.berserk_mult(_crew(0), true)
	h.health = h.max_health
	assert_near(_crew(0).weapons.damage_at(Enums.WeaponSlot.PRIMARY, 1.0), full, 0.01, "the gun reads it")
	_grant(0, RED_MIST)
	h.health = 1.0
	assert_near(SkillTriggers.berserk_mult(_crew(0), true), float(_p(RED_MIST, &"defense.berserk", false)
		["ranged_max_damage_mult"]), 0.02, "Basic: ranged at its own max")


## weapon.kill_damage_buff: a kill with the trigger class gives that class (Aced: every class) x damage_mult for
## `duration` s; another kill refreshes it.
func test_overkill_after_a_shotgun_kill() -> void:
	var p: Dictionary = _p(MOMENTUM, &"weapon.kill_damage_buff", false)
	var shotgun: StringName = &""
	var rifle: StringName = &""
	for w: WeaponDef in ContentDB.all_weapons():
		var q: StringName = Enums.weapon_class_qualifier(w.weapon_class)
		if q == StringName(p["trigger_class"]) and shotgun == &"":
			shotgun = w.id
		elif q != StringName(p["trigger_class"]) and rifle == &"":
			rifle = w.id
	var cls: StringName = StringName(p["trigger_class"])
	_grant(0, MOMENTUM)
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": rifle})
	assert_eq(Modifiers.mult(0, &"weapon.damage_mult", cls), 1.0, "another class's kill: nothing")
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": shotgun})
	assert_near(Modifiers.mult(0, &"weapon.damage_mult", cls), float(p["damage_mult"]), 0.001, "the class buffed")
	var other: StringName = Enums.weapon_class_qualifier(ContentDB.weapon(rifle).weapon_class)
	assert_eq(Modifiers.mult(0, &"weapon.damage_mult", other), 1.0, "Basic: that class only")
	var buffs: CrewBuffs = CrewBuffs.of(_rt)
	assert_near(buffs.left(0, SkillTriggers.BUFF_OVERKILL), float(p["duration"]), 0.1, "for `duration` s")
	buffs._buffs[0][SkillTriggers.BUFF_OVERKILL]["left"] = 1.0
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": shotgun})
	assert_near(buffs.left(0, SkillTriggers.BUFF_OVERKILL), float(p["duration"]), 0.1, "a kill refreshes it")
	_grant(0, MOMENTUM, true)
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": shotgun})
	assert_near(Modifiers.mult(0, &"weapon.damage_mult", other), float(p["damage_mult"]), 0.001,
		"Aced: every class")


## defense.bullseye: a headshot that hurts an enemy restores `armor`, at most once per `cooldown` s.
func test_bullseye_headshot_restores_armor() -> void:
	var p: Dictionary = _p(CLEAN_SHOT, &"defense.bullseye", false)
	_grant(0, CLEAN_SHOT)
	var npc: NpcBase = _an_enemy()
	assert_true(npc != null, "an enemy")
	var h: CrewHealth = _crew(0).health
	h.armor = 0.0
	h.regen_delay_left = 1000.0  # no natural armor regen during the test
	var head: Dictionary = {"amount": 10.0, "zone": Enums.HitZone.HEAD}
	EventBus.damage_applied.emit(npc.net_id, _crew(0).net_id, {"amount": 10.0, "zone": Enums.HitZone.BODY})
	assert_eq(h.armor, 0.0, "a body hit: nothing")
	EventBus.damage_applied.emit(npc.net_id, _crew(0).net_id, head)
	assert_near(h.armor, minf(float(p["armor"]), h.max_armor), 0.001, "a headshot restores `armor`")
	EventBus.damage_applied.emit(npc.net_id, _crew(0).net_id, head)
	assert_near(h.armor, minf(float(p["armor"]), h.max_armor), 0.001, "not again inside the cooldown")
	await wait_seconds(float(p["cooldown"]) + 0.2)
	EventBus.damage_applied.emit(npc.net_id, _crew(0).net_id, head)
	assert_near(h.armor, minf(2.0 * float(p["armor"]), h.max_armor), 0.001, "again after %.0f s" % float(p["cooldown"]))


## defense.self_revive_charges: a kill while downed gets the killer up, `charges` times per heist;
## defense.self_revive_refill_on_doctor_bag (Aced): a doctor bag use refills them.
func test_messiah_kill_from_the_floor() -> void:
	var charges: int = int(_skill(COMEBACK).grants_basic[&"defense.self_revive_charges"])
	_grant(0, COMEBACK)
	var h: CrewHealth = _crew(0).health
	for i: int in charges:
		h.go_down()
		EventBus.npc_killed.emit(9999, _crew(0).net_id, {})
		assert_eq(_crew(0).crew_state, Enums.CrewState.NORMAL, "kill %d from the floor: up" % (i + 1))
	h.go_down()
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {})
	assert_eq(_crew(0).crew_state, Enums.CrewState.DOWNED, "no charge left")
	SkillTriggers.of(_rt).on_doctor_bag(_crew(0))
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {})
	assert_eq(_crew(0).crew_state, Enums.CrewState.DOWNED, "Basic: a doctor bag refills nothing")
	_grant(0, COMEBACK, true)
	assert_true(Modifiers.flag(0, &"defense.self_revive_refill_on_doctor_bag"), "Aced grants the refill")
	SkillTriggers.of(_rt).on_doctor_bag(_crew(0))
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {})
	assert_eq(_crew(0).crew_state, Enums.CrewState.NORMAL, "Aced: the doctor bag refilled the charge")


## deploy.ammo_bag_bulletstorm: taking ammo from the holder's bag means no ammo used for base + max x share s (at
## most max_duration); the bag owner's skill, on whoever uses it.
func test_bulletstorm_from_the_owners_bag() -> void:
	var p: Dictionary = _p(LEAD_RAIN, &"deploy.ammo_bag_bulletstorm", true)
	_grant(0, LEAD_RAIN, true)
	var t: SkillTriggers = SkillTriggers.of(_rt)
	t.on_ammo_bag(_crew(0), 1, 0.5)
	assert_false(CrewBuffs.free_ammo(_crew(0)), "a bag of a crew member without the skill: nothing")
	t.on_ammo_bag(_crew(1), 0, 0.5)
	assert_true(CrewBuffs.free_ammo(_crew(1)), "the user of the holder's bag fires free")
	var want: float = minf(float(p["base_duration"]) + float(p["max_duration"]) * 0.5, float(p["max_duration"]))
	assert_near(CrewBuffs.of(_rt).left(1, SkillTriggers.BUFF_BULLETSTORM), want, 0.1, "scaled by the share")
	var w: CrewWeapons = _crew(1).weapons
	var ws: int = w.equipped_slot
	var mag: int = w.mag(ws)
	w.server_commit_shot({"weapon_slot": ws})
	assert_eq(w.mag(ws), mag, "a shot uses no round")
	CrewBuffs.of(_rt).end(1, SkillTriggers.BUFF_BULLETSTORM)
	w.server_commit_shot({"weapon_slot": ws})
	assert_eq(w.mag(ws), mag - 1, "after it, rounds are used again")


## interaction.device_melee_restart (Aced): melee on a jammed drill restarts it with the tweak chance, one try per jam.
func test_kickstarter_melee_restarts_a_jammed_drill() -> void:
	var me: CrewController = _crew(0)
	var aim: Vector3 = me.aim_direction()
	var flat: Vector3 = Vector3(aim.x, 0.0, aim.z).normalized()
	var drill: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", me.global_position + flat * 1.0) as DrillPoint
	await wait_physics_frames(2)
	drill.runner.place(0, 60.0)
	drill.runner._jam()
	var tw: CombatTweak = CombatTweak.data()
	var eye: Vector3 = me.eye_position()
	var to: Vector3 = (drill.global_position + Vector3(0, 0.5, 0) - eye).normalized()
	assert_false(me.melee._kick_device(eye, to, 1.5, tw), "Basic only: no kick")
	_grant(0, PERCUSSIVE, true)
	assert_true(Modifiers.flag(0, &"interaction.device_melee_restart"), "Aced grants the melee restart")
	var chance: float = Tweak.interaction().device_melee_restart_chance
	Tweak.interaction().device_melee_restart_chance = 1.0
	assert_true(me.melee._kick_device(eye, to, 1.5, tw), "Aced: the swing strikes the jammed drill")
	assert_eq(drill.runner.state, DeviceRunner.State.RUNNING, "and restarts it")
	drill.runner._jam()
	Tweak.interaction().device_melee_restart_chance = 0.0
	me.melee._kick_device(eye, to, 1.5, tw)
	assert_eq(drill.runner.state, DeviceRunner.State.JAMMED, "a failed roll leaves it jammed")
	Tweak.interaction().device_melee_restart_chance = 1.0
	assert_false(drill.runner.kick(0), "one try per jam")
	Tweak.interaction().device_melee_restart_chance = chance
