## B's unhooked skill keys, batch 5 (the trip-mine fire; the sentry keys wait on a crew sentry) and batch 6 (hostages,
## converts, marks). Every number comes from B's skill data (ContentDB).
extends TestCase

const HOT_FLOOR: StringName = &"skill.breacher.hot_floor"
const ACCOMPLICE: StringName = &"skill.persuader.accomplice"
const LEVERAGE: StringName = &"skill.persuader.leverage"
const CAPTIVE: StringName = &"skill.persuader.captive_audience"
const PRICE_TAG: StringName = &"skill.quiet_professional.price_tag"

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1206, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 1), "ai_teammates": 1, "crew_ai": false,
		"loadouts": {0: CrewWeapons.build_loadout(null)}})
	await wait_physics_frames(3)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _skill(id: StringName) -> SkillDef:
	return ContentDB.by_id(ContentDB.SKILLS, id) as SkillDef


func _grant(slot: int, id: StringName, aced: bool = false) -> void:
	var g: Dictionary = (_skill(id).grants_basic as Dictionary).duplicate()
	if aced:
		g.merge(_skill(id).grants_aced, true)
	Modifiers.set_source(slot, StringName("test.%s" % id), g)


func _val(id: StringName, key: StringName, aced: bool = false) -> Variant:
	var g: Dictionary = (_skill(id).grants_basic as Dictionary).duplicate()
	if aced:
		g.merge(_skill(id).grants_aced, true)
	return g.get(key)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _enemy(pos: Vector3) -> NpcBase:
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	return dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"), Transform3D(Basis.IDENTITY, pos), null)


## deploy.trip_mine_fire (Hot Floor): the holder's trip mine leaves a fire pool of radius m for duration s.
func test_hot_floor_trip_mine_fire() -> void:
	_rt.stealth.raise_alarm(&"test")
	var p: Dictionary = _val(HOT_FLOOR, &"deploy.trip_mine_fire", true)
	var pools: Callable = func() -> Array[Node]:
		return _rt.find_children("FirePool_*", "ThrownItem", true, false)
	var ds: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	ds.give(0, &"deployable.trip_mine")
	var mine: DeployablePrefab = ds.place(_crew(0)) as DeployablePrefab
	assert_true(mine != null, "a trip mine placed")
	if mine == null:
		return
	mine.trip_detonate()
	assert_true(pools.call().is_empty(), "no skill: no fire")
	_grant(0, HOT_FLOOR, true)
	ds.give(0, &"deployable.trip_mine")
	var mine2: DeployablePrefab = ds.place(_crew(0)) as DeployablePrefab
	await wait_physics_frames(2)
	mine2.trip_detonate()
	var found: Array[Node] = pools.call()
	assert_eq(found.size(), 1, "the blast leaves a fire pool")
	if found.is_empty():
		return
	var pool: ThrownItem = found[0] as ThrownItem
	assert_near(float(pool.params["radius_m"]), float(p["radius"]), 0.0001, "of `radius` m")
	assert_near(pool.pool_left, float(p["duration"]), 0.1, "burning `duration` s")
	var npc: NpcBase = _enemy(pool.global_position + Vector3(float(p["radius"]) * 0.5, 0, 0))
	var burnt: bool = await wait_until(func() -> bool: return npc.get_node_or_null(BurnStatus.NODE_NAME) != null, 2.0)
	assert_true(burnt, "an enemy inside burns")


## ability.convert_owner_buff (Accomplice): while the holder owns a living converted enemy, move (Aced: health) up.
func test_accomplice_with_a_converted_enemy() -> void:
	var p: Dictionary = _val(ACCOMPLICE, &"ability.convert_owner_buff", true)
	_grant(0, ACCOMPLICE, true)
	await wait_physics_frames(2)
	assert_eq(Modifiers.mult(0, &"movement.speed_mult"), 1.0, "no convert: nothing")
	var npc: NpcBase = _enemy(Vector3(0, 0, -20))
	var ally: ConvertedAllyBrain = ConvertedAllyBrain.new()
	ally.name = ConvertedAllyBrain.NODE_NAME
	ally.owner_slot = 0
	ally.process_mode = Node.PROCESS_MODE_DISABLED
	npc.add_child(ally)
	await wait_physics_frames(2)
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), float(p["move_mult"]), 0.0001, "faster")
	assert_near(Modifiers.mult(0, &"defense.health_mult"), float(p["health_mult"]), 0.0001, "Aced: more health")
	assert_eq(Modifiers.mult(1, &"movement.speed_mult"), 1.0, "not the other crew member")


