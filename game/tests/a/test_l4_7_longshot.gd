## A3-01a / L4.7 Longshot (PD2 Sniper): spawns only at SNIPER_PERCH TacticalPoints, a visible tracking
## laser and a 1.2 s aim lock before each shot, 100-240 damage by difficulty that bypasses armor gating,
## halved beyond 30 m except on the top difficulty, cue.longshot_report.
extends TestCase

const DEF: String = "res://systems/ai/data/enemies/longshot.tres"

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func after_each() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	_events.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(difficulty: int = Enums.Difficulty.LETHAL, loud: bool = true) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4707, difficulty, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	_listen(EventBus.special_spawned, &"special")
	_listen(EventBus.audio_cue_requested, &"cue")
	for c: CrewController in _rt.crew_members():
		Modifiers.set_source(c.slot, &"test.nododge", {&"defense.dodge_add": -1.0})
	# Slot 1 parked out of the way behind a wall (keeps the heist alive, never the target).
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(25, 0.05, 25)))
	ATestMaps.add_wall(_rt.map, Vector3(25, 1.5, 23), Vector3(4, 3, 0.4))
	if loud:
		for c: CrewController in _rt.crew_members():
			c.set_masked()
		_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(1)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, _c: Variant = null) -> void:
		_events.append([tag, a, b])
	sig.connect(cb)
	_conns.append([sig, cb])


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _add_perch(pos: Vector3) -> TacticalPoint:
	var tp: TacticalPoint = TacticalPoint.new()
	tp.name = "Perch_%d" % _rt.map.get_node("Tactical").get_child_count()
	tp.kind = TacticalPoint.Kind.SNIPER_PERCH
	_rt.map.get_node("Tactical").add_child(tp)
	tp.global_position = pos
	return tp


func _spawn() -> NpcBase:
	var units: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"longshot")
	return units[0] if not units.is_empty() else null


func _brain(p: NpcBase) -> LongshotBrain:
	return p.get_node("Brain") as LongshotBrain


func test_l4_7_def_and_perch_only_spawn() -> void:
	var def: EnemyDef = load(DEF) as EnemyDef
	assert_eq(def.id, &"enemy.longshot")
	assert_true(def.is_special, "special")
	assert_eq(def.damage.size(), 6, "damage per difficulty")
	assert_near(def.damage[Enums.Difficulty.ROUTINE], 60.0, 0.001, "60 on the lowest difficulty (PO-17, was 100)")
	assert_near(def.damage[Enums.Difficulty.CATACLYSM], 240.0, 0.001, "240 on the top difficulty")
	await _launch(Enums.Difficulty.LETHAL, false)
	assert_true(SpecialSpawner.spawn_special(_rt, &"longshot").is_empty(), "no SNIPER_PERCH: nothing spawns")
	var perch: TacticalPoint = _add_perch(Vector3(-10, 0.05, -5))
	var units: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"enemy.longshot",
		Transform3D(Basis.IDENTITY, Vector3(10, 0.05, 0)))
	assert_eq(units.size(), 1, "spawns on the perch")
	var p: NpcBase = units[0] if not units.is_empty() else null
	if p == null:
		return
	assert_true(p.global_position.distance_to(perch.global_position) < 0.2, "at the perch, not at the given xform")
	assert_true(SpecialSpawner.spawn_special(_rt, &"longshot").is_empty(), "the only perch is taken")
	assert_true(p.find_child("LaserOrigin", true, false) is Marker3D, "LaserOrigin marker (characters.md)")
	assert_true(p.get_node_or_null("LaserBeam") is Node3D, "laser beam node")
	await wait_physics_frames(2)
	assert_has(_events, [&"special", p.net_id, &"longshot"], "special_spawned(net_id, longshot)")
	assert_true(_brain(p).is_perched(), "perched")
	# A director spawn off-perch is moved onto a free perch.
	var perch2: TacticalPoint = _add_perch(Vector3(-4, 0.05, -5))
	var q: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(12, 0.05, 3)), {"enemy_def": def})
	await wait_physics_frames(2)
	assert_true(q.global_position.distance_to(perch2.global_position) < 0.2, "off-perch spawn moved to a free perch")


