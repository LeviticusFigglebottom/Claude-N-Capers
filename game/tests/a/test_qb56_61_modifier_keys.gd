## QB-56..61 modifier hooks: movement.armor_penalty_mult (+ ArmorDef.move_speed_mult), stamina
## (movement.stamina_mult, team.stamina_mult, ArmorDef.stamina_mult), weapon.ammo_pickup_mult (ammo
## box drops + walk-over pickup, weapon.ammo_pickup_range_mult), deploy.armor_bag,
## interaction.doctor_bag_speed_mult, team.health_mult / team.armor_mult / team.armor_regen_delay_mult /
## team.armor_regen_rate_mult / team.damage_reduction_hostage, ability.shout_range_mult.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	Modifiers.clear_all()


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(l: Loadout = null, ai: int = 0) -> CrewController:
	var loadouts: Dictionary = {0: l} if l != null else {}
	_rt = await HeistLauncher.launch(&"unit_map", 5661, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": ai, "skip_casing": true, "loadouts": loadouts})
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 20)))
	await wait_physics_frames(3)
	return c


func _armored(armor_id: StringName) -> Loadout:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.armor = armor_id
	return l


func _move(sprint: bool, jump: bool = false) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.sprint = sprint
	i.jump = jump
	_rt.set_bot_intent(0, i)


func _hit(amount: float) -> Dictionary:
	return Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO, Vector3.FORWARD)


func _flat_speed(c: CrewController) -> float:
	return Vector2(c.velocity.x, c.velocity.z).length()


# --- QB-56 armor move speed -----------------------------------------------------------------------

func test_qb56_armor_move_speed_and_penalty_mult() -> void:
	var c: CrewController = await _launch(_armored(&"armor.heavy_vest"))
	var vest: ArmorDef = ContentDB.armor(&"armor.heavy_vest")
	var tw: CrewTweak = Tweak.crew()
	_move(false)
	await wait_seconds(0.5)
	assert_near(_flat_speed(c), tw.walk_speed * vest.move_speed_mult, 0.02, "heavy vest slows walking")
	Modifiers.set_source(0, &"perk", {&"movement.armor_penalty_mult": 0.5})
	await wait_seconds(0.4)
	var expected: float = tw.walk_speed * (1.0 - (1.0 - vest.move_speed_mult) * 0.5)
	assert_near(_flat_speed(c), expected, 0.02, "movement.armor_penalty_mult halves the penalty")
	Modifiers.set_source(0, &"perk", {&"movement.armor_penalty_mult": 0.0})
	await wait_seconds(0.4)
	assert_near(_flat_speed(c), tw.walk_speed, 0.02, "no penalty at 0")


# --- QB-60 stamina --------------------------------------------------------------------------------

func test_qb60_stamina_max_from_modifiers_and_armor() -> void:
	var c: CrewController = await _launch(_armored(&"armor.heavy_vest"))
	var vest: ArmorDef = ContentDB.armor(&"armor.heavy_vest")
	var base: float = Tweak.crew().stamina_base
	assert_near(c.stamina.max_value, base * vest.stamina_mult, 0.01, "ArmorDef.stamina_mult")
	assert_near(c.stamina.value, c.stamina.max_value, 0.01, "starts full")
	Modifiers.set_source(0, &"skills", {&"movement.stamina_mult": 1.25})
	Modifiers.set_source(Modifiers.TEAM, &"team_perk.foreman", {&"team.stamina_mult": 1.5})
	await wait_physics_frames(2)
	assert_near(c.stamina.max_value, base * vest.stamina_mult * 1.25 * 1.5, 0.01, "movement x team stamina mult")
	assert_near(c.stamina.fraction(), 1.0, 0.01, "fraction kept on a max change")


func test_qb60_sprint_drains_blocks_at_zero_and_regenerates() -> void:
	var c: CrewController = await _launch()
	var tw: CrewTweak = Tweak.crew()
	_move(true)
	await wait_seconds(0.5)
	assert_true(c.sprinting, "sprints with stamina")
	var before: float = c.stamina.value
	await wait_seconds(0.5)
	assert_true(c.stamina.value < before - tw.stamina_drain_per_s * 0.3, "sprinting drains stamina")
	c.stamina.value = 0.05
	await wait_seconds(0.3)
	assert_false(c.sprinting, "no sprint at 0 stamina")
	assert_true(c.stamina.exhausted, "exhausted")
	assert_near(_flat_speed(c), tw.walk_speed, 0.05, "falls back to walking")
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_seconds(tw.stamina_regen_delay_s * 0.5)
	assert_near(c.stamina.value, 0.0, 0.01, "no regen during the delay")
	await wait_seconds(tw.stamina_regen_delay_s * 0.5 + 2.0)
	assert_true(c.stamina.value > tw.stamina_min_threshold, "regenerates after the delay")
	assert_false(c.stamina.exhausted, "sprint allowed again above the threshold")


