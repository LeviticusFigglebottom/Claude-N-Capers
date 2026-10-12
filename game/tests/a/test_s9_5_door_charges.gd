## S9.5 / A5-03: a locked BARRED / CODE / ELECTRONIC door with charges_required is blown open by C4 items or
## trip mines used as shaped charges (interaction.shaped_charge); explosion noise, then unlocked + open.
extends TestCase

var _rt: HeistRuntime = null
var _noises: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_noises.clear()
	_rt = await HeistLauncher.launch(&"unit_doors", 909, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	_rt.noise_made.connect(func(p: Vector3, r: float, k: StringName, s: int) -> void: _noises.append([p, r, k, s]))


func after_each() -> void:
	Engine.time_scale = 1.0
	Modifiers.clear_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _door(lock: Door.Lock, charges: int) -> Door:
	return ATestMaps.add_prefab(_rt, "door", Vector3(0, 0, -6), func(n: Node) -> void:
		var d: Door = n as Door
		d.lock = lock
		d.charges_required = charges) as Door


func test_s9_5_barred_door_needs_charges_then_blows_open() -> void:
	var c: CrewController = _crew()
	var d: Door = _door(Door.Lock.BARRED, 2)
	await wait_physics_frames(2)
	assert_eq(d.interactable.kind, &"place_c4")
	assert_eq(d.interactable.availability(c), InteractableComponent.BLOCK_ITEM, "no charges")
	var dep: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	dep.give(c.slot, &"deployable.trip_mine")
	Modifiers.set_source(c.slot, &"test", {&"interaction.shaped_charge": true})
	assert_eq(d.interactable.availability(c), InteractableComponent.BLOCK_NONE, "2 of 3 trip mines")
	_rt.teleport_crew(0, d.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, d.net_id)
	await wait_seconds(Tweak.interaction().c4_place_s + 0.15)
	_rt.clear_bot_intent(0)
	assert_true(d.c4_armed, "armed")
	assert_eq(dep.count_of_kind(c.slot, &"trip_mine"), 1, "2 spent")
	assert_true(d.locked, "still locked during the fuse")
	Engine.time_scale = 4.0
	var ok: bool = await wait_until(func() -> bool: return not d.locked and d.is_open, Tweak.interaction().c4_fuse_s + 2.0)
	Engine.time_scale = 1.0
	assert_true(ok, "blown open")
	var boom: int = 0
	for e: Array in _noises:
		if e[2] == &"explosion":
			boom += 1
	assert_eq(boom, 1, "explosion noise")


func test_s9_5_charges_zero_keeps_old_behaviour() -> void:
	var d: Door = _door(Door.Lock.BARRED, 0)
	await wait_physics_frames(2)
	assert_eq(d.interactable.kind, &"open_door")
	assert_eq(d.interactable.availability(_crew()), InteractableComponent.BLOCK_STATE, "barred: other prefabs only")
