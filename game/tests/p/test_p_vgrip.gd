## D-118 vertical grip (PD2): with a vertical-grip mod, the FP left hand IKs to the mod's LeftHandIK at
## FpViewmodelTweak.set_vgrip_grip_offset and takes ENV D's `<set>_vgrip_hand` pose; without one it keeps the normal
## grip. Skips until B's grip mods and D's clips are on this branch. Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(wid: StringName, mods: Array[StringName]) -> FpViewmodel:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = wid
	l.primary_mods = mods
	l.resolved_primary = LoadoutResolver.resolve_weapon(wid, mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await inp.tap(&"slot_primary")
	await wait_physics_frames(90)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	return FpViewmodel.of(CrewView.of(c).camera())


func test_vgrip_takes_the_left_hand() -> void:
	if not ContentDB.has(ContentDB.MODS, &"mod.corsair_vertical_grip"):
		skip("ENV B's vertical grip mods not on this branch")
		return
	for pair: Array in [[&"weapon.corsair_ar", &"mod.corsair_vertical_grip"], [&"weapon.wasp_pdw", &"mod.rail_vertical_grip"]]:
		var vm: FpViewmodel = await _launch(pair[0], [pair[1]] as Array[StringName])
		assert_true(vm != null, "%s: viewmodel" % pair[0])
		if vm == null:
			await after_each()
			continue
		if vm._resolve(vm.anim_set, &"vgrip_hand") != &"vgrip_hand":
			skip("ENV D's %s_vgrip_hand clip not on this branch" % vm.anim_set)
			return
		assert_true(vm.vgrip_active(), "%s + %s: the grip takes the left hand" % pair)
		var mk: Node3D = vm.weapon_visual.get_marker(&"LeftHandIK")
		var grip: Node3D = mk.get_node_or_null(FpLeftHandIk.GRIP_NAME) as Node3D if mk != null else null
		assert_true(grip != null and grip.position.is_equal_approx(
			FpViewmodelTweak.data().set_vgrip_grip_offset[vm.anim_set]), "%s: IK target at the vgrip wrist offset" % pair[0])
		assert_true(mk != vm.weapon_visual.get_base_marker(&"LeftHandIK"), "%s: on the mod's marker" % pair[0])
		await after_each()
		var bare: FpViewmodel = await _launch(pair[0], [] as Array[StringName])
		assert_false(bare != null and bare.vgrip_active(), "%s without the grip: normal hold" % pair[0])
		await after_each()
