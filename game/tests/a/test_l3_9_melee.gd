## L3.9 melee (CrewMelee, D-069): quick swing vs charged swing (MeleeDef damage -> charged_damage), silent
## stealth kills (no noise, no alarm), gun bash without a melee item, knockdown, no melee while casing.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Dictionary] = []
var _cb: Callable = Callable()


func after_each() -> void:
	if EventBus.damage_applied.is_connected(_cb):
		EventBus.damage_applied.disconnect(_cb)
	Modifiers.clear_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(melee_id: StringName) -> CrewController:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.melee = melee_id
	_rt = await HeistLauncher.launch(&"unit_map", 3901, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true,
		"loadouts": {0: l}})
	await wait_physics_frames(2)
	_events = []
	_cb = func(v: int, _a: int, info: Dictionary) -> void: _events.append({"victim": v, "info": info})
	EventBus.damage_applied.connect(_cb)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	return c


func _target(pos: Vector3 = Vector3(0, 0.05, -1.2), hp: float = 100000.0) -> NpcBase:
	var n: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", pos, Vector3(0, 0, 1))
	n.max_health = hp
	n.health = hp
	return n


func _melee_hits(n: NpcBase) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events:
		if int(e["victim"]) == n.net_id and int((e["info"] as Dictionary)["type"]) == Enums.DamageType.MELEE:
			out.append(e["info"])
	return out


## Hold melee for `hold_s` aimed at `at`, then release and wait the swing out.
func _swing(c: CrewController, at: Vector3, hold_s: float) -> void:
	var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), at)
	i.melee = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(hold_s)
	_rt.set_bot_intent(0, BotUtil.look_at_intent(c.eye_position(), at))
	await wait_seconds(0.8)


func test_quick_and_charged_swing() -> void:
	var c: CrewController = await _launch(&"melee.folding_knife")
	c.set_masked()
	var knife: MeleeDef = ContentDB.melee(&"melee.folding_knife")
	var n: NpcBase = _target()
	await wait_physics_frames(2)
	await _swing(c, CombatSystem.target_center(n), 0.05)
	var hits: Array[Dictionary] = _melee_hits(n)
	assert_eq(hits.size(), 1, "one melee hit")
	if hits.size() == 1:
		assert_near(float(hits[0]["amount"]), knife.damage, 0.5, "quick swing = MeleeDef.damage")
	await _swing(c, CombatSystem.target_center(n), knife.charge_time_s + 0.2)
	hits = _melee_hits(n)
	assert_eq(hits.size(), 2, "charged swing hit")
	if hits.size() == 2:
		assert_near(float(hits[1]["amount"]), knife.charged_damage, 0.5, "full charge = charged_damage")


func test_silent_stealth_kill() -> void:
	var c: CrewController = await _launch(&"melee.folding_knife")
	c.set_masked()
	var n: NpcBase = _target(Vector3(0, 0.05, -1.2), 10.0)
	var noises: Array = []
	_rt.noise_made.connect(func(p: Vector3, r: float, k: StringName, _s: int) -> void: noises.append([k, r]))
	await wait_physics_frames(2)
	await _swing(c, CombatSystem.target_center(n), 0.05)
	assert_false(n.alive, "the knife kills the guard")
	assert_eq(noises, [], "L3.9 / S4.3: melee makes no noise")
	assert_false(_rt.went_loud, "a silent kill raises no alarm")


func test_gun_bash_without_melee_item() -> void:
	var c: CrewController = await _launch(&"")
	c.set_masked()
	var n: NpcBase = _target()
	await wait_physics_frames(2)
	assert_true(c.melee.melee_def() == null, "no melee item: gun bash")
	await _swing(c, CombatSystem.target_center(n), 0.05)
	var hits: Array[Dictionary] = _melee_hits(n)
	assert_eq(hits.size(), 1, "the bash hits")
	if hits.size() == 1:
		assert_near(float(hits[0]["amount"]), CombatTweak.data().bash_damage, 0.5, "bash damage")


func test_no_melee_while_casing_and_knockdown() -> void:
	var c: CrewController = await _launch(&"melee.folding_knife")
	var n: NpcBase = _target()
	await wait_physics_frames(2)
	await _swing(c, CombatSystem.target_center(n), 0.05)
	assert_eq(_melee_hits(n).size(), 0, "no melee while casing")
	c.set_masked()
	Modifiers.set_source(0, &"skills", {&"weapon.melee_knockdown_mult": 100.0})
	await _swing(c, CombatSystem.target_center(n), 0.05)
	assert_eq(_melee_hits(n).size(), 1, "masked: hit")
	assert_false(n.is_stunned(), "a quick swing never knocks down")
	await _swing(c, CombatSystem.target_center(n), ContentDB.melee(&"melee.folding_knife").charge_time_s + 0.2)
	assert_eq(_melee_hits(n).size(), 2, "charged hit")
	assert_true(n.is_stunned(), "charged knockdown (MeleeDef.knockdown x weapon.melee_knockdown_mult)")


func test_infiltrator_chain_on_real_swings() -> void:
	var c: CrewController = await _launch(&"melee.folding_knife")
	c.set_masked()
	Modifiers.set_source(0, &"perk", {&"perk.infiltrator": {"melee_chain_mult": 3.0, "melee_chain_window_s": 5.0,
		"melee_hit_heal_fraction": 0.0, "melee_hit_heal_cooldown_s": 10.0}})
	var knife: MeleeDef = ContentDB.melee(&"melee.folding_knife")
	var n: NpcBase = _target()
	await wait_physics_frames(2)
	await _swing(c, CombatSystem.target_center(n), 0.05)
	await _swing(c, CombatSystem.target_center(n), 0.05)
	var hits: Array[Dictionary] = _melee_hits(n)
	assert_eq(hits.size(), 2)
	if hits.size() == 2:
		assert_near(float(hits[1]["amount"]), knife.damage * 3.0, 0.5, "perk.infiltrator: the chained hit x3 (PerkHooks)")
	await _swing(c, Vector3(5, 1.5, 5), 0.05)  # a miss
	assert_near(PerkHooks.melee_damage_mult(c), 1.0, 0.001, "a miss resets the chain")
