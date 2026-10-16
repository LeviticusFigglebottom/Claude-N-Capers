## D-118 shotgun AMMO runtime (visual_slots.md v1.3): ShotgunAmmo profile + clamps, buckshot unchanged,
## slug (1 pellet, armor/shield/wall pierce), HE (pellet hits explode via Explosion.apply, no penetration),
## flechette (more pellets + bleed DoT), dragon's breath (fire DoT, civilian panic, range_mult), the server
## pellet cap on claims, and ammo_pickup_mult on ammo boxes. Content has no AMMO mods yet: the tests clone
## weapon.brute_12 with the params a mod would merge in (SpecialWeapons.params_of).
extends TestCase

const BASE_ID: StringName = &"weapon.brute_12"
const WS: int = Enums.WeaponSlot.PRIMARY

var _rt: HeistRuntime = null
var _events: Array[Dictionary] = []
var _cb: Callable = Callable()
var _seq: int = 50000


func before_each() -> void:
	_rt = await ACombatSpecials.launch(self)
	_events = []
	_cb = func(v: int, a: int, info: Dictionary) -> void: _events.append({"victim": v, "attacker": a, "info": info})
	EventBus.damage_applied.connect(_cb)


func after_each() -> void:
	if EventBus.damage_applied.is_connected(_cb):
		EventBus.damage_applied.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	ContentDB.clear_cache()
	await wait_frames(2)


## A clone of brute_12 as `id` with merged ammo `params` (quiet: suppressed, no noise, so civilians only
## panic through the ammo).
func _shotgun(id: StringName, params: Dictionary, quiet: bool = false) -> WeaponDef:
	var src: WeaponDef = ContentDB.weapon(BASE_ID)
	var d: WeaponDef = src.duplicate() as WeaponDef
	d.id = id
	d.params = src.params.duplicate(true)
	d.params.merge(params, true)
	d.mod_slots = {}
	if quiet:
		var st: WeaponStats = src.base.duplicate() as WeaponStats
		st.suppressed = true
		st.noise_radius_m = 0.0
		d.base = st
	ContentDB.inject(ContentDB.WEAPONS, id, d)
	return d


func _arm(id: StringName) -> CrewWeapons:
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var w: CrewWeapons = ACombatSpecials.arm(_rt, 0, id)
	await wait_physics_frames(int(ceil(w.stats(WS).equip_time_s * 60.0)) + 4)
	return w


func _npc(pos: Vector3, facing: Vector3 = Vector3.BACK) -> NpcBase:
	var n: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", pos, facing)
	_freeze(n)
	n.max_health = 100000.0
	n.health = 100000.0
	return n


func _freeze(n: NpcBase) -> void:
	for nm: String in ["Brain", "Motor", "Gunner"]:
		var c: Node = n.get_node_or_null(nm)
		if c != null:
			c.set_physics_process(false)


