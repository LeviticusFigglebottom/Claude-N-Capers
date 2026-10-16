## Akimbo in first person (D-050, ENV D rig fp.offhand_grip; LEAD 2026-10-16 from D's review): the left gun rides
## hand.L (not the right gun's Offhand rest pose), is put away with the visual on a swap, and no muzzle flash shows
## outside actual shots (reload, draw). Real input (PInputDriver). Owner: ENV P.
extends TestCase

const AKIMBO: StringName = &"weapon.akimbo_warden_45"

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
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.secondary = AKIMBO
	l.secondary_mods = [] as Array[StringName]
	l.resolved_secondary = LoadoutResolver.resolve_weapon(AKIMBO, l.secondary_mods)
	l.primary = &"weapon.corsair_ar"
	l.primary_mods = [] as Array[StringName]
	l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await _inp.tap(&"slot_secondary")
	await wait_physics_frames(90)
	return c


func test_left_gun_rides_hand_l() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	assert_eq(vm.anim_set, &"akimbo", "akimbo set")
	var gun: Node3D = vm.offhand.gun()
	assert_true(gun != null, "the offhand gun is on hand.L")
	if gun == null:
		return
	assert_false(vm.weapon_attach.is_ancestor_of(gun), "not under the right hand's weapon attachment")
	assert_true(vm.offhand.attach.is_ancestor_of(gun), "under the hand.L attachment")
	var hb: int = vm.skeleton.find_bone(FpLeftHandIk.END_BONE)
	var hand: Vector3 = vm.skeleton.global_transform * vm.skeleton.get_bone_global_pose(hb).origin
	assert_true(gun.global_position.distance_to(hand) < 0.25, "the left gun is in the left hand (%.3f m)" %
		gun.global_position.distance_to(hand))
	await _inp.tap(&"swap_weapon")
	assert_true(await wait_until(func() -> bool: return vm.anim_set != &"akimbo" and vm.action == FpViewmodel.Action.NONE,
		6.0), "swapped to the primary (set %s, slot %d, action %d, cw %s, primary %s, state %d)" % [vm.anim_set,
		c.weapons.equipped_slot, vm.action, c.weapons.weapon_id(c.weapons.equipped_slot),
		c.weapons.weapon_id(Enums.WeaponSlot.PRIMARY), c.crew_state])
	assert_true(vm.offhand.gun() == null, "swapped away: no offhand on hand.L")
	var sock: Node = vm.offhand.attach.get_node(^"OffhandSocket")
	await wait_frames(2)
	assert_eq(sock.get_child_count(), 0, "nothing left on the left socket")


func test_no_flash_outside_shots() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	for _k: int in 2:  # a full magazine does not reload
		await _inp.tap(&"fire")
		await wait_physics_frames(15)
	await wait_physics_frames(30)
	await _inp.tap(&"reload")
	var shown: Array[int] = [0, 0]
	assert_true(await wait_until(func() -> bool:
		shown[1] += 1
		if vm.fx.flash_visible():
			shown[0] += 1
		return vm.action == FpViewmodel.Action.NONE, 6.0), "reload finished")
	assert_eq(shown[0], 0, "no flash during the reload (%d of %d frames)" % shown)
	vm.play_draw()
	shown[0] = 0
	shown[1] = 0
	assert_true(await wait_until(func() -> bool:
		shown[1] += 1
		if vm.fx.flash_visible():
			shown[0] += 1
		return vm.action == FpViewmodel.Action.NONE, 4.0), "draw finished")
	assert_eq(shown[0], 0, "no flash during the draw (%d of %d frames)" % shown)


func test_shots_alternate_and_left_mag_hides_in_reload() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	if vm.offhand.gun() == null:
		assert_true(false, "offhand on hand.L")
		return
	var sides: Array[bool] = []
	var clips: Array[StringName] = []
	for _k: int in 4:
		await _inp.tap(&"fire")
		var seen: StringName = &""
		for _f: int in 12:  # the fire clips are 3 frames: catch whichever plays
			if String(vm.clip).begins_with("fire"):
				seen = vm.clip
			await wait_frames(1)
		sides.append(vm.offhand.shot_left)
		clips.append(seen)
		await wait_physics_frames(10)
	assert_eq(sides, [false, true, false, true] as Array[bool], "shots alternate right, left (%s)" % [sides])
	assert_true(String(clips[1]).ends_with("_l"), "the left shot plays the rig's fire_l (%s)" % [clips])
	var mag: Node3D = vm.offhand.gun().find_child("Magwell", true, false) as Node3D
	if mag == null:
		skip("the offhand model has no Magwell")
		return
	assert_true(mag.visible, "left magazine in before the reload")
	await _inp.tap(&"reload")
	var hidden: Array[int] = [0]
	assert_true(await wait_until(func() -> bool:
		if not mag.visible:
			hidden[0] += 1
		return vm.action == FpViewmodel.Action.NONE and not c.weapons.reloading, 8.0), "reload finished")
	assert_true(hidden[0] > 0, "the left magazine is hidden between mag_out_l and mag_in_l (%d frames)" % hidden[0])
	assert_true(mag.visible, "the left magazine is back after the reload")


## ENV A reads fx_muzzle() for the tracer origin BEFORE `fired`: it must name the gun of the upcoming shot.
func test_fx_muzzle_predicts_the_next_gun() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of_crew(c)
	assert_true(vm != null and vm.offhand.gun() != null, "akimbo viewmodel via of_crew")
	if vm == null or vm.offhand.gun() == null:
		return
	for k: int in 4:
		var predicted: Node3D = vm.fx_muzzle()
		await _inp.tap(&"fire")
		await wait_physics_frames(3)
		var fired: Node3D = vm.offhand.marker(vm.weapon_visual, &"Muzzle")
		assert_true(predicted != null and predicted == fired, "shot %d: fx_muzzle() named the firing gun" % k)
		assert_eq(vm.offhand.gun().is_ancestor_of(fired), k % 2 == 1, "shot %d is the %s gun" % [k,
			"left" if k % 2 == 1 else "right"])
		await wait_physics_frames(12)
