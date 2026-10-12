## PI-19: every shipped WeaponDef has an AimPoint (ADS sights align), and a gun without one warns once.
## PI-21: the arms trail the camera's step smoothing when walking up a curb with real input (PInputDriver).
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## PI-19 audit over ContentDB.all_weapons(): no gun is left with off-axis sights.
func test_every_weapon_has_aim_point() -> void:
	var defs: Array = ContentDB.all_weapons()
	assert_true(defs.size() > 0, "weapons registered")
	var missing: Array[StringName] = FpViewmodel.missing_aim_points(defs)
	assert_eq(missing.size(), 0, "weapons without AimPoint: %s" % [missing])


## PI-19: a weapon without AimPoint is reported (once per id), not silently skipped.
func test_missing_aim_point_is_reported_once() -> void:
	var root: Node3D = Node3D.new()
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	var def: WeaponDef = WeaponDef.new()
	def.id = &"weapon.test_no_aimpoint"
	def.model = ps
	assert_eq(FpViewmodel.missing_aim_points([def]), [&"weapon.test_no_aimpoint"] as Array[StringName], "detected")
	FpViewmodel._aim_missing_logged.erase(def.id)
	var wv: WeaponVisual = WeaponVisual.new()
	var none: Array[WeaponModDef] = []
	wv.setup(def, none)
	var fp: FpViewmodel = FpViewmodel.new()
	fp._check_aim_point(wv)
	assert_true(FpViewmodel._aim_missing_logged.has(def.id), "warned")
	var n: int = FpViewmodel._aim_missing_logged.size()
	fp._check_aim_point(wv)
	assert_eq(FpViewmodel._aim_missing_logged.size(), n, "no repeat entry")
	FpViewmodel._aim_missing_logged.erase(def.id)
	wv.free()
	fp.free()


## PI-21: walk (real input) up a 0.3 m curb: the arms dip below their rest while the camera settles, then return.
func test_arms_lag_on_step_up() -> void:
	ATestMaps.add_wall(_rt.map, Vector3(0.0, 0.15, -4.0), Vector3(3.0, 0.3, 4.0))
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 1.0)))
	assert_true(await _inp.turn_to_yaw(c, 0.0), "face the curb")
	assert_true(await wait_until(func() -> bool: return c.grounded, 2.0), "grounded")
	var fp: FpViewmodel = FpViewmodel.new()
	fp._crew = c
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var min_lag: Array[float] = [0.0]
	var ok: bool = await _inp.walk_until(&"move_forward", func() -> bool:
		return c.global_position.z < -3.0, 4.0, func() -> void:
			min_lag[0] = minf(min_lag[0], fp.step_lag(tw)))
	assert_true(ok, "walked onto the curb (y %.3f)" % c.global_position.y)
	assert_true(min_lag[0] < -0.03, "arms dipped after the step up (%.3f m)" % min_lag[0])
	assert_true(min_lag[0] >= -Tweak.crew().step_height_m * tw.step_lag_mult - 1e-4, "bounded by step height")
	assert_true(await wait_until(func() -> bool: return absf(fp.step_lag(tw)) < 0.001, 1.0), "settles with camera")
	fp.free()
