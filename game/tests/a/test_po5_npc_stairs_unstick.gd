## PO-5 (D-086 playability): NPCs climb and descend Glasshouse's solid-step U-stair past the balustrade
## ends (they used to stand at the stair foot pressed against the first riser / the balustrade end,
## blocking the only stair: no step-up, Godot's 15 deg wall_min_slide_angle, 0.5 m corner cutting), and
## a civilian whose walk stalls re-paths, then gives the target up instead of standing there forever.
extends TestCase

var _rt: HeistRuntime = null
var _saved_stall_s: float = 2.5


func before_each() -> void:
	_saved_stall_s = Tweak.stealth().civilian_walk_stall_s


func after_each() -> void:
	Tweak.stealth().civilian_walk_stall_s = _saved_stall_s
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## Walk `civ` from `from` to `to` (brain parked: seated, no wander); true when it arrives within `timeout_s`.
func _walk(civ: NpcBase, from: Vector3, to: Vector3, timeout_s: float) -> bool:
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	b._idle_activity = &"sit"
	b.mode = CivilianBrain.Mode.IDLE
	civ.global_position = from
	civ.velocity = Vector3.ZERO
	await wait_physics_frames(3)
	var m: NpcMotor = civ.get_node(^"Motor") as NpcMotor
	m.go_to(to, Tweak.stealth().civilian_walk_speed)
	return await wait_until(func() -> bool: return m.arrived, timeout_s)


func test_po5_civilian_climbs_and_descends_glasshouse_stair() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched glasshouse")
	await wait_physics_frames(5)
	var civ: NpcBase = _rt.npcs(&"civilian")[0] as NpcBase
	var landing: Vector3 = Vector3(14.5, 2.1, 0.8)
	# From the east corridor the path rounds the up-flight's balustrade end at the stair foot (13.6-14.3, 4.5-4.8).
	assert_true(await _walk(civ, Vector3(16.5, 0.05, 5.25), landing, 12.0), "east corridor -> half landing")
	assert_true(civ.global_position.y > 1.8, "it is up on the landing")
	assert_true(await _walk(civ, Vector3(9.0, 0.05, 5.25), landing, 14.0), "west corridor -> half landing (wall end)")
	assert_true(await _walk(civ, Vector3(14.5, 2.15, 0.8), Vector3(16.5, 0.0, 5.25), 12.0), "landing -> east corridor")
	assert_true(await _walk(civ, Vector3(15.3, 4.25, 5.25), Vector3(13.8, 0.0, 5.25), 14.0), "upper floor -> stair foot")
	assert_true(civ.global_position.y < 0.3, "back on the ground floor")


func test_po5_stalled_wander_gives_up() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 516, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	Tweak.stealth().civilian_walk_stall_s = 1.0
	# No navmesh on the unit map: the motor walks straight into this wall and cannot reach the point.
	ATestMaps.add_wall(_rt.map, Vector3(3, 1.5, 0), Vector3(0.4, 3.0, 20.0))
	var pp: PatrolPoint = PatrolPoint.new()
	pp.tags = [&"civilian"]
	_rt.map.add_child(pp)
	pp.global_position = Vector3(6, 0.05, 0)
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), {"idle_activity": &"browse"})
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	await wait_physics_frames(2)
	b._wander_timer = 0.0
	await wait_physics_frames(2)
	assert_eq(b.mode, CivilianBrain.Mode.WANDER, "walking to the point behind the wall")
	var gave_up: bool = await wait_until(func() -> bool: return b.mode == CivilianBrain.Mode.IDLE, 4.0)
	assert_true(gave_up, "a stalled walk ends (re-path, then give the point up) within a few seconds")
	assert_true(civ.global_position.x < 3.0, "it never got through the wall")
	assert_eq(b._failed_target, pp, "the unreachable point is skipped by the next pick")