func _events_for(n: NpcBase, type: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events:
		var info: Dictionary = e["info"]
		if int(e["victim"]) == n.net_id and (type < 0 or int(info["type"]) == type):
			out.append(info)
	return out


## A server-local claim of crew 0 with `n` BODY pellet hits on `npc`.
func _claim(id: StringName, npc: NpcBase, n: int) -> Dictionary:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var eye: Vector3 = c.eye_position()
	var pt: Vector3 = CombatSystem.target_center(npc)
	var hits: Array[Dictionary] = []
	for i: int in range(n):
		hits.append({"target_id": npc.net_id, "zone": Enums.HitZone.BODY, "distance": eye.distance_to(pt), "position": pt})
	_seq += 1
	return {"seq": _seq, "weapon_slot": WS, "weapon_id": id, "origin": eye, "direction": (pt - eye).normalized(),
		"hits": hits}


func _apply(id: StringName, npc: NpcBase, n: int) -> Dictionary:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var res: Dictionary = CombatSystem.validate_and_apply(_claim(id, npc, n), c)
	assert_true(bool(res["accepted"]), "claim accepted: %s" % res["reason"])
	return res


func test_d118_profile_defaults_overrides_and_clamps() -> void:
	var buck: Dictionary = ShotgunAmmo.profile({})
	assert_eq(ShotgunAmmo.type_of({}), ShotgunAmmo.BUCKSHOT, "absent = buckshot")
	assert_eq(ShotgunAmmo.type_of({"ammo_type": &"bogus"}), ShotgunAmmo.BUCKSHOT, "unknown type = buckshot")
	assert_eq(ShotgunAmmo.pellets(10, buck), 10, "buckshot keeps WeaponStats.pellets")
	assert_near(float(buck["armor_pierce"]), 0.0, 0.0001)
	assert_false(bool(buck["has_penetration"]), "buckshot keeps WeaponStats.wall_pierce")
	assert_true(ShotgunAmmo.wall_pierce(true, buck) and not ShotgunAmmo.wall_pierce(false, buck))
	var slug: Dictionary = ShotgunAmmo.profile({"ammo_type": &"slug"})
	assert_eq(ShotgunAmmo.pellets(10, slug), 1, "slug: one pellet")
	assert_true(float(slug["armor_pierce"]) >= 1.0 and bool(slug["shield_pierce"]), "slug: armor + shield pierce")
	assert_true(ShotgunAmmo.wall_pierce(false, slug), "slug: penetration")
	var he: Dictionary = ShotgunAmmo.profile({"ammo_type": &"he", "explosion_radius_m": 2.0})
	assert_eq(ShotgunAmmo.pellets(10, he), 5, "HE: fewer pellets (tweak pellets_mult)")
	assert_near(float(he["explosion_radius_m"]), 2.0, 0.0001, "B's param beats the tweak default")
	assert_false(ShotgunAmmo.wall_pierce(true, he), "HE: no penetration")
	var fl: Dictionary = ShotgunAmmo.profile({"ammo_type": &"flechette"})
	assert_true(ShotgunAmmo.pellets(10, fl) > 10, "flechette: more pellets")
	assert_true(float(fl["dot_dps"]) > 0.0 and not bool(fl["ignite"]), "flechette: bleed DoT")
	var db: Dictionary = ShotgunAmmo.profile({"ammo_type": &"dragons_breath", "range_mult": 0.5})
	assert_true(bool(db["ignite"]) and bool(db["panic_civilians"]), "dragon's breath: fire + panic")
	assert_near(float(db["range_mult"]), 0.5, 0.0001)
	var tw: CombatTweak = CombatTweak.data()
	var wild: Dictionary = ShotgunAmmo.profile({"ammo_type": &"he", "pellets": 999, "armor_pierce": 5.0,
		"explosion_radius_m": 99.0, "range_mult": 0.0, "ammo_pickup_mult": 99.0, "dot_s": 999.0})
	assert_eq(ShotgunAmmo.pellets(10, wild), tw.shotgun_ammo_max_pellets, "pellets clamped")
	assert_near(float(wild["armor_pierce"]), 1.0, 0.0001, "armor_pierce clamped")
	assert_near(float(wild["explosion_radius_m"]), tw.shotgun_ammo_max_explosion_radius_m, 0.0001, "radius clamped")
	assert_near(float(wild["range_mult"]), tw.shotgun_ammo_range_mult_min, 0.0001, "range_mult clamped")
	assert_near(float(wild["ammo_pickup_mult"]), tw.shotgun_ammo_max_pickup_mult, 0.0001, "pickup mult clamped")
	assert_near(float(wild["dot_s"]), tw.shotgun_ammo_max_dot_s, 0.0001, "dot_s clamped")


func test_d118_buckshot_unchanged() -> void:
	var w: CrewWeapons = await _arm(BASE_ID)
	var st: WeaponStats = w.stats(WS)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(st.pellets > 1, "brute_12 is multi-pellet")
	assert_eq(w.pellet_count(WS), st.pellets, "buckshot: WeaponStats.pellets")
	assert_eq(w.wall_pierce(WS), st.wall_pierce, "buckshot: WeaponStats.wall_pierce")
	assert_near(w.ammo_pickup_mult(WS), 1.0, 0.0001)
	var prof: Dictionary = CombatSystem.pierce_profile(c, WS)
	assert_near(float(prof["armor_pierce"]), st.armor_pierce, 0.0001, "buckshot: stats armor pierce")
	assert_eq(bool(prof["shield_pierce"]), st.shield_pierce)
	assert_near(w.damage_at(WS, 20.0), st.damage * CombatSystem.falloff_mult(st, 20.0), 0.001, "falloff unchanged")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -4))
	await wait_physics_frames(2)
	_apply(BASE_ID, npc, 3)
	assert_eq(_events_for(npc, Enums.DamageType.BULLET).size(), 3, "three pellet hits, three bullet hits")
	await wait_physics_frames(2)
	assert_true(npc.get_node_or_null(ShotgunAmmo.BLEED_NODE) == null, "no DoT")
	assert_true(npc.get_node_or_null(BurnStatus.NODE_NAME) == null, "no burn")


