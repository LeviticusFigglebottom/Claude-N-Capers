## PO6-11 pistol hold: the support hand stays wrapped on the firing hand through the hip <-> ADS transition (left-hand
## IK on the clip's own wrist offset), the hip pose / ADS arc tweaks are in place, and the ADS settle returns the
## sights to the crosshair. Real input (PInputDriver). Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null
## Post-modifier wrist (hand.L origin) in LeftHandIK marker space, sampled in Skeleton3D.skeleton_updated.
var _wrists: Array[Vector3] = []
var _fp: FpViewmodel = null
var _marker: Node3D = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	_fp = null
	_marker = null
	await wait_frames(1)


func test_pistol_sets_on_ik() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	for s: StringName in [&"pistol", &"revolver"]:
		assert_false(tw.left_hand_ik_skip_sets.has(s), "%s support hand is IK'd onto the gun" % s)
		assert_true(tw.set_left_hand_grip_offset.has(s), "%s has the clip's own wrist offset" % s)
		assert_true(tw.set_hip_rot_deg.has(s), "%s has a hip pose" % s)
		assert_true(float(tw.set_ads_arc_roll_deg.get(s, 0.0)) > 0.0, "%s has an ADS arc" % s)


func _launch(wid: StringName) -> CrewController:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.secondary = wid
	l.secondary_mods = [] as Array[StringName]
	l.resolved_secondary = LoadoutResolver.resolve_weapon(wid, l.secondary_mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await _inp.tap(&"slot_secondary")
	await wait_physics_frames(90)
	return c


func _on_skel() -> void:
	if _fp == null or not is_instance_valid(_fp) or _marker == null or not is_instance_valid(_marker):
		return
	var hb: int = _fp.skeleton.find_bone(FpLeftHandIk.END_BONE)
	var hand: Transform3D = _fp.skeleton.global_transform * _fp.skeleton.get_bone_global_pose(hb)
	_wrists.append(_marker.global_transform.orthonormalized().affine_inverse() * hand.origin)


func test_support_hand_stays_on_gun_through_ads() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	for wid: StringName in [&"weapon.kestrel_p9", &"weapon.marshal_357"]:
		var c: CrewController = await _launch(wid)
		_fp = FpViewmodel.of(get_viewport().get_camera_3d())
		assert_true(_fp != null, "%s: FP viewmodel" % wid)
		if _fp == null:
			await after_each()
			continue
		_marker = (c.weapon_visual as WeaponVisual).get_marker(&"LeftHandIK")
		assert_true(_marker != null, "%s: LeftHandIK marker" % wid)
		var want: Vector3 = FpViewmodelTweak.data().grip_offset(_fp.anim_set)
		_wrists.clear()
		_fp.skeleton.skeleton_updated.connect(_on_skel)
		_inp.press(&"aim")
		await wait_physics_frames(40)
		_inp.release(&"aim")
		await wait_physics_frames(40)
		_fp.skeleton.skeleton_updated.disconnect(_on_skel)
		var worst: float = 0.0
		for w: Vector3 in _wrists:
			worst = maxf(worst, w.distance_to(want))
		assert_true(_wrists.size() > 30, "%s: sampled %d poses" % [wid, _wrists.size()])
		# Before PO6-11 the FK blend swung the wrist ~45 mm off the gun mid-transition.
		assert_true(worst < 0.01, "%s: support wrist within 10 mm of the grip through hip -> ADS -> hip (%.1f mm)"
			% [wid, worst * 1000.0])
		await after_each()


func test_ads_settles_on_axis() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch(&"weapon.kestrel_p9")
	assert_true(c != null, "crew")
	_fp = FpViewmodel.of(get_viewport().get_camera_3d())
	_inp.press(&"aim")
	await wait_physics_frames(60)
	var cam: Camera3D = get_viewport().get_camera_3d()
	var aim: Node3D = _fp.weapon_visual.get_marker(WeaponVisual.AIM_POINT)
	var p: Vector3 = cam.global_transform.affine_inverse() * aim.global_position
	assert_near(_fp.ads_weight, 1.0, 1e-3, "aimed")
	assert_true(Vector2(p.x, p.y).length() < 0.002, "settled sights on the camera axis (%s)" % p)
	_inp.release(&"aim")
