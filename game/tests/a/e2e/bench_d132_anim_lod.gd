## D-132 (3) animation LOD bench: N NPCs driven by AnimDriver (real character visuals) at seeded spots between --near
## and --far metres from a camera, a fraction --behind of them behind it (off screen), half walking in place, half
## idle. Each phase simulates --frames frames at 60 fps: per frame and driver, an IDLE AnimationPlayer samples itself
## (advance(dt), what the engine does) and the driver runs its _process (step_lod: AnimLod + tick + the LOD's own
## advance); that work is timed with usec. Phases alternate `off` (AnimTweak.anim_lod_enabled false: today's cost)
## and `on`, --rounds times; "[BENCH]" lines give the mean animation ms per frame (all drivers), per driver tick,
## ticks per frame and the band mix. Excludes the deferred skeleton update (bone globals, modifiers), which also runs
## only on sampled frames under the LOD (the skeleton is MANUAL). Real frames are awaited between simulated frames
## (untimed). Owner: ENV A.
##   /opt/godot/godot --headless --path game res://tests/a/e2e/bench_d132_anim_lod.tscn -- [--n=34] [--near=4]
##     [--far=45] [--behind=0.3] [--frames=300] [--rounds=2] [--seed=1] [--ids=gallery_guard,civilian_clerk,...]
extends Node

var _ids: PackedStringArray = ["gallery_guard", "civilian_clerk", "club_patron", "bank_customer", "dock_worker",
	"gallery_attendant"]
var _n: int = 34
var _near: float = 4.0
var _far: float = 45.0
var _behind: float = 0.3
var _frames: int = 300
var _seed: int = 1
var _rounds: int = 2
## phase -> animation ms per frame of each round.
var _results: Dictionary = {}
## Simulated frame number.
var _frame: int = 0
var _drivers: Array[AnimDriver] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"ids": _ids = v.split(",")
			"n": _n = int(v)
			"near": _near = float(v)
			"far": _far = float(v)
			"behind": _behind = float(v)
			"frames": _frames = int(v)
			"seed": _seed = int(v)
			"rounds": _rounds = int(v)
	Engine.max_fps = 0
	AnimLod.allow_headless = true  # the bench measures the LOD; headless otherwise runs full rate
	await _bench()
	get_tree().quit(0)


func _bench() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()  # bench placement only, not gameplay
	rng.seed = _seed
	var cam: Camera3D = Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.position = Vector3(0.0, 1.65, 0.0)
	cam.current = true
	for i: int in _n:
		var id: String = _ids[i % _ids.size()]
		var npc: NpcBase = NpcBase.new()
		npc.role = &"civilian" if i % 2 == 0 else &"guard"
		npc.net_id = 70000 + i
		var visual: Node3D = Node3D.new()
		visual.name = "Visual"
		visual.add_child((load("res://world/characters/%s/%s.tscn" % [id, id]) as PackedScene).instantiate())
		npc.add_child(visual)
		add_child(npc)
		var d: float = lerpf(_near, _far, rng.randf())
		var a: float = deg_to_rad(rng.randf_range(-30.0, 30.0))
		if rng.randf() < _behind:
			a += PI
		npc.global_position = Vector3(sin(a) * d, 0.0, -cos(a) * d)
		npc.rotation.y = rng.randf_range(0.0, TAU)
		if i % 2 == 0:
			npc.velocity = -npc.global_basis.z * 1.6  # walks in place (no motor)
		var drv: AnimDriver = AnimDriver.of(npc)
		if drv != null:
			_drivers.append(drv)
	print("[BENCH] d132 n=%d drivers=%d near=%.0f far=%.0f behind=%.2f frames=%d" % [_n, _drivers.size(), _near, _far,
		_behind, _frames])
	for d: AnimDriver in _drivers:
		d.set_process(false)  # the bench drives them
	var tw: AnimTweak = AnimTweak.data()
	for _r: int in _rounds:
		for phase: String in ["off", "on"]:
			tw.anim_lod_enabled = phase == "on"
			await _measure(phase)
	tw.anim_lod_enabled = true
	for phase: String in ["off", "on"]:
		print("[BENCH] d132 summary lod=%s animation_ms_per_frame=%.3f (mean of %d rounds, %d drivers)"
			% [phase, _mean(_results[phase]), _rounds, _drivers.size()])
	var off: float = _mean(_results["off"])
	print("[BENCH] d132 summary saving=%.0f%%" % (100.0 * (1.0 - _mean(_results["on"]) / maxf(off, 0.000001))))


static func _mean(xs: Array) -> float:
	var t: float = 0.0
	for x: float in xs:
		t += x
	return t / maxf(float(xs.size()), 1.0)


func _measure(label: String) -> void:
	var dt: float = 1.0 / 60.0
	var us: int = 0
	var bands: Dictionary = {}
	var ticks0: int = 0
	for d: AnimDriver in _drivers:
		ticks0 += d.lod.ticks
	for i: int in _frames + 30:
		_frame += 1
		var t0: int = Time.get_ticks_usec()
		for d: AnimDriver in _drivers:
			if d.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE:
				d.player.advance(dt)
			d.step_lod(dt, _frame)
		if i >= 30:  # 30 warm-up frames per phase
			us += Time.get_ticks_usec() - t0
			for d: AnimDriver in _drivers:
				var b: String = AnimLod.Band.keys()[d.lod.band]
				bands[b] = int(bands.get(b, 0)) + 1
		elif i == 29:
			ticks0 = 0
			for d: AnimDriver in _drivers:
				ticks0 += d.lod.ticks
		await get_tree().process_frame
	var ticks: int = 0
	for d: AnimDriver in _drivers:
		ticks += d.lod.ticks
	var f: float = float(_frames)
	var ms: float = float(us) / 1000.0 / f
	if not _results.has(label):
		_results[label] = []
	(_results[label] as Array).append(ms)
	var share: PackedStringArray = PackedStringArray()
	for b: String in bands:
		share.append("%s=%.1f" % [b, float(bands[b]) / f])
	print("[BENCH] d132 lod=%s animation_ms_per_frame=%.3f per_driver_ms=%.4f ticks_per_frame=%.1f bands(avg)={%s}"
		% [label, ms, ms / maxf(float(_drivers.size()), 1.0), float(ticks - ticks0) / f, ", ".join(share)])
