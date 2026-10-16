## X-5 (heist_completion.md, ENV C audit): Gallery Night's staff patrol points StaffCO / StaffCS / StaffAO pause in
## `desk_work` with no seat. The PO6-06 rule is shared (CivilianBrain.seated_or_standing): a seated pause_anim at a
## point with no seat under the NPC plays its standing counterpart (StealthTweak.civilian_unseated_activity:
## desk_work -> teller) for a staff civilian arriving on a wander AND for a guard reaching a patrol point.
extends TestCase

const POINTS: Array[String] = ["StaffCO", "StaffCS", "StaffAO"]
const SEATED: Array[StringName] = [&"desk_work", &"phone_seated", &"sit"]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_x5_gn_staff_points_need_a_seat() -> void:
	_rt = await HeistLauncher.launch(&"gallery_night", 1, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched")
	await wait_physics_frames(3)
	var checked: int = 0
	for pname: String in POINTS:
		var pp: PatrolPoint = _rt.map.get_node_or_null(NodePath("Patrols/Staff/" + pname)) as PatrolPoint
		assert_true(pp != null, "GN %s exists" % pname)
		if pp == null:
			continue
		assert_eq(pp.pause_anim, &"desk_work", "%s pauses in desk_work (map data)" % pname)
		var xf: Transform3D = Transform3D(Basis.IDENTITY, pp.global_position + Vector3(0.0, 0.05, 0.0))
		# A staff civilian arriving at the point from a wander.
		var civ: NpcBase = _rt.spawn_npc(&"civilian", xf, {"idle_activity": &"browse", "tags": [&"civ_curator"]})
		await wait_physics_frames(3)
		var cb: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
		cb.call_target = {"kind": CivilianBrain.KIND_POINT, "node": pp, "position": pp.global_position, "reason": &""}
		cb.mode = CivilianBrain.Mode.WANDER
		(civ.get_node(^"Motor") as NpcMotor).stop()
		await wait_physics_frames(2)
		var seat: bool = CivilianBrain.has_seat_under(civ)
		var want: StringName = &"desk_work" if seat else &"teller"
		assert_eq(cb.anim_hint, want, "civilian at %s (seat %s) plays %s" % [pname, seat, want])
		# A guard whose patrol reaches the point.
		var guard: NpcBase = _rt.spawn_npc(&"guard", xf, {"no_patrol": true})
		await wait_physics_frames(3)
		var gb: GuardBrain = guard.get_node(^"Brain") as GuardBrain
		var rp: Array[PatrolPoint] = [pp]
		gb.route_points = rp
		var rv: Array[Vector3] = [pp.global_position]
		gb.route = rv
		gb._route_index = 0
		gb._reach_point()
		var gseat: bool = CivilianBrain.has_seat_under(guard)
		assert_eq(gb.anim_hint, &"desk_work" if gseat else &"teller", "guard at %s (seat %s) does not sit on thin air" % [pname, gseat])
		print("X-5 GN %s at %s: seat %s, civilian %s, guard %s" % [pname, pp.global_position, seat, cb.anim_hint, gb.anim_hint])
		checked += 1
		civ.queue_free()
		guard.queue_free()
		await wait_frames(1)
	assert_eq(checked, POINTS.size(), "all three GN staff points checked")


func test_x5_shared_rule() -> void:
	_rt = await HeistLauncher.launch(&"unit_x5_gn", 6, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true})
	var g: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(4, 0.05, 4)), {"no_patrol": true})
	await wait_physics_frames(3)
	for a: StringName in SEATED:
		var s: StringName = CivilianBrain.seated_or_standing(g, a)
		assert_eq(s, StringName(Tweak.stealth().civilian_unseated_activity[a]), "%s on thin air -> standing" % a)
	assert_eq(CivilianBrain.seated_or_standing(g, &"smoke"), &"smoke", "standing activities untouched")
	assert_eq(CivilianBrain.seated_or_standing(null, &"sit"), &"sit", "null-safe")