## D-107 (PD2; updated by ENV P under the D-107 carve-out): stamina never blocks a jump; only a run-jump (sprinting
## longer than stamina_run_jump_min_s, moving) costs stamina_jump_cost.
func test_qb60_jump_never_blocked_run_jump_costs() -> void:
	var c: CrewController = await _launch()
	var tw: CrewTweak = Tweak.crew()
	c.stamina.value = tw.stamina_min_threshold * 0.5
	var i: CrewIntent = CrewIntent.new()
	i.jump = true
	_rt.set_bot_intent(0, i)
	var max_y: float = 0.0
	for k: int in range(20):
		await wait_physics_frames(1)
		max_y = maxf(max_y, c.global_position.y)
	assert_true(max_y > 0.3, "jumps below the stamina threshold (max y %f)" % max_y)
	assert_true(c.stamina.value >= tw.stamina_min_threshold * 0.5 - 0.01, "a standing jump costs nothing")
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_seconds(1.0)
	c.stamina.value = 20.0
	_move(true)
	await wait_seconds(tw.stamina_run_jump_min_s + 0.3)
	assert_true(c.sprinting, "sprinting")
	var before: float = c.stamina.value
	_move(true, true)
	for k: int in range(6):
		await wait_physics_frames(1)
	var run_drain: float = tw.stamina_drain_per_s * 6.0 / Engine.physics_ticks_per_second
	assert_near(before - c.stamina.value, tw.stamina_jump_cost + run_drain, 0.12, "a run-jump costs stamina")


func test_qb60_hud_stamina_and_replicated_state() -> void:
	var c: CrewController = await _launch(null, 1)
	var hud: LocalHudModel = _rt.hud_model
	var fired: Array[int] = [0]
	hud.stamina_changed.connect(func() -> void: fired[0] += 1)
	hud.refresh()
	assert_near(hud.stamina, 1.0, 0.001, "full stamina on the HUD")
	assert_false(hud.exhausted)
	assert_true(hud.snapshot().has(&"stamina") and hud.snapshot().has(&"exhausted"), "in snapshot()")
	var before: int = fired[0]
	hud.refresh()
	assert_eq(fired[0], before, "no signal without a change")
	_move(true)
	c.stamina.value = 0.05
	await wait_seconds(0.3)
	hud.refresh()
	assert_near(hud.stamina, 0.0, 0.001, "drained")
	assert_true(hud.exhausted, "exhausted on the HUD")
	assert_true(fired[0] >= before + 1, "stamina_changed fired")
	var st: Dictionary = NetEntityCodec.state_of(c)
	assert_true(st.has("st") and st.has("sx"), "stamina in the crew state diff")
	var other: CrewController = _rt.crew_controller(1) as CrewController
	NetEntityCodec.apply_state(other, {"st": 0.25, "sx": true})
	assert_near(other.stamina.fraction(), 0.25, 0.001, "client applies replicated stamina")
	assert_true(other.stamina.exhausted)


# --- QB-60 team keys ------------------------------------------------------------------------------

func test_qb60_team_health_armor_and_regen_keys() -> void:
	await _launch(null, 1)
	var c1: CrewController = _rt.crew_controller(1) as CrewController
	var tw: CrewTweak = Tweak.crew()
	var h0: float = c1.health.max_health
	var a0: float = c1.health.max_armor
	Modifiers.set_source(Modifiers.TEAM, &"team_perk.foreman", {
		&"team.health_mult": 1.1, &"team.armor_mult": 1.05, &"team.armor_regen_delay_mult": 0.5,
		&"team.armor_regen_rate_mult": 2.0,
	})
	await wait_physics_frames(2)
	assert_near(c1.health.max_health, h0 * 1.1, 0.01, "team.health_mult")
	assert_near(c1.health.max_armor, a0 * 1.05, 0.01, "team.armor_mult")
	c1.health.take_hit(_hit(5.0))
	assert_near(c1.health.regen_delay_left, tw.armor_regen_delay_s * 0.5, 0.05, "team.armor_regen_delay_mult")
	c1.health.regen_delay_left = 0.0
	c1.health.armor = 0.0
	await wait_seconds(tw.armor_regen_full_time_s * 0.5 + 0.05)
	assert_near(c1.health.armor, c1.health.max_armor, 0.01, "team.armor_regen_rate_mult 2: full in half the time")


