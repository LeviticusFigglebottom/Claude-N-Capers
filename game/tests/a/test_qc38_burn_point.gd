## QC-38 (D-064): burn_point takes a carried thermite bag (consumed), burns `duration_s` (no jams,
## device_started kind &"thermite"), telegraphs (cue.burn_warning, burn_warning_s countdown), then
## device_finished and the fire volume: FIRE DoT that ignores armour (L3.4) on crew inside.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_burn_flow_and_fire_volume() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 3801, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var bp: BurnPoint = ATestMaps.add_prefab(_rt, "burn_point", Vector3(0, 0, -4), func(p: GameplayPrefab) -> void:
		(p as BurnPoint).requires_loot = &"loot.jewelry"  # loot.thermite comes with ENV B's QC-39
		(p as BurnPoint).duration_s = 1.0
		(p as BurnPoint).fire_volume_size = Vector3(4, 3, 4)) as BurnPoint
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -3.0)))
	await wait_physics_frames(2)
	assert_eq(bp.interactable.availability(c), InteractableComponent.BLOCK_ITEM, "needs the thermite bag")
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, c.global_position))
	await wait_physics_frames(1)
	assert_true(loot.carry(bag, c), "carrying the bag")
	assert_eq(bp.interactable.availability(c), InteractableComponent.BLOCK_NONE, "bag in hand: can place it")
	var events: Array = []
	var on_start: Callable = func(id: int, kind: StringName, dur: float) -> void: events.append(["start", id, kind, dur])
	var on_end: Callable = func(id: int) -> void: events.append(["end", id])
	var cues: Array[StringName] = []
	var cue_cb: Callable = ACombatSpecials.record_cues(cues)
	EventBus.device_started.connect(on_start)
	EventBus.device_finished.connect(on_end)
	ATestMaps.hold_interact(_rt, 0, bp.net_id)
	await wait_seconds(Tweak.interaction().burn_place_s + 0.4)
	_rt.set_bot_intent(0, CrewIntent.new())
	assert_eq(bp.stage, BurnPoint.Stage.BURNING, "burning")
	assert_false(c.is_carrying_bag(), "the bag is consumed")
	assert_false(is_instance_valid(bag) and bag.is_inside_tree(), "the bag is gone")
	assert_has(events, ["start", bp.net_id, BurnPoint.KIND, 1.0], "device_started(thermite)")
	await wait_seconds(1.2)
	assert_eq(bp.stage, BurnPoint.Stage.WARNING, "telegraph after the burn")
	assert_has(cues, &"cue.burn_warning", "warning cue")
	assert_false(events.has(["end", bp.net_id]), "no device_finished during the countdown")
	await wait_seconds(Tweak.interaction().burn_warning_s + 0.3)
	assert_eq(bp.stage, BurnPoint.Stage.LIT, "lit")
	assert_has(events, ["end", bp.net_id], "device_finished: the mission drops the shutters")
	EventBus.device_started.disconnect(on_start)
	EventBus.device_finished.disconnect(on_end)
	EventBus.audio_cue_requested.disconnect(cue_cb)
	# Fire: the crew member stands inside the volume.
	var armor0: float = c.health.armor
	var hp0: float = c.health.health
	assert_true(bp.contains(c.global_position + Vector3(0, 0.3, 0)), "inside the fire volume")
	await wait_seconds(1.2)
	assert_true(c.health.health < hp0, "fire hurts (%.1f -> %.1f)" % [hp0, c.health.health])
	assert_near(c.health.armor, armor0, 0.001, "L3.4: fire ignores armour")
	_check_obstacle(bp)


func _check_obstacle(bp: BurnPoint) -> void:
	assert_true(bp.find_child("FireObstacle", true, false) != null, "nav obstacle for AI avoidance")
	assert_true(bp.is_in_group(BurnPoint.GROUP), "in the fire_volume group")
