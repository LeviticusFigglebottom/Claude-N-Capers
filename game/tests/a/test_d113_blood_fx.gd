## D-113 (ENV C's gore VFX): blood_hit on bullet / melee flesh hits (strength, headshot, exit point on lethal hits,
## victim kind; crew only when health is hit) and bleed_changed for corpses (start at death, stop when bagged) and
## downed crew (start, stop on revive). EventBus.blood_hit / bleed_changed (events.md v1.3).
extends TestCase

var _rt: HeistRuntime = null
var _hits: Array[Array] = []
var _bleeds: Array[Array] = []


func before_each() -> void:
	_hits = []
	_bleeds = []
	EventBus.blood_hit.connect(_on_hit)
	EventBus.bleed_changed.connect(_on_bleed)


func after_each() -> void:
	EventBus.blood_hit.disconnect(_on_hit)
	EventBus.bleed_changed.disconnect(_on_bleed)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _on_hit(a0: Variant, a1: Variant, a2: Variant, a3: Variant, a4: Variant, a5: Variant, a6: Variant, a7: Variant) -> void:
	_hits.append([a0, a1, a2, a3, a4, a5, a6, a7])


func _on_bleed(a0: Variant, a1: Variant, a2: Variant, a3: Variant) -> void:
	_bleeds.append([a0, a1, a2, a3])


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1131, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false})
	await wait_physics_frames(2)


func test_d113_npc_hits_death_and_bagging() -> void:
	await _launch()
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	g.max_health = 100.0
	g.health = 100.0
	g.set_alert_state(Enums.AlertState.COMBAT)  # S3.6: an unalerted guard dies to any hit
	g.take_hit(Damage.info(25.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.kestrel_p9",
		g.global_position + Vector3(0, 1.2, 0), Vector3(0, 0, -1)))
	assert_eq(_hits.size(), 1, "a non-lethal bullet hit")
	if _hits.size() == 1:
		var h: Array = _hits[0]
		assert_eq(int(h[0]), g.net_id, "victim")
		assert_near(float(h[4]), 0.25, 0.01, "strength = damage / max health")
		assert_false(bool(h[5]), "body hit")
		assert_eq(h[6], Vector3.ZERO, "a pistol body hit does not exit")
		assert_eq(StringName(h[7]), BloodFx.KIND_NPC, "npc")
	g.take_hit(Damage.info(500.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, &"weapon.kestrel_p9",
		g.global_position + Vector3(0, 1.7, 0), Vector3(0, 0, -1)))
	assert_eq(_hits.size(), 2, "the lethal hit")
	if _hits.size() == 2:
		assert_true(bool(_hits[1][5]), "headshot")
		assert_true((_hits[1][6] as Vector3) != Vector3.ZERO, "a lethal hit has an exit point")
	assert_eq(_bleeds.size(), 1, "the corpse starts bleeding")
	if _bleeds.size() == 1:
		assert_true(bool(_bleeds[0][1]) and float(_bleeds[0][3]) >= BloodFx.RATE_DEATH_HEAVY, "fast after a headshot")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.body_bags = 1
	(_rt.service(G.SVC_LOOT) as LootManager).bag_body(c, g)
	assert_eq(_bleeds.size(), 2, "bagging")
	if _bleeds.size() == 2:
		assert_false(bool(_bleeds[1][1]), "bagged: the bleed stops")
	g.take_hit(Damage.info(10.0, Enums.DamageType.EXPLOSION, Enums.HitZone.BODY, &"", Vector3.ZERO, Vector3.ZERO))
	assert_eq(_hits.size(), 2, "no blood_hit for a dead body / explosions")


func test_d113_crew_armour_hit_no_blood_then_down_and_revive() -> void:
	await _launch()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var h: CrewHealth = c.health
	h.armor = 50.0
	h.take_hit(Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", c.global_position, Vector3(0, 0, 1)))
	assert_eq(_hits.size(), 0, "armour soaked it: no blood")
	h.armor = 0.0
	h.take_hit(Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", c.global_position, Vector3(0, 0, 1)))
	assert_eq(_hits.size(), 1, "health hit: blood")
	if _hits.size() == 1:
		assert_eq(StringName(_hits[0][7]), BloodFx.KIND_CREW, "crew")
	h.take_hit(Damage.info(9999.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", c.global_position, Vector3(0, 0, 1)))
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "downed")
	assert_true(_bleeds.size() >= 1 and bool(_bleeds[-1][1]), "downed: bleeding")
	h.revive(1)
	assert_true(_bleeds.size() >= 2 and not bool(_bleeds[-1][1]), "revived: the bleed stops")
