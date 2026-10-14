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


## P PO-pass: in transit (doors, corridors) a bot waits trail_gap_m behind a moving lower-slot teammate on its line;
## the lower slot never waits on a higher one, and nobody waits behind a teammate standing still.
func test_bots_trail_single_file_behind_a_moving_teammate() -> void:
	await _launch()
	var bots: Array[CrewController] = _bots()
	bots.sort_custom(func(x: CrewController, y: CrewController) -> bool: return x.slot < y.slot)
	var lead: CrewController = bots[0]
	var back: CrewController = bots[1]
	_rt.teleport_crew(lead.slot, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -5.3)))
	_rt.teleport_crew(back.slot, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4.6)))
	await wait_physics_frames(1)
	var fwd: Vector3 = Vector3(0, 0, -1)
	lead.velocity = fwd * 2.0
	assert_true(CrewAiBrain.of(back)._trailing(fwd), "behind a moving teammate 0.7 m ahead: wait")
	assert_false(CrewAiBrain.of(lead)._trailing(-fwd), "the lower slot never waits on a higher one")
	lead.velocity = Vector3.ZERO
	assert_false(CrewAiBrain.of(back)._trailing(fwd), "a teammate standing still: no waiting (unstick handles it)")
	lead.velocity = fwd * 2.0
	assert_false(CrewAiBrain.of(back)._trailing(Vector3(1, 0, 0)), "not on our line: go")


## D-111 (PD2 bots crouch): a loud bot settled at its cover point crouches; a bot waiting at the van in stealth
## mirrors the leader's crouch.
func test_bots_crouch_in_cover_and_mirror_the_leader() -> void:
	await _launch()
	var bots: Array[CrewController] = _bots()
	var leader: CrewController = _rt.crew_controller(0) as CrewController
	leader.set_masked(true)  # casing blocks crouching (S1.1)
	await wait_physics_frames(2)
	var ci: CrewIntent = CrewIntent.new()
	ci.crouch = true
	_rt.set_bot_intent(0, ci)  # the leader crouches (scripted intent)
	await wait_physics_frames(4)
	assert_true(leader.crouched, "setup: the leader crouches")
	for b: CrewController in bots:
		assert_true(b.crouched, "waiting bot %d crouches with the crouched leader" % b.slot)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(4)
	assert_false(bots[0].crouched, "and stands with the leader")
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4)))
	var cover: Marker3D = Marker3D.new()
	cover.add_to_group(G.COVER_POINT)
	_rt.map.add_child(cover)
	cover.global_position = Vector3(2, 0.05, -2)
	_rt.teleport_crew(bots[0].slot, Transform3D(Basis.IDENTITY, Vector3(2, 0.05, -2)))
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -14)), {})
	cop.get_node("Brain").set_physics_process(false)
	var b0: CrewAiBrain = CrewAiBrain.of(bots[0])
	assert_true(await wait_until(func() -> bool: return b0.cover_point == cover and bots[0].crouched, 4.0),
		"loud, enemy near: the bot takes the cover point and crouches (mode %d)" % b0.mode)


## PD2 bot warp (P's GN pass: bots stacked at the relocked bronze doors): a bot held at a door it may not open,
## with the leader far beyond it, teleports to its slot by the leader after warp_after_blocked_s.
func test_bot_warps_past_a_door_it_cannot_open() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4344, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0)})
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "nav synced")
	for s: int in range(4):
		Modifiers.set_source(s, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.LOCKPICK) as Door
	await wait_physics_frames(2)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var bot: CrewController = _bots()[0]
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 12)))  # leader beyond the locked door
	for c: CrewController in _bots():
		_rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, Vector3(float(c.slot) - 2.0, 0.05, -4)))
	var leader: CrewController = _rt.crew_controller(0) as CrewController
	var max_s: float = CrewAiBrain.of(bot).tweak.warp_after_blocked_s + 8.0
	Engine.time_scale = TIME_SCALE
	var warped: bool = await wait_until(func() -> bool:
		return bot.global_position.z > 2.0 and Vector2(bot.global_position.x - leader.global_position.x,
			bot.global_position.z - leader.global_position.z).length() < 6.0, max_s * TIME_SCALE)
	Engine.time_scale = 1.0
	assert_true(warped, "the bot reached the leader past the locked door (at %s)" % bot.global_position)
	assert_true(door.locked and not door.is_open, "the door stayed locked (no bot lockpicking)")
