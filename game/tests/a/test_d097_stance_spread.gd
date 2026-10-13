## D-097: stance spread multipliers follow PD2 (standing 1.0, moving 1.0, crouching 0.4; crouched wins over
## moving) and the spread radius is uniform (shots cluster toward the centre).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_d097_stance_multipliers() -> void:
	var tw: CombatTweak = CombatTweak.data()
	assert_near(tw.spread_mult_still, 1.0, 0.0001, "standing 1.0")
	assert_near(tw.spread_mult_moving, 1.0, 0.0001, "moving 1.0")
	assert_near(tw.spread_mult_crouched, 0.4, 0.0001, "crouching 0.4")
	_rt = await HeistLauncher.launch(&"unit_map", 3, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var w: CrewWeapons = c.weapons
	var s: Variant = w.get(&"_states").get(w.equipped_slot)
	var i: CrewIntent = CrewIntent.new()
	c.crouched = false
	var stand: float = w.call(&"_spread_deg", s, i)
	c.crouched = true
	var crouch: float = w.call(&"_spread_deg", s, i)
	assert_true(stand > 0.0, "hip spread > 0")
	assert_near(crouch / stand, 0.4, 0.001, "crouched = 0.4 x standing")


func test_d097_uniform_radius_clusters_to_centre() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 3, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var w: CrewWeapons = (_rt.crew_controller(0) as CrewController).weapons
	var inner: int = 0
	var n: int = 2000
	var fwd: Vector3 = Vector3(0, 0, -1)
	for _k: int in n:
		var d: Vector3 = w.call(&"_spread_dir", fwd, 10.0)
		if rad_to_deg(d.angle_to(fwd)) < 5.0:
			inner += 1
	# Uniform radius: ~50 % inside half the cone (area-uniform would give ~25 %).
	assert_true(absf(float(inner) / n - 0.5) < 0.06, "inner half of the cone holds %.0f%%" % (100.0 * inner / n))
