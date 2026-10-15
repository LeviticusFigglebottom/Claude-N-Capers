## A2-06 / L2.11: deployables runtime. Deploy hold (S1.1: not while casing), counts (deploy.extra),
## doctor bag (2 uses, full heal + downs reset), first aid kit (1 s deploy, 4 per player, heals, no
## down reset), ammo bag (shared 400 % pool), HUD reads (crew.weapons.deployable_id / _count).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(deployable: StringName, with_weapons: bool = false) -> void:
	var l: Loadout = CrewWeapons.build_loadout(null) if with_weapons else Loadout.new()
	l.deployable = deployable
	ADeployableGateUtil.grant(l)  # D-111 gate flag, no extra units
	_rt = await HeistLauncher.launch(&"unit_map", 2116, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "skip_casing": true, "loadouts": {0: l}})


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _sys() -> DeployableSystem:
	return _rt.service(DeployableSystem.SERVICE) as DeployableSystem


func _stand(masked: bool = true) -> CrewController:
	var c: CrewController = _crew()
	if masked:
		c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(3)
	return c


func _hold_deploy(seconds: float) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.deploy = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(seconds)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)


func _use(p: Node, seconds: float) -> void:
	ATestMaps.hold_interact(_rt, 0, NetIds.of(p))
	await wait_seconds(seconds)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)


func test_l2_11_doctor_bag_deploy_hold_and_hud() -> void:
	await _launch(&"deployable.doctor_bag")
	var c: CrewController = await _stand()
	assert_eq(_sys().deployable_count(0), 1, "doctor bag: 1 unit")
	assert_eq(c.weapons.deployable_count, 1, "HUD read: weapons.deployable_count")
	assert_eq(c.weapons.deployable_id, &"deployable.doctor_bag", "HUD read: weapons.deployable_id")
	await wait_seconds(0.3)
	assert_eq(_rt.hud_model.deployable_count, 1, "LocalHudModel deployable_count")
	assert_eq(_rt.hud_model.deployable_id, &"deployable.doctor_bag", "LocalHudModel deployable_id")
	await _hold_deploy(1.0)
	assert_true(_sys().placed().is_empty(), "released before 2 s: nothing placed")
	await _hold_deploy(2.3)
	var placed: Array[Node] = _sys().placed(&"doctor_bag")
	assert_eq(placed.size(), 1, "placed after the 2 s hold")
	assert_eq(_sys().deployable_count(0), 0, "count consumed")
	assert_eq(c.weapons.deployable_count, 0, "HUD count synced")
	if placed.size() == 1:
		var p: DeployablePrefab = placed[0] as DeployablePrefab
		assert_true(p.is_in_group(G.DEPLOYABLE), "G.DEPLOYABLE")
		assert_true(p.net_id != 0, "net_id claimed")
		assert_near(p.global_position.y, 0.0, 0.05, "on the floor")
		assert_near(p.global_position.z, -Tweak.crew().capsule_radius - 0.45, 0.5, "in front (-Z)")
		assert_eq(p.interactable.kind, &"use_doctor_bag")
	await _hold_deploy(2.3)
	assert_eq(_sys().placed().size(), 1, "no second unit")


func test_s1_1_no_deploy_while_casing() -> void:
	await _launch(&"deployable.doctor_bag")
	await _stand(false)
	await _hold_deploy(2.5)
	assert_true(_sys().placed().is_empty(), "casing: cannot deploy")
	assert_eq(_sys().blocked.get(0, &""), DeployableSystem.BLOCK_CASING, "blocked reason")
	assert_eq(_sys().deployable_count(0), 1, "count kept")


func test_l2_11_doctor_bag_two_uses_full_heal_and_downs_reset() -> void:
	await _launch(&"deployable.doctor_bag")
	var c: CrewController = await _stand()
	var p: DeployablePrefab = _sys().place(c) as DeployablePrefab
	assert_true(p != null, "placed")
	await wait_physics_frames(2)
	assert_eq(p.uses_left, 2, "2 uses")
	assert_ne(p.interactable.availability(c), InteractableComponent.BLOCK_NONE, "full health: not usable")
	c.health.health = 50.0
	c.health.downs_used = 2
	await _use(p, 2.4)
	assert_near(c.health.health, c.health.max_health, 0.01, "full heal")
	assert_eq(c.health.downs_used, 0, "downs reset")
	assert_eq(p.uses_left, 1, "one use left")
	c.health.health = 10.0
	await _use(p, 2.4)
	assert_near(c.health.health, c.health.max_health, 0.01, "second heal")
	assert_true(not is_instance_valid(p) or p.is_queued_for_deletion(), "spent after 2 uses")


func test_l2_11_first_aid_kit_count_deploy_time_no_down_reset() -> void:
	await _launch(&"deployable.fak")
	var c: CrewController = await _stand()
	assert_eq(_sys().deployable_count(0), 4, "4 first aid kits per player")
	await _hold_deploy(1.2)
	var placed: Array[Node] = _sys().placed(&"fak")
	assert_eq(placed.size(), 1, "1 s deploy")
	assert_eq(_sys().deployable_count(0), 3)
	if placed.is_empty():
		return
	var p: DeployablePrefab = placed[0] as DeployablePrefab
	c.health.health = 20.0
	c.health.downs_used = 1
	await _use(p, 0.3)
	assert_near(c.health.health, minf(20.0 + DeployableTweak.data().fak_heal, c.health.max_health), 0.01, "heals 150")
	assert_eq(c.health.downs_used, 1, "no down reset")
	assert_true(not is_instance_valid(p) or p.is_queued_for_deletion(), "single use")


func test_l2_11_deploy_extra_modifier_by_kind() -> void:
	Modifiers.set_source(0, &"test", {&"deploy.extra.doctor_bag": 1, &"deploy.capacity_mult.doctor_bag": 2.0})
	await _launch(&"deployable.doctor_bag")
	var c: CrewController = await _stand()
	assert_eq(_sys().deployable_count(0), 2, "deploy.extra.doctor_bag +1")
	var p: DeployablePrefab = _sys().place(c) as DeployablePrefab
	assert_eq(p.uses_left, 4, "capacity mult x2")


func test_l2_11_ammo_bag_shared_pool() -> void:
	await _launch(&"deployable.ammo_bag", true)
	var c: CrewController = await _stand()
	var w: CrewWeapons = c.weapons
	var slots: Array[int] = []
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if w.has_weapon(ws):
			slots.append(ws)
	assert_true(not slots.is_empty(), "armed")
	var full: Dictionary = {}
	for ws: int in slots:
		full[ws] = w.mag(ws) + w.reserve(ws)
		w.set_ammo(ws, 0, 0)
	var p: DeployablePrefab = _sys().place(c) as DeployablePrefab
	assert_near(p.ammo_left, 4.0, 0.001, "400 %")
	await wait_physics_frames(2)
	await _use(p, 1.4)
	for ws: int in slots:
		assert_eq(w.mag(ws) + w.reserve(ws), int(full[ws]), "refilled slot %d" % ws)
	assert_near(p.ammo_left, 3.0, 0.01, "one full loadout taken")
	assert_ne(p.interactable.availability(c), InteractableComponent.BLOCK_NONE, "full: not usable")
	# Half empty: only what is missing is taken.
	for ws: int in slots:
		w.set_ammo(ws, w.mag(ws), maxi(int(full[ws]) / 2 - w.mag(ws), 0))
	var before: float = p.ammo_left
	await _use(p, 1.4)
	assert_true(p.ammo_left < before and p.ammo_left > before - 1.0, "partial take (%.2f -> %.2f)" % [before, p.ammo_left])