## ability.hostage_regen (Leverage): heal per_hostage of max health every interval s per hostage (up to max).
func test_leverage_hostage_regen() -> void:
	var p: Dictionary = _val(LEVERAGE, &"ability.hostage_regen", true)
	_grant(0, LEVERAGE, true)
	var h: CrewHealth = _crew(0).health
	h.health = h.max_health * 0.5
	var t: SkillTriggers = SkillTriggers.of(_rt)
	var ct: CivilianTargets = _rt.service(CivilianTargets.SERVICE) as CivilianTargets
	assert_true(ct != null, "civilian targets")
	var npc: NpcBase = _enemy(Vector3(0, 0, -20))
	npc.add_to_group(G.HOSTAGE)
	ct.recount_hostages()
	t._regen_left[0] = 0.01
	await wait_physics_frames(3)
	assert_near(h.health, h.max_health * (0.5 + float(p["per_hostage"]) * mini(1, int(p["max_hostages"]))), 0.01,
		"a hostage: per_hostage of max health")
	assert_near(t._regen_left[0], float(p["interval"]), 0.2, "every interval s")


## ability.stockholm (Captive Audience Aced): a tied hostage nearby revives the downed holder, once per hostage;
## stealth.noise_intimidates_civilians (Basic): the holder's gunfire intimidates civilians in the shout range.
func test_captive_audience() -> void:
	_grant(0, CAPTIVE, true)
	assert_true(Modifiers.flag(0, &"ability.stockholm"), "Aced grants Stockholm")
	assert_true(Modifiers.flag(0, &"stealth.noise_intimidates_civilians"), "Basic grants the noise intimidation")
	var hostage: NpcBase = _enemy(_crew(0).global_position + Vector3(3, 0, 0))
	hostage.add_to_group(G.HOSTAGE)
	var h: CrewHealth = _crew(0).health
	h.go_down()
	h.down_s = SkillTriggers.STOCKHOLM_DELAY_S + 0.1
	await wait_physics_frames(2)
	assert_eq(_crew(0).crew_state, Enums.CrewState.NORMAL, "the hostage revived the holder")
	h.go_down()
	h.down_s = SkillTriggers.STOCKHOLM_DELAY_S + 0.1
	await wait_physics_frames(2)
	assert_eq(_crew(0).crew_state, Enums.CrewState.DOWNED, "each hostage once")
	var civ: NpcBase = null
	for n: Node in _rt.npcs(&"civilian"):
		civ = n as NpcBase
	assert_true(civ != null, "a civilian on the map")
	if civ == null:
		return
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, civ.global_position + Vector3(2, 0, 0)))
	await wait_physics_frames(2)
	EventBus.weapon_fired.emit(_crew(1).net_id, &"", false, _crew(1).global_position)
	assert_ne(civ.alert_state, Enums.AlertState.INTIMIDATED, "no skill: gunfire intimidates nobody")
	_grant(1, CAPTIVE)
	EventBus.weapon_fired.emit(_crew(1).net_id, &"", false, _crew(1).global_position)
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED, "Captive Audience: the gunfire puts the civilian down")


## stealth.mark_by_aim (Aced): aiming at a markable enemy marks it; stealth.mark_damage_bonus_mult (Basic) and
## mark_far_damage_mult (Aced): marked enemies take more crew damage (far: more again).
func test_price_tag_marks() -> void:
	_rt.stealth.raise_alarm(&"test")
	var me: CrewController = _crew(0)
	var aim: Vector3 = me.aim_direction()
	var npc: NpcBase = _enemy(me.global_position + Vector3(aim.x, 0, aim.z).normalized() * 6.0)
	npc.role = &"guard"  # markable (guards, specials, cameras)
	await wait_physics_frames(3)
	assert_eq(CombatSystem.mark_damage_mult(npc, 5.0), 1.0, "unmarked: x1")
	_grant(0, PRICE_TAG, true)
	assert_true(Modifiers.flag(0, &"stealth.mark_by_aim"), "Aced grants marking by aim")
	var to: Vector3 = npc.global_position + Vector3(0, 1.2, 0) - me.eye_position()
	me.look_pitch = 0.0
	for sgn: float in [1.0, -1.0]:
		me.look_pitch = sgn * atan2(to.y, Vector2(to.x, to.z).length())
		if me.aim_direction().angle_to(to) < 0.05:
			break
	var i: CrewIntent = CrewIntent.new()
	i.aim = true
	i.look_yaw = me.look_yaw
	i.look_pitch = me.look_pitch
	_rt.set_bot_intent(0, i)
	var marked: bool = await wait_until(func() -> bool: return _rt.stealth.is_marked(npc), SkillTriggers.MARK_AIM_S + 1.0)
	assert_true(marked, "aimed at for MARK_AIM_S: marked")
	var bonus: float = float(_val(PRICE_TAG, &"stealth.mark_damage_bonus_mult", true))
	var far: Dictionary = _val(PRICE_TAG, &"stealth.mark_far_damage_mult", true)
	assert_near(CombatSystem.mark_damage_mult(npc, float(far["min_distance"]) - 1.0), bonus, 0.0001, "marked: x bonus")
	assert_near(CombatSystem.mark_damage_mult(npc, float(far["min_distance"]) + 1.0), bonus * float(far["mult"]), 0.0001,
		"marked and far: x bonus x far")
