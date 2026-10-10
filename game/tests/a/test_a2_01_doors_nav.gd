## A2-01 (D-032 QA-11): NPCs and AI teammates open unlocked doors on their path (0.6 s in stealth,
## instantly in loud), guards pass keycard doors their post authorises, other closed doors block
## NPC paths (they stop in front), the door's NavigationLink3D follows its state.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(crew_ai: bool = false) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 11, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0), "crew_ai": crew_ai})
	await wait_physics_frames(2)


func _door(lock: Door.Lock, tags: Array[StringName] = [], suspicious: bool = false) -> Door:
	var d: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, func(p: GameplayPrefab) -> void:
		var door: Door = p as Door
		door.lock = lock
		door.npc_authorized_tags = tags
		door.suspicious_when_open = suspicious) as Door
	await wait_physics_frames(2)
	return d


## A guard whose brain is switched off so the test drives its NpcMotor directly.
func _walker(pos: Vector3, tags: Array[StringName] = []) -> NpcBase:
	var npc: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, pos), {"tags": tags})
	npc.get_node("Brain").set_physics_process(false)
	await wait_physics_frames(2)
	return npc


func _motor(npc: NpcBase) -> NpcMotor:
	return npc.get_node("Motor") as NpcMotor


func test_a2_01_nav_path_crosses_doorway_and_closed_door_is_detected() -> void:
	await _launch()
	var door: Door = await _door(Door.Lock.LOCKPICK)
	var nav_map: RID = _rt.get_viewport().world_3d.navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, Vector3(3, 0, -5), Vector3(-3, 0, 5), true)
	assert_true(path.size() >= 2, "navmesh path through the baked doorway")
	var hit: Dictionary = Door.first_closed_on_path(_rt.get_tree(), path, 100.0)
	assert_eq(hit.get("door"), door, "the closed door is on the NavigationServer3D path")
	assert_near((hit["point"] as Vector3).z, 0.0, 0.05, "crossing on the doorway plane")
	assert_true(Door.first_closed_on_path(_rt.get_tree(), path, 2.0).is_empty(), "beyond the look-ahead: ignored")
	door.unlock()
	door.set_open(true)
	assert_true(Door.first_closed_on_path(_rt.get_tree(), path, 100.0).is_empty(), "open doors never block")


func test_a2_01_locked_door_blocks_npc_path() -> void:
	await _launch()
	var door: Door = await _door(Door.Lock.LOCKPICK)
	var npc: NpcBase = await _walker(Vector3(0, 0.05, -4))
	var blocked: Array[Node] = []
	_motor(npc).door_blocked.connect(func(d: Node) -> void: blocked.append(d))
	_motor(npc).go_to(Vector3(0, 0, 4), 2.0)
	await wait_seconds(4.0)
	assert_false(door.is_open, "a guard cannot open a locked door without authorisation")
	assert_true(npc.global_position.z < -0.4, "NPC stopped in front of the door (z=%.2f)" % npc.global_position.z)
	assert_true(npc.global_position.z > -1.5, "...after walking up to it")
	assert_eq(_motor(npc).blocked_door, door, "motor reports the blocking door")
	assert_true(_motor(npc).arrived, "the go_to ended")
	assert_true(blocked.has(door), "door_blocked fired (P3 breach hook)")


func test_a2_01_unlocked_door_opens_after_stealth_delay() -> void:
	await _launch()
	var door: Door = await _door(Door.Lock.NONE)
	var npc: NpcBase = await _walker(Vector3(0.3, 0.05, -4))
	var opened_by: Array[int] = []
	door.open_changed.connect(func(o: bool, by: int) -> void:
		if o:
			opened_by.append(by))
	var m: NpcMotor = _motor(npc)
	m.go_to(Vector3(-0.5, 0, 4), 2.0)
	var t: float = 0.0
	var t_wait: float = -1.0
	var t_open: float = -1.0
	while t < 6.0 and t_open < 0.0:
		await wait_physics_frames(1)
		t += 1.0 / Engine.physics_ticks_per_second
		if t_wait < 0.0 and m.waiting_door == door:
			t_wait = t
		if door.is_open:
			t_open = t
	assert_true(t_wait >= 0.0, "NPC waited at the door")
	assert_true(t_open >= 0.0, "NPC opened the door")
	var dt: float = t_open - t_wait
	assert_true(dt > 0.5 and dt < 0.75, "stealth open animation ~0.6 s (got %.2f)" % dt)
	assert_eq(opened_by, [npc.net_id] as Array[int], "open_changed names the NPC")
	await wait_seconds(4.0)
	assert_true(npc.global_position.z > 2.0, "walked through (z=%.2f)" % npc.global_position.z)


