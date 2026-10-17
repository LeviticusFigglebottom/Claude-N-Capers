## DB-4 (heist_completion.md): Dockside Burn cartel gunmen whose SpawnPoint idle_activity is `sit` rendered standing
## inside the chair (CartelBrain always hinted idle -> idle_thug). ENV C now puts GunmanPlatformA / B on the
## ForemanChair / BreakChairS seats. The PO6-06 rule (CivilianBrain.seated_or_standing): `sit` on a real seat ->
## anim_hint sit (AnimDriver sit_chair), no patrol, held on the seat; `sit` with no seat -> standing idle (idle_thug).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _gunman(pos: Vector3, yaw: float, activity: StringName) -> NpcBase:
	var info: Dictionary = {"idle_activity": activity, "tags": [CartelBrain.SPAWN_TAG],
		"enemy_def": load(CartelBrain.ENEMY_DEF) as EnemyDef}
	return _rt.spawn_npc(CartelBrain.ROLE, Transform3D(Basis(Vector3.UP, yaw), pos), info)


func test_db4_cartel_sit_on_a_seat_plays_seated() -> void:
	_rt = await HeistLauncher.launch(&"dockside_burn", 3, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched")
	var chairs: Array[Node3D] = []
	for p: NodePath in [^"Props/Mezzanine/ForemanChair", ^"Props/Mezzanine/BreakChairS"]:
		var c: Node3D = _rt.map.get_node_or_null(p) as Node3D
		assert_true(c != null and c.get_node_or_null(^"Seat") != null, "%s with a Seat marker" % p)
		if c != null:
			chairs.append(c)
	var seated: Array[NpcBase] = []
	var marks: Array[Vector3] = []
	for c: Node3D in chairs:
		seated.append(_gunman(c.global_position, c.global_rotation.y, &"sit"))
		marks.append(c.global_position)
	var floor_pos: Vector3 = chairs[0].global_position + Vector3(0.0, 0.0, 2.5) if not chairs.is_empty() else Vector3.ZERO
	var standing: NpcBase = _gunman(floor_pos, 0.0, &"sit")
	await wait_seconds(3.0)
	for i: int in seated.size():
		var g: NpcBase = seated[i]
		var b: CartelBrain = g.get_node(^"Brain") as CartelBrain
		assert_eq(g.alert_state, Enums.AlertState.CALM, "%s asleep" % g.name)
		assert_true(CivilianBrain.has_seat_under(g), "%s has a seat under it" % g.name)
		assert_eq(b.anim_hint, &"sit", "%s on a seat sits" % g.name)
		assert_true(b.route.is_empty(), "%s does not patrol off its chair" % g.name)
		var d: float = Vector2(g.global_position.x - marks[i].x, g.global_position.z - marks[i].z).length()
		assert_true(d <= 0.1, "%s stays on the seat (moved %.2f m)" % [g.name, d])
		var ad: AnimDriver = g.get_node_or_null(^"AnimDriver") as AnimDriver
		if ad != null and ad.player != null:
			# DB-4 (characters.md v1.24): the armed seated idle when the rig has it, else sit_chair.
			var want_seat: StringName = &"sit_chair_armed" if ad._has_clip(&"sit_chair_armed") else &"sit_chair"
			assert_eq(ad.choose_clip(), want_seat, "%s plays %s" % [g.name, want_seat])
		print("DB-4 %s seated: hint %s, clip %s, moved %.3f" % [g.name, b.anim_hint, ad.choose_clip() if ad else &"-", d])
	var sb: CartelBrain = standing.get_node(^"Brain") as CartelBrain
	assert_false(CivilianBrain.has_seat_under(standing), "no seat under the floor gunman")
	assert_eq(sb.anim_hint, &"idle", "`sit` with no seat stands (idle -> idle_thug)")
	var sad: AnimDriver = standing.get_node_or_null(^"AnimDriver") as AnimDriver
	if sad != null and sad.player != null:
		assert_eq(sad.choose_clip(), &"idle_thug", "unseated gunman idles as a thug")
	# Woken: off the chair and fighting (the hold is released).
	(seated[0].get_node(^"Brain") as CartelBrain).wake(&"damage")
	await wait_physics_frames(2)
	assert_false((seated[0].get_node(^"Motor") as NpcMotor).holding(), "awake: not held on the chair")
	assert_ne((seated[0].get_node(^"Brain") as CartelBrain).anim_hint, &"sit", "awake: not sitting")


func test_db4_map_platform_gunmen() -> void:
	# The shipped map: GunmanPlatformA / B (Slot_post_platform) sit when C's marks are on the seats, else stand.
	for sd: int in [1, 2, 3, 4, 5, 6]:
		_rt = await HeistLauncher.launch(&"dockside_burn", sd, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
		await wait_seconds(1.0)
		var found: int = 0
		for n: Node in _rt.npcs(CartelBrain.ROLE):
			var g: NpcBase = n as NpcBase
			if not (g.spawn_info.get("tags", []) as Array).has(&"cartel_platform"):
				continue
			found += 1
			var b: CartelBrain = g.get_node(^"Brain") as CartelBrain
			var want: StringName = &"sit" if CivilianBrain.has_seat_under(g) else &"idle"
			if g.alert_state == Enums.AlertState.CALM and b.route.is_empty():
				assert_eq(b.anim_hint, want, "seed %d %s: %s" % [sd, g.name, want])
			print("DB-4 seed %d %s at %s: seat %s hint %s route %d" % [sd, g.name, g.global_position,
				CivilianBrain.has_seat_under(g), b.anim_hint, b.route.size()])
		_rt.teardown()
		_rt = null
		await wait_frames(2)
		if found > 0:
			return
