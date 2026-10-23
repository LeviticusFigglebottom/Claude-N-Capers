## VfxDirector.prewarm (ENV A's HITCH root cause, PO-7): every pool is built to its cap at heist load, so shots during
## a fight create no nodes (a new GPU resource mid-fight stalled llvmpipe for seconds). Idempotent. Headless.
extends TestCase

var _vfx: VfxDirector


func before_each() -> void:
	VfxSettings.reset()
	GameRng.begin_run(7)
	_vfx = (load("res://world/vfx/vfx_director.tscn") as PackedScene).instantiate() as VfxDirector
	_vfx.auto_advance = false
	add_child(_vfx)


func after_each() -> void:
	if is_instance_valid(_vfx):
		_vfx.free()
	VfxSettings.reset()


func _nodes(n: Node) -> int:
	return n.get_child_count(true) + n.find_children("*", "", true, false).size()


func test_prewarm_fills_caps_and_is_idempotent() -> void:
	_vfx.prewarm()
	assert_eq(_vfx.muzzles.set_count(), _vfx.muzzles.cap(), "muzzle sets at cap")
	var n: int = _nodes(_vfx)
	_vfx.prewarm()
	assert_eq(_nodes(_vfx), n, "a second prewarm builds nothing")


func test_shots_after_prewarm_add_no_nodes() -> void:
	_vfx.prewarm()
	var n: int = _nodes(_vfx)
	for i: int in range(60):
		var o: Vector3 = Vector3(float(i % 6), 1.4, -float(i / 6))
		_vfx.on_shot_fx(o, o + Vector3(0, 0, -10), Vector3.BACK, &"concrete", [&"rifle", &"pistol", &"shotgun"][i % 3], 100 + i % 5, 0)
		_vfx.advance(0.016)
	assert_eq(_nodes(_vfx), n, "60 NPC shots after prewarm: no new nodes")


## The LEAD's A4-02 follow-up (ENV A: a 220 ms stall on the first metal impact of an AR miss, unprewarmed): after
## prewarm, every surface x weapon class (the muzzle shapes, their aliases, melee) x shot flavour (third person,
## first person, suppressed, headshot, penetrating) creates no node, no impact set, no decal and no texture, at every
## effects quality (LOW's impact total, 14, is exactly one set per surface profile) and with gore Off.
func test_every_surface_x_shot_class_after_prewarm_adds_nothing() -> void:
	var ps: PackedScene = load(_vfx.scene_file_path) as PackedScene
	for q: int in [VfxSettings.Quality.LOW, VfxSettings.Quality.MEDIUM, VfxSettings.Quality.HIGH]:
		_vfx.free()
		VfxSettings.set_quality(q)
		_vfx = ps.instantiate() as VfxDirector
		_vfx.auto_advance = false
		_vfx.use_game_settings = false   # keep the quality under test (GameSettings would sync it at _ready)
		add_child(_vfx)
		if not _every_combination(q):
			return
	VfxSettings.gore = VfxSettings.GORE_OFF   # flesh plays the flesh_dust profile (D-113)
	_vfx.free()
	_vfx = ps.instantiate() as VfxDirector
	_vfx.auto_advance = false
	_vfx.use_game_settings = false
	add_child(_vfx)
	_every_combination(VfxSettings.Quality.HIGH)


func _every_combination(q: int) -> bool:
	_vfx.prewarm()
	var classes: Array[StringName] = [VfxDirector.MELEE]
	for k: StringName in MuzzleFlash.SHAPES.keys():
		classes.append(k)
	for a: StringName in MuzzleFlash.CLASS_ALIASES.keys():
		classes.append(a)
	var surfaces: Array[StringName] = ImpactFx.SURFACES.duplicate()
	surfaces.append(&"unknown_surface")   # falls back to the default surface
	var flags: Array[int] = [0, VfxDirector.FLAG_FIRST_PERSON, VfxDirector.FLAG_SUPPRESSED, VfxDirector.FLAG_HEADSHOT,
		VfxDirector.FLAG_PENETRATED | VfxDirector.FLAG_STRONG]
	var n: int = _nodes(_vfx)
	var sets: int = _vfx.impacts.set_count()
	var tex: int = VfxTextures._cache.size()
	var shots: int = 0
	for s: StringName in surfaces:
		for c: StringName in classes:
			for f: int in flags:
				var o: Vector3 = Vector3(float(shots % 7), 1.4, -float(shots % 11))
				_vfx.on_shot_fx(o, o + Vector3(0.3, 0.0, -12.0), Vector3.BACK, s, c, 200 + shots % 9, f)
				_vfx.advance(0.016)
				shots += 1
				assert_eq(_nodes(_vfx), n, "quality %d: %s x %s (flags %d): no new node" % [q, s, c, f])
				if _nodes(_vfx) != n:
					return false
	assert_eq(_vfx.impacts.set_count(), sets, "quality %d: no impact set built after prewarm" % q)
	assert_eq(VfxTextures._cache.size(), tex, "quality %d: no procedural texture made after prewarm" % q)
	assert_true(shots >= surfaces.size() * 6 * flags.size(), "%d shots over %d surfaces" % [shots, surfaces.size()])
	return true

