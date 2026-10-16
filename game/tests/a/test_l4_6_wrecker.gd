## A3-01b L4.6 Wrecker: EnemyDefs (variants share the enemy.wrecker limit), huge HP, stun immunity,
## staged weak points (Faceplate 150 -> Visor 160 -> head; plates break in order, head only vulnerable
## after the visor, each break hides the mesh + cue), real shots hit the plates first, roar + footsteps.
extends TestCase

var _rt: HeistRuntime = null
var _cues: Array[StringName] = []
var _cue_cb: Callable = Callable()


func before_each() -> void:
	_rt = await ACombatSpecials.launch(self)
	_cues = []
	_cue_cb = ACombatSpecials.record_cues(_cues)


func after_each() -> void:
	if EventBus.audio_cue_requested.is_connected(_cue_cb):
		EventBus.audio_cue_requested.disconnect(_cue_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(2)


func _wrecker(pos: Vector3 = Vector3(0, 0.05, -6), frozen: bool = true) -> NpcBase:
	var w: NpcBase = ACombatSpecials.spawn(_rt, "wrecker", pos, Vector3(0, 0, 1))
	if frozen:
		for nm: String in ["Brain", "Motor", "Gunner"]:
			w.get_node(nm).set_physics_process(false)
	return w


func _weak_hit(w: NpcBase, hitbox: String, amount: float) -> Dictionary:
	var hb: Hitbox = w.get_node("Hitboxes/" + hitbox) as Hitbox
	var info: Dictionary = Damage.info(amount, Enums.DamageType.BULLET, hb.get_hit_zone(), &"weapon.test",
		w.head_position(), Vector3(0, 0, -1), 0)
	return CombatSystem.deliver_hit(Damage.find_target(hb), info, 0)


func test_l4_6_defs_and_variants() -> void:
	for id: String in ["wrecker", "wrecker_g", "wrecker_b", "wrecker_s", "wrecker_m"]:
		var d: EnemyDef = ACombatSpecials.def(id)
		assert_true(d != null and d.is_special, "%s loads, special" % id)
		assert_eq(d.id, StringName("enemy." + id))
		assert_eq(PoliceSpecialKit.limit_key(d.id), &"enemy.wrecker", "%s counts toward enemy.wrecker" % id)
		assert_eq(PoliceSpecialKit.special_type_of(d.id), &"wrecker")
		var hp_mult: float = 2.0 if id == "wrecker_m" else 1.0  # minigun: 2x HP (L4.6)
		assert_near(d.health[0], 2000.0 * hp_mult, 0.1, "%s HP on the lowest difficulty" % id)
		assert_near(d.health[5], 10000.0 * hp_mult, 0.1, "%s HP on the top difficulty (D-125)" % id)
		assert_near(float((d.params["plate_health"] as Array)[0]), 150.0, 0.01)
		assert_near(float((d.params["plate_health"] as Array)[1]), 160.0, 0.01)
		assert_near(float(d.params["explosive_mult"]), 1.1, 0.0001)
		assert_eq(String(d.params["scene"]), "res://systems/ai/npc/npc_wrecker.tscn")
	assert_ne(ACombatSpecials.def("wrecker_g").weapon, ACombatSpecials.def("wrecker_s").weapon, "pump vs LMG")


func test_l4_6_stun_immune() -> void:
	var w: NpcBase = _wrecker()
	await wait_physics_frames(2)
	w.stun(5.0)
	assert_false(w.is_stunned(), "Wreckers ignore stuns")


func test_l4_6_plates_break_in_order_head_after_visor() -> void:
	var w: NpcBase = _wrecker()
	await wait_physics_frames(3)
	var armor: WreckerArmor = w.get_node("Weakpoints") as WreckerArmor
	assert_eq(armor.current_plate(), &"Faceplate")
	var hp0: float = w.health
	# Headshots do x1 while the plates stand.
	var r: Dictionary = ACombatSpecials.hit(w, 100.0, Enums.HitZone.HEAD)
	assert_near(float(r["amount"]), 100.0, 0.001, "headshot-immune: x1 while armored")
	assert_true(bool(r.get("head_armored", false)), "head_armored flag")
	# A hit on the Visor hitbox while the faceplate stands still damages the faceplate.
	r = _weak_hit(w, "Visor", 100.0)
	assert_eq(StringName(r["plate"]), &"Faceplate", "stages break in order")
	assert_near(armor.hp_left(), 50.0, 0.001, "faceplate 150 - 100")
	assert_near(w.health, hp0 - 100.0, 0.001, "plate hits do not hurt the Wrecker")
	r = _weak_hit(w, "Faceplate", 60.0)
	assert_true(bool(r["plate_broken"]), "faceplate broken")
	assert_eq(armor.current_plate(), &"Visor")
	assert_false((w.get_node("Hitboxes/Faceplate") as Hitbox).collision_layer != 0, "faceplate hitbox disabled")
	assert_false(_mesh(w, "Faceplate").visible, "Faceplate mesh hidden")
	assert_true(_mesh(w, "Visor").visible, "Visor mesh still up")
	assert_eq(_cues.count(&"cue.wrecker_plate_crack"), 1, "crack cue")
	r = ACombatSpecials.hit(w, 100.0, Enums.HitZone.HEAD)
	assert_near(float(r["amount"]), 100.0, 0.001, "still x1 with the visor up")
	r = _weak_hit(w, "Visor", 160.0)
	assert_true(bool(r["plate_broken"]) and StringName(r["plate"]) == &"Visor", "visor broken (160 HP)")
	assert_false(_mesh(w, "Visor").visible, "Visor mesh hidden")
	var ha: Node3D = w.get_node("Visual").find_child("HeadArmored", true, false) as Node3D
	assert_true(ha == null or not ha.visible, "HeadArmored hidden with the visor")
	assert_eq(_cues.count(&"cue.wrecker_plate_crack"), 2, "second crack cue")
	assert_false(armor.is_head_armored(), "head exposed")
	r = ACombatSpecials.hit(w, 100.0, Enums.HitZone.HEAD)
	assert_near(float(r["amount"]), 100.0 * w.enemy_def.headshot_mult[0], 0.001, "headshot multiplier applies now")


func test_l4_6_real_shots_hit_faceplate_then_visor_then_head() -> void:
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var w: NpcBase = _wrecker()
	await wait_physics_frames(3)
	var armor: WreckerArmor = w.get_node("Weakpoints") as WreckerArmor
	Modifiers.set_source(0, &"test", {&"weapon.damage_mult.all": 10.0})
	var zones: Array[int] = []
	var cb: Callable = func(v: int, _a: int, info: Dictionary) -> void:
		if v == w.net_id:
			zones.append(int(info["zone"]))
	EventBus.damage_applied.connect(cb)
	for i: int in range(3):
		await ACombatSpecials.shoot_at(_rt, 0, w.head_position())
		await wait_seconds(0.2)
	EventBus.damage_applied.disconnect(cb)
	assert_eq(zones, [Enums.HitZone.WEAKPOINT, Enums.HitZone.WEAKPOINT, Enums.HitZone.HEAD] as Array[int],
		"faceplate, visor, then the head")
	assert_eq(armor.stage, 2, "both plates broken")


func test_l4_6_roar_and_footsteps_when_loud() -> void:
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	var spawned: Array[StringName] = []
	var cb: Callable = func(_id: int, t: StringName) -> void: spawned.append(t)
	EventBus.special_spawned.connect(cb)
	_rt.stealth.raise_alarm(&"test", 0)
	var w: NpcBase = _wrecker(c.global_position + Vector3(0, 0, -16), false)
	var b: WreckerBrain = w.get_node("Brain") as WreckerBrain
	var stepped: bool = await wait_until(func() -> bool: return b.steps >= 2, 6.0)
	EventBus.special_spawned.disconnect(cb)
	assert_eq(spawned, [&"wrecker"] as Array[StringName], "special_spawned wrecker")
	assert_true(b.roared and _cues.count(&"cue.wrecker_roar") == 1, "roar intro once")
	assert_true(stepped and _cues.has(&"cue.wrecker_step"), "heavy footsteps while moving")
	var close: bool = await wait_until(func() -> bool:
		return Vector2(w.global_position.x - c.global_position.x, w.global_position.z - c.global_position.z).length() < 6.0, 8.0)
	assert_true(close, "keeps pushing in (no cover)")
	assert_true(b.cover_point == null, "never takes cover")


## Wrecker-M (minigun, Cataclysm only): spin-up before the first shot, then very high RPM; spins down
## after spin_down_s without a target.
func test_l4_6_wrecker_m_minigun_spin_up_and_rpm() -> void:
	var d: EnemyDef = ACombatSpecials.def("wrecker_m")
	assert_true(float(d.params["fire_interval_s"]) <= 0.06, "very high RPM")
	var spin: float = float(d.params["spin_up_s"])
	assert_true(spin > 0.5, "spin-up delay")
	var g: SpawnGroupDef = load("res://systems/ai/data/groups/special_wrecker_m.tres") as SpawnGroupDef
	for i: int in range(Enums.Difficulty.CATACLYSM):
		assert_near(g.weights[i], 0.0, 0.0001, "no Wrecker-M below Cataclysm (difficulty %d)" % i)
	assert_true(g.weights[Enums.Difficulty.CATACLYSM] > 0.0, "Wrecker-M on Cataclysm")
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	var w: NpcBase = ACombatSpecials.spawn(_rt, "wrecker_m", Vector3(0, 0.05, -6), Vector3(0, 0, 1))
	for nm: String in ["Brain", "Motor"]:
		w.get_node(nm).set_physics_process(false)
	await wait_physics_frames(2)
	var gun: NpcGunner = w.get_node("Gunner") as NpcGunner
	var shots: Array[int] = [0]
	var cb: Callable = func(_t: Node, _hit: bool) -> void: shots[0] += 1
	gun.shot.connect(cb)
	var t0: int = Time.get_ticks_msec()
	gun.fire_at(c)
	var first: bool = await wait_until(func() -> bool: return shots[0] > 0, spin + 2.0)
	var waited: float = float(Time.get_ticks_msec() - t0) / 1000.0
	assert_true(first, "fires after spinning up")
	assert_true(waited >= spin - 0.1, "first shot after the spin-up (%.2f s)" % waited)
	assert_true(gun.spun_up, "barrels at speed")
	shots[0] = 0
	await wait_seconds(0.5)
	assert_true(shots[0] >= 6, "minigun rate (%d shots in 0.5 s)" % shots[0])
	gun.hold_fire()
	await wait_seconds(float(d.params["spin_down_s"]) + 0.3)
	assert_false(gun.spun_up, "spins down without a target")
	gun.shot.disconnect(cb)


## damage.md v1.1 plates: x1, no crit, excess lost (never carried to the visor or the head).
func test_d052_plates_x1_no_crit_excess_lost() -> void:
	var w: NpcBase = _wrecker()
	await wait_physics_frames(3)
	var armor: WreckerArmor = w.get_node("Weakpoints") as WreckerArmor
	var hb: Hitbox = w.get_node("Hitboxes/Faceplate") as Hitbox
	var info: Dictionary = Damage.info(100.0, Enums.DamageType.BULLET, hb.get_hit_zone(), &"weapon.test",
		w.head_position(), Vector3(0, 0, -1), 0)
	info["crit"] = true
	info["headshot_bonus"] = 3.0
	var r: Dictionary = CombatSystem.deliver_hit(Damage.find_target(hb), info, 0)
	assert_near(float(r["amount"]), 100.0, 0.001, "x1: no crit, no headshot bonus on a plate")
	assert_false(bool(r["crit"]), "crit cleared on plates")
	assert_false(bool(r["blocked"]), "a plate hit is not blocked")
	var hp0: float = w.health
	r = _weak_hit(w, "Faceplate", 500.0)
	assert_true(bool(r["plate_broken"]), "faceplate broken")
	assert_near(float(r["amount"]), 50.0, 0.001, "only the 50 HP left are dealt")
	assert_eq(armor.current_plate(), &"Visor")
	assert_near(armor.hp_left(), 160.0, 0.001, "excess lost: the visor is untouched")
	assert_near(w.health, hp0, 0.001, "and the Wrecker too")


## damage.md v1.0 addendum (D-027): a crit multiplies by the HEAD zone multiplier on any zone, except an
## armored head.
func test_d052_crit_target_side() -> void:
	var w: NpcBase = _wrecker()
	await wait_physics_frames(3)
	var hm: float = w.enemy_def.headshot_mult[0]
	var target: Vector3 = CombatSystem.target_center(w)
	var info: Dictionary = Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.test",
		target, Vector3(0, 0, -1), 0)
	info["crit"] = true
	assert_near(float(w.take_hit(info, 0)["amount"]), 10.0 * hm, 0.001, "body crit x head mult")
	info["zone"] = Enums.HitZone.HEAD
	var r: Dictionary = w.take_hit(info, 0)
	assert_near(float(r["amount"]), 10.0, 0.001, "armored head: x1, no crit")
	assert_false(bool(r["crit"]), "crit cleared on the armored head")


## characters.md: the Wrecker's `Faceplate` / `Visor` meshes, anywhere under the visual (the character
## puts them under Skeleton3D; the capsule placeholder directly under Visual).
func _mesh(w: NpcBase, nm: String) -> Node3D:
	var n: Node3D = w.get_node("Visual").find_child(nm, true, false) as Node3D
	assert_true(n != null, "%s mesh (characters.md)" % nm)
	return n if n != null else Node3D.new()
