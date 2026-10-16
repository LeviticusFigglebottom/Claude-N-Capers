## DET (loud-path determinism audit): two runs of one seed in loud replay the same. Golden Hour (glasshouse)
## at HAZARDOUS, alarm raised at once, crew AI bots on (mortal; the diagnostic can make them immune), the director with events; the
## DetTrace of both runs (spawns, shots, damage, kills, unit positions / targets) must hash the same.
## DET_JITTER=1 adds per-frame wall-clock jitter (OS.delay_usec in _process), exposing decisions that hang on
## the render-frame rate instead of the fixed physics tick.
extends TestCase

const SEED: int = 1792002290
const RUN_S: float = 40.0
const TIME_SCALE: float = 2.0
const CORPSE_SCENE: String = "res://world/characters/security_officer/security_officer.tscn"

var _rt: HeistRuntime = null
var _jitter: FrameJitter = null
var _phys_drivers: Array[AnimDriver] = []


func after_each() -> void:
	Engine.time_scale = 1.0
	if _jitter != null and is_instance_valid(_jitter):
		_jitter.queue_free()
	_jitter = null
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


class FrameJitter:
	extends Node
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()  # test-only wall-clock noise (not gameplay)
	var max_us: int = 40000

	func _ready() -> void:
		rng.seed = Time.get_ticks_usec()
		process_priority = -1000

	func _process(_d: float) -> void:
		OS.delay_usec(rng.randi_range(0, max_us))


func _run(seed: int, run_s: float, jitter: bool, immune: bool = true, opts: Dictionary = {}) -> DetTrace:
	if not bool(opts.get("nav_sync", true)):  # the engine default (the shared world map keeps the last setting)
		NavigationServer3D.map_set_use_async_iterations(get_viewport().world_3d.navigation_map, true)
	if jitter:
		_jitter = FrameJitter.new()
		_jitter.max_us = int(opts.get("jitter_us", 40000))
		add_child(_jitter)
	var heist: StringName = StringName(opts.get("heist", &"glasshouse"))
	_rt = await HeistLauncher.launch(heist, seed, Enums.Difficulty.HAZARDOUS, self, opts)
	assert_true(_rt != null, "launched")
	if _rt == null:
		return null
	var trace: DetTrace = DetTrace.new()
	if OS.get_environment("DET_SAMPLE") != "":
		trace.sample_ticks = int(OS.get_environment("DET_SAMPLE"))
	add_child(trace)
	trace.start(_rt)
	if immune:
		for s: int in _rt.crew_members().size():
			Modifiers.set_source(s, &"diag.immune", {&"defense.damage_taken_mult": 0.0})
	for c: CrewController in _rt.crew_members():
		c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	Engine.time_scale = TIME_SCALE
	await wait_physics_frames(int(run_s * Engine.physics_ticks_per_second / TIME_SCALE))
	Engine.time_scale = 1.0
	trace.stop()
	trace.get_parent().remove_child(trace)
	if _jitter != null:
		_jitter.queue_free()
		_jitter = null
	if immune:
		for s: int in _rt.crew_members().size():
			Modifiers.clear_source(s, &"diag.immune")
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	return trace


