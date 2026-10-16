## D-103 / QC-58 ambient clips (characters.md v1.9): a panicked civilian still in its seat cowers there
## (cower_seated); a fleeing civilian runs to a free PatrolPoint tagged `cower` and cowers standing, back to the
## wall (cower_stand); `text` civilians walk texting (walk_text); `inspect` plays curator_inspect. AnimDriver maps
## the hints to the clips, with fallbacks for an older library.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1111, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func _brain(npc: NpcBase) -> CivilianBrain:
	return npc.get_node(^"Brain") as CivilianBrain


func test_gn_seated_civilian_cowers_in_the_seat() -> void:
	await _launch()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 4)))
	var seat: Node3D = Node3D.new()  # PO6-06: a seated activity needs a seating prop's `Seat` marker under it
	seat.name = "Seat"
	_rt.map.add_child(seat)
	seat.global_position = Vector3(0, 0.5, -2)
	var seated: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -2)), {"idle_activity": &"sit"})
	await wait_physics_frames(2)
	var at: Vector3 = seated.global_position
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_seconds(1.0)
	assert_eq(_brain(seated).mode, CivilianBrain.Mode.COWER, "cowers")
	assert_eq(_brain(seated).anim_hint, &"cower_seated", "in the seat")
	assert_true(seated.global_position.distance_to(at) < 0.2, "did not run off")


func test_gn_fleeing_civilian_cowers_at_a_cower_point() -> void:
	await _launch()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(-4, 0.05, -2)))
	var pp: PatrolPoint = PatrolPoint.new()
	pp.tags = [&"cower"]
	_rt.map.add_child(pp)
	pp.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(4, 0.05, -2))
	var behind: PatrolPoint = PatrolPoint.new()  # on the crew's side: never picked
	behind.tags = [&"cower"]
	_rt.map.add_child(behind)
	behind.global_position = Vector3(-2, 0.05, -2)
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -2)), {"idle_activity": &"browse"})
	await wait_physics_frames(2)
	_rt.stealth.raise_alarm(&"test", 0)
	var b: CivilianBrain = _brain(civ)
	assert_true(await wait_until(func() -> bool: return b.mode == CivilianBrain.Mode.COWER, 8.0), "ran and cowered")
	assert_eq(b.anim_hint, &"cower_stand", "standing cower at the point")
	assert_true(Vector2(civ.global_position.x - 4.0, civ.global_position.z + 2.0).length() <= CivilianBrain.COWER_POINT_M,
		"at the cower point")
	var other: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -3)), {"idle_activity": &"browse"})
	await wait_physics_frames(1)
	var targets: CivilianTargets = CivilianTargets.ensure(_rt)
	assert_true(targets.claim_cower_point(other, Vector3(0, 0.05, -3), Vector3(-4, 0.05, -2), 10.0) == null,
		"the far point is taken, the near one is on the crew's side")


func test_gn_texting_walk_and_clip_mapping() -> void:
	await _launch()
	var pp: PatrolPoint = PatrolPoint.new()
	pp.tags = [&"civilian"]
	_rt.map.add_child(pp)
	pp.global_position = Vector3(6, 0.05, 0)
	var walker: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(3, 0.05, 0)), {"idle_activity": &"text"})
	await wait_physics_frames(1)
	var b: CivilianBrain = _brain(walker)
	assert_eq(b.anim_hint, &"text", "texting idle")
	b._wander_timer = 0.0
	await wait_physics_frames(2)
	assert_eq(b.mode, CivilianBrain.Mode.WANDER, "wanders")
	assert_eq(b.anim_hint, &"walk_text", "walks texting")
	assert_eq(AnimDriver.HINT_CLIPS[&"inspect"], &"curator_inspect", "inspect -> curator_inspect")
	assert_eq(AnimDriver.HINT_CLIPS[&"cower_seated"], &"cower_seated")
	assert_true(AnimDriver.POSE_CLIPS.has(&"cower_stand") and AnimDriver.POSE_CLIPS.has(&"cower_seated"), "poses")
	assert_eq(AnimDriver.FALLBACK_CLIPS[&"walk_text"], &"walk", "fallback")
	assert_near(float(AnimTweak.data().clip_speeds[&"walk_text"]), 1.2, 0.001, "1.2 m/s")


## D-115 cast roster: an authored `walk_text` activity walks texting too (walk_text clip), not a plain walk.
func test_d115_walk_text_activity_walks_texting() -> void:
	await _launch()
	var pp: PatrolPoint = PatrolPoint.new()
	pp.tags = [&"civilian"]
	_rt.map.add_child(pp)
	pp.global_position = Vector3(6, 0.05, 0)
	var walker: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(3, 0.05, 0)),
		{"idle_activity": &"walk_text"})
	await wait_physics_frames(1)
	var b: CivilianBrain = _brain(walker)
	b._wander_timer = 0.0
	await wait_physics_frames(2)
	assert_eq(b.mode, CivilianBrain.Mode.WANDER, "wanders")
	assert_eq(b.anim_hint, &"walk_text", "walks texting")
	await wait_physics_frames(20)
	var d: AnimDriver = AnimDriver.of(walker)
	if d != null and d.player != null and d.player.has_animation("%s/walk_text" % AnimDriver.LIBRARY) \
			and d.horizontal_speed() > 0.3:
		assert_eq(d.clip, &"walk_text", "the walk_text clip plays while walking")
