## PO-5.4 / KR-1: the director's alive force on Routine (PD2 Normal) for 1 human + 3 AI teammates.
## L1.1 FADE stops spawning and retreats, L1.3 stage force (50 / 75 / 100%), PD2 crew balance (bots
## count half), per-assault force pool, PD2 specials by difficulty (no Stinger / Corpsman / Wrecker /
## Phantom on Routine). Runs the real AssaultDirector headless on the dev sandbox, compressed timings.
extends TestCase

const DEFAULT_TWEAK: String = "res://systems/director/director_tweak.tres"
const GROUPS: String = "res://systems/ai/data/groups/"
const TIME_SCALE: float = 4.0

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## Routine, guards removed, every crew member immune; AI teammates idle (crew_ai off) so the alive
## count is decided by the director alone.
func _launch(bots: int, options: Dictionary = {}) -> HeistRuntime:
	options["ai_teammates"] = bots
	options["crew_ai"] = false
	options["captain"] = false
	_rt = await HeistLauncher.launch(&"dev_sandbox", 5401, Enums.Difficulty.ROUTINE, self, options)
	for g: Node in _rt.npcs(&"guard"):
		(g as NpcBase).die()
	for s: int in range(bots + 1):
		Modifiers.set_source(s, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	return _rt


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func _fast_tweak() -> DirectorTweak:
	var tw: DirectorTweak = (load(DEFAULT_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 3.0
	tw.control_between_waves_s = 3.0
	tw.anticipation_s = 1.0
	tw.build_s = 8.0
	tw.sustain_by_stage_s = PackedFloat32Array([12.0, 14.0, 16.0])
	tw.fade_wait_cap_s = 1.0
	tw.fade_s = 25.0
	tw.assault_group_interval_s = 1.0
	tw.unit_spawn_interval_s = 0.25
	return tw


func test_po5_force_cap_by_crew_and_stage() -> void:
	await _launch(3)
	var d: AssaultDirector = _director()
	assert_eq(d.enemy_cap(), 16, "Routine enemy_cap (full crew)")
	assert_eq(d._force_crew_count(), 2, "1 human + 3 bots = PD2 force crew 2 (bots count max(1, floor(3/2)))")
	assert_eq(d.force_cap(1), 4, "wave 1 (50%): 16 x 0.5 x 0.5")
	assert_eq(d.force_cap(2), 6, "wave 2 (75%)")
	assert_eq(d.force_cap(3), 8, "wave 3+ (100%)")
	assert_eq(d.force_cap(7), 8, "wave 7 stays at 100%")
	assert_eq(d._force_pool(1), ceili(8.0 * 10.3 * 0.6), "wave 1 force pool (PD2 175 / 17 per force; PO-17 Routine x0.6)")
	assert_true(d._force_pool(3) > d._force_pool(1), "later waves have a larger pool")
	assert_true(d.police_budget() <= d.force_cap(), "police budget bounded by the force cap")


func test_po5_solo_force_floor() -> void:
	await _launch(0)
	var d: AssaultDirector = _director()
	assert_eq(d._force_crew_count(), 1, "solo")
	assert_eq(d.force_cap(1), 4, "solo Routine wave 1 at the force_min floor")
	assert_eq(d.force_cap(3), 4, "solo Routine wave 3: 16 x 0.25")


func test_po5_routine_specials_match_pd2_normal() -> void:
	var forbidden: Array[String] = ["special_stinger", "special_corpsman", "special_wrecker_g", "special_wrecker_b",
		"special_wrecker_s", "special_wrecker_m", "special_phantom", "control_stinger", "control_bulwark",
		"control_phantom"]
	for f: String in forbidden:
		var g: SpawnGroupDef = load(GROUPS + f + ".tres") as SpawnGroupDef
		for st: int in range(3):
			assert_eq(g.weight_for(Enums.Difficulty.ROUTINE, st), 0.0, "%s never on Routine (stage %d)" % [f, st])
	var bw: SpawnGroupDef = load(GROUPS + "special_bulwark.tres") as SpawnGroupDef
	assert_true(bw.weight_for(Enums.Difficulty.ROUTINE, 1) > 0.0, "Bulwarks (PD2 shields) do come on Routine")
	for f: String in ["special_wrecker_g", "special_wrecker_b"]:
		var w: SpawnGroupDef = load(GROUPS + f + ".tres") as SpawnGroupDef
		assert_eq(w.weight_for(Enums.Difficulty.TENSE, 2), 0.0, "%s never on Tense (PD2 Hard: no Dozers)" % f)


## Three compressed waves: alive police never exceed the wave's force cap, the cap rises 4 -> 6 -> 8 and
## is reached, nothing spawns during FADE, FADE retreats (units leave the map), Routine spawns no
## Stinger / Corpsman / Wrecker / Phantom.
func test_po5_waves_capped_fade_stops_and_retreats() -> void:
	await _launch(3, {"director_tweak": _fast_tweak()})
	var d: AssaultDirector = _director()
	var peak: Dictionary[int, int] = {}
	var over: Array[String] = []
	var fade_spawns: Array[int] = []
	var bad_specials: Array[StringName] = []
	var pool_over: Array[String] = []
	var fade_start_alive: Dictionary[int, int] = {}
	var fade_end_alive: Dictionary[int, int] = {}
	var fade_ordered: Dictionary[int, Variant] = {}
	var retreating: Dictionary[int, Vector2i] = {}  # wave -> (units with a retreat order, alive) at FADE
	var on_unit: Callable = func(npc: NpcBase, _p: Node3D) -> void:
		if d.assault_phase == Enums.AssaultPhase.FADE:
			fade_spawns.append(d.wave_index)
		var id: StringName = npc.enemy_def.id if npc.enemy_def != null else &""
		if String(id).begins_with("enemy.stinger") or String(id).begins_with("enemy.corpsman") \
				or String(id).begins_with("enemy.wrecker") or String(id).begins_with("enemy.phantom"):
			bad_specials.append(id)
	var on_phase: Callable = func(p: int, w: int) -> void:
		if p == Enums.AssaultPhase.FADE:
			fade_start_alive[w] = d.alive_count()
			fade_ordered[w] = true  # orders checked on the next watch tick (given on FADE entry)
		elif p == Enums.AssaultPhase.CONTROL and w > 1:
			fade_end_alive[w - 1] = d.alive_count()
	d.unit_spawned.connect(on_unit)
	d.phase_changed.connect(on_phase)
	_rt.stealth.raise_alarm(&"test", 0)
	Engine.time_scale = TIME_SCALE
	var watch: Callable = func() -> bool:
		var w: int = d.wave_index
		var n: int = d.alive_count()
		if d.is_assault_active() and d.assault_phase != Enums.AssaultPhase.FADE:
			peak[w] = maxi(peak.get(w, 0), n)
		if d.assault_phase == Enums.AssaultPhase.FADE and fade_ordered.has(w) and not retreating.has(w):
			var ordered: int = 0
			for u: Node in d.alive_units():
				var b: PoliceBrain = u.get_node_or_null(^"Brain") as PoliceBrain
				ordered += 1 if b != null and b.has_order() else 0
			retreating[w] = Vector2i(ordered, n)
		if n > d.force_cap(w):
			over.append("wave %d phase %d: %d > %d" % [w, d.assault_phase, n, d.force_cap(w)])
		if d._force_pool() > 0 and d.assault_spawned > d._force_pool() + 2:
			pool_over.append("wave %d: %d > pool %d" % [w, d.assault_spawned, d._force_pool()])
		return d.wave_index >= 4
	var ok: bool = await wait_until(watch, 300.0)
	Engine.time_scale = 1.0
	d.unit_spawned.disconnect(on_unit)
	d.phase_changed.disconnect(on_phase)
	assert_true(ok, "three waves ran (wave %d phase %d)" % [d.wave_index, d.assault_phase])
	assert_eq(over, [] as Array[String], "alive police never above the wave's force cap")
	assert_eq(pool_over, [] as Array[String], "per-assault force pool respected")
	var start_sum: int = 0
	var end_sum: int = 0
	for w: int in [1, 2, 3]:
		assert_eq(peak.get(w, 0), d.force_cap(w), "wave %d fills exactly its force (%d)" % [w, d.force_cap(w)])
		assert_true(int(fade_start_alive.get(w, 0)) > 0, "wave %d had units at FADE" % w)
		var r: Vector2i = retreating.get(w, Vector2i(-1, -1))
		assert_true(r.x == r.y and r.y > 0, "wave %d FADE: every unit ordered to retreat (%d of %d)" % [w, r.x, r.y])
		start_sum += int(fade_start_alive.get(w, 0))
		end_sum += int(fade_end_alive.get(w, 99))
	# Leaving needs a spawn point out of every crew member's sight before FADE ends (timing-dependent per
	# wave at TIME_SCALE), so require units to have left over the three waves, not in each one.
	assert_true(end_sum < start_sum, "FADE retreat: units left the map (%d -> %d over 3 waves)" % [start_sum, end_sum])
	assert_eq(fade_spawns, [] as Array[int], "no spawns during FADE")
	assert_eq(bad_specials, [] as Array[StringName], "no PD2-Normal-forbidden specials on Routine")


## The force pool ends an assault early: BUILD/SUSTAIN go to FADE once it is spent, before the timers.
func test_po5_force_pool_spent_ends_assault() -> void:
	var tw: DirectorTweak = _fast_tweak()
	tw.build_s = 60.0
	tw.sustain_by_stage_s = PackedFloat32Array([120.0, 120.0, 120.0])
	tw.force_pool_per_force = PackedFloat32Array([0.75, 0.75, 0.75])  # pool = ceil(8 x 0.75) = 6
	tw.force_pool_difficulty_mult = PackedFloat32Array()  # PO-17's Routine x0.6 off: this test pins the pool mechanism
	tw.fade_retreat = false
	await _launch(3, {"director_tweak": tw})
	var d: AssaultDirector = _director()
	assert_eq(d._force_pool(1), 6, "test pool")
	_rt.stealth.raise_alarm(&"test", 0)
	Engine.time_scale = TIME_SCALE
	var built: bool = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.BUILD, 30.0)
	assert_true(built, "BUILD reached")
	# Kill units as they come so the alive cap never holds the pool back.
	var faded: bool = await wait_until(func() -> bool:
		for u: NpcBase in d.alive_units():
			u.die()
		return d.assault_phase == Enums.AssaultPhase.FADE, 60.0)
	Engine.time_scale = 1.0
	assert_true(faded, "FADE once the pool is spent (phase %d, spawned %d)" % [d.assault_phase, d.assault_spawned])
	assert_true(d.assault_spawned >= 6 and d.assault_spawned <= 8, "spawned the pool (+ group rest): %d" % d.assault_spawned)
	assert_eq(d.wave_index, 1, "still wave 1 (no SUSTAIN timer ran out)")
