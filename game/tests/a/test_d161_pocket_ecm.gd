## D-161 stealth.pocket_ecm (Hacker deck, PD2 Pocket ECM): the deck throwable (perk.throwable -> ThrowableDef kind
## pocket_ecm) uses a charge; in stealth it JAMS cameras, phones and pagers for duration_s; loud it is FEEDBACK (stun
## pulses around the holder); 2 charges recharging one after another in cooldown_s, minus kill_cooldown_reduction_s
## per kill; Bit Decay kill_heal, Kluge kill dodge, Botnet crew_kill_heal; a placed ECM is not held up by it (no
## door / ATM path at all); the state replicates (EcmSystem.net_state).
extends TestCase

const KEY: StringName = &"stealth.pocket_ecm"
const ITEM: StringName = &"throwable.test_pocket_ecm"
const P: Dictionary = {"charges": 2, "duration_s": 6.0, "cooldown_s": 100.0, "kill_cooldown_reduction_s": 6.0}

var _rt: HeistRuntime = null
var _victim_id: int = 9000


func before_each() -> void:
	var d: ThrowableDef = ThrowableDef.new()
	d.id = ITEM
	d.kind = PerkPocketEcm.KIND
	d.count = 1
	ContentDB.inject(ContentDB.THROWABLES, ITEM, d)
	_rt = await HeistLauncher.launch(&"unit_map", 1610, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "skip_casing": true})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	ContentDB.clear_cache()
	await wait_frames(1)


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _ecm() -> EcmSystem:
	return _rt.service(EcmSystem.SERVICE) as EcmSystem


func _grant(extra: Dictionary = {}) -> void:
	var p: Dictionary = P.duplicate()
	p.merge(extra, true)
	Modifiers.set_source(0, &"deck", {KEY: p, &"perk.throwable": {"item_id": ITEM}})
	PerkHooks.of(_crew()).refresh()


func _kill_by(c: CrewController) -> void:
	_victim_id += 1
	EventBus.npc_killed.emit(_victim_id, c.net_id, {"type": Enums.DamageType.BULLET})


func test_stealth_jam_cameras_phones_pagers_then_ends() -> void:
	_grant()
	var e: EcmSystem = _ecm()
	assert_false(e.is_jamming(), "nothing jams yet")
	assert_true(PerkHooks.use_throwable(_crew()), "the throwable key uses a charge")
	assert_true(e.is_jamming(), "jamming (cameras)")
	assert_true(EcmSystem.phones_jammed(), "phones jammed")
	assert_true(e.pager_delay_active(), "pagers jammed")
	assert_eq(StringName(e.pocket_state(0)["mode"]), EcmSystem.MODE_JAM, "stealth: the jam")
	assert_eq(int(e.pocket_state(0)["charges"]), 1, "one charge left")
	assert_false(PerkHooks.use_throwable(_crew()), "not again while it runs")
	Engine.time_scale = 4.0
	assert_true(await wait_until(func() -> bool: return not e.is_jamming(), 8.0), "ends after duration_s")
	Engine.time_scale = 1.0
	assert_false(e.pager_delay_active(), "pagers free again")
	assert_true(PerkHooks.use_throwable(_crew()), "the second charge")
	assert_eq(int(e.pocket_state(0)["charges"]), 0)


func test_charges_recharge_one_after_another_and_kills_cut_it() -> void:
	_grant()
	var e: EcmSystem = _ecm()
	e.use_pocket(0, P)
	e.pocket[0]["active_left"] = 0.0
	e.pocket[0]["mode"] = &""
	e.use_pocket(0, P)
	assert_eq(int(e.pocket_state(0)["charges"]), 0, "both used")
	assert_near(float(e.pocket_state(0)["recharge_left"]), 100.0, 0.01, "one recharge running")
	for _i: int in 2:
		_kill_by(_crew())
	assert_near(float(e.pocket_state(0)["recharge_left"]), 88.0, 0.01, "-6 s per kill")
	e.pocket[0]["recharge_left"] = 0.05
	await wait_physics_frames(6)
	assert_eq(int(e.pocket_state(0)["charges"]), 1, "first charge back")
	assert_near(float(e.pocket_state(0)["recharge_left"]), 100.0, 0.2, "then the next one starts (not both at once)")


func test_loud_feedback_stuns_around_the_holder() -> void:
	_grant({"kill_heal": 20.0, "kill_dodge_add": 0.2, "kill_dodge_s": 30.0, "crew_kill_heal": 10.0})
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var c: CrewController = _crew()
	var npcs: Array[NpcBase] = []
	for i: int in 8:
		var n: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, c.global_position + Vector3(i - 4, 0, -6)))
		n.get_node("Brain").set_physics_process(false)
		npcs.append(n)
	var far: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, c.global_position + Vector3(0, 0, -40)))
	await wait_physics_frames(2)
	var e: EcmSystem = _ecm()
	assert_true(PerkHooks.use_throwable(c), "used loud")
	assert_eq(StringName(e.pocket_state(0)["mode"]), EcmSystem.MODE_FEEDBACK, "loud: feedback")
	assert_false(e.is_jamming(), "feedback does not jam")
	await wait_physics_frames(3)
	var stunned: int = npcs.filter(func(n: NpcBase) -> bool: return n.is_stunned()).size()
	assert_true(stunned >= 2, "the first pulse stuns enemies in range (%d of 8)" % stunned)
	assert_false(far.is_stunned(), "not past ecm_feedback_radius_m")
	# Bit Decay / Kluge (the holder's kills) and Botnet (a teammate's kill), while the feedback runs.
	c.health.health = c.health.max_health - 50.0
	_kill_by(c)
	assert_near(c.health.health, c.health.max_health - 30.0, 0.01, "kill_heal 20")
	var comp: PerkPocketEcm = PerkHooks.of(c).component(KEY) as PerkPocketEcm
	assert_near(comp.dodge_add(), 0.2, 0.0001, "Kluge: +0.2 dodge")
	var mate: CrewController = _crew(1)
	mate.health.health = mate.health.max_health - 50.0
	_kill_by(mate)
	assert_near(mate.health.health, mate.health.max_health - 40.0, 0.01, "Botnet: the teammate heals 10")


func test_a_placed_ecm_is_not_held_up_by_the_pocket_jam() -> void:
	_grant()
	PerkHooks.use_throwable(_crew())
	var ds: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	ds.give(0, &"deployable.ecm")
	var placed: Node = ds.place(_crew(), &"deployable.ecm")
	assert_true(placed != null, "an ECM placed")
	assert_eq(_ecm().active_ecm_net_id(), NetIds.of(placed), "it starts at once (no queue behind a pocket jam)")


func test_state_replicates() -> void:
	_grant()
	var e: EcmSystem = _ecm()
	e.use_pocket(0, P)
	var wire: Dictionary = bytes_to_var(var_to_bytes(e.net_state())) as Dictionary
	var mirror: EcmSystem = EcmSystem.new()
	mirror.apply_net_state(wire)
	assert_eq(int(mirror.pocket_state(0)["charges"]), 1, "charges")
	assert_eq(StringName(mirror.pocket_state(0)["mode"]), EcmSystem.MODE_JAM, "mode")
	assert_true(float(mirror.pocket_state(0)["active_left"]) > 5.0, "time left")
	mirror.free()
