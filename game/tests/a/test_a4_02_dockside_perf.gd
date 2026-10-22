## A4-02 perf scene (roadmap: Dockside, 4 crew, enemy cap reached): Dockside Burn loud with 3 AI teammates and the
## police at the enemy cap, headless (CPU: AI, animation, physics, scripts; no draw). Prints PERF lines (frame /
## process averages and p95, wall time per physics tick, the caperworks/* monitors, FrameProf's per-system top)
## and asserts the
## CI budgets below. The budgets are generous headless ceilings measured on the cloud runners (2026-10-22: see
## docs/status/env_a.md) so the test catches regressions of 2x and more without flaking.
extends TestCase

const SAMPLE_FRAMES: int = 300
const WARMUP_PHYSICS_FRAMES: int = 180
## CI budgets (ms, headless, this scene).
const BUDGET_PROCESS_AVG_MS: float = 20.0
## Simulation cost per physics tick (ms of wall time), measured saturated: physics_ticks_per_second SATURATE_HZ (and up
## to 16 steps a frame) so the game cannot keep up (at 60 Hz the wall time per tick only reads the pacing, 16.7 ms;
## Engine.time_scale scales each tick's delta, not their number). Real time at 60 Hz needs < 16.7 ms per tick.
const SATURATE_HZ: int = 480
const BUDGET_TICK_MS: float = 12.0
## Net (HeistNetSync at SYNC_HZ): the transform stream (every replicated NPC / crew / bag, the worst case: all moved)
## and a full discrete-state message (bring-up / late join), bytes per var_to_bytes.
const BUDGET_XFORM_KBPS: float = 96.0
const BUDGET_FULL_STATE_KB: float = 64.0
const BUDGET_FRAME_P95_MS: float = 40.0

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	FrameProf.enabled = false
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _fill_to_cap(dir: AssaultDirector) -> void:
	var pts: Array[Node3D] = dir.valid_spawn_points()
	var defs: Array[StringName] = [&"enemy.patrol_officer", &"enemy.tac_light", &"enemy.tac_heavy"]
	var i: int = 0
	while _rt.npcs().filter(func(n: Node) -> bool: return n.is_in_group(G.ENEMY) and (n as NpcBase).alive).size() \
			< dir.enemy_cap() and i < 200 and not pts.is_empty():
		var def: EnemyDef = dir.enemy_def_for(defs[i % defs.size()])
		if def != null:
			dir.spawn_enemy(def, pts[i % pts.size()].global_transform, pts[i % pts.size()])
		i += 1


