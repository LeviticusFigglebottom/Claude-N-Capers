## G1 traversal harness self-test (next_heist.md §7, D-104): PTraversal's real-input checks on a synthetic course
## (gap, low bar, balcony + rail, ladder, heavy-bag carry) so the helpers are proven before Gallery Night's greybox.
extends TestCase

var _rt: HeistRuntime = null
var _tr: PTraversal = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 104, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_tr = PTraversal.new(self, _rt)


func after_each() -> void:
	_tr.inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _world() -> Node:
	return _rt.map


## Two walls leaving a `width` m opening across x = 0 at z = `z`.
func _gap_walls(z: float, width: float) -> void:
	ATestMaps.add_wall(_world(), Vector3(-(width * 0.5 + 2.0), 1.5, z), Vector3(4.0, 3.0, 0.3))
	ATestMaps.add_wall(_world(), Vector3(width * 0.5 + 2.0, 1.5, z), Vector3(4.0, 3.0, 0.3))


func test_gap_widths() -> void:
	_gap_walls(-4.0, 0.8)
	await wait_physics_frames(2)
	var r: Dictionary = await _tr.gap(Vector3(0.3, 0, 0), Vector3(0.3, 0, -8))
	assert_true(r["ok"], "0.8 m gap (5 cm a side), approached off-centre: %s" % r)
	_gap_walls(-12.0, 0.6)
	await wait_physics_frames(2)
	var r2: Dictionary = await _tr.gap(Vector3(0, 0, -9), Vector3(0, 0, -15), false, 6.0)
	assert_false(r2["ok"], "0.6 m gap blocks the 0.70 m capsule")
	assert_true(r2["stalled_at"] != null and float((r2["stalled_at"] as Vector3).z) > -12.0, "stalled in front of it")


func test_low_bar_needs_a_crouch() -> void:
	# A solid bar from 1.27 m up (the lz_static lowest beam height) across a 3 m passage.
	ATestMaps.add_wall(_world(), Vector3(0, 1.27 + 0.6, -4.0), Vector3(3.0, 1.2, 0.2))
	ATestMaps.add_wall(_world(), Vector3(-2.0, 1.5, -4.0), Vector3(1.0, 3.0, 0.2))
	ATestMaps.add_wall(_world(), Vector3(2.0, 1.5, -4.0), Vector3(1.0, 3.0, 0.2))
	await wait_physics_frames(2)
	var stand: Dictionary = await _tr.gap(Vector3(0, 0, 0), Vector3(0, 0, -7), false, 5.0)
	assert_false(stand["ok"], "standing is blocked by a 1.27 m bar")
	var crouch: Dictionary = await _tr.gap(Vector3(0, 0, 0), Vector3(0, 0, -7), true, 8.0)
	assert_true(crouch["ok"], "crouching (1.2 m capsule) passes under it: %s" % crouch)


func test_balcony_throw_clears_the_rail() -> void:
	# A 5.4 m balcony 3 m deep with a 1.1 m rail on its open (-Z) edge.
	ATestMaps.add_wall(_world(), Vector3(0, 5.3, 8.0), Vector3(6.0, 0.2, 3.0))
	ATestMaps.add_wall(_world(), Vector3(0, 5.4 + 0.55, 6.6), Vector3(6.0, 1.1, 0.15))
	await wait_physics_frames(2)
	for pitch_deg: float in [0.0, 20.0, -20.0]:
		var r: Dictionary = await _tr.throw_bag(Vector3(0, 5.42, 7.4), 0.0, deg_to_rad(pitch_deg), Enums.LootWeight.LIGHT)
		assert_true(r["thrown"], "thrown at %.0f deg" % pitch_deg)
		var land: Vector3 = r["landing"]
		assert_true(land.y < 1.0 and land.z < 6.4, "pitch %.0f: over the rail onto the floor (%s)" % [pitch_deg, land])
		if is_instance_valid(r["bag"]):
			(r["bag"] as Node).queue_free()
		await wait_physics_frames(2)


func test_ladder_up_and_down() -> void:
	var l: Ladder = ATestMaps.add_prefab(_rt, "ladder", Vector3(0, 0, -4), func(p: GameplayPrefab) -> void:
		p.set(&"height_m", 3.0)) as Ladder
	ATestMaps.add_wall(_world(), Vector3(0, 2.9, -2.35), Vector3(3.0, 0.2, 3.0))  # landing at the top (wall side, +Z)
	await wait_physics_frames(5)
	var r: Dictionary = await _tr.ladder(l)
	assert_true(r["up"], "climbs up with W (%s)" % r)
	assert_true(r["down"], "climbs down (%s)" % r)


func test_heavy_bag_carry_route() -> void:
	await ATestMaps.await_nav_synced(_rt)
	await wait_physics_frames(5)
	var r: Dictionary = await _tr.carry(Vector3(0, 0, 0), Vector3(6, 0, -10), Enums.LootWeight.HEAVY, 30.0)
	assert_true(r["ok"], "heavy carry arrives: %s" % r)
	assert_true(r["carrying"], "still carrying at the end")
	var speed: float = float(r["path_m"]) / maxf(float(r["time_s"]), 0.01)
	assert_true(speed < Tweak.crew().walk_speed * 0.6, "at heavy-bag pace (%.2f m/s)" % speed)
