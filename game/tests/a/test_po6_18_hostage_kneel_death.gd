## P GH regression (po6_18_hostage_kneel_death_corpse): a tied hostage on a real civilian rig plays a real kneeling
## clip (never the bind pose), and a pistol-shot death from it ends with the corpse down (hips < 0.3 m), not upright
## on its knees.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _hips_y(d: AnimDriver) -> float:
	var sk: Skeleton3D = d.rig.get_node("Skeleton3D") as Skeleton3D
	var out: Array[float] = [NAN]
	var grab: Callable = func() -> void:
		out[0] = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hips")).origin).y
	sk.skeleton_updated.connect(grab)
	await wait_frames(3)
	sk.skeleton_updated.disconnect(grab)
	if is_nan(out[0]):  # a ragdoll-owned skeleton (paused player) may not emit skeleton_updated: read it directly
		out[0] = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hips")).origin).y
	return out[0]


func test_po6_18_tied_hostage_kneels_and_dies_down() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1818, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 6)))
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), {})
	var d0: AnimDriver = AnimDriver.of(civ)
	assert_true(d0 != null and d0.player.is_playing() and String(d0.player.current_animation) != "",
		"posed from the spawn frame (no bind pose before the first tick)")
	await wait_physics_frames(3)
	var d: AnimDriver = AnimDriver.of(civ)
	assert_true(d != null and d.player != null, "civilian animated (%s)" % civ.visual_scene.resource_path)
	var b: CivilianBrain = civ.get_node("Brain") as CivilianBrain
	b.mode = CivilianBrain.Mode.TIED
	b.anim_hint = &"tied"
	civ.set_alert_state(Enums.AlertState.TIED)
	for i: int in 30:
		await wait_frames(1)
		assert_true(d.player.is_playing() and String(d.player.current_animation) != "",
			"frame %d: a real clip plays (%s / driver %s), never the bind pose" % [i, d.player.current_animation, d.clip])
	print("[po6_18] tied: driver %s player %s" % [d.clip, d.player.current_animation])
	assert_true(await _hips_y(d) < 0.75, "kneeling")
	civ.die({"type": Enums.DamageType.BULLET, "direction": Vector3(0, 0, -1), "position": civ.global_position + Vector3(0, 1, 0)}, 0)
	await wait_seconds(5.0)
	var hy: float = await _hips_y(d)
	print("[po6_18] dead: driver %s hips %.2f" % [d.clip, hy])
	assert_true(hy < 0.3, "the corpse is down (hips %.2f m)" % hy)


func test_po6_18_gh_manager_hostage_dies_down() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 5, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	await wait_physics_frames(5)
	var civ: NpcBase = null
	for n: Node in _rt.npcs(&"civilian"):
		var nb: NpcBase = n as NpcBase
		if nb.visual_scene != null and nb.visual_scene.resource_path.contains("vossberg"):
			civ = nb
	if civ == null:
		civ = _rt.npcs(&"civilian")[0] as NpcBase
	print("[po6_18] GH hostage %s at %s" % [civ.visual_scene.resource_path.get_file(), civ.global_position])
	var d: AnimDriver = AnimDriver.of(civ)
	var b: CivilianBrain = civ.get_node("Brain") as CivilianBrain
	b.mode = CivilianBrain.Mode.TIED
	b.anim_hint = &"tied"
	civ.set_alert_state(Enums.AlertState.TIED)
	await wait_seconds(1.0)
	print("[po6_18] GH tied: driver %s player %s hips %.2f" % [d.clip, d.player.current_animation, await _hips_y(d)])
	assert_true(d.player.is_playing() and String(d.player.current_animation).ends_with(String(d.clip)), "tied clip plays")
	civ.die({"type": Enums.DamageType.BULLET, "direction": Vector3(0, 0, -1), "position": civ.global_position + Vector3(0, 1, 0)}, 0)
	for t: int in 6:
		await wait_seconds(1.0)
		var rd: NpcRagdoll = NpcRagdoll.of(civ)
		print("[po6_18] GH dead +%ds: driver %s player %s/%s hips %.2f ragdoll phase %s" % [t + 1, d.clip,
			d.player.current_animation, d.player.is_playing(), await _hips_y(d), rd.phase if rd else -1])
	assert_true(await _hips_y(d) < 0.3, "the GH corpse is down")