func test_a4_02_dockside_at_the_enemy_cap() -> void:
	_rt = await HeistLauncher.launch(&"dockside_burn", 4202, Enums.Difficulty.HAZARDOUS, self,
		{"ai_teammates": 3, "crew_ai": true, "skip_casing": true, "vfx_prewarm": true})
	for slot: int in 4:
		Modifiers.set_source(slot, &"perf.immune", {&"defense.damage_taken_mult": 0.0})  # a stable population
	_rt.stealth.raise_alarm(&"perf", 0)
	await wait_physics_frames(10)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	_fill_to_cap(dir)
	await wait_physics_frames(WARMUP_PHYSICS_FRAMES)
	_fill_to_cap(dir)
	FrameProf.enabled = true
	FrameProf.totals.clear()
	var frames: Array[float] = []
	var proc: float = 0.0
	var last: int = Time.get_ticks_usec()
	for _i: int in SAMPLE_FRAMES:
		FrameProf.reset_frame()
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		if frames[frames.size() - 1] > 50.0:
			print("PERF dockside hitch %.1f ms (frame %d): %s" % [frames[frames.size() - 1], frames.size(), FrameProf.top(6)])
		last = now
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	FrameProf.enabled = false
	var hz: int = Engine.physics_ticks_per_second
	var steps: int = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = SATURATE_HZ
	Engine.max_physics_steps_per_frame = 16
	await wait_frames(10)
	var t_start: int = Time.get_ticks_usec()
	var ticks0: int = Engine.get_physics_frames()
	await wait_frames(120)
	var tick_ms: float = (Time.get_ticks_usec() - t_start) / 1000.0 / maxf(float(Engine.get_physics_frames() - ticks0), 1.0)
	Engine.physics_ticks_per_second = hz
	Engine.max_physics_steps_per_frame = steps
	frames.sort()
	var avg: float = 0.0
	for f: float in frames:
		avg += f
	avg /= float(frames.size())
	var p95: float = frames[int(frames.size() * 0.95)]
	var proc_avg: float = proc / SAMPLE_FRAMES
	var mon: Dictionary = {}
	for k: String in ["npcs", "enemies_alive", "civilians", "crew_standing", "dynamic_nodes"]:
		mon[k] = Performance.get_custom_monitor(StringName(PerfMonitors.PREFIX + k))
	print("PERF dockside cap=%d %s nodes=%d" % [dir.enemy_cap(), mon, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	print("PERF dockside frame avg %.2f ms p95 %.2f ms max %.2f ms | process avg %.2f ms | wall per physics tick %.2f ms" % [
		avg, p95, frames[frames.size() - 1], proc_avg, tick_ms])
	print("PERF dockside per-system ms/frame: %s" % _top_totals(12))
	var net: Dictionary = _net_payloads()
	print("PERF dockside net: %d entities, transforms %.1f KB/s at %.0f Hz (all moving), full state %.1f KB" % [
		net["entities"], net["xform_kbps"], HeistNetSync.SYNC_HZ, net["state_kb"]])
	assert_true(float(net["xform_kbps"]) < BUDGET_XFORM_KBPS, "transform stream %.1f KB/s < %.0f" % [net["xform_kbps"],
		BUDGET_XFORM_KBPS])
	assert_true(float(net["state_kb"]) < BUDGET_FULL_STATE_KB, "full state %.1f KB < %.0f" % [net["state_kb"],
		BUDGET_FULL_STATE_KB])
	assert_true(int(mon["enemies_alive"]) >= dir.enemy_cap() - 2, "at the enemy cap (%d of %d)" % [mon["enemies_alive"],
		dir.enemy_cap()])
	assert_true(proc_avg < BUDGET_PROCESS_AVG_MS, "process avg %.2f ms < %.0f" % [proc_avg, BUDGET_PROCESS_AVG_MS])
	assert_true(tick_ms < BUDGET_TICK_MS, "wall per physics tick %.2f ms < %.0f (real time)" % [tick_ms, BUDGET_TICK_MS])
	assert_true(p95 < BUDGET_FRAME_P95_MS, "frame p95 %.2f ms < %.0f" % [p95, BUDGET_FRAME_P95_MS])


## The replicated payloads HeistNetSync would send now (it idles in solo): every transform, and a full state message.
func _net_payloads() -> Dictionary:
	var xforms: Dictionary = {}
	var states: Dictionary = {}
	for n: Node in _rt.dynamic_root.get_children():
		var id: int = NetIds.of(n)
		if id == 0:
			continue
		var x: Variant = NetEntityCodec.xform_of(n)
		if x != null:
			xforms[id] = x
		states[id] = NetEntityCodec.state_of(n)
	var sync: HeistNetSync = _rt.service(HeistNetSync.SERVICE) as HeistNetSync
	var svc: Dictionary = sync.services_state() if sync != null else {}
	return {"entities": states.size(), "xform_kbps": var_to_bytes(xforms).size() * HeistNetSync.SYNC_HZ / 1024.0,
		"state_kb": var_to_bytes([states, svc]).size() / 1024.0}


func _top_totals(n: int) -> String:
	var keys: Array = FrameProf.totals.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(FrameProf.totals[a]) > int(FrameProf.totals[b]))
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(mini(n, keys.size())):
		parts.append("%s=%.2f" % [keys[i], int(FrameProf.totals[keys[i]]) / 1000.0 / SAMPLE_FRAMES])
	return " ".join(parts)
