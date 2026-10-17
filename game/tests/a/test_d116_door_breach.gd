## D-116 police door breach (ENV D door_kick_rifle / door_kick_pistol, 84 f, test@22, impact@75 = 2.5 s): when
## Door.npc_open starts a loud breach, the breaching unit stands square to the door (InteractionTweak
## npc_door_breach_stand_m from the door plane) and plays door_kick_<fam>, scaled so `impact` lands when the door
## bursts open; a second cop waiting at the same door keeps its aim; a rig without the clip stands as before.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 11, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0)})
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "navigation map synced to this map's navmesh")


func _door() -> Door:
	var d: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.LOCKPICK) as Door
	await wait_physics_frames(2)
	return d


## A police unit whose brain / gunner are off (the test drives its motor; `aim` keeps its aim hint).
func _cop(pos: Vector3, aim: bool = false) -> NpcBase:
	var npc: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, pos), {})
	for nm: String in ["Brain", "Gunner"]:
		var c: Node = npc.get_node_or_null(nm)
		if c != null:
			c.set_physics_process(false)
			c.set_process(false)
	if aim:
		npc.get_node("Brain").set(&"anim_hint", &"aim")
	npc.max_health = 100000.0
	npc.health = 100000.0
	await wait_physics_frames(2)
	return npc


func _kick_clip(d: AnimDriver) -> StringName:
	return StringName("door_kick_" + String(d.aim_family()))


## Run until the door opens: [door_kick clip time when it opened (or -1), clip speed, max angle (deg) between the
## body's facing and the door normal while kicking, a second cop's clips seen, breach started].
func _breach(door: Door, cop: NpcBase, other: NpcBase) -> Array:
	var d: AnimDriver = AnimDriver.of(cop)
	var kick: StringName = _kick_clip(d)
	var t: float = 0.0
	var started: bool = false
	var max_angle: float = 0.0
	var at_open: float = -1.0
	var spd: float = 0.0
	var others: Dictionary = {}
	var last_pos: float = -1.0
	while t < 12.0 and not door.is_open:
		await wait_frames(1)
		t += get_process_delta_time()
		started = started or door.breach_elapsed_s(cop) >= 0.0
		if other != null and AnimDriver.of(other) != null:
			others[AnimDriver.of(other).clip] = true
		if d.clip == kick and String(d.player.current_animation).ends_with(String(kick)):
			last_pos = d.player.current_animation_position
			spd = d.player.speed_scale
			if door.breach_elapsed_s(cop) > 1.0:
				var n: Vector3 = (door.breach_stand(cop.global_position)[1] as Vector3)
				var f: Vector3 = -cop.global_transform.basis.z
				max_angle = maxf(max_angle, rad_to_deg(Vector2(f.x, f.z).angle_to(Vector2(n.x, n.z))))
	if door.is_open and d.clip == kick:
		at_open = d.player.current_animation_position
	elif door.is_open:
		at_open = last_pos
	return [at_open, spd, absf(max_angle), others, started]


func test_breacher_plays_door_kick_on_time_and_square() -> void:
	await _launch()
	var door: Door = await _door()
	EventBus.alarm_raised.emit(&"test", 0)
	var cop: NpcBase = await _cop(Vector3(0, 0.05, -4))
	var d: AnimDriver = AnimDriver.of(cop)
	if d == null or d.player == null or not d._has_clip(_kick_clip(d)):
		print("[d116 door] skip: the police rig has no %s" % (_kick_clip(d) if d != null else &"door_kick"))
		return
	var other: NpcBase = await _cop(Vector3(0.5, 0.05, -5.2), true)
	(cop.get_node("Motor") as NpcMotor).go_to(Vector3(0, 0, 4), 2.5)
	await wait_seconds(0.3)
	(other.get_node("Motor") as NpcMotor).go_to(Vector3(0.5, 0, 4), 2.5)
	var r: Array = await _breach(door, cop, other)
	assert_true(bool(r[4]), "the first cop started the breach")
	assert_true(door.is_open, "breached")
	var impact: float = AnimTweak.clip_event_s(_kick_clip(d), &"impact", AnimTweak.data().door_kick_impact_s)
	var want_speed: float = impact / Tweak.interaction().npc_door_breach_s
	assert_near(float(r[1]), want_speed, 0.001, "the clip is scaled so impact lands on npc_door_breach_s")
	var frame_clip_s: float = want_speed * maxf(get_process_delta_time(), 1.0 / 60.0)
	assert_near(float(r[0]), impact, frame_clip_s * 1.5 + 0.001,
		"impact (%.3f) vs the clip time when the door opened (%.3f): within a frame" % [impact, r[0]])
	assert_true(float(r[2]) <= 10.0, "square to the door while kicking (%.1f deg)" % r[2])
	var stand: Vector3 = door.breach_stand(cop.global_position)[0] as Vector3
	assert_true(Vector2(cop.global_position.x - stand.x, cop.global_position.z - stand.z).length() < 0.15,
		"stood at the breach stand, %.2f m from the door plane" % absf((door.global_transform.affine_inverse()
			* cop.global_position).z))
	var seen: Dictionary = r[3]
	assert_false(seen.has(&"door_kick_rifle") or seen.has(&"door_kick_pistol"),
		"the second cop never kicks (%s)" % [seen.keys()])
	assert_true(seen.has(AnimDriver.of(other).aim_clip()), "the second cop kept aiming (%s)" % [seen.keys()])


func test_rig_without_the_clip_stands() -> void:
	await _launch()
	var door: Door = await _door()
	EventBus.alarm_raised.emit(&"test", 0)
	var cop: NpcBase = await _cop(Vector3(0, 0.05, -4))
	var d: AnimDriver = AnimDriver.of(cop)
	if d == null or d.player == null:
		print("[d116 door] skip: no animated police rig")
		return
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	var removed: Dictionary = {}  # the library resource is shared by every rig: put the clips back after
	for c: StringName in [&"door_kick_rifle", &"door_kick_pistol"]:
		if lib.has_animation(c):
			removed[c] = lib.get_animation(c)
			lib.remove_animation(c)
	(cop.get_node("Motor") as NpcMotor).go_to(Vector3(0, 0, 4), 2.5)
	var kicked: bool = false
	var t: float = 0.0
	while t < 12.0 and not door.is_open:
		await wait_frames(1)
		t += get_process_delta_time()
		kicked = kicked or String(d.clip).begins_with("door_kick")
	for c: StringName in removed:
		lib.add_animation(c, removed[c])
	assert_true(door.is_open, "the breach still opens the door on time")
	assert_false(kicked, "no door_kick without the clip (stands)")
