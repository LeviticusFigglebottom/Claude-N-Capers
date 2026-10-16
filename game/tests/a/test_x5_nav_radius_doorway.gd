## X-5 (heist_completion.md): the navmesh is baked for agent_radius 0.30 (D-025); an NPC body wider than that (it was
## a r 0.35 capsule) clips door frames and counter corners on a path that keeps only 0.30 from them. Now the bake
## radius >= every NPC capsule and NavAgent radius, and NPCs walk a 0.9 m doorway (ATestMaps.with_doorway_wall: a
## 0.9 m gap at x = 0 in a wall along z = 0) from straight and from steep angles without snagging on a jamb.
extends TestCase

const NPC_KINDS: Array[StringName] = [&"civilian", &"guard", &"police"]
## Start -> goal pairs crossing the doorway (z = 0); the steep ones make the path cut the jamb corners.
const LEGS: Array[Array] = [
	[Vector3(0.0, 0.05, 4.0), Vector3(0.0, 0.0, -4.0)],
	[Vector3(-5.0, 0.05, 1.2), Vector3(4.5, 0.0, -1.2)],
	[Vector3(5.0, 0.05, 0.8), Vector3(-5.0, 0.0, -0.8)],
	[Vector3(-3.0, 0.05, -1.0), Vector3(3.0, 0.0, 1.0)],
]
const SPEED: float = 2.5
## A body that makes less than this progress (m) over STALL_WINDOW_S while it has a goal is snagged.
const STALL_M: float = 0.1
const STALL_WINDOW_S: float = 0.5

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _launch() -> NavigationRegion3D:
	_rt = await HeistLauncher.launch(&"unit_x5_door", 7, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0), "skip_casing": true, "crew_ai": false})
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "navigation synced to the doorway map")
	return _rt.map.get_node(^"Navigation") as NavigationRegion3D


func _walker(kind: StringName, pos: Vector3) -> NpcBase:
	var npc: NpcBase = _rt.spawn_npc(kind, Transform3D(Basis.IDENTITY, pos), {"no_patrol": true})
	var brain: Node = npc.get_node_or_null(^"Brain")
	if brain != null:
		brain.set_physics_process(false)  # the test drives the motor
	await wait_physics_frames(2)
	return npc


func test_x5_bake_radius_fits_every_npc_body() -> void:
	var nav: NavigationRegion3D = await _launch()
	var bake_r: float = nav.navigation_mesh.agent_radius
	for kind: StringName in NPC_KINDS:
		var npc: NpcBase = await _walker(kind, Vector3(-8, 0.05, 6))
		var cap: CapsuleShape3D = (npc.get_node(^"Collision") as CollisionShape3D).shape as CapsuleShape3D
		var agent: NavigationAgent3D = npc.get_node_or_null(^"NavAgent") as NavigationAgent3D
		assert_true(cap.radius <= bake_r + 0.001, "%s capsule r %.2f fits the bake radius %.2f" % [kind, cap.radius, bake_r])
		assert_true(agent != null and agent.radius <= bake_r + 0.001, "%s NavAgent radius fits the bake radius" % kind)
		npc.queue_free()
	# The path through the 0.9 m gap keeps the agent radius from both jambs (x = +-0.45): the body fits.
	var map: RID = _rt.get_viewport().world_3d.navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(-5, 0, 1.2), Vector3(4.5, 0, -1.2), true)
	assert_true(path.size() >= 2, "a path through the doorway")
	var worst: float = INF
	for i: int in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		if signf(a.z) == signf(b.z) and absf(a.z) > 0.15 and absf(b.z) > 0.15:
			continue
		for k: int in range(21):  # the segment's points inside the wall slab (|z| <= 0.1 + body)
			var p: Vector3 = a.lerp(b, float(k) / 20.0)
			if absf(p.z) <= 0.1:
				worst = minf(worst, 0.45 - absf(p.x))
	assert_true(worst >= 0.3 - 0.06, "the doorway path keeps >= the agent radius from the jambs (%.2f m)" % worst)


func test_x5_npcs_walk_a_0_9m_doorway_without_snagging() -> void:
	await _launch()
	var runs: int = 0
	for kind: StringName in NPC_KINDS:
		for leg: Array in LEGS:
			var from: Vector3 = leg[0]
			var to: Vector3 = leg[1]
			var npc: NpcBase = await _walker(kind, from)
			var m: NpcMotor = npc.get_node(^"Motor") as NpcMotor
			m.go_to(to, SPEED)
			var t: float = 0.0
			var window_t: float = 0.0
			var window_p: Vector3 = npc.global_position
			var worst_stall: float = 0.0
			var stall: float = 0.0
			var budget: float = (_flat(from, to) + 2.0) / SPEED * 2.0 + 1.0
			while t < budget and not m.arrived:
				await wait_physics_frames(1)
				var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
				t += dt
				window_t += dt
				if window_t >= STALL_WINDOW_S:
					stall = stall + window_t if _flat(window_p, npc.global_position) < STALL_M else 0.0
					worst_stall = maxf(worst_stall, stall)
					window_t = 0.0
					window_p = npc.global_position
			print("X-5 doorway %s %s -> %s: arrived %s in %.2f s (budget %.1f), worst stall %.2f s, at %s" % [
				kind, from, to, m.arrived, t, budget, worst_stall, npc.global_position])
			assert_true(m.arrived, "%s %s -> %s crossed the 0.9 m doorway (at %s)" % [kind, from, to, npc.global_position])
			assert_true(signf(npc.global_position.z) == signf(to.z), "%s ended on the far side" % kind)
			assert_true(worst_stall < 1.0, "%s %s -> %s never snagged on a jamb (stall %.2f s)" % [kind, from, to, worst_stall])
			npc.queue_free()
			await wait_physics_frames(1)
			runs += 1
	assert_eq(runs, NPC_KINDS.size() * LEGS.size(), "every kind walked every leg")
