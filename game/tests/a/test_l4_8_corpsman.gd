## A3-01b L4.8 Corpsman: revives ONE ally within 7 m (through walls) instead of letting it die, 3 s
## cooldown, never heals medics, out of range does nothing, heal lock (neither moves nor shoots), heals a
## hurt ally when loud, cue.corpsman_heal + green outline state, special_spawned corpsman.
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


func _medic(pos: Vector3) -> NpcBase:
	return ACombatSpecials.spawn(_rt, "corpsman", pos)


func _cop(pos: Vector3) -> NpcBase:
	var n: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", pos)
	for nm: String in ["Brain", "Motor", "Gunner"]:
		n.get_node(nm).set_physics_process(false)
	return n


func _lethal(n: NpcBase) -> Dictionary:
	return ACombatSpecials.hit(n, n.health + 50.0)


func test_l4_8_revive_one_ally_then_cooldown() -> void:
	var spawned: Array[StringName] = []
	var cb: Callable = func(_id: int, t: StringName) -> void: spawned.append(t)
	EventBus.special_spawned.connect(cb)
	var med: NpcBase = _medic(Vector3(0, 0.05, -10))
	var cop: NpcBase = _cop(Vector3(4, 0.05, -10))
	await wait_physics_frames(3)
	EventBus.special_spawned.disconnect(cb)
	assert_eq(spawned, [&"corpsman"] as Array[StringName], "special_spawned corpsman")
	var b: CorpsmanBrain = med.get_node("Brain") as CorpsmanBrain
	var r: Dictionary = _lethal(cop)
	assert_true(cop.alive, "the ally is revived instead of dying")
	assert_false(bool(r["killed"]), "not killed")
	assert_true(bool(r.get("revived", false)) and int(r.get("healed_by", 0)) == med.net_id, "healed_by the medic")
	assert_near(cop.health, cop.max_health, 0.001, "full health")
	assert_near(b.cooldown_left, b.special_tweak.corpsman_cooldown_s, 0.05, "3 s cooldown")
	assert_true(_cues.has(&"cue.corpsman_heal"), "heal chime")
	assert_true(CorpsmanBrain.is_outlined(cop), "green outline on the healed unit")
	# Heal lock: neither moves nor shoots.
	assert_true(cop.is_stunned(), "target locked")
	assert_eq(b.mode, &"heal")
	assert_false(b.wants_to_fire, "medic does not shoot while healing")
	# Within the cooldown the next lethal hit kills.
	_lethal(cop)
	assert_false(cop.alive, "cooldown: no second revive")
	await wait_seconds(b.special_tweak.corpsman_heal_lock_s + 0.2)
	assert_true(b.mode != &"heal", "medic free again after the lock")


func test_l4_8_revive_through_walls_cooldown_expires() -> void:
	var med: NpcBase = _medic(Vector3(0, 0.05, -10))
	var a: NpcBase = _cop(Vector3(5, 0.05, -10))
	var c2: NpcBase = _cop(Vector3(-5, 0.05, -10))
	ATestMaps.add_wall(_rt.map, Vector3(2.5, 1, -10), Vector3(0.3, 3, 4))
	await wait_physics_frames(3)
	var b: CorpsmanBrain = med.get_node("Brain") as CorpsmanBrain
	_lethal(a)
	assert_true(a.alive, "revived through a wall")
	var tw: HeavySpecialTweak = b.special_tweak
	await wait_seconds(tw.corpsman_cooldown_s + 0.3)
	_lethal(c2)
	assert_true(c2.alive, "ready again after the 3 s cooldown")
	assert_eq(b.revives, 2)


func test_l4_8_range_and_medics_do_not_heal_medics() -> void:
	var med: NpcBase = _medic(Vector3(0, 0.05, -10))
	var med2: NpcBase = _medic(Vector3(3, 0.05, -10))
	var far: NpcBase = _cop(Vector3(0, 0.05, -18.5))
	await wait_physics_frames(3)
	_lethal(far)
	assert_false(far.alive, "out of the 7 m radius")
	_lethal(med2)
	assert_false(med2.alive, "medics don't heal medics")
	assert_true(med.alive)
	assert_eq((med.get_node("Brain") as CorpsmanBrain).revives, 0)


func test_l4_8_heals_hurt_ally_when_loud() -> void:
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	_rt.stealth.raise_alarm(&"test", 0)
	var med: NpcBase = _medic(Vector3(0, 0.05, -12))
	var cop: NpcBase = _cop(Vector3(3, 0.05, -12))
	await wait_physics_frames(3)
	cop.health = cop.max_health * 0.3
	var b: CorpsmanBrain = med.get_node("Brain") as CorpsmanBrain
	var healed: bool = await wait_until(func() -> bool: return b.heals > 0, 4.0)
	assert_true(healed, "heals a hurt ally")
	assert_near(cop.health, cop.max_health, 0.001, "to full")