func test_qb60_team_damage_reduction_per_hostage() -> void:
	var c: CrewController = await _launch()
	var ct: CivilianTargets = CivilianTargets.ensure(_rt)
	ct.hostage_count = 2
	# D-056: flat absorption per hostage capped by hostage count.
	Modifiers.set_source(Modifiers.TEAM, &"team_perk.foreman",
		{&"team.damage_reduction_hostage": {"absorb_per_hostage": 2.0, "max_hostages": 1}})
	var out: Dictionary = c.health.take_hit(_hit(10.0))
	assert_near(float(out["amount"]), 8.0, 0.01, "2 absorbed per hostage, capped at 1 hostage")
	Modifiers.clear_all()
	c.health.invuln_left = 0.0
	c.health.armor = c.health.max_armor
	Modifiers.set_source(Modifiers.TEAM, &"team_skill.skill.persuader.zip_and_tie",
		{&"team.damage_reduction_hostage": {"absorb_per_hostage": 5.0, "max_hostages": 8}})
	out = c.health.take_hit(_hit(15.0))
	assert_near(float(out["amount"]), 5.0, 0.01, "5 absorbed per hostage (2 hostages)")
	ct.hostage_count = 0
	c.health.invuln_left = 0.0
	c.health.armor = c.health.max_armor
	out = c.health.take_hit(_hit(15.0))
	assert_near(float(out["amount"]), 15.0, 0.01, "no hostages: no reduction")


# --- QB-57 ammo pickups ---------------------------------------------------------------------------

func _ammo() -> AmmoPickupSystem:
	return _rt.service(AmmoPickupSystem.SERVICE) as AmmoPickupSystem


func test_qb57_enemy_drops_box_walk_over_gives_rounds() -> void:
	var c: CrewController = await _launch()
	var ws: int = Enums.WeaponSlot.SECONDARY
	var st: WeaponStats = c.weapons.stats(ws)
	assert_true(st != null and st.ammo_pickup_max > 0.0, "default sidearm has pickup values")
	var guard: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(6, 0.05, 20)))
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(-6, 0.05, 20)))
	await wait_physics_frames(2)
	guard.die({}, c.net_id)
	civ.die({}, c.net_id)
	await wait_physics_frames(2)
	assert_eq(_ammo().boxes().size(), 1, "the guard drops an ammo box, the civilian does not")
	var box: Node3D = _ammo().boxes()[0] as Node3D
	assert_true(NetIds.of(box) != Ids.INVALID, "box has a net id (replicated spawn)")
	var picked: Array = []
	_ammo().ammo_picked.connect(func(crew: CrewController, amount: int) -> void: picked.append([crew, amount]))
	box.global_position = c.global_position + Vector3(3, 0, 0)
	await wait_physics_frames(3)
	assert_eq(_ammo().boxes().size(), 1, "full ammo and out of reach: box stays")
	c.weapons.set_ammo(ws, c.weapons.mag(ws), 0)
	box.global_position = c.global_position + Vector3(0.3, 0, 0)
	await wait_physics_frames(3)
	assert_eq(_ammo().boxes().size(), 0, "walking over it takes it")
	var got: int = c.weapons.reserve(ws)
	assert_true(got >= int(round(st.ammo_pickup_min)) and got <= int(round(st.ammo_pickup_max)),
		"rounds in [%s, %s] (got %d)" % [st.ammo_pickup_min, st.ammo_pickup_max, got])
	assert_eq(picked.size(), 1, "ammo_picked emitted")
	if picked.size() == 1:
		assert_eq(picked[0][0], c)
		assert_eq(int(picked[0][1]), got, "amount = rounds added")


func test_qb57_ammo_pickup_mult_and_range_mult() -> void:
	var c: CrewController = await _launch()
	var ws: int = Enums.WeaponSlot.SECONDARY
	var st: WeaponStats = c.weapons.stats(ws)
	Modifiers.set_source(0, &"perk", {&"weapon.ammo_pickup_mult.all": 10.0, &"weapon.ammo_pickup_range_mult": 3.0})
	c.weapons.set_ammo(ws, c.weapons.mag(ws), 0)
	_ammo().drop(c.global_position + Vector3(AmmoPickupTweak.data().pickup_radius_m * 2.0, 0.05, 0))
	await wait_physics_frames(3)
	assert_eq(_ammo().boxes().size(), 0, "weapon.ammo_pickup_range_mult reaches a box 2 radii away")
	var got: int = c.weapons.reserve(ws)
	assert_true(got >= int(round(st.ammo_pickup_min * 10.0)) - 1, "x10 pickup (got %d)" % got)


# --- QB-58 armor bag ------------------------------------------------------------------------------

