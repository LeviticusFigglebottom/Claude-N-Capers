## PO6-12 (ENV B firing range) viewmodel support: FpViewmodel.play_draw() replays the equipped weapon's draw, and
## CrewView.refresh_weapon wears the loadout's weapon finish (B7-04) on the first-person gun. Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_physics_frames(90)
	return c


func test_play_draw_replays_the_draw() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	assert_true(vm != null, "FP viewmodel")
	if vm == null:
		return
	assert_eq(vm.action, FpViewmodel.Action.NONE, "idle before")
	vm.play_draw()
	assert_eq(vm.action, FpViewmodel.Action.SWAP, "draw playing")
	assert_eq(vm.clip, &"draw", "the draw clip")
	assert_true(await wait_until(func() -> bool: return vm.action == FpViewmodel.Action.NONE, 3.0), "back to idle")


func test_fp_gun_wears_the_loadout_finish() -> void:
	var c: CrewController = await _launch()
	if not (&"weapon_finishes" in c.loadout):
		skip("Loadout.weapon_finishes not on this branch yet (ENV B)")
		return
	var wid: StringName = (c.weapon_visual as WeaponVisual).weapon.id
	c.loadout.set(&"weapon_finishes", {wid: &"finish.carbon"})
	CrewView.of(c).refresh_weapon()
	var wv: WeaponVisual = c.weapon_visual as WeaponVisual
	assert_eq(wv.finish_id, &"finish.carbon", "FP gun wears the loadout's finish")
