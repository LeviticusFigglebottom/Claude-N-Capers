## D-103 §6 (Gallery Night groundwork): Door.relock(new_lock, close) for missions (last call relocks the court doors
## LOCKPICK; the lockdown BARs the Treasury shutter / art door; a hack unlocks them again). Server-side, replicated
## (net state `locked` + `lk`), and the interaction follows the new lock: LOCKPICK = a pick, BARRED = blocked for the
## crew, unlock() restores "open".
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _door(pos: Vector3, lock: Door.Lock, open: bool = false) -> Door:
	var d: Door = ATestMaps.add_prefab(_rt, "door", pos, func(p: GameplayPrefab) -> void:
		(p as Door).lock = lock
		(p as Door).starts_open = open) as Door
	return d


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1103, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func test_gn_relock_open_public_door_to_lockpick_closes_and_picks() -> void:
	await _launch()
	var d: Door = _door(Vector3(0, 0, -6), Door.Lock.NONE, true)
	await wait_physics_frames(3)
	assert_true(d.is_open and not d.locked, "public door starts open")
	d.relock(Door.Lock.LOCKPICK)
	await wait_physics_frames(2)
	assert_false(d.is_open, "relock closes it")
	assert_true(d.locked and d.lock == Door.Lock.LOCKPICK, "locked as a lockpick door")
	assert_eq(d.interactable.kind, &"lockpick", "offers a pick")
	assert_true(d.interactable.enabled, "interactable")
	assert_near(d.interactable.interaction_time_s, Tweak.interaction().lockpick_door_s, 0.001, "lockpick hold time")
	var st: Dictionary = d._net_state()
	assert_eq(int(st.get("lk", -1)), int(Door.Lock.LOCKPICK), "lock type replicated")
	assert_true(bool(st.get("locked", false)), "locked replicated")


func test_gn_relock_barred_blocks_the_crew_and_unlock_restores_it() -> void:
	await _launch()
	var d: Door = _door(Vector3(0, 0, -6), Door.Lock.KEYCARD)
	await wait_physics_frames(3)
	d.relock(Door.Lock.BARRED)
	await wait_physics_frames(1)
	assert_true(d.locked and d.lock == Door.Lock.BARRED, "barred")
	assert_eq(d.interactable.availability(null), InteractableComponent.BLOCK_STATE, "the crew cannot operate a barred door")
	d.unlock()
	d.set_open(true)
	await wait_physics_frames(2)
	assert_true(d.interactable.kind == &"open_door" and d.interactable.availability(null) == InteractableComponent.BLOCK_NONE,
		"unlocked: plain open again")
	assert_true(d.is_open, "opened by the mission (hack)")


func test_gn_relock_replicates_to_a_client_copy() -> void:
	await _launch()
	var server: Door = _door(Vector3(0, 0, -6), Door.Lock.NONE)
	var client: Door = _door(Vector3(4, 0, -6), Door.Lock.NONE)
	await wait_physics_frames(3)
	server.relock(Door.Lock.BARRED)
	client._apply_net_state(server._net_state())  # what HeistNetSync delivers to a client
	assert_true(client.locked and client.lock == Door.Lock.BARRED, "client mirrors the relock")
	assert_eq(client.interactable.availability(null), InteractableComponent.BLOCK_STATE, "client: barred")
	server.unlock()
	client._apply_net_state(server._net_state())
	assert_false(client.locked, "client mirrors the unlock")
	assert_eq(client.interactable.availability(null), InteractableComponent.BLOCK_NONE, "client: openable again")


## ENV C's shutters (bff4dd40): Door.shutter = a lift-up shutter. No crew interaction, no leaf rotation, closing never
## blocks on a body in the arc, NPCs never open it; the mission bars it and lifts it.
func test_gn_shutter_mode() -> void:
	await _launch()
	var sh: Door = ATestMaps.add_prefab(_rt, "door", Vector3(0, 0, -6), func(p: GameplayPrefab) -> void:
		(p as Door).shutter = true
		(p as Door).width_m = 2.0
		(p as Door).starts_open = true) as Door
	await wait_physics_frames(3)
	assert_false(sh.interactable.enabled, "no crew interaction on a shutter")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0.3, 0.05, -6.6)))  # standing under it
	await wait_physics_frames(2)
	sh.relock(Door.Lock.BARRED)
	assert_true(await wait_until(func() -> bool: return not sh.swing_blocked and sh._swing_frac <= 0.001, 3.0),
		"closes without blocking on the player")
	for leaf: Node3D in sh._leaves:
		assert_near(leaf.rotation.y, 0.0, 0.001, "leaves never rotate")
	var guard: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(2, 0.05, -4)), {})
	await wait_physics_frames(1)
	assert_false(sh.can_npc_open(guard), "NPCs never raise a shutter")
	sh.unlock()
	sh.set_open(true)
	await wait_physics_frames(2)
	assert_true(sh.is_open and not sh.locked, "the mission lifts it")
	assert_false(sh.interactable.enabled, "still no interaction once open")
