## ND wave-2 stall hunt (lead): a loud heist piles up police corpses. A corpse must cost (almost) nothing per frame:
## no navigation agent left registered, no brain / motor work, no animation after its death clip.
## Spawns CORPSES police, kills them, then measures the frame cost and the navigation agent count.
extends TestCase

const CORPSES: int = 30
const FRAMES: int = 120

var _rt: HeistRuntime = null


func after_each() -> void:
	FrameProf.enabled = false
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_corpses_cost_nothing_per_frame() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 5150, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)
	var nav_map: RID = _rt.get_viewport().world_3d.navigation_map
	var agents0: int = NavigationServer3D.map_get_agents(nav_map).size()
	FrameProf.enabled = true
	var base_ms: float = await _avg_frame_ms()
	var npcs: Array[NpcBase] = []
	for i: int in range(CORPSES):
		var pos: Vector3 = Vector3(-7.5 + float(i % 6) * 3.0, 0.05, -6.0 - float(i / 6) * 3.0)
		npcs.append(_rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, pos), {}))
	await wait_physics_frames(10)
	var agents_alive: int = NavigationServer3D.map_get_agents(nav_map).size()
	var alive_ms: float = await _avg_frame_ms()
	var alive_top: String = _top_totals()
	for n: NpcBase in npcs:
		n.die({}, 0)
	await wait_seconds(4.0)  # death clips finish
	var agents_dead: int = NavigationServer3D.map_get_agents(nav_map).size()
	var dead_ms: float = await _avg_frame_ms()
	print("CORPSEPERF n=%d agents base=%d alive=%d dead=%d frame base=%.2fms alive=%.2fms dead=%.2fms" % [
		CORPSES, agents0, agents_alive, agents_dead, base_ms, alive_ms, dead_ms])
	print("CORPSEPERF alive top: %s" % alive_top)
	print("CORPSEPERF dead top: %s" % _top_totals())
	assert_true(agents_dead <= agents0, "dead NPCs leave no navigation agent (%d -> %d)" % [agents0, agents_dead])
	var corpse_ms: float = _total_ms_per_frame()
	assert_true(corpse_ms < 1.0, "%d corpses cost < 1 ms/frame in game systems (%.2f)" % [CORPSES, corpse_ms])


## Mean engine process + physics time per frame over FRAMES frames (ms; reported only: the engine monitors lag,
## so the asserts use FrameProf's own timings).
func _avg_frame_ms() -> float:
	FrameProf.totals.clear()
	var sum: float = 0.0
	for _i: int in range(FRAMES):
		await wait_frames(1)
		sum += (Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	return sum / float(FRAMES)


## Sum of every FrameProf key over the last _avg_frame_ms() window, per frame (ms).
static func _total_ms_per_frame() -> float:
	var us: int = 0
	for k: Variant in FrameProf.totals:
		us += int(FrameProf.totals[k])
	return us / 1000.0 / float(FRAMES)


static func _top_totals() -> String:
	var keys: Array = FrameProf.totals.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(FrameProf.totals[a]) > int(FrameProf.totals[b]))
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys.slice(0, 8):
		parts.append("%s=%.2fms/f" % [k, int(FrameProf.totals[k]) / 1000.0 / float(FRAMES)])
	return " ".join(parts)