func test_a2_01_loud_opens_instantly() -> void:
	await _launch()
	var door: Door = await _door(Door.Lock.NONE)
	var npc: NpcBase = await _walker(Vector3(0, 0.05, -4))
	_rt.stealth.raise_alarm(&"scripted")
	await wait_physics_frames(2)
	var brain: GuardBrain = npc.get_node("Brain") as GuardBrain
	brain.set_physics_process(false)
	var m: NpcMotor = _motor(npc)
	m.go_to(Vector3(0, 0, 4), 3.0)
	var waited: int = 0
	var frames: int = 0
	while not door.is_open and frames < 300:
		await wait_physics_frames(1)
		frames += 1
		if m.waiting_door != null:
			waited += 1
	assert_true(door.is_open, "loud: door opened")
	assert_true(waited <= 2, "no stealth animation delay in loud (%d frames)" % waited)


func test_a2_01_authorised_guard_uses_keycard_door() -> void:
	await _launch()
	var door: Door = await _door(Door.Lock.KEYCARD, [&"vault_post"] as Array[StringName])
	var other: NpcBase = await _walker(Vector3(-3, 0.05, -4), [&"lobby"] as Array[StringName])
	assert_false(door.can_npc_open(other), "post not authorised")
	var npc: NpcBase = await _walker(Vector3(0, 0.05, -4), [&"vault_post"] as Array[StringName])
	assert_true(door.can_npc_open(npc), "post authorised (npc_authorized_tags)")
	_motor(npc).go_to(Vector3(0, 0, 4), 2.0)
	assert_true(await wait_until(func() -> bool: return door.is_open, 6.0), "authorised guard opened the keycard door")
	assert_true(door.locked, "it stays locked for the crew")
	await wait_seconds(3.0)
	assert_true(npc.global_position.z > 2.0, "guard went through (z=%.2f)" % npc.global_position.z)
	await wait_seconds(Tweak.interaction().npc_locked_door_close_s)
	assert_false(door.is_open, "a locked door closes again behind the guard")


func test_a2_01_nav_link_follows_door_state() -> void:
	await _launch()
	var door: Door = await _door(Door.Lock.LOCKPICK)
	var link: NavigationLink3D = door.get_node("NavLink") as NavigationLink3D
	assert_true(link != null, "door has a NavLink through the doorway")
	assert_false(link.enabled, "locked + closed: link disabled")
	door.set_open(true)
	assert_true(link.enabled, "open: enabled")
	door.set_open(false)
	assert_false(link.enabled)
	door.unlock()
	assert_true(link.enabled, "unlocked: NPCs can open it, link enabled")
	var bar: Door = ATestMaps.add_prefab(_rt, "door", Vector3(8, 0, 0), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.BARRED
		(p as Door).npc_authorized_tags = [&"x"] as Array[StringName]) as Door
	await wait_physics_frames(1)
	assert_false((bar.get_node("NavLink") as NavigationLink3D).enabled, "BARRED doors are never NPC-passable")


func test_a2_01_npc_opened_suspicious_door_is_a_stimulus() -> void:
	await _launch()
	var door: Door = await _door(Door.Lock.NONE, [] as Array[StringName], true)
	var npc: NpcBase = await _walker(Vector3(0, 0.05, -4))
	_motor(npc).go_to(Vector3(0, 0, 4), 2.0)
	assert_true(await wait_until(func() -> bool: return door.is_open, 6.0), "opened by the NPC")
	var kinds: Array[StringName] = []
	for s: Dictionary in _rt.stealth.stimuli():
		kinds.append(StringName(s["kind"]))
	assert_has(kinds, &"open_door", "S4.2 stimulus registered for an NPC-opened door")


func test_a2_01_ai_teammate_opens_door_in_loud() -> void:
	await _launch(true)
	var door: Door = await _door(Door.Lock.NONE)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.05, 7.0)))
	for s: int in [2, 3]:
		_rt.teleport_crew(s, Transform3D(Basis.IDENTITY, Vector3(3.0 * s, 0.05, 9.0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, -6.0)))
	_rt.set_bot_intent(0, CrewIntent.new())
	_rt.stealth.raise_alarm(&"scripted")
	var ai: CrewController = _rt.crew_controller(1) as CrewController
	assert_true(await wait_until(func() -> bool: return door.is_open, 8.0), "AI teammate opened the door on its way")
	assert_true(await wait_until(func() -> bool: return ai.global_position.z > 1.0, 8.0),
		"AI teammate followed through the doorway (z=%.2f)" % ai.global_position.z)
