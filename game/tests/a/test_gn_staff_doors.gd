## D-103 §3b.6 (Gallery Night staff doors): a locked door's `npc_authorized_tags` also authorises staff civilians
## (curator, conservator; ND's night manager / cleaner) by their SpawnPoint tags. A patron without the tag is still
## stopped by it; BARRED stays shut for everyone.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1109, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0)})
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "navigation map synced")


## A civilian whose brain is off so the test drives its NpcMotor.
func _civ(pos: Vector3, tags: Array[StringName]) -> NpcBase:
	var npc: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), {"tags": tags})
	npc.get_node("Brain").set_physics_process(false)
	await wait_physics_frames(2)
	return npc


func test_gn_staff_civilian_walks_through_an_authorised_lockpick_door() -> void:
	await _launch()
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.LOCKPICK
		(p as Door).npc_authorized_tags = [&"guard", &"civ_curator"] as Array[StringName]) as Door
	await wait_physics_frames(2)
	var patron: NpcBase = await _civ(Vector3(-3, 0.05, -4), [&"civ_patron"] as Array[StringName])
	assert_false(door.can_npc_open(patron), "a patron is not staff")
	var curator: NpcBase = await _civ(Vector3(0, 0.05, -4), [&"civ_curator"] as Array[StringName])
	assert_true(door.can_npc_open(curator), "the curator is")
	(curator.get_node("Motor") as NpcMotor).go_to(Vector3(0, 0, 4), 2.0)
	assert_true(await wait_until(func() -> bool: return door.is_open, 6.0), "the curator opened the staff door")
	assert_true(door.locked, "still locked for the crew")
	assert_true(await wait_until(func() -> bool: return curator.global_position.z > 2.0, 6.0),
		"and walked through (z=%.2f)" % curator.global_position.z)
	door.relock(Door.Lock.BARRED)
	await wait_physics_frames(1)
	assert_false(door.can_npc_open(curator), "BARRED: staff cannot open it")


func test_gn_vault_door_authorises_only_listed_tags() -> void:
	await _launch()
	var plain: Door = ATestMaps.add_prefab(_rt, "door", Vector3(8, 0, 0), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.VAULT) as Door
	var courier_door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-8, 0, 0), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.VAULT
		(p as Door).npc_authorized_tags = [&"guard_vaultline"] as Array[StringName]) as Door
	await wait_physics_frames(2)
	var courier: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4)),
		{"tags": [&"guard_vaultline"]})
	var guard: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(2, 0.05, -4)), {"tags": [&"guard_hall"]})
	await wait_physics_frames(2)
	assert_false(plain.can_npc_open(courier), "VAULT without tags: nobody (default)")
	assert_false((plain.get_node("NavLink") as NavigationLink3D).enabled, "and no nav link")
	assert_true(courier_door.can_npc_open(courier), "VAULT with guard_vaultline listed: the courier")
	assert_false(courier_door.can_npc_open(guard), "but not another guard")
	assert_true((courier_door.get_node("NavLink") as NavigationLink3D).enabled, "linked for the courier")
