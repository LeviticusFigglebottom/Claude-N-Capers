## P coverage (env/p-play ab48541c, scc_cop_tied_standing): a surrendered cop holds a surrender / hands-up pose (the
## AnimationPlayer keeps playing what the driver chose) and a tied cop kneels cuffed (kneel_cuffed), like guards.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## Hips height above the feet in the final pose (read in skeleton_updated, after the player applied it).
func _hips_y(d: AnimDriver) -> float:
	var sk: Skeleton3D = d.rig.get_node("Skeleton3D") as Skeleton3D
	var out: Array[float] = [NAN]
	var grab: Callable = func() -> void:
		out[0] = sk.get_bone_global_pose(sk.find_bone("hips")).origin.y
	sk.skeleton_updated.connect(grab)
	await wait_frames(3)
	sk.skeleton_updated.disconnect(grab)
	return out[0]


func _playing(d: AnimDriver) -> String:
	return String(d.player.current_animation) if d.player.is_playing() else "<stopped>"


func test_police_surrender_then_tied_pose() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4401, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 6)))
	var cop: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", Vector3(0, 0.05, 0))
	await wait_physics_frames(3)
	var d: AnimDriver = AnimDriver.of(cop)
	assert_true(d != null and d.player != null, "cop animated")
	var standing: float = await _hips_y(d)
	var s: PoliceSurrender = PoliceSurrender.of(cop, true)
	await wait_physics_frames(1)
	assert_true(s.surrender(0), "surrendered")
	for t: float in [0.5, 2.0, 4.0]:
		await wait_seconds(t - (0.0 if t == 0.5 else (0.5 if t == 2.0 else 2.0)))
		print("[cop pose] surrendered t=%.1f driver %s player %s" % [t, d.clip, _playing(d)])
		assert_true(d.player.is_playing(), "t=%.1f: the player keeps playing (no frozen one-shot)" % t)
		assert_true(_playing(d).ends_with(String(d.clip)) or _playing(d).contains(String(d.clip)),
			"t=%.1f: driver %s and player %s agree" % [t, d.clip, _playing(d)])
	s.tie(0)
	await wait_seconds(1.0)
	print("[cop pose] tied driver %s player %s" % [d.clip, _playing(d)])
	assert_true(String(d.clip).begins_with("kneel_cuffed") or d.clip == &"tied", "tied cop kneels cuffed (%s)" % d.clip)
	assert_true(d.player.is_playing() and _playing(d).contains(String(d.clip)), "player plays %s (%s)" % [d.clip, _playing(d)])
	await wait_seconds(2.0)
	assert_true(d.player.is_playing() and _playing(d).contains(String(d.clip)), "still kneeling 2 s later (%s)" % _playing(d))
	var kneel: float = await _hips_y(d)
	print("[cop pose] hips standing %.2f tied %.2f" % [standing, kneel])
	assert_true(kneel < standing * 0.8, "tied cop is kneeling (hips %.2f vs standing %.2f)" % [kneel, standing])
