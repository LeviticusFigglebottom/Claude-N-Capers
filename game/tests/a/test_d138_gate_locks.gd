## D-138.4: the mission switch to the gate locks (no stand-in safes). SL [cage] completes when the CageGate's
## CageKeypad (open_method code) or CagePadlock (placed / handheld saw: open_method saw) opens the gate; DB
## [count_cage] completes when the CountCagePadlock (drill 120 s / C4) opens the CountCageGate (open_method drill /
## c4) and the cage cash is enabled. On a pre-D-138 map (CageLock / CountCage safes) the test builds C's layout
## at runtime: the stand-in safe is removed and the keypad / padlock prefabs are placed as C's generator does.
extends "res://tests/a/sl6_case.gd"


func after_each() -> void:
	Modifiers.clear_source(Modifiers.TEAM, &"test_d138g")
	await super()


func _prefab(id: String) -> GameplayPrefab:
	return (load("res://systems/prefabs/%s/%s.tscn" % [id, id]) as PackedScene).instantiate() as GameplayPrefab


func _drop_tagged_safes(tag: StringName) -> void:
	for n: Node in _rt.find_by_tag(tag):
		if n is Safe:
			n.get_parent().remove_child(n)
			n.free()


## SL: [CageGate, CageKeypad, CagePadlock] (built when the map predates D-138).
func _sl_locks() -> Array:
	var gate: Door = _one(&"cage_gate") as Door
	assert_true(gate != null, "the CageGate (tag cage_gate)")
	if gate == null:
		return []
	if gate.get_node_or_null(^"CagePadlock") != null:
		_cage_padlock()  # C's map: pin the D-138.4 padlock options its next regen sets
	else:  # legacy: pre-D-138 maps, remove after C b4ad9153 is on trunk
		_drop_tagged_safes(&"cage")
		var kp: Keypad = _prefab("keypad") as Keypad
		kp.name = "CageKeypad"
		kp.code_group = &"cage"
		kp.targets = [NodePath("..")] as Array[NodePath]
		kp.objective_tag = &"cage"
		kp.position = Vector3(0.8, 1.2, 0.1)
		gate.add_child(kp)
		var pl: Padlock = _prefab("padlock") as Padlock
		pl.name = "CagePadlock"
		pl.targets = [NodePath("..")] as Array[NodePath]
		pl.objective_tag = &"cage"
		pl.place_saw = true
		pl.place_saw_stealth = true
		pl.saw_duration_s = 90.0
		pl.allow_lockpick = false
		pl.position = Vector3(0.6, 1.0, -0.1)
		gate.add_child(pl)
		_rt.mission.call(&"_watch_cage_locks")
	return [gate, gate.get_node(^"CageKeypad"), gate.get_node(^"CagePadlock")]


func _assert_sl_cage(m: HeistMission, gate: Door, method: StringName) -> void:
	assert_eq(m.objective_state(&"cage"), DONE, "[cage] done (%s)" % method)
	assert_eq(StringName(_data(&"cage").get("open_method", &"")), method, "open_method %s" % method)
	assert_true(gate.is_open, "the cage gate is open")
	assert_true(_enabled(_one(&"hack")), "the hack terminal is live")
	assert_eq(_rt.find_by_tag(&"cage").filter(func(n: Node) -> bool: return n is Safe).size(), 0, "no stand-in safe")


func test_sl_cage_keypad_code() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	var locks: Array = _sl_locks()
	if locks.is_empty():
		return
	var kp: Keypad = locks[1]
	assert_eq(m.objective_state(&"cage"), ACTIVE, "the cage is shut")
	kp.call(&"_on_completed", _rt.crew_controller(0))  # the code entered (Keypad opens its targets: the gate)
	EventBus.interaction_completed.emit(kp.net_id, 0, &"enter_code")
	_assert_sl_cage(m, locks[0], &"code")
	assert_false(_enabled(locks[2]), "the padlock stops offering the saw")


func test_sl_cage_padlock_placed_saw_in_stealth() -> void:
	Modifiers.set_source(Modifiers.TEAM, &"test_d138g", {&"interaction.device_jam_chance_mult": 0.0})
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	var locks: Array = _sl_locks()
	if locks.is_empty():
		return
	var pl: Padlock = locks[2]
	assert_true(pl.place_saw and pl.place_saw_stealth and not pl.allow_lockpick, "C's CagePadlock options")
	assert_false(_rt.went_loud, "stealth")
	(_rt.crew_controller(0) as CrewController).set_masked()
	pl.interactable.availability(_rt.crew_controller(0))
	assert_eq(pl.interactable.kind, &"place_saw", "the saw goes on in stealth")
	pl.placed_kind = &"saw"
	pl.runner.place(-1, 0.4)
	await wait_physics_frames(2)
	assert_eq(m.objective_state(&"cage"), ACTIVE, "placing the saw does not open the cage")
	var ok: bool = await wait_until(func() -> bool: return m.objective_state(&"cage") == DONE, 2.0)
	assert_true(ok, "the cut opens the cage")
	_assert_sl_cage(m, locks[0], &"saw")
	assert_false(_enabled(locks[1]), "the keypad stops offering the code")
	assert_eq(m.objective_state(&"cage_code"), DONE, "the code note is moot")


func test_sl_cage_open_lock_and_device_finished() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	var locks: Array = _sl_locks()
	if locks.is_empty():
		return
	var pl: Padlock = locks[2]
	pl.open_lock()  # ENV C's test_shadow_ledger_launch drives it like this
	EventBus.device_finished.emit(pl.net_id)
	_assert_sl_cage(m, locks[0], &"saw")


