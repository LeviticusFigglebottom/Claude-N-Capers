## OF-A5 (QC-68): a police spawn on an off-navmesh roof island (Ostrander's P5 setback, +16 m) whose only exit is a
## chain of two one-way rappels (setback -> terrace +12.2 -> lantern +8.6). The director accepts the island spawn
## (L1.4 LOS / distance only, no reachability rule) and a unit spawned there walks, rappels, walks, rappels and
## walks to a target on the lowest level within a time budget.
extends TestCase

const SETBACK_Y: float = 16.0
const TERRACE_Y: float = 12.2
const LANTERN_Y: float = 8.6
const SPAWN_POS: Vector3 = Vector3(0, SETBACK_Y + 0.05, -7.0)
const GOAL: Vector3 = Vector3(0, LANTERN_Y, 6.0)
## Generous: ~13 m of walking plus 3.8 m + 3.6 m of rope at NpcMotor.rappel_speed.
const BUDGET_S: float = 25.0

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## Three slabs (lantern 24 x 24, terrace 8 x 8, setback 4 x 3, each 0.4 thick and > agent_max_climb apart, so three
## navmesh islands); R1 on the setback's +Z edge drops onto the terrace, R2 on the terrace's +Z edge onto the
## lantern. The crew stays on the ground (y 0) under the lantern slab: no LOS to the roof, > 15 m away flat.
static func _map() -> PackedScene:
	return ATestMaps.with_slabs(
		[[Vector3(0, LANTERN_Y - 0.2, 0), Vector3(24, 0.4, 24)],
			[Vector3(0, TERRACE_Y - 0.2, -4), Vector3(8, 0.4, 8)],
			[Vector3(0, SETBACK_Y - 0.2, -6.5), Vector3(4, 0.4, 3)]],
		[{"name": "R1Setback", "pos": Vector3(0, SETBACK_Y, -5.3)},
			{"name": "R2Terrace", "pos": Vector3(0, TERRACE_Y, -0.3)}],
		[{"name": "PoliceSetback", "kind": SpawnPoint.Kind.POLICE, "pos": SPAWN_POS}],
		AABB(Vector3(-15.0, LANTERN_Y - 0.6, -15.0), Vector3(30.0, SETBACK_Y - LANTERN_Y + 2.5, 30.0)))


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_of_a5", 6805, Enums.Difficulty.ROUTINE, self,
		{"map_packed": _map(), "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "navigation synced")
	await wait_physics_frames(2)


func test_director_accepts_the_island_spawn() -> void:
	await _launch()
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var sp: Node3D = _rt.map.get_node(^"Spawns/PoliceSetback") as Node3D
	assert_true(d.is_spawn_valid(sp.global_position), "L1.4 valid: no crew LOS, far enough")
	assert_has(d.valid_spawn_points(), sp, "the island spawn is offered")
	var nav_map: RID = _rt.get_viewport().world_3d.navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, SPAWN_POS, GOAL, true, 1 | Door.NAV_LAYER_BREACH)
	assert_true(path.size() >= 2 and path[path.size() - 1].distance_to(GOAL) < 0.3,
		"a police-layer path leaves the island through both rappel links")
	var npc: NpcBase = d.spawn_enemy(null, Transform3D(Basis.IDENTITY, sp.global_position), sp)
	assert_true(npc != null and npc.role == &"police", "the director spawns a police unit there")


func test_police_unit_descends_the_rappel_chain() -> void:
	await _launch()
	for n: String in ["R1Setback", "R2Terrace"]:
		assert_true(RappelLinks.link_of(_rt.map.get_node("Tactical/" + n)) != null, "%s link built at load" % n)
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var sp: Node3D = _rt.map.get_node(^"Spawns/PoliceSetback") as Node3D
	var npc: NpcBase = d.spawn_enemy(null, Transform3D(Basis.IDENTITY, sp.global_position), sp)
	for nm: String in ["Brain", "Gunner"]:  # the motor alone: the brain would chase the crew
		var c: Node = npc.get_node_or_null(nm)
		if c != null:
			c.set_physics_process(false)
	await wait_physics_frames(3)
	assert_true(npc.global_position.y > SETBACK_Y - 0.3, "standing on the setback")
	var m: NpcMotor = npc.get_node("Motor") as NpcMotor
	m.go_to(GOAL, 3.0)
	var rappels: Array[int] = [0]
	var was: Array[bool] = [false]
	var levels: Array[float] = []
	var t0: int = Time.get_ticks_msec()
	var reached: bool = await wait_until(func() -> bool:
		if m.rappelling and not was[0]:
			rappels[0] += 1
			levels.append(npc.global_position.y)
		was[0] = m.rappelling
		return npc.global_position.distance_to(GOAL) < 0.6 and not m.rappelling, BUDGET_S)
	assert_true(reached, "reached the lantern target in %.1f s (at %s, %d rappel(s))" % [
		(Time.get_ticks_msec() - t0) / 1000.0, npc.global_position, rappels[0]])
	assert_eq(rappels[0], 2, "two chained rappels")
	if levels.size() == 2:
		assert_true(levels[0] > SETBACK_Y - 0.5, "first from the setback (%.2f)" % levels[0])
		assert_true(absf(levels[1] - TERRACE_Y) < 0.5, "second from the terrace (%.2f)" % levels[1])
	assert_near(npc.global_position.y, LANTERN_Y, 0.2, "on the lantern level")
