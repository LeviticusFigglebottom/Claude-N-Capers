## P6 #3 AI CPU (LEAD r313): Afterhours on Cataclysm, headless (CPU only: AI, motor, animation, physics, scripts; no draw).
## Three phases: the calm club (the full crowd dancing / milling, guards on their posts), loud with the police filled to
## the enemy cap, and loud with the crew somewhere the police cannot path to (the unreachable-target case: it cost ~20 ms
## a tick in path re-queries before NpcMotor parked the agent on the reachable end, P6 #3). Per phase: wall time per physics tick saturated
## (as A4-02), process avg, and
## FrameProf's per-system ms / frame. Budgets are ~2x the 2026-10-24 baseline (calm 4.9 ms, loud 6.6, unreachable 6.5
## per tick), so the test catches a motor / animation regression without flaking on a busy runner.
extends TestCase

const SAMPLE_FRAMES: int = 240
const SATURATE_HZ: int = 480
const BUDGET_CALM_TICK_MS: float = 10.0
const BUDGET_LOUD_TICK_MS: float = 14.0

var _rt: HeistRuntime = null


func after_each() -> void:
	FrameProf.enabled = false
	AnimLod.allow_headless = false
	AnimLod.invalidate()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_p6_afterhours_cataclysm_ai_cpu() -> void:
	if not ResourceLoader.exists(HeistLauncher.map_path(&"afterhours")):
		skip("no afterhours map on this branch")
		return
	_rt = await HeistLauncher.launch(&"afterhours", 4210, Enums.Difficulty.CATACLYSM, self,
		{"ai_teammates": 3, "crew_ai": true, "skip_casing": true})
	for slot: int in 4:
		Modifiers.set_source(slot, &"perf.immune", {&"defense.damage_taken_mult": 0.0})  # crew stay at their spawns, on the map
	await wait_physics_frames(120)
	var calm: Dictionary = await _measure("calm")
	AnimLod.allow_headless = true  # what a player's machine runs: the D-132 LOD against the local camera
	_ensure_camera()
	var calm_lod: Dictionary = await _measure("calm_lod")
	print("PERF ah calm_lod bands: %s" % _bands())
	AnimLod.allow_headless = false
	_rt.stealth.raise_alarm(&"perf", 0)
	await wait_physics_frames(60)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	_fill_to_cap(dir)
	await wait_physics_frames(120)
	_fill_to_cap(dir)
	var loud: Dictionary = await _measure("loud")
	for slot: int in 4:  # the crew somewhere the police cannot path to (off the navmesh): the unreachable-target case
		_rt.teleport_crew(slot, Transform3D(Basis.IDENTITY, Vector3(-30, 0.05, -30) + Vector3(2.0 * slot, 0, 0)))
	await wait_physics_frames(60)
	var unreach: Dictionary = await _measure("loud_unreachable")
	assert_true(float(unreach["tick_ms"]) < BUDGET_LOUD_TICK_MS, "loud, crew unreachable: wall per physics tick %.2f ms < %.0f" % [
		unreach["tick_ms"], BUDGET_LOUD_TICK_MS])
	assert_true(float(calm_lod["tick_ms"]) <= float(calm["tick_ms"]) * 1.1 + 0.5, "the LOD never costs more: %.2f vs %.2f ms" % [
		calm_lod["tick_ms"], calm["tick_ms"]])
	assert_true(float(calm["tick_ms"]) < BUDGET_CALM_TICK_MS, "calm: wall per physics tick %.2f ms < %.0f" % [calm["tick_ms"],
		BUDGET_CALM_TICK_MS])
	assert_true(float(loud["tick_ms"]) < BUDGET_LOUD_TICK_MS, "loud: wall per physics tick %.2f ms < %.0f" % [loud["tick_ms"],
		BUDGET_LOUD_TICK_MS])


func _measure(tag: String) -> Dictionary:
	FrameProf.enabled = true
	FrameProf.totals.clear()
	var proc: float = 0.0
	var f0: int = Time.get_ticks_usec()
	for _i: int in SAMPLE_FRAMES:
		FrameProf.reset_frame()
		await get_tree().process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var frame_ms: float = (Time.get_ticks_usec() - f0) / 1000.0 / SAMPLE_FRAMES
	var top: String = _top_totals(24)
	FrameProf.enabled = false
	var hz: int = Engine.physics_ticks_per_second
	var steps: int = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = SATURATE_HZ
	Engine.max_physics_steps_per_frame = 16
	await wait_frames(10)
	var t0: int = Time.get_ticks_usec()
	var k0: int = Engine.get_physics_frames()
	await wait_frames(120)
	var tick_ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / maxf(float(Engine.get_physics_frames() - k0), 1.0)
	Engine.physics_ticks_per_second = hz
	Engine.max_physics_steps_per_frame = steps
	var civs: int = _rt.npcs(&"civilian").size()
	var npcs: int = _rt.npcs().size()
	print("PERF ah %s: %d NPCs (%d civilians) | wall per physics tick %.2f ms | process avg %.2f ms | wall per frame %.2f ms" \
		% [tag, npcs, civs, tick_ms, proc / SAMPLE_FRAMES, frame_ms])
	print("PERF ah %s per-system ms/frame: %s" % [tag, top])
	return {"tick_ms": tick_ms, "npcs": npcs}


## The local player's camera if the runtime made one, else one at slot 0's eyes looking along its spawn.
func _ensure_camera() -> void:
	if get_viewport().get_camera_3d() == null:
		var c: Node3D = _rt.crew_controller(0) as Node3D
		var cam: Camera3D = Camera3D.new()
		_rt.add_child(cam)
		cam.global_transform = c.global_transform.translated(Vector3(0, 1.65, 0)) if c != null else Transform3D.IDENTITY
		cam.current = true
	AnimLod.invalidate()


func _bands() -> Dictionary:
	var n: Dictionary = {}
	for npc: Node in _rt.npcs():
		var d: AnimDriver = AnimDriver.of(npc)
		if d != null and d.lod != null:
			var k: String = AnimLod.Band.keys()[d.lod.band]
			n[k] = int(n.get(k, 0)) + 1
	return n


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


func _top_totals(n: int) -> String:
	var keys: Array = FrameProf.totals.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(FrameProf.totals[a]) > int(FrameProf.totals[b]))
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(mini(n, keys.size())):
		parts.append("%s=%.2f" % [keys[i], int(FrameProf.totals[keys[i]]) / 1000.0 / SAMPLE_FRAMES])
	return " ".join(parts)
