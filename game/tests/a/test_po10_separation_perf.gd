## PO-10 perf guard (lead, ND wave-2 stall hunt): NpcMotor personal space must stay cheap at wave-2 density.
## 40 NPCs spread over a 20 m square (wave-2 density) or packed into a 6 m square (the ND vault choke, worst case for
## the neighbour grid) keep re-targeting inside it; the per-frame cost of every motor's separation work (grid
## rebuild once per physics frame, _separate, _idle_drift, _target_crowded) must stay under its budget, and
## whole physics frames must not spike past SPIKE_MS.
extends TestCase

const NPCS: int = 40
## Wave-2 spread (lead budget: < 1 ms/frame at 40 NPCs) and the worst case, everyone packed into a choke.
const SPREAD_M: float = 20.0
const SPREAD_BUDGET_MS: float = 1.0
const CROWD_M: float = 6.0
const CROWD_BUDGET_MS: float = 2.0
const FRAMES: int = 240
const SPIKE_MS: float = 250.0

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_po10_separation_under_1ms_per_frame_at_40_npcs() -> void:
	await _measure(SPREAD_M, SPREAD_BUDGET_MS)


func test_po10_separation_under_2ms_per_frame_at_40_npcs_packed_in_a_choke() -> void:
	await _measure(CROWD_M, CROWD_BUDGET_MS)


func _measure(area_m: float, budget_ms: float) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4242, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var center: Vector3 = Vector3(0, 0.05, -12)
	var motors: Array[NpcMotor] = []
	for i: int in range(NPCS):
		var pos: Vector3 = center + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * area_m * 0.5
		var npc: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), {"idle_activity": &"stand"})
		var brain: Node = npc.get_node_or_null(^"Brain")
		if brain != null:
			brain.set_physics_process(false)
			brain.set_process(false)
		motors.append(npc.get_node(^"Motor") as NpcMotor)
	await wait_physics_frames(2)
	var worst_ms: float = 0.0
	var total_ms: float = 0.0
	var spike_ms: float = 0.0
	for f: int in range(FRAMES):
		if f % 30 == 0:  # keep everyone walking into the crowd (moving NPCs do the most separation work)
			for m: NpcMotor in motors:
				m.go_to(center + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * area_m * 0.5, 1.6)
		await wait_physics_frames(1)
		spike_ms = maxf(spike_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var ms: float = _separation_cost_ms(motors)
		worst_ms = maxf(worst_ms, ms)
		total_ms += ms
	var avg_ms: float = total_ms / float(FRAMES)
	print("PO10PERF npcs=%d area=%.0fm avg=%.3fms worst=%.3fms physics_worst=%.1fms" % [NPCS, area_m, avg_ms,
		worst_ms, spike_ms])
	assert_true(avg_ms < budget_ms, "separation avg %.3f ms/frame < %.1f ms at %d NPCs in %.0f m" % [avg_ms, budget_ms,
		NPCS, area_m])
	assert_true(worst_ms < budget_ms * 5.0, "separation worst frame %.3f ms < %.1f ms" % [worst_ms, budget_ms * 5.0])
	assert_true(spike_ms < SPIKE_MS, "no physics frame spike (worst %.1f ms < %.0f ms)" % [spike_ms, SPIKE_MS])


## One physics frame's separation work for every motor, timed (the grid is rebuilt once: first query this frame).
static func _separation_cost_ms(motors: Array[NpcMotor]) -> float:
	NpcMotor._grid_frame = -1  # force the grid rebuild and every motor's neighbour query into the timed window
	for m: NpcMotor in motors:
		m._own_nb_frame = -1
	var t0: int = Time.get_ticks_usec()
	for m: NpcMotor in motors:
		var dir: Vector3 = Vector3.FORWARD
		if m.target != Vector3.INF:
			var d: Vector3 = m.target - m.get_parent().global_position
			d.y = 0.0
			if d.length() > 0.01:
				dir = d.normalized()
		m._separate(dir)
		m._idle_drift(m.get_parent() as NpcBase)
		m._target_crowded()
	return (Time.get_ticks_usec() - t0) / 1000.0