func test_sl_cage_handheld_saw() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	var locks: Array = _sl_locks()
	if locks.is_empty():
		return
	(locks[2] as Padlock).saw_cut(1000.0, 0)
	var ok: bool = await wait_until(func() -> bool: return m.objective_state(&"cage") == DONE, 2.0)
	assert_true(ok, "the mission notices the cut padlock")
	_assert_sl_cage(m, locks[0], &"saw")


# --- DB count cage -------------------------------------------------------------------------------------------

func _db_launch(cash: StringName = &"cash_countroom") -> HeistMission:
	_rt = await HeistLauncher.launch(&"dockside_burn", 9001, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0, "preplan": {"force_variants": {&"cash_location": [cash]}}})
	await wait_physics_frames(3)
	assert_true(_rt != null and _rt.mission != null, "DB launched")
	return _rt.mission if _rt != null else null


## DB: [CountCageGate, CountCagePadlock] (built when the map predates D-138).
func _db_lock() -> Array:
	var lock: Padlock = null
	for n: Node in _rt.find_by_tag(&"count_cage"):
		if n is Padlock:
			lock = n as Padlock
	if lock != null:  # C's map: pin the D-138.4 options (drill 120 s / C4, no lockpick) its next regen sets
		pin_padlock(lock, {&"place_drill": true, &"drill_duration_s": 120.0, &"place_c4": true,
			&"allow_lockpick": false})
	else:  # legacy: pre-D-138 maps, remove after C b4ad9153 is on trunk
		var pos: Vector3 = Vector3.ZERO
		for n: Node in _rt.find_by_tag(&"count_cage"):
			pos = (n as Node3D).global_position
		_drop_tagged_safes(&"count_cage")
		var gate: Door = _prefab("door") as Door
		gate.name = "CountCageGate"
		gate.lock = Door.Lock.BARRED
		_rt.map.get_node(^"Gameplay").add_child(gate)
		gate.global_position = pos
		lock = _prefab("padlock") as Padlock
		lock.name = "CountCagePadlock"
		lock.objective_tag = &"count_cage"
		lock.place_drill = true
		lock.drill_duration_s = 120.0
		lock.place_c4 = true
		lock.allow_lockpick = false
		_rt.map.get_node(^"Gameplay").add_child(lock)
		lock.global_position = pos + Vector3(0.0, 1.0, -0.2)
		lock.targets = [lock.get_path_to(gate)] as Array[NodePath]
		_rt.mission.call(&"_watch_count_cage")
	var g: Door = lock.get_node_or_null(lock.targets[0]) as Door if not lock.targets.is_empty() else null
	assert_true(g != null, "the padlock opens the CountCageGate")
	return [g, lock]


func _assert_count_cage(m: HeistMission, gate: Door, method: StringName) -> void:
	assert_eq(m.objective_state(&"count_cage"), DONE, "[count_cage] done (%s)" % method)
	assert_eq(StringName(_data(&"count_cage").get("open_method", &"")), method, "open_method %s" % method)
	assert_true(gate != null and gate.is_open, "the cage gate is open")
	var cash: Array[Node] = _rt.find_by_tag(&"cash_bricks")
	assert_true(cash.size() > 0, "count-room cash spawns")
	for c: Node in cash:
		assert_true(_enabled(c), "%s enabled" % c.name)


func test_db_count_cage_drill() -> void:
	Modifiers.set_source(Modifiers.TEAM, &"test_d138g", {&"interaction.device_jam_chance_mult": 0.0})
	var m: HeistMission = await _db_launch()
	assert_eq(m.objective_state(&"count_cage"), ACTIVE, "countroom: [count_cage] active")
	var pair: Array = _db_lock()
	var lock: Padlock = pair[1]
	assert_near(lock.effective_drill_duration(), 120.0, 0.01, "the cage drill runs 120 s")
	for c: Node in _rt.find_by_tag(&"cash_bricks"):
		assert_false(_enabled(c), "cash waits for the cage")
	lock.placed_kind = &"drill"
	lock.runner.place(-1, 0.4)
	var ok: bool = await wait_until(func() -> bool: return m.objective_state(&"count_cage") == DONE, 2.0)
	assert_true(ok, "drilled")
	_assert_count_cage(m, pair[0], &"drill")


func test_db_count_cage_c4() -> void:
	var m: HeistMission = await _db_launch()
	var pair: Array = _db_lock()
	var lock: Padlock = pair[1]
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.add_item(Safe.C4_ITEM, 1)
	lock.set(&"_session", &"c4")
	lock.call(&"_on_completed", crew)
	assert_true(lock.c4_armed(), "C4 armed")
	var ok: bool = await wait_until(func() -> bool: return m.objective_state(&"count_cage") == DONE,
		Tweak.interaction().c4_fuse_s + 2.0)
	assert_true(ok, "blown")
	_assert_count_cage(m, pair[0], &"c4")


## The CountCagePadlock sits on the gate in every cash variant (C's map): off unless cash_countroom.
func test_db_count_cage_padlock_only_with_countroom() -> void:
	var m: HeistMission = await _db_launch(&"cash_strongroom")
	assert_eq(m.objective_state(&"count_cage"), Enums.ObjectiveState.HIDDEN, "strongroom: [count_cage] hidden")
	for n: Node in _rt.find_by_tag(&"count_cage"):
		if n is Padlock:
			assert_false((n as Padlock).is_enabled(), "strongroom: the cage padlock is off")
			assert_ne((n as Padlock).interactable.availability(_rt.crew_controller(0)), InteractableComponent.BLOCK_NONE,
				"and offers nothing")
	await _teardown()
	await _db_launch()
	for n: Node in _rt.find_by_tag(&"count_cage"):
		if n is Padlock:
			assert_true((n as Padlock).is_enabled(), "countroom: the cage padlock is on")
