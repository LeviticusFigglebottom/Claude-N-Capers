## P PO-pass #3 / ND attempt 21: AI teammates never stand inside each other and, once loud, keep close to the
## leader (PD2 bots stick with you in a fight). Each AI follows to its own formation slot (follow_spread_deg),
## an idle AI stacked within unstack_m of another steps to its slot, and the loud leash is follow_max_loud_m.
extends TestCase

const TIME_SCALE: float = 3.0
const MIN_SPACING_M: float = 1.0

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4343, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)
	for s: int in range(4):
		Modifiers.set_source(s, &"test.immune", {&"defense.damage_taken_mult": 0.0})


func _bots() -> Array[CrewController]:
	var out: Array[CrewController] = []
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			out.append(c)
	return out


static func _min_spacing(bots: Array[CrewController]) -> float:
	var best: float = INF
	for i: int in range(bots.size()):
		for j: int in range(i + 1, bots.size()):
			var a: Vector3 = bots[i].global_position
			var b: Vector3 = bots[j].global_position
			best = minf(best, Vector2(a.x - b.x, a.z - b.z).length())
	return best


func test_stacked_bots_spread_to_their_own_slots() -> void:
	await _launch()
	var bots: Array[CrewController] = _bots()
	assert_eq(bots.size(), 3, "three AI teammates")
	_rt.stealth.raise_alarm(&"test", 0)  # stealth bots wait at the van (D-014); ND attempt 21 stacked in loud
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4)))
	for c: CrewController in bots:  # all three on one spot, 3.5 m from the leader (inside the follow band)
		_rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.5)))
	await wait_physics_frames(2)
	assert_true(_min_spacing(bots) < 0.2, "setup: stacked")
	Engine.time_scale = TIME_SCALE
	var spread: bool = await wait_until(func() -> bool: return _min_spacing(bots) >= MIN_SPACING_M, 6.0 * TIME_SCALE)
	Engine.time_scale = 1.0
	assert_true(spread, "bots stepped apart (min spacing %.2f m)" % _min_spacing(bots))
	await wait_seconds(1.0)
	assert_true(_min_spacing(bots) >= MIN_SPACING_M, "and stay apart (%.2f m)" % _min_spacing(bots))


func test_loud_bots_keep_close_and_apart_when_the_leader_moves() -> void:
	await _launch()
	var bots: Array[CrewController] = _bots()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	assert_true(_rt.went_loud, "loud")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4)))
	for i: int in range(bots.size()):
		_rt.teleport_crew(bots[i].slot, Transform3D(Basis.IDENTITY, Vector3(-1.5 + 1.5 * i, 0.05, -1.0)))
	await wait_seconds(1.0)
	# The leader walks 5 m on: inside the old 8 m leash, so before this fix nobody moved.
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -9)))
	var leader: CrewController = _rt.crew_controller(0) as CrewController
	var max_d: float = CrewAiBrain.of(bots[0]).tweak.follow_max_loud_m
	Engine.time_scale = TIME_SCALE
	var close: bool = await wait_until(func() -> bool:
		for c: CrewController in bots:
			if Vector2(c.global_position.x - leader.global_position.x, c.global_position.z - leader.global_position.z).length() > max_d:
				return false
		return true, 8.0 * TIME_SCALE)
	Engine.time_scale = 1.0
	assert_true(close, "loud: every bot back within %.1f m of the leader" % max_d)
	assert_true(_min_spacing(bots) >= MIN_SPACING_M * 0.8, "and still apart (%.2f m)" % _min_spacing(bots))
