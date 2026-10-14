## PO-10 (product-owner playtest 2): NPCs keep personal space (PD2: they never walk stacked or clip into each
## other). NpcMotor steers moving NPCs apart and stops short of a target another NPC stands on
## (StealthTweak npc_separation_* / npc_crowd_*); guards sharing a patrol graph start staggered
## (GuardTweak.patrol_stagger_*); two civilians never head for the same wander point (CivilianTargets).
extends TestCase

const OVERLAP_M: float = 0.5
const OVERLAP_MAX_S: float = 0.5

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(map: PackedScene, seed_value: int = 1010) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", seed_value, Enums.Difficulty.ROUTINE, self, {"map_packed": map})
	await wait_physics_frames(2)


## A civilian whose brain is paused, so the test drives its motor directly.
func _puppet(pos: Vector3) -> NpcBase:
	var npc: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), {"idle_activity": &"stand"})
	var brain: Node = npc.get_node_or_null(^"Brain")
	if brain != null:
		brain.set_physics_process(false)
		brain.set_process(false)
	return npc


static func _motor(npc: Node) -> NpcMotor:
	return npc.get_node(^"Motor") as NpcMotor


## Steps `seconds` of physics and returns the longest time (s) any pair of `npcs` stayed closer than
## OVERLAP_M (horizontal, same floor). `done` (optional) ends the run early when it returns true.
func _track_overlap(npcs: Array[NpcBase], seconds: float, done: Callable = Callable()) -> float:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var run: Dictionary = {}
	var worst: float = 0.0
	for _f: int in range(int(seconds * Engine.physics_ticks_per_second)):
		await wait_physics_frames(1)
		for i: int in range(npcs.size()):
			for j: int in range(i + 1, npcs.size()):
				var a: Vector3 = npcs[i].global_position
				var b: Vector3 = npcs[j].global_position
				var key: int = i * 100 + j
				if absf(a.y - b.y) < 1.0 and Vector2(a.x - b.x, a.z - b.z).length() < OVERLAP_M:
					run[key] = float(run.get(key, 0.0)) + dt
					worst = maxf(worst, float(run[key]))
				else:
					run[key] = 0.0
		if done.is_valid() and bool(done.call()):
			break
	return worst


func test_po10_converging_npcs_never_overlap_and_all_arrive() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var center: Vector3 = Vector3(0, 0.05, -12)
	var npcs: Array[NpcBase] = []
	for i: int in range(6):
		var ang: float = TAU * float(i) / 6.0
		npcs.append(_puppet(center + Vector3(cos(ang), 0.0, sin(ang)) * 7.0))
	await wait_physics_frames(2)
	for i: int in range(npcs.size()):
		# Every target within 0.35 m of the centre: without personal space they all end up inside each other.
		var off: Vector3 = Vector3(0.35, 0, 0).rotated(Vector3.UP, TAU * float(i) / 6.0) if i > 0 else Vector3.ZERO
		_motor(npcs[i]).go_to(center + off, 1.6)
	var all_arrived: Callable = func() -> bool:
		for n: NpcBase in npcs:
			if not _motor(n).arrived:
				return false
		return true
	var worst: float = await _track_overlap(npcs, 14.0, all_arrived)
	assert_true(worst <= OVERLAP_MAX_S, "no two NPCs closer than %.1f m for more than %.1f s (worst %.2f s)" % [
		OVERLAP_M, OVERLAP_MAX_S, worst])
	assert_true(all_arrived.call(), "every converging NPC settles (arrives beside an occupied target)")
	# Settled: they stay apart.
	worst = await _track_overlap(npcs, 2.0)
	assert_true(worst <= OVERLAP_MAX_S, "settled NPCs keep personal space (worst %.2f s)" % worst)


func test_po10_head_on_npcs_pass_each_other() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var a: NpcBase = _puppet(Vector3(-5, 0.05, -12))
	var b: NpcBase = _puppet(Vector3(5, 0.05, -12))
	await wait_physics_frames(2)
	_motor(a).go_to(Vector3(5, 0.05, -12), 1.6)
	_motor(b).go_to(Vector3(-5, 0.05, -12), 1.6)
	var both: Callable = func() -> bool: return _motor(a).arrived and _motor(b).arrived
	var worst: float = await _track_overlap([a, b] as Array[NpcBase], 12.0, both)
	assert_true(worst <= OVERLAP_MAX_S, "head-on walkers never overlap (worst %.2f s)" % worst)
	assert_true(both.call(), "both reach the other side (no head-on stall)")


func test_po10_stacked_idle_npcs_drift_apart() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var a: NpcBase = _puppet(Vector3(0, 0.05, -12))
	var b: NpcBase = _puppet(Vector3(0.1, 0.05, -12))
	await wait_physics_frames(2)
	assert_true(await wait_until(func() -> bool:
		return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length() >= OVERLAP_M, 2.0),
		"two calm NPCs spawned inside each other separate")


