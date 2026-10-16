## D-118 first-person gadgets (FpViewmodelGadgets): real input (gadget_toggle) turns the equipped weapon's laser
## (beam + dot on the surface it hits) and flashlight (real SpotLight3D, no shadows, contract defaults) on and off; the
## state is per weapon and survives a swap. Until ENV A's replicated CrewWeapons.gadget_on lands the local fallback
## is exercised. Owner: ENV P.
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
	await wait_physics_frames(60)
	return c


func test_toggle_laser_and_flashlight() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	assert_true(vm != null and vm.gadgets != null, "viewmodel with gadgets")
	if vm == null or vm.gadgets == null:
		return
	var ws: int = c.weapons.equipped_slot
	var st: WeaponStats = c.weapons.stats(ws)
	var g0: Array[StringName] = st.gadgets.duplicate()
	st.gadgets = [&"laser", &"flashlight"] as Array[StringName]  # setup: a gadget-equipped gun (B's mods pending)
	for _k: int in 4:
		_inp.look(0.0, 60.0)  # look down a little: the beam hits the floor
		await wait_physics_frames(1)
	await wait_frames(3)
	assert_false(vm.gadgets.laser_visible or vm.gadgets.light_visible, "off by default")
	await _inp.tap(&"gadget_toggle")
	await wait_frames(4)
	assert_true(vm.gadgets.laser_visible, "laser on")
	assert_true(vm.gadgets.light_visible, "flashlight on")
	var cam: Camera3D = CrewView.of(c).camera()
	var d: float = cam.global_position.distance_to(vm.gadgets.laser_end)
	assert_true(d > 0.5 and d < FpViewmodelTweak.data().gadget_laser_range_m, "the beam stops on the floor (%.2f m)" % d)
	var light: SpotLight3D = vm.gadgets.find_child("Flashlight", true, false) as SpotLight3D
	assert_true(light != null and not light.shadow_enabled, "a real light, no shadows")
	if light != null:
		assert_near(light.spot_range, 25.0, 0.01, "contract range")
		assert_near(light.spot_angle, 30.0, 0.01, "contract angle")
		assert_true(light.layers & CrewView.VIEWMODEL_LIT_LAYER != 0, "lights the viewmodel too")
	# Per weapon: swap away and back, it stays on.
	await _inp.tap(&"slot_primary" if ws == Enums.WeaponSlot.SECONDARY else &"slot_secondary")
	await wait_seconds(1.5)
	await _inp.tap(&"slot_secondary" if ws == Enums.WeaponSlot.SECONDARY else &"slot_primary")
	await wait_seconds(1.5)
	await wait_frames(3)
	assert_true(vm.gadgets.gadget_on(ws), "still on after a swap")
	await _inp.tap(&"gadget_toggle")
	await wait_frames(4)
	assert_false(vm.gadgets.laser_visible or vm.gadgets.light_visible, "toggled off")
	st.gadgets = g0


func test_no_gadget_no_effect() -> void:
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	if vm == null or vm.gadgets == null:
		skip("no viewmodel")
		return
	var st: WeaponStats = c.weapons.stats(c.weapons.equipped_slot)
	if not st.gadgets.is_empty():
		skip("equipped gun has a gadget")
		return
	await _inp.tap(&"gadget_toggle")
	await wait_frames(4)
	assert_false(vm.gadgets.laser_visible or vm.gadgets.light_visible, "a gun without gadgets shows nothing")
