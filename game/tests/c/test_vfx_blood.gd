## D-113 blood (VfxBlood via VfxDirector): gore Full / Reduced / Off, both blood sources (EventBus.blood_hit /
## bleed_changed, and the shot_fx-flag + npc_killed fallback), splatter behind the target, growing pools, caps,
## determinism with a fixed GameRng run seed. Headless.
extends TestCase

const WALL_Z: float = -1.5
const SHOOTER: Vector3 = Vector3(0.0, 1.4, 6.0)
const HIT: Vector3 = Vector3(0.0, 1.3, 0.0)

var _d: VfxDirector
var _world: Array[Node] = []


func before_each() -> void:
	VfxSettings.reset()
	GameRng.begin_run(1234)
	_d = VfxDirector.new()
	_d.listen_to_event_bus = false
	_d.use_game_settings = false
	_d.auto_advance = false
	_d.play_impact_cues = false
	add_child(_d)
	# A wall 1.5 m behind the target and a floor (world_static).
	_world.append(_static_box(Vector3(0, 1.5, WALL_Z), Vector3(6, 3, 0.2)))
	_world.append(_static_box(Vector3(0, -0.1, 0), Vector3(6, 0.2, 6)))
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_d):
		_d.free()
	_d = null
	for n: Node in _world:
		if is_instance_valid(n):
			n.free()
	_world.clear()
	VfxSettings.reset()


func _static_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	b.position = pos
	add_child(b)
	return b


func _flesh_shot(flags: int = 0, point: Vector3 = HIT) -> void:
	_d.on_shot_fx(SHOOTER, point, (SHOOTER - point).normalized(), &"flesh", &"assault_rifle", 7, flags)


func _signal_hit(headshot: bool = false, exit_point: Vector3 = Vector3.INF) -> void:
	_d.on_blood_hit(9, HIT, (HIT - SHOOTER).normalized(), Vector3.ZERO, 0.6, headshot, exit_point, &"npc")


func test_fallback_spray_and_splatter_behind_target() -> void:
	_d.blood_from_signals = false
	_flesh_shot()
	assert_eq(_d.blood.sprays_fired, 1, "one spray along the shot")
	assert_eq(_d.blood.splats.live >= 1, true, "a splatter decal")
	var splat: Node3D = _d.blood.splats.get_child(0) as Node3D
	assert_near(splat.global_position.z, WALL_Z + 0.1, 0.05, "on the wall face behind the target")
	assert_true(splat.global_position.y < HIT.y + 0.1, "follows the slightly downward shot")
	assert_eq(_d.impacts.fired, 1, "the flesh impact puff still fires")


func test_fallback_flags_exit_strong_headshot() -> void:
	_d.blood_from_signals = false
	_flesh_shot(VfxDirector.FLAG_PENETRATED)
	assert_eq(_d.blood.sprays_fired, 2, "penetrated: entry spray + exit spurt")
	var before: int = _d.blood.sprays_fired
	_flesh_shot(VfxDirector.FLAG_HEADSHOT | VfxDirector.FLAG_STRONG, Vector3(0, 1.7, 0))
	assert_eq(_d.blood.sprays_fired, before + 1)
	var spray: Node3D = _d.blood._sprays[_d.blood._cursor]
	assert_true(spray.basis.get_scale().x > 1.5, "headshot + strong spray is bigger (%s)" % spray.basis.get_scale())


func test_signal_path_has_no_doubles() -> void:
	_d.blood_from_signals = true
	_flesh_shot(VfxDirector.FLAG_PENETRATED)
	assert_eq(_d.blood.sprays_fired, 0, "shot_fx draws no blood when blood_hit exists")
	assert_eq(_d.blood.splats.live, 0)
	assert_eq(_d.impacts.fired, 1, "flesh impact puff only")
	_signal_hit()
	assert_eq(_d.blood.sprays_fired, 1, "blood_hit: spray")
	assert_true(_d.blood.splats.live >= 1, "blood_hit: splatter behind (normal ZERO -> raycast)")
	_signal_hit(false, HIT + Vector3(0, 0, -0.7))
	assert_eq(_d.blood.sprays_fired, 3, "exit_point set: entry spray + exit spurt")
	_d.on_npc_killed(9, 1, {"position": Vector3.ZERO})
	assert_eq(_d.blood.pools.live, 0, "npc_killed handler is not the pool source on the signal path")