func test_po10_guards_sharing_a_route_start_staggered_and_keep_space() -> void:
	await _launch(ATestMaps.with_patrol_grid(0, 0, 3, 3, 3.0, true, Vector2(0.5, 1.5)))
	var graph: PatrolGraph = _rt.map.get_node(^"Patrols/Graph") as PatrolGraph
	var tw: GuardTweak = load(GuardBrain.DEFAULT_TWEAK) as GuardTweak
	var guards: Array[NpcBase] = []
	for off: Vector3 in [Vector3.ZERO, Vector3(0.8, 0, 0), Vector3(0, 0, 0.8), Vector3(0.8, 0, 0.8)]:
		guards.append(_rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(5, 0.05, -5) + off), {"patrol_graph": graph}))
		await wait_physics_frames(1)
	await wait_physics_frames(3)
	var pauses: Array[float] = []
	for g: NpcBase in guards:
		var b: GuardBrain = g.get_node(^"Brain") as GuardBrain
		assert_true(b.route.size() >= 2, "guard has a route on the shared graph")
		assert_eq(b.patrol_graph, graph, "route from the shared graph")
		pauses.append(b._pause_left)
	pauses.sort()
	for k: int in range(1, pauses.size()):
		assert_true(pauses[k] - pauses[k - 1] >= tw.patrol_stagger_s - tw.patrol_stagger_jitter_s - 0.2,
			"start delays staggered (%s)" % [pauses])
	var worst: float = await _track_overlap(guards, 20.0)
	assert_true(worst <= OVERLAP_MAX_S, "patrolling guards never overlap for long (worst %.2f s)" % worst)
	for g: NpcBase in guards:
		assert_eq(g.alert_state, Enums.AlertState.CALM, "still calm")


func _point(pos: Vector3) -> PatrolPoint:
	var pp: PatrolPoint = PatrolPoint.new()
	pp.tags = [&"civilian"] as Array[StringName]
	_rt.map.add_child(pp)
	pp.global_position = pos
	return pp


func test_po10_wander_point_reserved_while_heading_or_standing_there() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var p: PatrolPoint = _point(Vector3(4, 0.05, -12))
	var q: PatrolPoint = _point(Vector3(-4, 0.05, -12))
	var a: NpcBase = _puppet(Vector3(0, 0.05, -10))
	var b: NpcBase = _puppet(Vector3(0, 0.05, -14))
	await wait_physics_frames(3)
	var targets: CivilianTargets = CivilianTargets.ensure(_rt)
	var prof: Dictionary = targets.wander_profile(b, b.global_position)
	var opts: Array[PatrolPoint] = targets.wander_options(b.global_position, prof, 15.0)
	assert_has(opts, p, "free point offered")
	_motor(a).go_to(p.global_position, 1.3)
	opts = targets.wander_options(b.global_position, prof, 15.0)
	assert_false(opts.has(p), "a point another NPC is heading to is not offered")
	assert_has(opts, q, "the other point still is")
	_motor(a).stop()
	opts = targets.wander_options(b.global_position, prof, 15.0)
	assert_has(opts, p, "released when it goes elsewhere / stops")
	a.global_position = p.global_position
	await wait_physics_frames(2)
	opts = targets.wander_options(b.global_position, prof, 15.0)
	assert_false(opts.has(p), "a point an NPC stands on is not offered")


func test_po10_two_civilians_never_hold_the_same_wander_target() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var pts: Array[PatrolPoint] = []
	for x: float in [-4.0, 0.0, 4.0]:  # 6 points for 4 civilians: they keep swapping between free ones
		pts.append(_point(Vector3(x, 0.05, -14)))
		pts.append(_point(Vector3(x, 0.05, -18)))
	var civs: Array[NpcBase] = []
	for i: int in range(4):
		civs.append(_rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(-4.5 + 3.0 * i, 0.05, -9)),
			{"idle_activity": &"browse"}))
	await wait_physics_frames(3)
	var brains: Array[CivilianBrain] = []
	for c: NpcBase in civs:
		brains.append(c.get_node(^"Brain") as CivilianBrain)
	var picks: int = 0
	var clashes: int = 0
	var was_wander: Array[bool] = [false, false, false, false]
	for _f: int in range(int(20.0 * Engine.physics_ticks_per_second)):
		for i: int in range(brains.size()):
			var br: CivilianBrain = brains[i]
			if br.mode == CivilianBrain.Mode.IDLE:
				br._wander_timer = minf(br._wander_timer, 0.3)  # wander far more often than the tweak's 15-40 s
		await wait_physics_frames(1)
		var held: Dictionary = {}
		for i: int in range(brains.size()):
			var br: CivilianBrain = brains[i]
			var wandering: bool = br.mode == CivilianBrain.Mode.WANDER
			if wandering and not was_wander[i]:
				picks += 1
			was_wander[i] = wandering
			if not wandering:
				continue
			var node: Object = br.call_target.get("node") as Object
			if node == null:
				continue
			if held.has(node.get_instance_id()):
				clashes += 1
			held[node.get_instance_id()] = true
	assert_true(picks >= 6, "civilians kept wandering (%d picks)" % picks)
	assert_eq(clashes, 0, "no two civilians ever held the same wander point")
	for c: NpcBase in civs:
		assert_eq(c.alert_state, Enums.AlertState.CALM, "still calm")
