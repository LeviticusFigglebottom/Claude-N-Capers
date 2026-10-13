## PO-5 (D-086, S1.1): a casing (unmasked) player can open an unlocked door; a locked door still needs
## the mask (lockpicking is a suspicious action).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 5, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _door(lock: Door.Lock) -> Door:
	return ATestMaps.add_prefab(_rt, "door", Vector3(2, 0, 0),
		func(p: GameplayPrefab) -> void: (p as Door).lock = lock) as Door


func test_po5_casing_player_opens_unlocked_door() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_false(c.masked, "casing")
	var d: Door = _door(Door.Lock.NONE)
	await wait_physics_frames(1)
	assert_eq(d.interactable.availability(c), InteractableComponent.BLOCK_NONE, "unlocked door: usable while casing")
	var l: Door = _door(Door.Lock.LOCKPICK)
	await wait_physics_frames(1)
	assert_eq(l.interactable.availability(c), InteractableComponent.BLOCK_CASING, "lockpick: needs the mask")
	l.unlock()
	assert_eq(l.interactable.availability(c), InteractableComponent.BLOCK_NONE, "once unlocked: usable while casing")