func test_d118_slug_single_pellet_pierces() -> void:
	_shotgun(&"weapon.test_slug", {"ammo_type": &"slug"})
	var w: CrewWeapons = await _arm(&"weapon.test_slug")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_eq(w.pellet_count(WS), 1, "slug: one pellet")
	var prof: Dictionary = CombatSystem.pierce_profile(c, WS)
	assert_near(float(prof["armor_pierce"]), 1.0, 0.0001, "slug: armor pierce")
	assert_true(bool(prof["shield_pierce"]), "slug: shield pierce")
	assert_true(bool(prof["wall_pierce"]), "slug: penetration")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -3))
	await wait_physics_frames(2)
	# The live client path fires one pellet.
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(npc))
	assert_eq(_events_for(npc).size(), 1, "one slug, one hit")
	_events.clear()
	await wait_seconds(0.6)
	_apply(&"weapon.test_slug", npc, 4)  # a forged claim: 4 hits for a 1-pellet shot
	var ev: Array[Dictionary] = _events_for(npc)
	assert_eq(ev.size(), 1, "server caps hits at the slug's single pellet")
	if ev.size() == 1:
		assert_true(bool(ev[0]["pierced_armor"]), "slug pierces armor")


func test_d118_he_pellet_hits_explode() -> void:
	_shotgun(&"weapon.test_he", {"ammo_type": &"he", "explosion_radius_m": 1.5, "explosion_damage_mult": 2.0})
	var w: CrewWeapons = await _arm(&"weapon.test_he")
	var base_pellets: int = ContentDB.weapon(BASE_ID).base.pellets
	assert_true(w.pellet_count(WS) < base_pellets, "HE: fewer pellets than buckshot")
	assert_false(w.wall_pierce(WS), "HE: no penetration")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -5))
	var near: NpcBase = _npc(Vector3(0.8, 0.05, -5))
	var far: NpcBase = _npc(Vector3(6, 0.05, -5))
	await wait_physics_frames(2)
	var expect: float = w.damage_at(WS, 5.0) * 2.0
	var res: Dictionary = _apply(&"weapon.test_he", npc, 1)
	var ev: Array[Dictionary] = _events_for(npc)
	assert_eq(ev.size(), 1, "one blast on the hit target")
	if ev.size() == 1:
		assert_eq(int(ev[0]["type"]), Enums.DamageType.EXPLOSION, "HE pellet damage is an explosion")
		assert_true(float(ev[0]["amount"]) > 0.0 and float(ev[0]["amount"]) <= expect + 0.01,
			"x explosion_damage_mult with falloff (%s <= %s)" % [ev[0]["amount"], expect])
	assert_eq(_events_for(near, Enums.DamageType.EXPLOSION).size(), 1, "splash inside the radius")
	assert_eq(_events_for(far).size(), 0, "nothing outside the radius")
	assert_eq((res["results"] as Array).size(), 1, "one result per pellet hit")


func test_d118_flechette_more_pellets_and_bleed() -> void:
	_shotgun(&"weapon.test_flechette", {"ammo_type": &"flechette", "dot_dps": 20.0, "dot_s": 2.0})
	var w: CrewWeapons = await _arm(&"weapon.test_flechette")
	assert_true(w.pellet_count(WS) > ContentDB.weapon(BASE_ID).base.pellets, "flechette: more pellets")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -4))
	await wait_physics_frames(2)
	_apply(&"weapon.test_flechette", npc, 2)
	var bleed: BurnStatus = npc.get_node_or_null(ShotgunAmmo.BLEED_NODE) as BurnStatus
	assert_true(bleed != null, "the target bleeds")
	assert_true(npc.get_node_or_null(BurnStatus.NODE_NAME) == null, "flechette does not ignite")
	if bleed != null:
		assert_eq(bleed.damage_type, Enums.DamageType.POISON, "bleed ticks are POISON (no fire, no blood)")
		assert_near(bleed.dps, 20.0, 0.0001)
	await wait_physics_frames(70)
	var ticks: Array[Dictionary] = _events_for(npc, Enums.DamageType.POISON)
	assert_true(ticks.size() >= 2, "bleed DoT ticks (%d)" % ticks.size())
	if not ticks.is_empty():
		assert_near(float(ticks[0]["amount"]), 20.0 * BurnStatus.TICK_S, 0.01, "dot_dps x tick")


