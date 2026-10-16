## Knife reach repro (LEAD 2026-10-16, routed to ENV A): a charged knife swing from 1.3 m (flat) behind an unaware
## guard, aimed at his chest, must kill him (PD2 melee reach ~1.5-2 m; CrewMelee range_m / bash_range_m 1.5). Today
## it misses at 1.3 m (swung, no hit_landed) and kills at 0.8 m. Real input (Po5Pilot mouse look + held melee).
## Owner: ENV P (the fix is ENV A's, systems/combat/crew_melee.gd).
extends TestCase

var _rt: HeistRuntime = null
var _pilot: Po5Pilot = null


func after_each() -> void:
	if _pilot != null:
		_pilot.inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	_pilot = null
	await wait_frames(1)


## Po5Pilot's driver interface.
func note(msg: String) -> void:
	print("[KNIFE] %s" % msg)


func shot(_label: String) -> void:
	pass


func _knife_from(dist_m: float) -> Dictionary:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false})
	var c: CrewController = _rt.crew_controller(Net.local_slot()) as CrewController
	await wait_physics_frames(30)
	_pilot = Po5Pilot.new(self, c)
	_pilot.quiet = true
	await _pilot.calibrate()
	await _pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var back: Vector3 = g.global_position + g.global_basis.z.normalized() * dist_m  # behind him
	_rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, Vector3(back.x, 0.05, back.z)))
	await wait_physics_frames(10)
	var counts: Array[int] = [0, 0]
	c.melee.swung.connect(func(_ch: bool) -> void: counts[0] += 1)
	c.melee.hit_landed.connect(func(_t: Object) -> void: counts[1] += 1)
	await _pilot.face(g.global_position + Vector3(0, 1.2, 0), 0.03, 1.5)  # chest
	var calm: bool = g.alert_state == Enums.AlertState.CALM
	await _pilot.inp.hold(&"melee", 1.05)  # charged swing
	await wait_physics_frames(40)
	return {"swung": counts[0], "hits": counts[1], "alive": g.is_alive(), "calm": calm,
		"dist": Vector2(g.global_position.x - c.global_position.x, g.global_position.z - c.global_position.z).length()}


func test_knife_kills_from_0_8_m() -> void:
	var r: Dictionary = await _knife_from(0.8)
	assert_true(r["calm"], "guard unaware before the swing")
	assert_eq(r["swung"], 1, "one swing")
	assert_false(r["alive"], "0.8 m: knifed (%s)" % r)


func test_knife_reaches_1_3_m() -> void:
	var r: Dictionary = await _knife_from(1.3)
	assert_true(r["calm"], "guard unaware before the swing")
	assert_eq(r["swung"], 1, "one swing")
	assert_eq(r["hits"], 1, "1.3 m behind the guard is in knife reach (%s)" % r)
	assert_false(r["alive"], "1.3 m: knifed (%s)" % r)