func test_signal_bleed_pool_grows_and_stops() -> void:
	_d.blood_from_signals = true
	_d.on_bleed_changed(42, true, Vector3(0.3, 0.0, 0.5), 1.0)
	assert_eq(_d.blood.pools.live, 1, "pool placed")
	var pool: Node3D = _d.blood.pool_of(42)
	assert_true(pool != null and _d.blood.pools.is_growing(pool), "growing")
	assert_near(pool.global_position.y, 0.0, 0.02, "on the floor")
	var s0: float = _d.blood.pools.size_of(pool).x
	_d.advance(2.0)
	var s1: float = _d.blood.pools.size_of(pool).x
	assert_true(s1 > s0, "grows (%.2f -> %.2f)" % [s0, s1])
	_d.on_bleed_changed(42, false, Vector3.ZERO, 0.0)
	_d.advance(3.0)
	assert_near(_d.blood.pools.size_of(pool).x, s1, 0.0001, "stopped: no more growth")
	_d.on_bleed_changed(43, true, Vector3(-0.5, 0.0, 0.5), 0.6)
	_d.advance(VfxSettings.POOL_GROW_S * 2.0)
	var p2: Node3D = _d.blood.pool_of(43)
	assert_true(_d.blood.pools.size_of(p2).x <= VfxSettings.POOL_MAX_M * 1.1, "capped at POOL_MAX_M")
	assert_false(_d.blood.pools.is_growing(p2), "growth ends at full size")
	_d.on_body_bagged(43, 7, 0)
	assert_eq(_d.blood.splats.live, 1, "bagging leaves a small smear")


## PO6-19: A re-sends bleed_changed(true) when the ragdoll settles > 0.5 m away; the body keeps one pool, moved there.
func test_repeated_bleed_start_moves_the_one_pool() -> void:
	_d.blood_from_signals = true
	_d.on_bleed_changed(50, true, Vector3(0.0, 0.0, 0.5), 1.0)
	_d.on_bleed_changed(50, true, Vector3(0.1, 0.0, 0.5), 1.0)
	assert_eq(_d.blood.pools.live, 1, "a start near the pool keeps it")
	_d.on_bleed_changed(50, true, Vector3(1.2, 0.0, 0.5), 1.0)
	assert_eq(_d.blood.pools.live, 1, "a start elsewhere restarts the body's one pool")
	var pool: Node3D = _d.blood.pool_of(50)
	assert_true(pool != null and pool.visible, "the pool is live")
	assert_near(pool.global_position.x, 1.2, 0.05, "at the settled position")
	assert_true(_d.blood.pools.is_growing(pool), "growing again")


func test_fallback_npc_killed_pool_and_death_splatter() -> void:
	_d.blood_from_signals = false
	_d.on_npc_killed(5, 1, {})
	assert_eq(_d.blood.pools.live, 0, "no position: skipped")
	_d.on_npc_killed(5, 1, {"position": Vector3(0, 0, 0.3), "hit_dir": Vector3(0, 0, -1)})
	assert_eq(_d.blood.pools.live, 1, "pool under the body")
	assert_eq(_d.blood.splats.live, 1, "death-shot splatter on the wall along hit_dir")
	_d.on_crew_downed(2, 1)  # no HeistRuntime in a test: nothing, no error
	_d.on_crew_revived(2, 0)
	assert_eq(_d.blood.pools.live, 1)


func test_gore_off_has_no_blood() -> void:
	VfxSettings.gore = VfxSettings.GORE_OFF
	for from_signals: bool in [false, true]:
		_d.blood_from_signals = from_signals
		_flesh_shot(VfxDirector.FLAG_HEADSHOT | VfxDirector.FLAG_PENETRATED)
		_signal_hit(true, HIT + Vector3(0, 0, -0.7))
		_d.on_bleed_changed(1, true, Vector3.ZERO, 1.0)
		_d.on_npc_killed(2, 1, {"position": Vector3.ZERO, "hit_dir": Vector3.FORWARD})
	assert_eq(_d.blood.sprays_fired, 0, "no spray")
	assert_eq(_d.blood.spray_count(), 0, "no spray nodes")
	assert_eq(_d.blood.splats.slot_count(), 0, "no blood decal nodes")
	assert_eq(_d.blood.pools.slot_count(), 0, "no pool nodes")
	assert_true(_d.impacts._sets.has(ImpactFx.FLESH_DUST), "flesh falls back to a dust puff")
	assert_false(_d.impacts._sets.has(&"flesh"), "no blood puff")


func test_gore_reduced_has_no_pools_and_fainter_splatter() -> void:
	VfxSettings.gore = VfxSettings.GORE_REDUCED
	_d.blood_from_signals = true
	_signal_hit(true, HIT + Vector3(0, 0, -0.7))
	assert_eq(_d.blood.splats.live, 1, "one splatter only (no second splatter, no drips)")
	assert_true(_d.blood.splats._peak[0] < 1.0, "fainter")
	_d.on_bleed_changed(1, true, Vector3.ZERO, 1.0)
	assert_eq(_d.blood.pools.live, 0, "no pools")
	_d.on_body_bagged(1, 2, 0)
	assert_eq(_d.blood.splats.live, 1, "no smear")


