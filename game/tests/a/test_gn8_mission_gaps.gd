## GN-8 (LEAD, from B's strings audit): Gallery Night mission objective gaps.
## (a) [extras] needs the 13 wall studies too, not only the AS rack studies; (b) [keycard] leaves the step list in loud
## (skipped by the lockdown, doc §B2), even when a card is picked up after the alarm; (c) [vault_drill] completes when the
## loud hack opens the vault (hack OR drill, doc §Objectives Loud 7); (d) the SV keypad code completes [server_door];
## (e) the inspectors / Vaultline errands: test_gn_inspectors_empty_slot.gd and test_gn8_vaultline_courier.gd.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch() -> HeistMission:
	_rt = await HeistLauncher.launch(&"gallery_night", 1130, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(3)
	return _rt.mission


func _net_id(n: Node) -> int:
	var v: Variant = n.get(&"net_id")
	return int(v) if v != null else 0


## Live (kept, visible) nodes tagged `tag`.
func _live(m: HeistMission, tag: StringName) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in m.find_tagged(tag):
		if n is Node3D and (n as Node3D).visible and not n.is_queued_for_deletion():
			out.append(n)
	return out


## The crew takes `n` (the interaction's fact, as InteractionSystem emits it on the server).
func _take(n: Node) -> void:
	EventBus.interaction_completed.emit(_net_id(n), 0, &"test")


func _loud() -> void:
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)


func _hack() -> HackTerminal:
	for n: Node in _rt.mission.find_tagged(&"hack"):
		if n is HackTerminal:
			return n as HackTerminal
	return null


func test_gn8_extras_needs_the_wall_studies() -> void:
	var m: HeistMission = await _launch()
	var studies: Array[Node] = _live(m, &"study")
	assert_true(studies.size() >= 13, "the wall studies are in the map (%d)" % studies.size())
	# Everything else [extras] lists: the whole list, the centrepiece, the AS rack studies, the lockers and the safe.
	for tag: StringName in [&"canvas_orchard", &"canvas_widow", &"canvas_saint", &"canvas_lantern", &"store_study",
			&"lockers", &"curator_safe"]:
		for n: Node in _live(m, tag):
			_take(n)
	assert_eq(m.objective_state(&"lockers"), Enums.ObjectiveState.COMPLETED, "lockers done")
	assert_eq(m.objective_state(&"curator_safe"), Enums.ObjectiveState.COMPLETED, "safe done")
	assert_eq(m.objective_state(&"extras"), Enums.ObjectiveState.ACTIVE, "the wall studies still hang: not done")
	for i: int in range(studies.size() - 1):
		_take(studies[i])
	assert_eq(m.objective_state(&"extras"), Enums.ObjectiveState.ACTIVE, "one wall study left")
	_take(studies[studies.size() - 1])


func test_gn8_keycard_leaves_the_steps_in_loud() -> void:
	var m: HeistMission = await _launch()
	assert_eq(m.objective_state(&"keycard"), Enums.ObjectiveState.ACTIVE, "stealth: get a keycard")
	await _loud()
	assert_eq(m.objective_state(&"keycard"), Enums.ObjectiveState.COMPLETED, "loud: skipped (the lockdown)")
	EventBus.item_picked_up.emit(&"item.keycard", 0)  # a card picked up after the alarm changes nothing
	await wait_physics_frames(2)
	assert_eq(m.objective_state(&"keycard"), Enums.ObjectiveState.COMPLETED, "still off the step list")
	for o: Dictionary in _rt.hud_model.objectives:
		if StringName(o["id"]) == &"keycard":
			assert_ne(int(o["state"]), Enums.ObjectiveState.ACTIVE, "the HUD does not show it as a step")


func test_gn8_loud_hack_completes_vault_drill() -> void:
	var m: HeistMission = await _launch()
	await _loud()
	assert_eq(m.objective_state(&"vault_drill"), Enums.ObjectiveState.ACTIVE, "loud: hack OR drill the vault")
	var ht: HackTerminal = _hack()
	assert_true(ht != null, "Argus terminal")
	ht.reconfigure(0.2, Vector2i.ZERO)
	ht.start_hack(0)
	assert_true(await wait_until(func() -> bool: return m.objective_state(&"hack") == Enums.ObjectiveState.COMPLETED,
		5.0), "loud hack done")
	assert_eq(m.objective_state(&"vault_drill"), Enums.ObjectiveState.COMPLETED, "the hack opened the vault: drill moot")
	assert_eq(m.objective_state(&"server_door"), Enums.ObjectiveState.COMPLETED, "the hack ran inside SV")


func test_gn8_vault_drill_completes_by_the_drill() -> void:
	var m: HeistMission = await _launch()
	await _loud()
	var drill: Array[Node] = m.find_tagged(&"vault_drill")
	assert_false(drill.is_empty(), "the vault drill")
	if drill.is_empty():
		return
	EventBus.device_finished.emit(_net_id(drill[0]))
	assert_eq(m.objective_state(&"vault_drill"), Enums.ObjectiveState.COMPLETED, "drilled")
	assert_eq(m.objective_state(&"art_store"), Enums.ObjectiveState.COMPLETED, "the vault is open")


func test_gn8_server_keypad_completes_server_door() -> void:
	var m: HeistMission = await _launch()
	await _loud()
	assert_eq(m.objective_state(&"server_door"), Enums.ObjectiveState.ACTIVE, "loud, code unknown: code or drill")
	var kp: Array[Node] = m.find_tagged(&"server_keypad")
	assert_false(kp.is_empty(), "the SV keypad")
	if kp.is_empty():
		return
	_take(kp[0])
	assert_eq(m.objective_state(&"server_door"), Enums.ObjectiveState.COMPLETED, "the code opened the server door")


func test_gn8_server_keypad_in_stealth_leaves_server_door_hidden() -> void:
	var m: HeistMission = await _launch()
	var kp: Array[Node] = m.find_tagged(&"server_keypad")
	if kp.is_empty():
		assert_true(false, "the SV keypad")
		return
	_take(kp[0])
	assert_eq(m.objective_state(&"server_door"), Enums.ObjectiveState.HIDDEN, "a loud-only step stays hidden")
