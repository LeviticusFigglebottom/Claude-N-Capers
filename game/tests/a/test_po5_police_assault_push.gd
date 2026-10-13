## PO-5.14 (L1.1): during an assault (BUILD / SUSTAIN) police without cover close in to the assault
## standoff band instead of backing off at 8 m (which made them hover in a doorway, out of sight).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _mode_at(assault_phase: int) -> StringName:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0})
	await wait_physics_frames(1)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var c: Node3D = _rt.crew_controller(0) as Node3D
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, c.global_position + Vector3(0, 0.05, -5)), {})
	var brain: PoliceBrain = cop.get_node(^"Brain") as PoliceBrain
	var modes: Array[StringName] = []
	for _i: int in 180:
		dir.assault_phase = assault_phase  # pin the phase (the director would move on)
		await wait_physics_frames(1)
		if not modes.has(brain.mode):
			modes.append(brain.mode)
	var out: StringName = &"back_off" if modes.has(&"back_off") else brain.mode
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	return out


func test_po5_police_push_during_assault() -> void:
	assert_eq(await _mode_at(Enums.AssaultPhase.CONTROL), &"back_off", "outside an assault: keep the 8 m standoff")
	assert_true(await _mode_at(Enums.AssaultPhase.SUSTAIN) != &"back_off", "during the assault: push in, no back-off at 5 m")
