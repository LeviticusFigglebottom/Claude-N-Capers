## A4-02 perf probe (PO-5): frame cost of N loud police + civilians wearing ENV D characters vs placeholder
## capsules on the real Glasshouse map (headless: animation/skeleton/AI/physics CPU, no draw). Prints PERF
## lines; asserts only a generous ceiling so it never flakes.
extends TestCase

const N_POLICE: int = 16
const SAMPLE_FRAMES: int = 240

var _rt: HeistRuntime = null


func after_each() -> void:
	NpcVisuals.disabled = false
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _measure(capsules: bool) -> Dictionary:
	NpcVisuals.disabled = capsules
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": true})
	await wait_physics_frames(5)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	dir.running = false  # hold the director: a fixed population
	var c: Node3D = _rt.crew_controller(0) as Node3D
	for i: int in N_POLICE:
		var p: Vector3 = Vector3(-6.0 + float(i % 8) * 1.5, 0.05, 20.0 + float(i / 8) * 1.5)
		_rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, p), {})
	_rt.stealth.raise_alarm(&"perf", 0)
	dir.running = false
	await wait_physics_frames(60)
	var npcs: int = _rt.npcs().size()
	var t0: int = Time.get_ticks_usec()
	var proc: float = 0.0
	var phys: float = 0.0
	for _i: int in SAMPLE_FRAMES:
		await get_tree().process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var wall_ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / SAMPLE_FRAMES
	var out: Dictionary = {"npcs": npcs, "frame_ms": wall_ms, "process_ms": proc * 1000.0 / SAMPLE_FRAMES,
		"physics_ms": phys * 1000.0 / SAMPLE_FRAMES, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	return out


func test_a4_02_character_vs_capsule_frame_cost() -> void:
	_rt = null
	var cap: Dictionary = await _measure(true)
	var chr: Dictionary = await _measure(false)
	print("PERF capsules   %s" % [cap])
	print("PERF characters %s" % [chr])
	var per_npc: float = (float(chr["frame_ms"]) - float(cap["frame_ms"])) / maxf(float(chr["npcs"]), 1.0)
	print("PERF extra per NPC with a character: %.3f ms/frame (process %+.2f ms, physics %+.2f ms total)" % [
		per_npc, float(chr["process_ms"]) - float(cap["process_ms"]), float(chr["physics_ms"]) - float(cap["physics_ms"])])
	assert_true(float(chr["frame_ms"]) < 250.0, "frame time sane (%.1f ms)" % float(chr["frame_ms"]))
