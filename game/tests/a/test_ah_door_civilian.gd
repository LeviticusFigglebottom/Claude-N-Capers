## AH (D-075 guest doors, LEAD r305): Door.civilian_allowed passes through to its interactable. A civilian player
## opens a guest door and is refused by a staff door (ui.blocked.civilian); relock() keeps the flag.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	_rt = await HeistLauncher.launch(&"unit_map", 1305, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "start_mode": &"civilian"})
	await wait_physics_frames(2)
	return _rt.crew_controller(0) as CrewController


func _door(pos: Vector3, guest: bool) -> Door:
	return ATestMaps.add_prefab(_rt, "door", pos, func(p: GameplayPrefab) -> void:
		(p as Door).civilian_allowed = guest) as Door


## Stand at `door`'s use side, aim at its handle and hold interact until it opens (or `limit_s`).
func _open(c: CrewController, door: Door, limit_s: float) -> bool:
	var comp: InteractableComponent = door.interactable
	var use: Node3D = door.get_node_or_null(^"UsePoint") as Node3D
	var stand: Vector3 = use.global_position if use != null else door.to_global(Vector3(0, 0, -0.9))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, stand + Vector3(0, 0.05, 0)))
	await wait_physics_frames(3)
	var to: Vector3 = comp.global_position - c.eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-to.x, -to.z)
	i.look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	i.interact = true
	_rt.set_bot_intent(0, i)
	var opened: bool = await wait_until(func() -> bool: return door.is_open, limit_s)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(1)
	return opened


func test_civilian_opens_a_guest_door_not_a_staff_door() -> void:
	var c: CrewController = await _launch()
	assert_true(c.civilian, "civilian start")
	var guest: Door = _door(Vector3(-4, 0, 0), true)
	var staff: Door = _door(Vector3(4, 0, 0), false)
	await wait_physics_frames(2)
	assert_true(guest.interactable.civilian_allowed, "the export reaches the interactable")
	assert_false(staff.interactable.civilian_allowed, "default: a staff door")
	assert_eq(guest.interactable.availability(c), InteractableComponent.BLOCK_NONE, "guest door: usable")
	assert_eq(staff.interactable.availability(c), InteractableComponent.BLOCK_CIVILIAN, "staff door: refused")
	var limit: float = Tweak.interaction().door_open_s + 1.5
	assert_true(await _open(c, guest, limit), "the civilian opened the guest door")
	assert_false(await _open(c, staff, limit), "the staff door stays shut for a civilian")


func test_relock_keeps_the_civilian_flag() -> void:
	var c: CrewController = await _launch()
	var guest: Door = _door(Vector3(-4, 0, 0), true)
	await wait_physics_frames(2)
	guest.relock(Door.Lock.LOCKPICK)
	await wait_physics_frames(1)
	assert_true(guest.interactable.civilian_allowed, "relock re-applies civilian_allowed")
	c.civilian = false
	assert_eq(guest.interactable.availability(c), InteractableComponent.BLOCK_CASING,
		"a casing player still may not pick a lock unmasked")
