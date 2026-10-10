## A3-06 L3.4 armor piercing: NPC body armor vs AP rounds, the AP roll (WeaponStats.armor_pierce +
## weapon.armor_pierce_add), Bulwark shields (blocked / shield-pierce x0.25 / flanks), thin walls
## (layer bullet_penetrable: blocked unless wall_pierce, then x wall_pierce_damage_mult).
extends TestCase

var _rt: HeistRuntime = null
var _conns: Array[Callable] = []


func before_each() -> void:
	_rt = await ACombatSpecials.launch(self)


func after_each() -> void:
	for cb: Callable in _conns:
		if EventBus.damage_applied.is_connected(cb):
			EventBus.damage_applied.disconnect(cb)
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(2)


func _armored_cop(mult: float) -> NpcBase:
	var npc: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", Vector3(0, 0.05, -10))
	var d: EnemyDef = npc.enemy_def.duplicate() as EnemyDef
	d.params = d.params.duplicate()
	d.params["body_armor_mult"] = mult
	npc.enemy_def = d
	npc.max_health = 1000.0
	npc.health = 1000.0
	_freeze(npc)
	return npc


func _damage_events(victim: NpcBase) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var id: int = victim.net_id
	var cb: Callable = func(v: int, _a: int, info: Dictionary) -> void:
		if v == id:
			out.append(info)
	EventBus.damage_applied.connect(cb)
	_conns.append(cb)
	return out


## Freeze an NPC's AI so it keeps its spawn pose (deterministic geometry).
func _freeze(npc: NpcBase) -> void:
	for nm: String in ["Brain", "Motor", "Gunner"]:
		var n: Node = npc.get_node_or_null(nm)
		if n != null:
			n.set_physics_process(false)


func test_l3_4_body_armor_reduces_non_ap_only() -> void:
	var npc: NpcBase = _armored_cop(0.5)
	await wait_physics_frames(1)
	assert_near(float(ACombatSpecials.hit(npc, 40.0)["amount"]), 20.0, 0.01, "non-AP body hit halved by armor")
	assert_near(float(ACombatSpecials.hit(npc, 40.0, Enums.HitZone.BODY, Vector3.INF,
		Enums.DamageType.BULLET, true)["amount"]), 40.0, 0.01, "AP round ignores armor")
	assert_near(float(ACombatSpecials.hit(npc, 40.0, Enums.HitZone.BODY, Vector3.INF,
		Enums.DamageType.FIRE)["amount"]), 40.0, 0.01, "fire ignores armor")
	var head: Dictionary = ACombatSpecials.hit(npc, 10.0, Enums.HitZone.HEAD)
	assert_near(float(head["amount"]), 10.0 * npc.enemy_def.headshot_mult[0], 0.01, "head not armored")


func test_l3_4_ap_roll_and_profile() -> void:
	assert_true(CombatSystem.roll_armor_pierce(1.0), "chance 1 always pierces")
	assert_false(CombatSystem.roll_armor_pierce(0.0), "chance 0 never pierces")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var ws: int = c.weapons.equipped_slot
	var prof: Dictionary = CombatSystem.pierce_profile(c, ws)
	assert_near(float(prof["armor_pierce"]), 0.0, 0.0001, "kestrel: no AP")
	assert_false(bool(prof["shield_pierce"]), "kestrel: no shield pierce")
	assert_near(float(prof["suppression"]), 0.0, 0.0001, "suppressed kestrel: 0 threat (L3.5)")
	Modifiers.set_source(0, &"test", {&"weapon.armor_pierce_add.pistol": 1.0, &"weapon.shield_pierce.pistol": true})
	prof = CombatSystem.pierce_profile(c, ws)
	assert_near(float(prof["armor_pierce"]), 1.0, 0.0001, "weapon.armor_pierce_add")
	assert_true(bool(prof["shield_pierce"]), "weapon.shield_pierce flag")
	var w: CrewWeapons = ACombatSpecials.arm(_rt, 0, &"weapon.heron_308")
	prof = CombatSystem.pierce_profile(c, w.equipped_slot)
	assert_true(float(prof["armor_pierce"]) >= 1.0 and bool(prof["wall_pierce"]), "Heron: AP + wall pierce from WeaponStats")


