## A4-04 ratchet batch 1 (LEAD r286): behaviour tests for keys the P4 gate listed as hooked but UNTESTED. Each test
## grants the key and checks the behaviour it drives (the saw keys are in test_b4_18_special_weapons). Class-qualified
## weapon keys are granted as "<key>.all" (Modifiers reads key.all / key.<class> when a qualifier is passed).
extends TestCase

const RECOIL: String = "weapon.recoil_mult"
const SWAP: String = "weapon.swap_speed_mult"
const AMMO_TOTAL: String = "weapon.ammo_total_mult"

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4041, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "loadouts": {0: _loadout()}})
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)


## Both slots armed (the default player loadout has no primary).
static func _loadout() -> Loadout:
	var l: Loadout = Loadout.new()
	l.primary = CombatTweak.data().bot_default_primary
	l.secondary = CombatTweak.data().default_secondary
	return CrewWeapons.build_loadout(l)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _grant(key: StringName, v: Variant) -> void:
	Modifiers.set_source(0, &"test.batch1", {key: v})


func test_recoil_mult_scales_the_kick() -> void:
	var w: CrewWeapons = _crew().weapons
	var pin: Node = _crew().get_node_or_null(^"PlayerInput")
	assert_true(pin != null and pin.has_method(&"add_recoil"), "the local human's PlayerInput")
	if pin == null:
		return
	var s: CrewWeapons.WeaponState = w._states[w.equipped_slot]
	pin.set(&"_recoil_acc", Vector2.ZERO)
	w._apply_recoil(s)
	var base: float = (pin.get(&"_recoil_acc") as Vector2).y
	pin.set(&"_recoil_acc", Vector2.ZERO)
	_grant(StringName(RECOIL + ".all"), 0.5)
	w._apply_recoil(s)
	var half: float = (pin.get(&"_recoil_acc") as Vector2).y
	assert_true(base > 0.0, "a kick (%f)" % base)
	assert_near(half, base * 0.5, 0.0001, "x0.5 recoil halves the vertical kick")


func test_swap_speed_mult_shortens_the_draw() -> void:
	var w: CrewWeapons = _crew().weapons
	var other: int = Enums.WeaponSlot.PRIMARY if w.equipped_slot == Enums.WeaponSlot.SECONDARY \
		else Enums.WeaponSlot.SECONDARY
	assert_true(w.has_weapon(other), "two weapons")
	_grant(StringName(SWAP + ".all"), 2.0)
	w.equip(other)
	assert_near(w._equip_left, w.stats(other).equip_time_s / 2.0, 0.0001, "x2 swap speed halves the equip time")


func test_ammo_total_mult_scales_the_reserve() -> void:
	var w: CrewWeapons = _crew().weapons
	var ws: int = Enums.WeaponSlot.PRIMARY
	var total: int = w.stats(ws).total_ammo
	_grant(StringName(AMMO_TOTAL + ".all"), 1.5)
	w.set_loadout(w.loadout)
	assert_eq(w.mag(ws) + w.reserve(ws), int(round(float(total) * 1.5)), "x1.5 total ammo")


func test_bleedout_time_add_extends_the_bleedout() -> void:
	_grant(&"defense.bleedout_time_add", 10.0)
	var h: CrewHealth = _crew().health
	h.go_down()
	assert_near(h.bleedout_left, Tweak.crew().bleedout_time_s + 10.0, 0.05, "+10 s bleedout")


func test_revived_health_mult_scales_the_revive_health() -> void:
	var h: CrewHealth = _crew().health
	h.go_down()
	h.revive(1)
	var base: float = h.health
	h.go_down()
	_grant(&"defense.revived_health_mult", 1.5)
	h.revive(1)
	assert_near(h.health, minf(base * 1.5, h.max_health), 0.5, "x1.5 health after a revive (%f -> %f)" % [base, h.health])


func test_armor_regen_rate_mult_doubles_the_regen() -> void:
	var h: CrewHealth = _crew().health
	var regen: Callable = func() -> float:
		h.armor = 0.0
		h.regen_delay_left = 0.0
		h.server_tick(0.1)
		return h.armor
	var base: float = regen.call()
	_grant(&"defense.armor_regen_rate_mult", 2.0)
	var fast: float = regen.call()
	assert_true(base > 0.0, "armor regenerates (%f)" % base)
	assert_near(fast, minf(base * 2.0, h.max_armor), 0.0001, "x2 armor regen rate")


func test_deploy_speed_mult_scales_the_deploy_time() -> void:
	var def: DeployableDef = DeployableSystem.def_for(&"deployable.ammo_bag")
	assert_true(def != null, "ammo bag def")
	var base: float = DeployableSystem.deploy_time_for(0, def)
	_grant(&"deploy.deploy_speed_mult", 0.5)
	assert_near(DeployableSystem.deploy_time_for(0, def), base * 0.5, 0.0001, "x0.5 deploy time")
	var ds: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	ds.give(0, &"deployable.ammo_bag")
	var i: CrewIntent = CrewIntent.new()
	i.deploy = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(base * 0.5 + 0.25)
	_rt.clear_bot_intent(0)
	assert_eq(ds.placed(&"ammo_bag").size(), 1, "placed within the shortened time")


func test_second_deployable_carries_both() -> void:
	var c: CrewController = _crew()
	var ds: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	c.loadout.deployable = &"deployable.ammo_bag"
	c.loadout.deployable_secondary = &"deployable.doctor_bag"
	ds._on_crew_spawned(0, c)
	assert_eq(ds.count_of_kind(0, &"doctor_bag"), 0, "without the skill only the first")
	_grant(&"deploy.second_deployable", true)
	ds._on_crew_spawned(0, c)
	assert_true(ds.count_of_kind(0, &"ammo_bag") > 0 and ds.count_of_kind(0, &"doctor_bag") > 0, "both carried")


func test_trip_mine_radius_mult_widens_the_blast() -> void:
	var radii: Array[float] = []
	var on_fx: Callable = func(_p: Vector3, r: float, _k: StringName) -> void: radii.append(r)
	EventBus.explosion_fx.connect(on_fx)
	_grant(&"deploy.trip_mine_radius_mult", 1.5)
	var ds: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	ds.give(0, &"deployable.trip_mine")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	var mine: Node = ds.place(_crew(), &"deployable.trip_mine")
	assert_true(mine != null, "a trip mine placed")
	if mine != null:
		mine.call(&"trip_detonate")
	await wait_physics_frames(1)
	EventBus.explosion_fx.disconnect(on_fx)
	assert_true(not radii.is_empty(), "it blew")
	if not radii.is_empty():
		assert_near(radii[0], DeployableTweak.data().trip_mine_radius_m * 1.5, 0.001, "x1.5 blast radius")


func test_convert_damage_mult_scales_the_allys_shots() -> void:
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var npc: NpcBase = dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -20)), null)
	var ally: ConvertedAllyBrain = ConvertedAllyBrain.new()
	ally.name = ConvertedAllyBrain.NODE_NAME
	ally.owner_slot = 0
	ally.process_mode = Node.PROCESS_MODE_DISABLED
	npc.add_child(ally)
	var base: float = ally._shot_damage()
	_grant(&"ability.convert_damage_mult", 1.5)
	assert_true(base > 0.0, "the ally hits (%f)" % base)
	assert_near(ally._shot_damage(), base * 1.5, 0.0001, "x1.5 converted ally damage")
