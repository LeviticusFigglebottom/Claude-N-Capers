## D-103 §6 / QC-55 (Gallery Night lockdown): KeycardReader.set_disabled(true) kills a reader: its prompt reads
## "Out of order" (ui.blocked.disabled), a completed hold or an ECM opens nothing; set_disabled(false) restores it.
## Replicated through the reader's net state (`disabled`).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_gn_disabled_reader_opens_nothing_until_enabled() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1104, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(0, 0, -6), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.KEYCARD) as Door
	var reader: KeycardReader = ATestMaps.add_prefab(_rt, "keycard_reader", Vector3(1.2, 1.2, -6.2)) as KeycardReader
	await wait_physics_frames(2)
	reader.bind_target(door)
	reader.set_disabled(true)
	assert_eq(reader.interactable.availability(null), InteractableComponent.BLOCK_DISABLED, "dead reader: Out of order")
	reader._on_completed(null)
	reader.open_by_ecm()
	await wait_physics_frames(2)
	assert_true(door.locked and not door.is_open, "a dead reader opens nothing (hold or ECM)")
	assert_false(reader.used, "not consumed")
	var client: KeycardReader = ATestMaps.add_prefab(_rt, "keycard_reader", Vector3(4, 1.2, -6.2)) as KeycardReader
	await wait_physics_frames(1)
	client._apply_net_state(reader._net_state())
	assert_true(client.disabled, "replicated to a client copy")
	assert_eq(client.interactable.availability(null), InteractableComponent.BLOCK_DISABLED, "client prompt: Out of order")
	reader.set_disabled(false)
	assert_eq(reader.interactable.availability(null), InteractableComponent.BLOCK_NONE, "alive again")
	reader._on_completed(null)
	await wait_physics_frames(2)
	assert_true(not door.locked and door.is_open, "works again once enabled")
