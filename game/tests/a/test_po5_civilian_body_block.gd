## PO-5 (D-086 playability): civilians on the floor (cower / down / tied) do not body-block the crew,
## and a flee that makes no progress ends in cower instead of running in place in a doorway.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 77, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 1), "crew_ai": false})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _civ() -> NpcBase:
	return _rt.npcs(&"civilian")[0] as NpcBase


func _brain(civ: NpcBase) -> CivilianBrain:
	return civ.get_node(^"Brain") as CivilianBrain


func test_po5_standing_civilian_blocks_cowering_does_not() -> void:
	var civ: NpcBase = _civ()
	await wait_physics_frames(2)
	assert_eq(civ.collision_layer, NpcBase.LAYER_NPCS, "a civilian on its feet blocks the crew")
	_brain(civ).call(&"_cower")
	await wait_physics_frames(2)
	assert_eq(civ.collision_layer, 0, "a cowering civilian does not block the crew")
	_brain(civ).call(&"_intimidate", 0)
	await wait_physics_frames(2)
	assert_eq(civ.collision_layer, 0, "an intimidated civilian does not block the crew")
	_brain(civ).mode = CivilianBrain.Mode.IDLE
	await wait_physics_frames(2)
	assert_eq(civ.collision_layer, NpcBase.LAYER_NPCS, "standing up blocks again")


func test_po5_stalled_flee_cowers() -> void:
	var civ: NpcBase = _civ()
	var b: CivilianBrain = _brain(civ)
	await wait_physics_frames(2)
	b.threat_position = civ.global_position + Vector3(1, 0, 0)
	b.call(&"_flee")
	assert_eq(b.mode, CivilianBrain.Mode.FLEE, "fleeing")
	# Pin the civilian in place (a crew member in the doorway): no progress -> cower after the stall time.
	var pin: Vector3 = civ.global_position
	var t: float = 0.0
	while b.mode == CivilianBrain.Mode.FLEE and t < Tweak.stealth().civilian_flee_stall_s * 2.0 + 1.0:
		civ.global_position = pin
		await wait_physics_frames(1)
		t += 1.0 / Engine.physics_ticks_per_second
	assert_eq(b.mode, CivilianBrain.Mode.COWER, "a stalled flee ends in cower (%.1f s)" % t)
