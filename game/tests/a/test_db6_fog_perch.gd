## DB-6 (heist_completion.md; dockside_burn.md §Rare events `fog_lifts`, §Snipers "S3 (`fog_lifts`)"): QC-25 director
## hook. With `fog_lifts` the S3 viaduct perch (Group_perch_viaduct, TacticalPoint tag `s3`) is in the map from the
## start (rare force_active), but the fog only thins at 6:00: until then the perch is closed to the director's
## Longshots (SpecialSpawner.set_perches_open / HeistMission.set_sniper_perches_open); _on_fog_lifts opens it.
extends TestCase

const PERCH_TAG: StringName = &"s3"

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## A seed whose variant roll has `fog_lifts` (the runtime resolves right after GameRng.begin_run(seed)).
func _fog_seed(difficulty: int) -> int:
	var map: HeistMap = (load(HeistLauncher.map_path(&"dockside_burn")) as PackedScene).instantiate() as HeistMap
	var slots: Dictionary = VariantResolver.collect_slots(map)
	var found: int = -1
	for sd: int in range(1, 400):
		GameRng.begin_run(sd)
		var v: Dictionary = VariantResolver.resolve(map.variant_table, slots, difficulty, {})
		if (v.get(VariantResolver.RARE_KEY, []) as Array).has(&"fog_lifts"):
			found = sd
			break
	map.free()
	return found


func _s3(rt: HeistRuntime) -> TacticalPoint:
	for n: Node in rt.map.get_slots(G.SNIPER_PERCH):
		var tp: TacticalPoint = n as TacticalPoint
		if tp != null and tp.tags.has(PERCH_TAG):
			return tp
	return null


func test_db6_s3_perch_opens_when_the_fog_lifts() -> void:
	var sd: int = _fog_seed(Enums.Difficulty.HAZARDOUS)
	assert_true(sd > 0, "a seed rolls fog_lifts")
	_rt = await HeistLauncher.launch(&"dockside_burn", sd, Enums.Difficulty.HAZARDOUS, self, {"crew_ai": false})
	assert_true(_rt != null, "launched")
	assert_true((_rt.variants.get(VariantResolver.RARE_KEY, []) as Array).has(&"fog_lifts"), "seed %d rolled fog_lifts" % sd)
	await wait_physics_frames(3)
	var s3: TacticalPoint = _s3(_rt)
	assert_true(s3 != null, "fog_lifts pins the S3 viaduct perch into the map")
	if s3 == null:
		return
	assert_true(s3.has_meta(SpecialSpawner.CLOSED_META), "S3 closed while the fog is in")
	assert_false(SpecialSpawner.open_perches(_rt).has(s3), "S3 not offered to the director")
	assert_true(SpecialSpawner.open_perches(_rt).size() >= 2, "S1 / S2 stay open")
	assert_ne(SpecialSpawner.free_perch(_rt, s3.global_position, null), s3, "the director's free perch is never S3")
	var mission: HeistMission = _rt.map.get_node(^"Mission") as HeistMission
	assert_true(mission.timer_left(&"fog_lifts") > 0.0, "the fog lift is scheduled")
	mission.call(&"_on_fog_lifts")
	assert_false(s3.has_meta(SpecialSpawner.CLOSED_META), "S3 open once the fog lifts")
	assert_eq(SpecialSpawner.free_perch(_rt, s3.global_position, null), s3, "the director may now perch a Longshot on S3")
	var snipers: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"longshot", Transform3D(), {})
	assert_false(snipers.is_empty(), "a Longshot spawns")
	print("DB-6 seed %d: S3 %s, perches open %d" % [sd, s3.global_position, SpecialSpawner.open_perches(_rt).size()])


func test_db6_perch_gate_api() -> void:
	_rt = await HeistLauncher.launch(&"dockside_burn", 2, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	await wait_physics_frames(2)
	var all: int = SpecialSpawner.open_perches(_rt).size()
	assert_true(all >= 2, "DB has perches (%d)" % all)
	var first: TacticalPoint = SpecialSpawner.open_perches(_rt)[0]
	var tag: StringName = first.tags[0] if not first.tags.is_empty() else &""
	var mission: HeistMission = _rt.map.get_node(^"Mission") as HeistMission
	var n: int = mission.set_sniper_perches_open(tag, false)
	assert_true(n >= 1, "closed %d perch(es) tagged %s" % [n, tag])
	assert_false(SpecialSpawner.open_perches(_rt).has(first), "closed perch skipped")
	assert_eq(SpecialSpawner.perch_at(_rt, first.global_position, 0.5, null), null, "no snapping onto a closed perch")
	mission.set_sniper_perches_open(tag, true)
	assert_true(SpecialSpawner.open_perches(_rt).has(first), "reopened")
	assert_eq(mission.set_sniper_perches_open(&"no_such_tag", false), 0, "unknown tag: nothing")