func _deploys() -> DeployableSystem:
	return _rt.service(DeployableSystem.SERVICE) as DeployableSystem


func test_qb58_armor_bag_swaps_armor() -> void:
	var l: Loadout = _armored(&"armor.heavy_vest")
	l.deployable = &"deployable.armor_bag"
	l.perk_deck = &"perk.foreman"
	l.perk_deck_cards = 6  # shared card 6 Walk-in Closet: deploy.armor_bag (pushed by QB-L2)
	l.modifiers = {}
	var c: CrewController = await _launch(l)
	var start: StringName = DeployableTweak.data().armor_bag_start_armor
	assert_eq(_deploys().deployable_count(0), 1, "armor bag in inventory")
	assert_eq(c.loadout.armor, start, "starts in the suit")
	assert_eq(l.armor, &"armor.heavy_vest", "the caller's Loadout is untouched")
	var p: DeployablePrefab = _deploys().place(c) as DeployablePrefab
	assert_true(p != null, "placed")
	if p == null:
		return
	await wait_physics_frames(2)
	assert_eq(p.bag_armor, &"armor.heavy_vest", "the bag holds the loadout armor")
	c.health.armor = 1.0
	ATestMaps.hold_interact(_rt, 0, NetIds.of(p))
	await wait_seconds(float(DeployableTweak.data().use_time_s[&"armor_bag"]) + 0.4)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)
	assert_eq(c.loadout.armor, &"armor.heavy_vest", "changed into the bag armor")
	assert_near(c.health.max_armor, c.health.compute_max_armor(), 0.01)
	assert_near(c.health.armor, c.health.max_armor, 0.01, "full armor")
	assert_true(c.health.max_armor > 60.0, "heavy vest armor")
	assert_true(not is_instance_valid(p) or p.is_queued_for_deletion(), "one use")


func test_qb58_armor_bag_needs_flag() -> void:
	var l: Loadout = _armored(&"armor.heavy_vest")
	l.deployable = &"deployable.armor_bag"
	var c: CrewController = await _launch(l)
	assert_eq(_deploys().deployable_count(0), 0, "no deploy.armor_bag: no bag")
	assert_eq(c.loadout.armor, &"armor.heavy_vest", "armor unchanged")


func test_deployable_gate_checked_at_runtime() -> void:
	assert_true(DeployableSystem._gate_ok(0, &"deployable.doctor_bag"), "ungated: always allowed")
	assert_true(not DeployableSystem._gate_ok(0, &"deployable.armor_bag"), "gated, no flag: refused")
	Modifiers.set_source(0, &"test", {DeployableGate.required_flag(&"deployable.armor_bag"): true})
	assert_true(DeployableSystem._gate_ok(0, &"deployable.armor_bag"), "gated, flag granted")


# --- QB-59 doctor bag use time ----------------------------------------------------------------------

func test_qb59_doctor_bag_speed_mult() -> void:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.deployable = &"deployable.doctor_bag"
	var c: CrewController = await _launch(l)
	var p: DeployablePrefab = _deploys().place(c) as DeployablePrefab
	await wait_physics_frames(2)
	var base: float = p.interactable.duration_for(c)
	assert_true(base > 0.0, "doctor bag has a use time")
	Modifiers.set_source(0, &"perk", {&"interaction.doctor_bag_speed_mult": 0.8333})
	assert_near(p.interactable.duration_for(c), base * 0.8333, 0.001, "interaction.doctor_bag_speed_mult")


# --- QB-61 shout range ----------------------------------------------------------------------------

func test_qb61_shout_range_mult_civilians_and_marks() -> void:
	var c: CrewController = await _launch()
	var sh: ShoutSystem = _rt.service(ShoutSystem.SERVICE) as ShoutSystem
	var tw: StealthTweak = Tweak.stealth()
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 20 - tw.shout_range_m - 3.0)))
	await wait_physics_frames(2)
	assert_false(sh.targets_for(c).has(civ), "civilian beyond the shout range")
	Modifiers.set_source(0, &"perk", {&"ability.shout_range_mult": 1.5})
	assert_true(sh.targets_for(c).has(civ), "ability.shout_range_mult reaches the civilian")
	Modifiers.clear_all()
	civ.queue_free()
	var guard: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 20 - tw.mark_range_m - 4.0)))
	await wait_physics_frames(2)
	assert_true(sh.mark_target_for(c) != guard, "guard beyond the mark range")
	Modifiers.set_source(0, &"perk", {&"ability.shout_range_mult": 1.25})
	assert_eq(sh.mark_target_for(c), guard, "ability.shout_range_mult extends shout marking")
