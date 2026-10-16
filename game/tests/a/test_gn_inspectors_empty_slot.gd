## GN-8 B3: the Gallery Night insurance inspectors (rare insurance_inspection, last call + 180 s) walk in at LD to the
## centrepiece's slot. An empty slot -> they radio the alarm (the Vaultline courier rule, QC-57: loud, never a fail);
## the canvas still hanging (or on the couriers' errand) -> no alarm, they walk back to LD.
## Design: docs/design/heists/gallery_night.md §Rare events (insurance_inspection) and §B3.
extends TestCase

const VARIANTS_PATH: String = "res://world/heists/gallery_night/gallery_night_variants.tres"
const RUN_SEED: int = 1130
const TIME_SCALE: float = 4.0

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## Gallery Night (Hazardous: the event's min_difficulty) with the centrepiece pinned on `slot`.
func _launch(slot: StringName = &"cp_treasury") -> bool:
	var vt: HeistVariantTable = (load(VARIANTS_PATH) as HeistVariantTable).duplicate(true) as HeistVariantTable
	var weights: Dictionary = {}
	for s: StringName in [&"cp_landing", &"cp_treasury", &"cp_store"]:
		weights[s] = 1.0 if s == slot else 0.0
	var by_diff: Dictionary = {}
	for d: int in Enums.Difficulty.values():
		by_diff[d] = weights
	for i: int in range(vt.rules.size()):
		if StringName(vt.rules[i].get("group", &"")) == &"centrepiece":
			var r: Dictionary = vt.rules[i].duplicate(true)
			r["weights_by_difficulty"] = by_diff
			vt.rules[i] = r
	_rt = await HeistLauncher.launch(&"gallery_night", RUN_SEED, Enums.Difficulty.HAZARDOUS, self,
		{"crew_ai": false, "ai_teammates": 0, "variant_table": vt})
	await wait_physics_frames(3)
	var cp: Variant = _rt.mission.variant(&"centrepiece") if _rt != null else null
	var ok: bool = cp is Array and (cp as Array) == [slot]
	assert_true(ok, "centrepiece pinned on %s (%s)" % [slot, cp])
	return ok


func _m() -> HeistMission:
	return _rt.mission


func _slot() -> LootSpawn:
	return _m().call(&"_lantern_slot") as LootSpawn


func _inspectors() -> Array:
	return _m().get(&"inspectors") as Array


func _state() -> StringName:
	return StringName(_m().get(&"inspector_state"))


## The inspectors walk in (the rare event's timed spawn, through the mission's own handler).
func _spawn_inspectors() -> void:
	_m().call(&"_on_timed_spawn", &"rare_insurance_inspection", &"guard_inspection")
	await wait_physics_frames(2)


## Put the inspectors at the slot's UsePoint and let the inspection tick.
func _teleport_to_slot() -> void:
	var stand: Vector3 = _m().call(&"_stand_of", _slot())
	for c: Variant in _inspectors():
		(c as NpcBase).global_position = stand
	await wait_until(func() -> bool: return _state() != &"to_slot", 3.0)


func test_gn_inspectors_spawn_and_head_for_the_slot() -> void:
	if not await _launch():
		return
	await _spawn_inspectors()
	assert_eq(_inspectors().size(), 2, "two inspectors walk in")
	assert_eq(_state(), &"to_slot", "they head for the centrepiece slot")
	for c: Variant in _inspectors():
		var b: GuardBrain = (c as NpcBase).get_node(^"Brain") as GuardBrain
		assert_true(b.route.is_empty(), "no patrol: a scripted walk")
		assert_false(b.at_post(1.0), "walking")