func test_l4_7_aim_lock_delay_and_tracking_laser() -> void:
	await _launch()
	_add_perch(Vector3(-10, 0.05, -5))
	var p: NpcBase = _spawn()
	var b: LongshotBrain = _brain(p)
	var lasing: bool = await wait_until(func() -> bool: return b.laser_active, 3.0)
	assert_true(lasing, "red laser on the target")
	var t0: int = Time.get_ticks_msec()
	assert_true((p.get_node("LaserBeam") as Node3D).visible, "laser beam visible")
	assert_eq(b.shots_fired, 0, "no shot at laser on")
	var c: CrewController = _crew(0)
	var lp: Vector3 = b.laser_point
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, c.global_position + Vector3(1.0, 0, 0)))
	await wait_physics_frames(3)
	assert_true(b.laser_point.distance_to(lp) > 0.8, "the laser tracks the target")
	var shot: bool = await wait_until(func() -> bool: return b.shots_fired >= 1, 3.0)
	var dt: float = float(Time.get_ticks_msec() - t0) / 1000.0
	assert_true(shot, "fires after the lock")
	assert_true(dt >= b.tweak.longshot_aim_lock_s - 0.1, "1.2 s aim lock (%.2f s)" % dt)
	var report: bool = false
	for e: Array in _events:
		report = report or (e[0] == &"cue" and e[1] == &"cue.longshot_report")
	assert_true(report, "cue.longshot_report")


func test_l4_7_bypasses_armor_gate() -> void:
	await _launch(Enums.Difficulty.LETHAL)
	_add_perch(Vector3(-10, 0.05, -5))
	var c: CrewController = _crew(0)
	var h: CrewHealth = c.health
	var hp: float = h.health
	var armor: float = h.armor
	var p: NpcBase = _spawn()
	var b: LongshotBrain = _brain(p)
	var dmg: float = (p.enemy_def as EnemyDef).damage[Enums.Difficulty.LETHAL]
	assert_true(dmg > armor, "test needs a shot larger than the armor")
	var shot: bool = await wait_until(func() -> bool: return b.shots_fired >= 1, 4.0)
	assert_true(shot, "fired")
	await wait_physics_frames(1)
	assert_near(h.armor, 0.0, 0.01, "armor stripped")
	assert_near(h.health, hp - (dmg - armor), 0.5, "overflow past the armor reaches health (no gating)")
	assert_eq(h.invuln_left, 0.0, "no gate invulnerability granted")


func test_l4_7_halved_beyond_30_m() -> void:
	await _launch(Enums.Difficulty.LETHAL)
	_add_perch(Vector3(20, 0.05, -15))
	var c: CrewController = _crew(0)
	var h: CrewHealth = c.health
	var total: float = h.health + h.armor
	var p: NpcBase = _spawn()
	var b: LongshotBrain = _brain(p)
	var full: float = (p.enemy_def as EnemyDef).damage[Enums.Difficulty.LETHAL]
	assert_true(p.global_position.distance_to(c.global_position) > 30.0, "perch beyond 30 m")
	assert_near(b.shot_damage(40.0), full * 0.5, 0.001, "halved beyond 30 m")
	assert_near(b.shot_damage(20.0), full, 0.001, "full within 30 m")
	var shot: bool = await wait_until(func() -> bool: return b.shots_fired >= 1, 4.0)
	assert_true(shot, "fired")
	await wait_physics_frames(1)
	assert_near(total - (h.health + h.armor), full * 0.5, 0.5, "the long shot dealt half damage")


func test_l4_7_top_difficulty_no_falloff() -> void:
	await _launch(Enums.Difficulty.CATACLYSM)
	_add_perch(Vector3(20, 0.05, -15))
	var p: NpcBase = _spawn()
	var b: LongshotBrain = _brain(p)
	assert_near(b.shot_damage(40.0), 240.0, 0.001, "Cataclysm: no halving beyond 30 m")