func test_d118_dragons_breath_burns_and_panics_civilians() -> void:
	_shotgun(&"weapon.test_db", {"ammo_type": &"dragons_breath", "dot_dps": 30.0, "dot_s": 2.0}, true)
	var w: CrewWeapons = await _arm(&"weapon.test_db")
	var npc: NpcBase = _npc(Vector3(0, 0.05, -4))
	var in_cone: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0.5, 0.05, -8)), {})
	var behind: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 8)), {})
	await wait_physics_frames(2)
	assert_eq(in_cone.alert_state, Enums.AlertState.CALM, "calm before the shot")
	_apply(&"weapon.test_db", npc, 2)
	var burn: BurnStatus = npc.get_node_or_null(BurnStatus.NODE_NAME) as BurnStatus
	assert_true(burn != null, "dragon's breath sets the target on fire")
	if burn != null:
		assert_eq(burn.damage_type, Enums.DamageType.FIRE)
	assert_eq(in_cone.alert_state, Enums.AlertState.PANICKED, "civilian in the cone panics")
	assert_eq(behind.alert_state, Enums.AlertState.CALM, "civilian behind the shooter does not")
	await wait_physics_frames(40)
	assert_true(_events_for(npc, Enums.DamageType.FIRE).size() >= 1, "fire DoT ticks")
	assert_near(w.ammo_pickup_mult(WS), 1.0, 0.0001)


func test_d118_range_mult_scales_falloff() -> void:
	_shotgun(&"weapon.test_db_short", {"ammo_type": &"dragons_breath", "range_mult": 0.5})
	var w: CrewWeapons = await _arm(&"weapon.test_db_short")
	var st: WeaponStats = w.stats(WS)
	var d: float = maxf(st.falloff_start_m, 1.0)
	assert_near(w.damage_at(WS, d), st.damage * CombatSystem.falloff_mult(st, d / 0.5), 0.001,
		"range_mult 0.5: falloff at half the distance")
	assert_true(w.damage_at(WS, d) <= st.damage * CombatSystem.falloff_mult(st, d) + 0.001, "never more than buckshot")


func test_d118_ammo_pickup_mult() -> void:
	_shotgun(&"weapon.test_pickup", {"ammo_type": &"slug", "ammo_pickup_mult": 2.0})
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var w: CrewWeapons = await _arm(BASE_ID)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var plain: int = AmmoPickupSystem.rounds_for(c, WS, rng)
	w = ACombatSpecials.arm(_rt, 0, &"weapon.test_pickup")
	assert_near(w.ammo_pickup_mult(WS), 2.0, 0.0001)
	rng.seed = 7
	var doubled: int = AmmoPickupSystem.rounds_for(c, WS, rng)
	assert_true(plain >= 1, "buckshot box rounds")
	assert_true(absi(doubled - plain * 2) <= 1, "x2 rounds per box (%d vs %d)" % [doubled, plain])


## D-118 addendum (LEAD ruling): per-shot damage is preserved: pellets x per-pellet damage at a range equals
## buckshot's, for slug (1 ray), HE (B's absolute 1) and flechette (B's pellets_mult 1.5).
func test_d118_per_shot_damage_preserved() -> void:
	_shotgun(&"weapon.test_slug_dmg", {"ammo_type": &"slug", "pellets": 1})
	_shotgun(&"weapon.test_he_dmg", {"ammo_type": &"he", "pellets": 1, "explosion_radius_m": 2.0})
	_shotgun(&"weapon.test_fl_dmg", {"ammo_type": &"flechette", "pellets_mult": 1.5})
	var w: CrewWeapons = await _arm(BASE_ID)
	var buck: Array[float] = []
	for r: float in [3.0, 20.0]:
		buck.append(w.damage_at(WS, r) * w.pellet_count(WS))
	var stock: int = w.pellet_count(WS)
	for id: StringName in [&"weapon.test_slug_dmg", &"weapon.test_he_dmg", &"weapon.test_fl_dmg"]:
		w = ACombatSpecials.arm(_rt, 0, id)
		await wait_physics_frames(2)
		for i: int in 2:
			var r: float = [3.0, 20.0][i]
			assert_near(w.damage_at(WS, r) * w.pellet_count(WS), buck[i], 0.01,
				"%s: per-shot total at %.0f m == buckshot (%d pellets vs %d)" % [id, r, w.pellet_count(WS), stock])
	assert_eq(w.pellet_count(WS), int(round(stock * 1.5)), "flechette 1.5x pellets")
