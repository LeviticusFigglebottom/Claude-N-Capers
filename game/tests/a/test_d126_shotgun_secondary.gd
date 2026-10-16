## D-126: the secondary slot holds pistols, SMGs and shotguns. A side: a shotgun secondary works everywhere the
## secondary is special: the downed equip (PD2 bleed-out: a downed player fires the secondary, pellets and all), ammo
## pickups (shotgun ammo per D-118 into the secondary pool), and the custody release refill.
extends TestCase

const SHOTGUN: StringName = &"weapon.plowman_12"
const WS: int = Enums.WeaponSlot.SECONDARY

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.corsair_ar"
	l.secondary = SHOTGUN
	l = CrewWeapons.build_loadout(l)
	_rt = await HeistLauncher.launch(&"unit_map", 1260, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true,
			"loadouts": {0: l}})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	await wait_physics_frames(2)
	return c


func _pull() -> void:
	var intent: CrewIntent = CrewIntent.new()
	intent.look_pitch = deg_to_rad(60.0)
	intent.fire = true
	_rt.set_bot_intent(0, intent)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(1)


func test_shotgun_secondary_is_armed() -> void:
	var c: CrewController = await _launch()
	assert_eq(c.weapons.weapon_id(WS), SHOTGUN, "the loadout's secondary is the shotgun")
	var st: WeaponStats = c.weapons.stats(WS)
	assert_true(st != null and st.pellets > 1, "a shotgun: several pellets per shot")
	assert_true(c.weapons.mag(WS) > 0 and c.weapons.reserve(WS) > 0, "full mag and reserve")


func test_downed_fires_the_shotgun_secondary() -> void:
	var c: CrewController = await _launch()
	assert_eq(c.weapons.equipped_slot, Enums.WeaponSlot.PRIMARY, "starts on the primary")
	c.health.armor = 0.0
	c.take_hit(CombatSystem.make_damage_info(10000.0, Enums.DamageType.BULLET, Enums.HitZone.BODY,
		&"weapon.npc_pistol", c.global_position, Vector3.FORWARD, false), 0)  # a real down (L2.5)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "downed")
	await wait_seconds(maxf(c.weapons.stats(WS).equip_time_s, 0.5) + 0.3)
	assert_eq(c.weapons.equipped_slot, WS, "downed: the secondary (shotgun) comes out")
	var shots: Array[Dictionary] = []
	var cb: Callable = func(claim: Dictionary) -> void: shots.append(claim)
	c.weapons.fired.connect(cb)
	var mag: int = c.weapons.mag(WS)
	await _pull()
	c.weapons.fired.disconnect(cb)
	assert_eq(shots.size(), 1, "a downed player fires the shotgun")
	assert_eq(c.weapons.mag(WS), mag - 1, "one shell spent")
	if shots.size() == 1:
		assert_eq(int(shots[0]["weapon_slot"]), WS, "from the secondary slot")


func test_ammo_pickup_refills_the_shotgun_secondary() -> void:
	var c: CrewController = await _launch()
	c.weapons.set_ammo(Enums.WeaponSlot.PRIMARY, c.weapons.mag(Enums.WeaponSlot.PRIMARY),
		DeployablePrefab.max_ammo(c, Enums.WeaponSlot.PRIMARY))
	c.weapons.set_ammo(WS, c.weapons.mag(WS), 0)
	var ammo: AmmoPickupSystem = _rt.service(AmmoPickupSystem.SERVICE) as AmmoPickupSystem
	for i: int in 3:
		ammo.drop(c.global_position + Vector3(0.2, 0.05, 0.0))
		await wait_physics_frames(2)
	var got: int = c.weapons.reserve(WS)
	var st: WeaponStats = c.weapons.stats(WS)
	assert_true(got >= 1, "boxes refill the shotgun secondary (%d)" % got)
	assert_true(got <= ceili(st.ammo_pickup_max * 3.0 * c.weapons.ammo_pickup_mult(WS)) + 1,
		"within 3 boxes of its own pickup data (%d)" % got)


func test_custody_release_refills_the_shotgun_secondary() -> void:
	var c: CrewController = await _launch()
	var cs: CustodySystem = _rt.service(CustodySystem.SERVICE) as CustodySystem
	c.weapons.set_ammo(WS, 0, 0)
	c.set_crew_state(Enums.CrewState.CUSTODY)
	await wait_physics_frames(2)
	cs.release(0)
	await wait_physics_frames(2)
	var full: int = DeployablePrefab.max_ammo(c, WS)
	var have: int = c.weapons.mag(WS) + c.weapons.reserve(WS)
	var frac: float = CustodyTweak.data().release_ammo_frac
	assert_eq(c.weapons.weapon_id(WS), SHOTGUN, "still the shotgun after custody")
	assert_true(absi(have - int(round(full * frac))) <= c.weapons.stats(WS).mag_size,
		"released with ~%.0f%% of the shotgun's ammo (%d of %d)" % [frac * 100.0, have, full])
