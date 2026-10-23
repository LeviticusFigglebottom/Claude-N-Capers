## A4-04 ratchet batch 2 (LEAD r286): behaviour tests for the remaining keys the P4 gate listed as hooked but
## UNTESTED. The movement / carry hooks live in ENV P's crew_controller.gd and are exercised here through the crew's
## own movement (no P file touched).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4042, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "skip_casing": true})
	var c: CrewController = _crew()
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 20)))
	await wait_physics_frames(3)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _grant(grants: Dictionary) -> void:
	Modifiers.set_source(0, &"test.batch2", grants)


func _move(sprint: bool = false, crouch: bool = false) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.sprint = sprint
	i.crouch = crouch
	_rt.set_bot_intent(0, i)


func _flat_speed() -> float:
	var c: CrewController = _crew()
	return Vector2(c.velocity.x, c.velocity.z).length()


func _carry(loot_id: StringName, weight: int) -> LootBag:
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(loot_id, Transform3D(Basis.IDENTITY, _crew().global_position))
	bag.set(&"weight", weight)
	assert_true(loot.carry(bag, _crew()), "carrying %s" % loot_id)
	return bag


# --- Movement / carry (P's crew_controller hooks) -------------------------------------------------

func test_crouch_speed_mult() -> void:
	_grant({&"movement.crouch_speed_mult": 1.5})
	_move(false, true)
	await wait_seconds(0.5)
	assert_near(_flat_speed(), Tweak.crew().crouch_speed * 1.5, 0.03, "x1.5 crouch speed")


func test_carry_speed_penalty_mult() -> void:
	_carry(&"loot.cash", Enums.LootWeight.HEAVY)
	var tw: CrewTweak = Tweak.crew()
	_move()
	await wait_seconds(0.5)
	var pen: float = 1.0 - tw.bag_speed_mult[Enums.LootWeight.HEAVY]
	assert_near(_flat_speed(), tw.walk_speed * (1.0 - pen), 0.03, "a heavy bag's full penalty")
	_grant({&"loot.carry_speed_penalty_mult": 0.5})
	await wait_seconds(0.4)
	assert_near(_flat_speed(), tw.walk_speed * (1.0 - pen * 0.5), 0.03, "x0.5 carry penalty")


func test_can_sprint_with_heavy() -> void:
	_carry(&"loot.cash", Enums.LootWeight.HEAVY)
	_move(true)
	await wait_seconds(0.3)
	assert_false(_crew().sprinting, "no sprint with a heavy bag")
	_grant({&"loot.can_sprint_with_heavy": true})
	await wait_seconds(0.3)
	assert_true(_crew().sprinting, "the skill lets the carrier sprint")


func test_body_bag_concealed_carry() -> void:
	_carry(&"loot.body_bag", Enums.LootWeight.HEAVY)
	var tw: CrewTweak = Tweak.crew()
	_move()
	await wait_seconds(0.5)
	assert_true(_flat_speed() < tw.walk_speed - 0.1, "a body bag slows (%f)" % _flat_speed())
	_grant({&"stealth.body_bag_concealed_carry": true})
	await wait_seconds(0.4)
	assert_near(_flat_speed(), tw.walk_speed, 0.03, "no carry penalty with the skill")


# --- Stealth ------------------------------------------------------------------------------------

func test_cable_tie_speed_mult() -> void:
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 15)), {})
	await wait_physics_frames(2)
	var tie: InteractableComponent = civ.get_node_or_null(^"TieInteractable") as InteractableComponent
	assert_true(tie != null, "the civilian's cable tie")
	if tie == null:
		return
	var base: float = tie.duration_for(_crew())
	_grant({&"stealth.cable_tie_speed_mult": 0.5})
	assert_near(tie.duration_for(_crew()), base * 0.5, 0.0001, "x0.5 cable tie time")


