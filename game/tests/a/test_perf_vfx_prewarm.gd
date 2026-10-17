## PERF (windowed npc_gunner HITCH, 1-22 s): HeistRuntime builds every VFX pool at load (VfxDirector.prewarm(), ENV C)
## so no NPC shot creates nodes / GPU resources mid-fight. Rendering peers only; options.vfx_prewarm forces it.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(opts: Dictionary) -> void:
	var o: Dictionary = {"map_packed": ATestMaps.basic(1, 0), "crew_ai": false}
	o.merge(opts, true)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self, o)
	await wait_physics_frames(1)


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func test_perf_vfx_not_prewarmed_headless_by_default() -> void:
	await _launch({})
	assert_true(_rt.vfx != null, "runtime has a VfxDirector")
	assert_eq(_rt.vfx.muzzles.set_count(), 0, "headless: pools stay lazy (nothing is drawn)")


func test_perf_vfx_prewarm_fills_every_pool() -> void:
	await _launch({"vfx_prewarm": true})
	if not _rt.vfx.has_method(&"prewarm"):
		skip("VfxDirector.prewarm() is not on this branch yet (ENV C patch)")
		return
	var v: VfxDirector = _rt.vfx
	assert_eq(v.muzzles.set_count(), v.muzzles.cap(), "muzzle flashes built to cap")
	assert_eq(v.impacts.set_count(), v.impacts.caps().y, "impact sets built to the total cap")
	assert_eq(v.decals.slot_count(), v.decals.cap(), "bullet decal slots built to cap")
	assert_true(v.lights.light_count() > 0, "flash lights built")
	assert_eq(v.blood.spray_count(), v.blood.spray_cap(), "blood sprays built to cap")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var p: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	await wait_physics_frames(2)
	var before: int = _nodes()
	var gun: NpcGunner = p.get_node("Gunner") as NpcGunner
	var shots: Array[bool] = []
	var cb: Callable = func(_t: Node, hit: bool) -> void: shots.append(hit)
	gun.shot.connect(cb)
	gun.fire_at(c)
	await wait_until(func() -> bool: return shots.size() >= 4, 8.0)
	gun.hold_fire()
	assert_true(shots.size() >= 4, "police fired (%d shots)" % shots.size())
	assert_eq(v.muzzles.set_count(), v.muzzles.cap(), "no muzzle set added mid-fight")
	assert_eq(v.impacts.set_count(), v.impacts.caps().y, "no impact set added mid-fight")
	assert_true(_nodes() - before <= 2, "shots added no VFX nodes (%d -> %d)" % [before, _nodes()])
