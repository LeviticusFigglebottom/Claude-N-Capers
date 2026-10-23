## S1.3 civilian mode (start_mode = civilian, B5-05): no gear (no mask-up, no firing), undetectable, only
## civilian_allowed interactions; the gear pickup moves a civilian to casing; an alarm masks everyone (ends it);
## HUD player_mode / crew[].mode (ui_hud v1.6).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(opts: Dictionary = {}) -> CrewController:
	var o: Dictionary = {"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false}
	o.merge(opts, true)
	_rt = await HeistLauncher.launch(&"unit_map", 1303, Enums.Difficulty.ROUTINE, self, o)
	await wait_physics_frames(2)
	return _rt.crew_controller(0) as CrewController


func test_default_start_is_casing() -> void:
	var c: CrewController = await _launch()
	assert_eq(_rt.start_mode, HeistRuntime.START_CASING)
	assert_false(c.civilian, "no civilian mode by default")
	assert_eq(c.player_mode, &"casing")
	_rt.hud_model.refresh()  # LEAD: deterministic poll
	assert_eq(_rt.hud_model.player_mode, &"casing", "ui_hud v1.6 player_mode")


func test_civilian_start_no_mask_up_and_no_fire() -> void:
	var c: CrewController = await _launch({"start_mode": &"civilian"})
	assert_eq(_rt.phase, Enums.HeistPhase.CASING, "civilians are in the casing phase")
	for m: CrewController in _rt.crew_members():
		assert_true(m.civilian, "every crew member starts civilian (slot %d)" % m.slot)
	assert_eq(c.player_mode, &"civilian")
	await wait_physics_frames(2)
	_rt.hud_model.refresh()  # LEAD: the HUD polls on render frames at poll_hz; 2 physics frames may not poll
	assert_eq(_rt.hud_model.player_mode, &"civilian", "HUD player_mode")
	var mates: Array[Dictionary] = _rt.hud_model.crew
	assert_true(not mates.is_empty() and StringName(mates[0].get("mode", &"")) == &"civilian", "crew[].mode")
	var i: CrewIntent = CrewIntent.new()
	i.mask_up = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(Tweak.crew().mask_up_time_s + 0.5)
	assert_false(c.masked, "S1.3: no mask-up without gear")
	assert_false(c.weapons.can_fire(), "no firing")


func test_civilian_is_undetectable_in_restricted() -> void:
	var c: CrewController = await _launch({"start_mode": &"civilian"})
	ATestMaps.add_zone(_rt.map, MapZone.Kind.RESTRICTED, Vector3(0, 1, -5), Vector3(12, 3, 12))
	var guard: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(0, 0.05, -8), Vector3(0, 0, 1))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4)))
	await wait_physics_frames(4)
	assert_near(_rt.stealth.fill_rate(guard, c), 0.0, 0.0001, "S1.3: civilians are undetectable")
	c.civilian = false
	await wait_physics_frames(1)
	assert_true(_rt.stealth.fill_rate(guard, c) > 0.0, "the same spot spots a casing crew member (control)")


func test_gear_pickup_ends_civilian_mode_and_only_civilian_allowed() -> void:
	var c: CrewController = await _launch({"start_mode": &"civilian"})
	var card: GameplayPrefab = ATestMaps.add_prefab(_rt, "keycard_pickup", Vector3(3, 0, 0))
	var gear: GearPickup = ATestMaps.add_prefab(_rt, "gear_pickup", Vector3(0, 0, -2)) as GearPickup
	await wait_physics_frames(2)
	assert_eq(card.interactable.availability(c), InteractableComponent.BLOCK_CIVILIAN, "keycard: not for civilians")
	assert_eq(gear.interactable.availability(c), InteractableComponent.BLOCK_NONE, "the gear bag is")
	var picked: Array = []
	var cb: Callable = func(item: StringName, slot: int) -> void: picked.append([item, slot])
	EventBus.item_picked_up.connect(cb)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, gear.global_position + Vector3(0, 0.05, 0.9)))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, gear.net_id)
	await wait_seconds(Tweak.interaction().item_pickup_s + 0.5)
	_rt.set_bot_intent(0, CrewIntent.new())
	EventBus.item_picked_up.disconnect(cb)
	assert_false(c.civilian, "gear taken: casing")
	assert_eq(c.player_mode, &"casing")
	assert_has(picked, [GearPickup.ITEM, 0], "item_picked_up(item.gear, slot) [R]")
	assert_true(is_instance_valid(gear) and gear.is_inside_tree(), "the bag stays for the others")
	assert_ne(gear.interactable.availability(c), InteractableComponent.BLOCK_NONE, "...but not for whoever has gear")
	var mate: CrewController = _rt.crew_controller(1) as CrewController
	assert_true(mate.is_ai, "slot 1 is an AI teammate")
	assert_false(mate.civilian, "D-065 P5: AI teammates gear up with the first human")
	# B r308 HUD pass: the used bag kept prompting "Hold F to pick up your gear" in red for the rest of the heist.
	assert_false(gear.interactable.aim_filter.call(c), "a geared player never targets the bag (no prompt)")
	assert_false(gear.interactable.enabled, "nobody in the crew still needs gear: the bag is off for everyone")


## B r308: per player while someone still needs gear (co-op: the other humans take theirs from the same bag).
func test_gear_bag_targets_only_crew_without_gear() -> void:
	var c: CrewController = await _launch({"start_mode": &"civilian"})
	var gear: GearPickup = ATestMaps.add_prefab(_rt, "gear_pickup", Vector3(0, 0, -2)) as GearPickup
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, gear.global_position + Vector3(0, 0.05, 0.9)))
	await wait_physics_frames(2)
	assert_true(gear.interactable.aim_filter.call(c), "a civilian targets the bag")
	c.civilian = false
	assert_false(gear.interactable.aim_filter.call(c), "geared: filtered out")
	assert_true(_rt.interaction.aimed_component(c) != gear.interactable, "and the aim never resolves to it")
	assert_true(gear.interactable.enabled, "still on while the bag was never used (another human may need it)")


func test_alarm_masks_civilians() -> void:
	var c: CrewController = await _launch({"start_mode": &"civilian"})
	EventBus.alarm_raised.emit(&"test", 0)
	await wait_physics_frames(1)
	for m: CrewController in _rt.crew_members():
		assert_true(m.masked and not m.civilian, "S1.2/S1.3: alarm masks everyone, civilian mode ends (slot %d)" % m.slot)
	assert_eq(c.player_mode, &"masked")
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD)