func test_convert_speed_mult() -> void:
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 15)), {})
	await wait_physics_frames(2)
	PoliceSurrender.of(cop, true)  # the surrender component carries the tie / convert interactions
	await wait_physics_frames(1)
	var conv: InteractableComponent = cop.get_node_or_null(PoliceSurrender.CONVERT_NAME) as InteractableComponent
	assert_true(conv != null, "the cop's convert interaction")
	if conv == null:
		return
	var base: float = conv.duration_for(_crew())
	_grant({&"ability.convert_speed_mult": 0.5})
	assert_near(conv.duration_for(_crew()), base * 0.5, 0.0001, "x0.5 convert time")


func test_civilian_intimidate_range_mult() -> void:
	var tw: StealthTweak = Tweak.stealth()
	var d: float = tw.shout_range_m * 1.3
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 20.0 - d)), {})
	civ.get_node("Brain").set_physics_process(false)
	await wait_physics_frames(2)
	var ss: ShoutSystem = ShoutSystem.ensure(_rt)
	assert_false(ss.targets_for(_crew()).has(civ), "out of the base shout range (%.1f m)" % d)
	_grant({&"stealth.civilian_intimidate_range_mult": 1.5})
	assert_true(ss.targets_for(_crew()).has(civ), "x1.5 intimidation range reaches it")


func test_civilian_stay_down_mult() -> void:
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 15)), {})
	await wait_physics_frames(2)
	var b: CivilianBrain = civ.get_node("Brain") as CivilianBrain
	_grant({&"stealth.civilian_stay_down_mult": 2.0})
	b._intimidate(0)
	assert_near(b.intimidate_left, Tweak.stealth().intimidate_duration_s * 2.0, 0.0001, "x2 stay-down time")


func test_ecm_feedback_duration_mult() -> void:
	var ds: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	ds.give(0, &"deployable.ecm")
	var ecm: DeployablePrefab = ds.place(_crew(), &"deployable.ecm") as DeployablePrefab
	assert_true(ecm != null, "an ECM placed")
	if ecm == null:
		return
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", ecm.global_position + Vector3(2, 0, 0), Vector3.FORWARD)
	await wait_physics_frames(2)
	_grant({&"stealth.ecm_feedback_duration_mult": 2.0})
	var es: EcmSystem = _rt.service(EcmSystem.SERVICE) as EcmSystem
	es.trigger_feedback(ecm, 0)
	await wait_physics_frames(1)
	assert_true(g.stun_left > DeployableTweak.data().ecm_feedback_stun_s * 1.5,
		"x2 feedback stun (%.2f s)" % g.stun_left)


# --- Melee --------------------------------------------------------------------------------------

func test_melee_charge_speed_mult() -> void:
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var m: CrewMelee = _crew().melee
	_crew().loadout.melee = &"melee.folding_knife"
	var def: MeleeDef = m.melee_def()
	assert_true(m.can_melee() and def != null, "melee ready")
	_grant({&"weapon.melee_charge_speed_mult": 2.0})
	var held: CrewIntent = CrewIntent.new()
	held.melee = true
	m.tick(held, 0.0)
	m.tick(held, 0.1)
	assert_near(m.charge, minf(0.2 / def.charge_time_s, 1.0), 0.0001, "x2 charge speed")


func test_melee_bloodthirst() -> void:
	_grant({&"weapon.melee_bloodthirst": {"per_kill": 0.25, "cap": 16.0}})
	var m: CrewMelee = _crew().melee
	for i: int in 3:
		EventBus.npc_killed.emit(1000 + i, _crew().net_id, {"type": Enums.DamageType.BULLET})
	assert_near(m._bloodthirst_mult(), 1.75, 0.0001, "3 non-melee kills x 0.25")


func test_shield_knockback() -> void:
	_rt.stealth.raise_alarm(&"test", 0)
	var npc: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, 18), Vector3(0, 0, 1))
	await wait_physics_frames(2)
	var bw: BulwarkBrain = npc.get_node("Brain") as BulwarkBrain
	var m: CrewMelee = _crew().melee
	m.charge = 0.0
	m._knock(npc, m.melee_def(), CombatTweak.data())
	assert_eq(bw.staggers, 0, "an uncharged hit leaves the Bulwark")
	_grant({&"weapon.shield_knockback": true})
	m._knock(npc, m.melee_def(), CombatTweak.data())
	assert_eq(bw.staggers, 1, "the skill knocks the Bulwark back")
