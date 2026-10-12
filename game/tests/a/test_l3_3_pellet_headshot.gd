## A4-01 / L3.3: for shotguns any pellet on the head counts. One HEAD pellet in a multi-pellet shot
## makes every pellet of that shot on the same target a headshot (EnemyDef.headshot_mult[difficulty]);
## other targets and single-projectile weapons are unaffected.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func test_l3_3_pellet_headshots_upgrades_same_target_only() -> void:
	var hits: Array = [
		{"target_id": 7, "zone": Enums.HitZone.BODY},
		{"target_id": 7, "zone": Enums.HitZone.HEAD},
		{"target_id": 7, "zone": Enums.HitZone.LEGS},
		{"target_id": 9, "zone": Enums.HitZone.BODY},
		{"zone": Enums.HitZone.HEAD},
	]
	var out: Array = CombatSystem.pellet_headshots(hits)
	assert_eq(out.size(), 5)
	for k: int in range(3):
		assert_eq(int(out[k]["zone"]), Enums.HitZone.HEAD, "pellet %d on the head target" % k)
	assert_eq(int(out[3]["zone"]), Enums.HitZone.BODY, "another target keeps its zone")
	assert_eq(int(hits[0]["zone"]), Enums.HitZone.BODY, "the claim itself is not modified")
	var none: Array = [{"target_id": 7, "zone": Enums.HitZone.BODY}]
	assert_eq(int(CombatSystem.pellet_headshots(none)[0]["zone"]), Enums.HitZone.BODY, "no head pellet: unchanged")


func test_l3_3_shotgun_claim_applies_head_mult_to_every_pellet() -> void:
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.brute_12"
	_rt = await HeistLauncher.launch(&"unit_map", 33, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false, "loadouts": {0: l}})
	await wait_physics_frames(1)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g.global_position + Vector3(0, 0, 3.0)))
	await wait_physics_frames(3)
	g.notify_crew_spotted(c)  # ALARMED: no S3.6 one-shot rule
	await wait_physics_frames(1)
	g.max_health = 100000.0
	g.health = g.max_health
	var ws: int = Enums.WeaponSlot.PRIMARY
	assert_true(c.weapons.stats(ws).pellets > 1, "brute_12 is a multi-pellet shotgun")
	var zones: Array[int] = []
	var cb: Callable = func(v: int, _a: int, info: Dictionary) -> void:
		if v == g.net_id:
			zones.append(int(info["zone"]))
	EventBus.damage_applied.connect(cb)
	var eye: Vector3 = c.eye_position()
	var body_pt: Vector3 = g.global_position + Vector3(0, 0.9, 0)
	var claim: Dictionary = {
		"seq": 5000, "weapon_slot": ws, "weapon_id": &"weapon.brute_12", "origin": eye,
		"direction": (body_pt - eye).normalized(),
		"hits": [
			{"target_id": g.net_id, "zone": Enums.HitZone.BODY, "distance": eye.distance_to(body_pt), "position": body_pt},
			{"target_id": g.net_id, "zone": Enums.HitZone.HEAD, "distance": eye.distance_to(g.head_position()),
				"position": g.head_position()},
			{"target_id": g.net_id, "zone": Enums.HitZone.BODY, "distance": eye.distance_to(body_pt), "position": body_pt},
		],
	}
	var res: Dictionary = CombatSystem.validate_and_apply(claim, c)
	EventBus.damage_applied.disconnect(cb)
	assert_true(bool(res["accepted"]), "claim accepted: %s" % res["reason"])
	assert_eq(zones, [Enums.HitZone.HEAD, Enums.HitZone.HEAD, Enums.HitZone.HEAD] as Array[int],
		"L3.3: every pellet on the target is a headshot")
