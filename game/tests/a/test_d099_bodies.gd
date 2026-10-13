## D-099: dead NPCs leave G.ENEMY (corpses are G.BODY); during loud, corpses no crew member can see are
## removed after DirectorTweak.body_despawn_delay_s; a corpse in sight stays.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_d099_corpse_leaves_enemy_group_and_despawns_out_of_sight() -> void:
	var tw: DirectorTweak = (load(AssaultDirector.DEFAULT_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.body_despawn_delay_s = 0.5
	tw.body_despawn_check_s = 0.1
	_rt = await HeistLauncher.launch(&"unit_map", 9, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "director_tweak": tw})
	await wait_physics_frames(2)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var seen: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, c.global_position + Vector3(0, 0.05, -4)), {})
	var hidden: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, c.global_position + Vector3(0, 0.05, 8)), {})
	ATestMaps.add_wall(_rt, c.global_position + Vector3(0, 1.5, 4), Vector3(8, 3, 0.3))
	await wait_physics_frames(2)
	seen.die()
	hidden.die()
	assert_false(seen.is_in_group(G.ENEMY), "a corpse is not an enemy")
	assert_true(seen.is_in_group(G.BODY), "a corpse is a body")
	await wait_seconds(1.5)
	assert_false(is_instance_valid(hidden) and hidden.is_inside_tree(), "the corpse behind the wall was removed")
	assert_true(is_instance_valid(seen) and seen.is_inside_tree(), "the corpse in sight stays")