func test_gn_inspectors_alarm_on_an_empty_slot() -> void:
	if not await _launch():
		return
	var slot: LootSpawn = _slot()
	var taken: LootBag = slot.take_for_npc()  # the crew got there first
	assert_true(taken != null and slot.remaining == 0, "slot emptied")
	await _spawn_inspectors()
	await _teleport_to_slot()
	assert_eq(_state(), &"alarm", "the canvas is gone")
	var npc: NpcBase = null
	for c: Variant in _inspectors():
		if (c as NpcBase).alert_state == Enums.AlertState.ALARMED:
			npc = c as NpcBase
	assert_true(npc != null, "an inspector radios it in (S3.3)")
	if npc != null:
		assert_eq((npc.get_node(^"Brain") as GuardBrain).alarm_cause, &"canvas_missing", "cause")
	assert_true(await wait_until(func() -> bool: return _rt.went_loud, Tweak.stealth().guard_radio_call_s + 2.0),
		"the radio call raises the alarm")
	assert_ne(_rt.phase, Enums.HeistPhase.ENDED, "loud, never a fail (B3)")
	assert_eq(_m().objective_state(&"lockdown"), Enums.ObjectiveState.COMPLETED, "the GN lockdown")


func test_gn_inspectors_no_alarm_when_the_canvas_hangs() -> void:
	if not await _launch():
		return
	assert_eq(_slot().remaining, 1, "the Lantern Bearer hangs")
	await _spawn_inspectors()
	await _teleport_to_slot()
	assert_eq(_state(), &"satisfied", "inspected: all in order")
	await wait_physics_frames(10)
	assert_false(_rt.went_loud, "no alarm")
	for c: Variant in _inspectors():
		assert_ne((c as NpcBase).alert_state, Enums.AlertState.ALARMED, "nobody radios")
		var b: GuardBrain = (c as NpcBase).get_node(^"Brain") as GuardBrain
		assert_false(b.at_post(1.0), "they walk back to LD")


## The couriers (vaultline_early) carried it away on their errand: the slot is empty, but the insurer expects that move.
func test_gn_inspectors_no_alarm_when_the_couriers_moved_it() -> void:
	if not await _launch():
		return
	_m().call(&"_on_timed_spawn", &"rare_vaultline_early", &"guard_vaultline")
	await wait_physics_frames(2)
	var stand: Vector3 = _m().call(&"_stand_of", _slot())
	for c: Variant in _m().get(&"couriers") as Array:
		(c as NpcBase).global_position = stand
	await wait_until(func() -> bool: return StringName(_m().get(&"courier_state")) != &"to_slot", 3.0)
	assert_eq(StringName(_m().get(&"courier_state")), &"carrying", "the couriers have the canvas")
	assert_eq(_slot().remaining, 0, "the slot is empty")
	await _spawn_inspectors()
	await _teleport_to_slot()
	assert_eq(_state(), &"satisfied", "the couriers' move is expected")
	assert_false(_rt.went_loud, "no alarm")


func test_gn_inspectors_stopped_on_the_way_never_alarm() -> void:
	if not await _launch():
		return
	_slot().take_for_npc()
	await _spawn_inspectors()
	for c: Variant in _inspectors():
		(c as NpcBase).die({}, 0)
	assert_true(await wait_until(func() -> bool: return _state() == &"intercepted", 2.0), "errand over")
	await wait_physics_frames(5)
	assert_ne(_state(), &"alarm", "the dead do not radio the empty slot")


## The real walk: LD -> the Treasury slot through the guard_inspection doors, then back (the canvas hangs).
func test_gn_inspectors_walk_to_the_treasury_slot() -> void:
	if not await _launch(&"cp_treasury"):
		return
	Engine.time_scale = TIME_SCALE
	await _spawn_inspectors()
	var ok: bool = await wait_until(func() -> bool: return _state() != &"to_slot", 240.0)
	assert_true(ok, "the inspectors reach the slot (state %s, at %s)" % [_state(),
		(_inspectors()[0] as NpcBase).global_position if not _inspectors().is_empty() else Vector3.ZERO])
	assert_eq(_state(), &"satisfied", "and find it in order")
	assert_false(_rt.went_loud, "no alarm on the way")