func test_gore_switch_to_off_clears_blood() -> void:
	_d.blood_from_signals = true
	_signal_hit()
	_d.on_bleed_changed(1, true, Vector3.ZERO, 1.0)
	VfxSettings.gore = VfxSettings.GORE_OFF
	_d.advance(0.0)
	assert_eq(_d.blood.splats.live + _d.blood.pools.live, 0, "cleared")


func test_caps_respected() -> void:
	_d.blood_from_signals = true
	for i: int in range(400):
		var p: Vector3 = Vector3(float(i % 9) * 0.3 - 1.2, 0.8 + float(i % 5) * 0.2, 0.0)
		_d.on_blood_hit(i, p, Vector3(0, -0.1, -1).normalized(), Vector3.ZERO, 1.0, i % 3 == 0, p + Vector3(0, 0, -0.7),
			&"npc")
		_d.on_bleed_changed(i, true, Vector3(float(i % 11) * 0.4 - 2.0, 0.0, 1.0), 1.0)
		if i % 4 == 0:
			_d.advance(1.0 / 30.0)
	var s: Dictionary = _d.stats()
	assert_true(int(s["blood_sprays"]) <= VfxSettings.BLOOD_SPRAY_CAP, "sprays %s" % s)
	assert_eq(int(s["blood_decals"]), VfxSettings.BLOOD_DECAL_CAP, "decal pool full and recycling")
	assert_eq(_d.blood.splats.get_child_count(), VfxSettings.BLOOD_DECAL_CAP, "no decal nodes beyond the cap")
	assert_eq(int(s["blood_pools"]), VfxSettings.BLOOD_POOL_CAP, "pool cap")
	assert_true(_d.blood.body_count() <= VfxBlood.MAX_BODIES, "tracked bodies bounded")
	VfxSettings.set_quality(VfxSettings.Quality.LOW)
	_d.advance(0.0)
	assert_true(_d.blood.splats.cap() < VfxSettings.BLOOD_DECAL_CAP, "quality scales blood caps")
	assert_true(_d.blood.spray_cap() < VfxSettings.BLOOD_SPRAY_CAP)


func test_splatter_fades() -> void:
	_d.blood_from_signals = true
	_signal_hit()
	_d.advance(VfxSettings.BLOOD_HOLD_S + VfxSettings.BLOOD_FADE_S + 0.5)
	assert_eq(_d.blood.splats.live, 0, "faded out")


func test_deterministic_with_fixed_seed() -> void:
	var a: Array = _run_sequence()
	_d.clear()
	var b: Array = _run_sequence()
	assert_eq(a.size(), b.size())
	assert_eq(str(a), str(b), "same seed, same splatter shapes, sizes and rotations")


func _run_sequence() -> Array:
	GameRng.begin_run(777)
	_d.blood_from_signals = true
	var out: Array = []
	for i: int in range(6):
		_d.on_blood_hit(i, HIT + Vector3(i * 0.1, 0, 0), Vector3(0, -0.05, -1).normalized(), Vector3.ZERO, 0.7,
			i == 2, Vector3.INF, &"npc")
	for c: Node in _d.blood.splats.get_children():
		var n: Node3D = c as Node3D
		if n.visible:
			out.append([n.global_position.snapped(Vector3.ONE * 0.0001), n.global_basis.x.snapped(Vector3.ONE * 0.0001),
				_d.blood.splats.size_of(n)])
	return out


func test_gore_from_game_settings() -> void:
	assert_eq(VfxSettings.gore_from(null), VfxSettings.GORE_FULL, "no settings: Full")
	assert_eq(VfxSettings.gore_from(_GoreStub.new(&"reduced")), VfxSettings.GORE_REDUCED)
	assert_eq(VfxSettings.gore_from(_GoreStub.new(&"off")), VfxSettings.GORE_OFF)
	assert_eq(VfxSettings.gore_from(_GoreStub.new(&"bogus")), VfxSettings.GORE_FULL, "unknown: Full")
	var gs: GameSettings = GameSettings.new()
	var expect: StringName = VfxSettings.GORE_FULL
	if gs.has_method(VfxSettings.GORE_METHOD):
		gs.set_value(&"gameplay", &"gore", &"off")
		expect = VfxSettings.GORE_OFF
	VfxSettings.sync_from_game_settings(gs)
	assert_eq(VfxSettings.gore, expect, "synced from GameSettings (Full when gore() does not exist yet)")


class _GoreStub:
	extends RefCounted
	var _g: StringName

	func _init(g: StringName) -> void:
		_g = g

	func gore() -> StringName:
		return _g
