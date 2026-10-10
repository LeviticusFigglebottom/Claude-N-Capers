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
	d.params["armor_body_mult"] = mult
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
	# damage.md v1.1: a blocked hit is reported (amount 0, blocked = true) against the carrier.
	assert_eq(ev.size(), 1, "blocked hit reported")
	if ev.size() == 1:
		assert_near(float(ev[0]["amount"]), 0.0, 0.0001, "blocked: amount 0")
		assert_true(bool(ev[0]["blocked"]), "blocked flag")
		assert_false(bool(ev[0]["shield_pierce"]), "not a shield-pierce round")
	assert_near(bw.health, before, 0.001, "Bulwark unhurt from the front")
	Modifiers.set_source(0, &"test", {&"weapon.shield_pierce.pistol": true})
	await wait_seconds(0.3)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(bw))
	assert_eq(shield.pierced_hits, 1, "shield-pierce round passes")
	assert_eq(ev.size(), 2, "Bulwark hit through the shield")
	assert_near(shield.pass_mult({"type": Enums.DamageType.BULLET, "shield_pierce": true}),
		float(bw.enemy_def.params["shield_pierce_mult"]), 0.0001, "EnemyDef shield_pierce_mult")
	if ev.size() == 2:
		var full: float = c.weapons.damage_at(c.weapons.equipped_slot, 5.0)
		assert_near(float(ev[1]["amount"]), full * 0.25, full * 0.05, "x0.25 through the shield")
		assert_true(bool(ev[1].get("shield_pierced", false)), "shield_pierced flag")
		assert_true(bool(ev[1]["shield_pierce"]), "attacker-side shield_pierce")
		assert_false(bool(ev[1]["blocked"]), "not blocked")


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


## D-052: canonical armour params (NpcHitRules.armor_of) on every EnemyDef, with legacy fallback.
func test_d052_armor_params_complete() -> void:
	var dir: String = "res://systems/ai/data/enemies/"
	var paths: Array[String] = []
	for sub: String in ["", "frd/", "sentinel/", "zero/"]:
		for f: String in DirAccess.get_files_at(dir + sub):
			if f.ends_with(".tres"):
				paths.append(dir + sub + f)
	assert_true(paths.size() >= 20, "enemy defs found (%d)" % paths.size())
	for path: String in paths:
		var d: EnemyDef = load(path) as EnemyDef
		for k: String in NpcHitRules.ARMOR_DEFAULTS:
			assert_true(d.params.has(k), "%s carries %s" % [path, k])
		for k: String in ["faceplate_hp", "visor_hp", "frontal_plate_arc_deg", "frontal_plate_mult", "body_armor_mult"]:
			assert_false(d.params.has(k), "%s: legacy key %s removed" % [path, k])
	var heavy: Dictionary = NpcHitRules.armor_of(load(dir + "tac_heavy.tres") as EnemyDef)
	assert_near(float(heavy["frontal_armor"]), 0.0, 0.0001, "TAC Heavy frontal armour blocks")
	assert_true(float(heavy["frontal_armor_arc_deg"]) > 0.0, "TAC Heavy arc")
	var bw: Dictionary = NpcHitRules.armor_of(load(dir + "bulwark.tres") as EnemyDef)
	assert_true(bool(bw["shield"]), "Bulwark has a shield")
	assert_near(float(bw["shield_pierce_mult"]), 0.25, 0.0001, "x0.25 through it")
	var wr: Dictionary = NpcHitRules.armor_of(load(dir + "wrecker.tres") as EnemyDef)
	assert_eq(wr["plate_health"], [150.0, 160.0] as Array[float], "Wrecker plates")
	var legacy: EnemyDef = EnemyDef.new()
	legacy.params = {"frontal_plate_arc_deg": 90.0, "body_armor_mult": 0.5, "faceplate_hp": 10.0, "visor_hp": 20.0}
	var la: Dictionary = NpcHitRules.armor_of(legacy)
	assert_near(float(la["frontal_armor_arc_deg"]), 90.0, 0.0001, "legacy arc read")
	assert_near(float(la["frontal_armor"]), 0.0, 0.0001, "legacy plate default blocks")
	assert_near(float(la["armor_body_mult"]), 0.5, 0.0001, "legacy body armour read")
	assert_eq(la["plate_health"], [10.0, 20.0] as Array[float], "legacy plate HP read")
	assert_false(bool(la["shield"]), "no shield by default")


## damage.md v1.1: final_info carries pierced_armor / shield_pierce / blocked; AP ignores body armour.
func test_d052_info_v11_keys_and_ap() -> void:
	var npc: NpcBase = _armored_cop(0.5)
	await wait_physics_frames(1)
	var info: Dictionary = Damage.info(40.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.test",
		npc.global_position, Vector3.FORWARD)
	var r: Dictionary = npc.take_hit(info, 0)
	for k: String in CombatSystem.V11_FLAGS:
		assert_true(r.has(k), "final_info has %s" % k)
	assert_false(bool(r["blocked"]), "not blocked")
	assert_near(float(r["amount"]), 20.0, 0.01, "non-AP halved")
	info["pierced_armor"] = true
	assert_near(float(npc.take_hit(info, 0)["amount"]), 40.0, 0.01, "pierced_armor ignores body armour")