func test_l3_4_ap_shot_pierces_body_armor_via_claim() -> void:
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var npc: NpcBase = _armored_cop(0.0)
	await wait_physics_frames(2)
	var ev: Array[Dictionary] = _damage_events(npc)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(npc))
	assert_true(ev.size() == 1 and float(ev[0]["amount"]) == 0.0, "armor x0 stops a non-AP round (%s)" % [ev])
	Modifiers.set_source(0, &"test", {&"weapon.armor_pierce_add.pistol": 1.0})
	await wait_seconds(0.3)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(npc))
	assert_eq(ev.size(), 2, "second hit")
	if ev.size() == 2:
		assert_true(bool(ev[1]["pierced_armor"]), "pierced_armor set by the AP roll")
		assert_true(float(ev[1]["amount"]) > 0.0, "AP round deals damage")
	assert_eq(c.weapons.shots_fired, 2)


func test_l3_4_shield_blocks_and_shield_pierce_passes_quarter() -> void:
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -5), Vector3(0, 0, 1))
	_freeze(bw)
	await wait_physics_frames(3)
	var shield: BulwarkShield = (bw.get_node("Brain") as BulwarkBrain).shield
	assert_true(shield != null, "shield attached")
	var ev: Array[Dictionary] = _damage_events(bw)
	var before: float = bw.health
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(bw))
	assert_eq(shield.blocked_hits, 1, "the shield took the round")
	assert_eq(ev.size(), 0, "nothing damaged")
	assert_near(bw.health, before, 0.001, "Bulwark unhurt from the front")
	Modifiers.set_source(0, &"test", {&"weapon.shield_pierce.pistol": true})
	await wait_seconds(0.3)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(bw))
	assert_eq(shield.pierced_hits, 1, "shield-pierce round passes")
	assert_eq(ev.size(), 1, "Bulwark hit through the shield")
	if ev.size() == 1:
		var full: float = c.weapons.damage_at(c.weapons.equipped_slot, 5.0)
		assert_near(float(ev[0]["amount"]), full * 0.25, full * 0.05, "x0.25 through the shield")
		assert_true(bool(ev[0].get("shield_pierced", false)), "shield_pierced flag")


func test_l3_4_shield_weak_to_flanks() -> void:
	await ACombatSpecials.place_crew(_rt, 0, Vector3(5, 0.05, -5))
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(0, 0.05, -5), Vector3(0, 0, 1))
	_freeze(bw)
	await wait_physics_frames(3)
	var ev: Array[Dictionary] = _damage_events(bw)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(bw))
	assert_eq(ev.size(), 1, "side shot reaches the Bulwark")
	if ev.size() == 1:
		assert_true(float(ev[0]["amount"]) > 20.0, "full damage from the flank (%s)" % ev[0]["amount"])


func test_l3_4_thin_wall_blocks_unless_wall_pierce() -> void:
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var npc: NpcBase = _armored_cop(1.0)
	var wall: StaticBody3D = ATestMaps.add_wall(_rt.map, Vector3(0, 1.0, -5), Vector3(4, 3, 0.1))
	wall.collision_layer = CombatTweak.data().penetrable_mask
	await wait_physics_frames(3)
	var ev: Array[Dictionary] = _damage_events(npc)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(npc))
	assert_eq(ev.size(), 0, "kestrel stopped by a thin wall")
	var w: CrewWeapons = ACombatSpecials.arm(_rt, 0, &"weapon.heron_308")
	await wait_seconds(1.3)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(npc))
	assert_eq(ev.size(), 1, "Heron (wall_pierce) shoots through")
	if ev.size() == 1:
		var full: float = w.damage_at(w.equipped_slot, 10.0)
		assert_near(float(ev[0]["amount"]), full * CombatTweak.data().wall_pierce_damage_mult, full * 0.05, "x wall factor")
		assert_true(bool(ev[0].get("wall_pierced", false)), "wall_pierced flag")
