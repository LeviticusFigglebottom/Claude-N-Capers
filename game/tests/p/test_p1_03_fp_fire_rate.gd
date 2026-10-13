## A4-04 / lead: the viewmodel fire cycle uses the gameplay cadence incl. weapon.fire_rate_mult (1.0 when unset).
extends TestCase

const SRC: StringName = &"test_p_fire_rate"
var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})


func after_each() -> void:
	Modifiers.clear_source(0, SRC)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_shot_interval_follows_fire_rate_mult() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var fp: FpViewmodel = FpViewmodel.new()
	fp._crew = c  # presentation-only probe; no arms rig needed for the cadence
	var ws: int = c.weapons.equipped_slot
	var base: float = 60.0 / maxf(c.weapons.stats(ws).fire_rate_rpm, 1.0)
	assert_near(FpViewmodel.fire_rate_mult(0, c.weapons.weapon_id(ws)), 1.0, 1e-6, "unset = 1.0")
	assert_near(fp._shot_interval(), base, 1e-6, "base cadence without the key")
	Modifiers.set_source(0, SRC, {&"weapon.fire_rate_mult.all": 1.25})
	assert_near(fp._shot_interval(), base / 1.25, 1e-6, "x1.25 fire rate = interval / 1.25")
	fp.free()