## The director with the pre-assault phases cut short, so a short run reaches BUILD / SUSTAIN (and its events).
static func fast_director() -> DirectorTweak:
	var tw: DirectorTweak = (load("res://systems/director/director_tweak.tres") as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 3.0
	tw.anticipation_s = 2.0
	tw.build_s = 15.0
	return tw


static func counts(t: DetTrace) -> String:
	var c: Dictionary = {}
	for l: String in t.lines:
		var k: String = l.get_slice(" ", 1)
		c[k] = int(c.get(k, 0)) + 1
	return str(c)


static func _report(a: DetTrace, b: DetTrace) -> int:
	print("[DET] counts A %s" % counts(a))
	print("[DET] counts B %s" % counts(b))
	var i: int = DetTrace.first_divergence(a.lines, b.lines)
	var ha: PackedInt64Array = a.bucket_hashes()
	var hb: PackedInt64Array = b.bucket_hashes()
	var first_bucket: int = -1
	for k: int in mini(ha.size(), hb.size()):
		if ha[k] != hb[k]:
			first_bucket = k
			break
	print("[DET] lines %d / %d, buckets %d / %d, first differing bucket %d, first differing line %d" % [
		a.lines.size(), b.lines.size(), ha.size(), hb.size(), first_bucket, i])
	if i >= 0:
		for k: int in range(maxi(i - 6, 0), mini(i + 6, mini(a.lines.size(), b.lines.size()))):
			var mark: String = "  " if a.lines[k] == b.lines[k] else "!!"
			print("[DET] %s A: %s" % [mark, a.lines[k]])
			if a.lines[k] != b.lines[k]:
				print("[DET] %s B: %s" % [mark, b.lines[k]])
		var shown: int = 0
		for k: int in range(i, mini(a.lines.size(), b.lines.size())):
			if a.lines[k] != b.lines[k] and shown < int(OS.get_environment("DET_SHOW") if OS.get_environment("DET_SHOW") != "" else "25"):
				shown += 1
				print("[DET] diff A: %s\n[DET] diff B: %s" % [a.lines[k], b.lines[k]])
	return i


## DET fix: the heist's navigation map and regions iterate synchronously (no thread-timed map updates).
func test_det_heist_navigation_iterates_synchronously() -> void:
	NavigationServer3D.map_set_use_async_iterations(get_viewport().world_3d.navigation_map, true)  # engine default
	_rt = await HeistLauncher.launch(&"glasshouse", SEED, Enums.Difficulty.HAZARDOUS, self, {})
	assert_true(_rt != null, "launched")
	var map_rid: RID = _rt.map.get_world_3d().navigation_map
	assert_false(NavigationServer3D.map_get_use_async_iterations(map_rid), "map iterates on the physics frame")
	var regions: int = 0
	for n: Node in _rt.map.find_children("*", "NavigationRegion3D", true, false):
		regions += 1
		assert_false(NavigationServer3D.region_get_use_async_iterations((n as NavigationRegion3D).get_rid()),
			"region %s iterates synchronously" % n.name)
	assert_true(regions > 0, "the map has navigation regions")


## DET: two loud runs of one seed (mortal crew AI, fast director, render-frame jitter) give the same trace:
## same spawns, shots, damage, kills, downs and unit positions / targets, second by second.
func test_det_same_seed_loud_runs_replay_identically() -> void:
	var opts: Dictionary = {"director_tweak": fast_director(), "jitter_us": 8000}
	var a: DetTrace = await _run(SEED, 30.0, true, false, opts)
	var b: DetTrace = await _run(SEED, 30.0, true, false, opts)
	assert_true(a != null and b != null, "both runs traced")
	if a == null or b == null:
		return
	var div: int = _report(a, b)
	var c: String = counts(a)
	var la: String = a.lines[div] if div >= 0 and div < a.lines.size() else "-"
	var lb: String = b.lines[div] if div >= 0 and div < b.lines.size() else "-"
	assert_eq(div, -1, "first divergence at line %d (%s vs %s)" % [div, la, lb])
	assert_eq(a.bucket_hashes(), b.bucket_hashes(), "per-second trace hashes")
	assert_true(c.contains("\"spawn\"") and c.contains("\"fire\"") and c.contains("\"dmg\""),
		"the run saw an assault (spawns, shots, damage): %s" % c)
	a.free()
	b.free()


func _diag_runs() -> int:
	return int(OS.get_environment("DET_RUNS")) if OS.get_environment("DET_RUNS") != "" else 0


## Diagnostic (DET_RUNS=n, default off): n same-seed runs, each compared with the first.
func test_det_diag_same_seed_runs() -> void:
	var n: int = _diag_runs()
	if n <= 0:
		skip("DET_RUNS not set (diagnostic)")
		return
	var jitter: bool = OS.get_environment("DET_JITTER") == "1"
	var run_s: float = float(OS.get_environment("DET_RUN_S")) if OS.get_environment("DET_RUN_S") != "" else RUN_S
	var immune: bool = OS.get_environment("DET_MORTAL") != "1"
	var opts: Dictionary = {"nav_sync": false} if OS.get_environment("DET_NAV_ASYNC") == "1" else {}
	if OS.get_environment("DET_HEIST") != "":
		opts["heist"] = OS.get_environment("DET_HEIST")
	if OS.get_environment("DET_FULL_TIMING") != "1":
		opts["director_tweak"] = fast_director()
	var first: DetTrace = await _run(SEED, run_s, jitter, immune, opts)
	for r: int in range(1, n):
		var t: DetTrace = await _run(SEED, run_s, jitter, immune, opts)
		print("[DET] run %d vs run 0 (jitter=%s immune=%s):" % [r, jitter, immune])
		_report(first, t)
		t.free()
	first.free()


# --- Corpse diagnostic (DET_CORPSE=1): death clip -> settle ragdoll vs frame timing --------------------------

func _tick_drivers() -> void:
	for d: AnimDriver in _phys_drivers:
		if is_instance_valid(d):
			d.tick(get_physics_process_delta_time())


func _corpse_run(jitter: bool, shotgun: bool, phys_anim: bool = false) -> String:
	var root: Node3D = Node3D.new()
	add_child(root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(col)
	root.add_child(floor_body)
	var jit: FrameJitter = null
	if jitter:
		jit = FrameJitter.new()
		root.add_child(jit)
	var npcs: Array[NpcBase] = []
	for i: int in 4:
		var npc: NpcBase = NpcBase.new()
		npc.name = "C%d" % i
		npc.role = &"guard"
		npc.visual_scene = load(CORPSE_SCENE) as PackedScene
		var visual: Node3D = Node3D.new()
		visual.name = "Visual"
		npc.add_child(visual)
		npc.position = Vector3(-40.0 + 3.0 * i, 0.0, 0.0)
		root.add_child(npc)
		npc.max_health = 100.0
		npc.health = 100.0
		npc.alert_state = Enums.AlertState.COMBAT
		npcs.append(npc)
	if phys_anim:  # experiment: the NPC animation advanced on the physics tick instead of the render frame
		await wait_frames(1)
		for n: NpcBase in npcs:
			var drv: AnimDriver = AnimDriver.of(n)
			if drv != null:
				drv.set_process(false)
				_phys_drivers.append(drv)
				if drv.player != null:
					drv.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		get_tree().physics_frame.connect(_tick_drivers)
	await wait_physics_frames(3)
	for i: int in npcs.size():
		var n: NpcBase = npcs[i]
		var dir: Vector3 = Vector3(0.3 * (i - 1.5), 0.0, 1.0).normalized()
		var hits: int = 10 if shotgun else 1
		for k: int in hits:
			var d: Dictionary = Damage.info(30.0 if shotgun else 500.0, Enums.DamageType.BULLET, Enums.HitZone.BODY,
				&"weapon.brute_12" if shotgun else &"weapon.kestrel_p9", n.global_position + Vector3(0.02 * k, 1.3, 0.0), dir)
			d["range_m"] = 1.0 if shotgun else 20.0
			n.take_hit(d)
	await wait_physics_frames(roundi(6.0 * Engine.physics_ticks_per_second))
	var sig: PackedStringArray = PackedStringArray()
	for n: NpcBase in npcs:
		var rd: NpcRagdoll = NpcRagdoll.of(n)
		var hb: Node3D = n.get_node_or_null(NpcBase.CORPSE_HITBOX) as Node3D
		sig.append("%s root=%s hb=%s ph=%d fz=%d" % [n.name, DetTrace.v3(n.global_position),
			DetTrace.v3(hb.global_position) if hb else "-", rd.phase if rd else -1, rd.freezes if rd else -1])
	if phys_anim:
		get_tree().physics_frame.disconnect(_tick_drivers)
		_phys_drivers.clear()
	root.queue_free()
	await wait_physics_frames(2)
	return "\n".join(sig)


func test_det_diag_corpse_settle() -> void:
	if OS.get_environment("DET_CORPSE") != "1":
		skip("DET_CORPSE not set (diagnostic)")
		return
	var phys: bool = OS.get_environment("DET_PHYS_ANIM") == "1"
	for shotgun: bool in [false, true]:
		var base: String = await _corpse_run(false, shotgun, phys)
		var again: String = await _corpse_run(false, shotgun, phys)
		var jit: String = await _corpse_run(true, shotgun, phys)
		print("[DET] corpse phys_anim=%s shotgun=%s" % [phys, shotgun])
		print("[DET] corpse shotgun=%s\n[DET] base:\n%s\n[DET] same=%s jitter_same=%s\n[DET] jitter:\n%s" % [shotgun, base,
			base == again, base == jit, jit])


# --- Bag diagnostic (DET_BAGS=1): thrown RigidBody loot bags tumbling over a tilted box ----------------------

func _bag_run() -> String:
	var root: Node3D = Node3D.new()
	add_child(root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(col)
	var box: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(1.0, 0.6, 3.0)
	box.shape = bs
	box.transform = Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(62.0, 0.3, 0.0))
	floor_body.add_child(box)
	root.add_child(floor_body)
	var bags: Array[LootBag] = []
	for i: int in 6:
		var bag: LootBag = (load("res://systems/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
		bag.name = "Bag%d" % i
		root.add_child(bag)
		bag.global_position = Vector3(60.0 + 0.3 * i, 1.5 + 0.4 * i, 0.0)
		bags.append(bag)
	await wait_physics_frames(2)
	for i: int in bags.size():
		bags[i].release(bags[i].global_position, Vector3(3.0, 2.0, 0.5 * (i - 2.5)), true)
	await wait_physics_frames(roundi(4.0 * Engine.physics_ticks_per_second))
	var sig: PackedStringArray = PackedStringArray()
	for b: LootBag in bags:
		sig.append("%s %s" % [b.name, DetTrace.v3(b.global_position)])
	root.queue_free()
	await wait_physics_frames(2)
	return "\n".join(sig)


func test_det_diag_bag_throw() -> void:
	if OS.get_environment("DET_BAGS") != "1":
		skip("DET_BAGS not set (diagnostic)")
		return
	var a: String = await _bag_run()
	var b: String = await _bag_run()
	var c: String = await _bag_run()
	print("[DET] bags same=%s/%s\n[DET] A:\n%s\n[DET] B:\n%s\n[DET] C:\n%s" % [a == b, a == c, a, b, c])
