## Lead (ND attempt 15): a player who holds interact on Night Deposit's TellerDoor (a LOCKPICK door, night_deposit.md
## G8) must finish the pick: aim-resolved like a real F hold (no explicit target id), from the door's UsePoint side,
## the door unlocks within InteractionTweak.lockpick_door_s (+ margin) and the hold never drops.
extends TestCase

const MARGIN_S: float = 1.5

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.clear_bot_intent(0)
		_rt.teardown()
	Input.action_release(&"interact")
	Modifiers.clear_all()
	_rt = null
	await wait_frames(1)


func test_nd_teller_door_lockpick_completes_with_a_held_aimed_interact() -> void:
	_rt = await HeistLauncher.launch(&"night_deposit", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched")
	var door: Door = _rt.map.find_child("TellerDoor", true, false) as Door
	assert_true(door != null, "TellerDoor exists")
	assert_eq(door.lock, Door.Lock.LOCKPICK, "TellerDoor is a lockpick door (night_deposit.md G8)")
	assert_true(door.locked, "starts locked")
	var comp: InteractableComponent = door.interactable
	assert_eq(comp.kind, &"lockpick", "offers a lockpick")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
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
	await wait_physics_frames(2)
	assert_true(_rt.interaction.aimed_component(c) == comp, "the aim from the UsePoint resolves to the door's lockpick")
	var limit: float = Tweak.interaction().lockpick_door_s * Modifiers.mult(0, &"interaction.lockpick_speed_mult") + MARGIN_S
	var t0: int = Time.get_ticks_msec()
	var gaps: int = 0
	var picked: bool = false
	while (Time.get_ticks_msec() - t0) / 1000.0 < limit + 1.0:
		await wait_physics_frames(1)
		if not door.locked:
			picked = true
			break
		if _rt.interaction.session(0).is_empty():
			gaps += 1  # the hold dropped (an F press resolved as something else, or the hold broke)
	var took: float = (Time.get_ticks_msec() - t0) / 1000.0
	_rt.clear_bot_intent(0)
	assert_true(picked, "held lockpick unlocked the door (%.1f s, limit %.1f s)" % [took, limit])
	assert_true(took <= limit, "within lockpick_door_s + %.1f s (%.1f s)" % [MARGIN_S, took])
	assert_true(gaps <= 1, "the hold never dropped (%d frames without a session)" % gaps)


## Lead (PD2 F rule): with a dominatable cop 2 m beside the door in view, holding F (the real PlayerInput path:
## interact when an interactable is aimed, shout only otherwise) still picks the lock, and the cop is not dominated.
func test_nd_teller_door_hold_f_picks_lock_with_a_cop_beside_it() -> void:
	_rt = await HeistLauncher.launch(&"night_deposit", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	var door: Door = _rt.map.find_child("TellerDoor", true, false) as Door
	var comp: InteractableComponent = door.interactable
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	var use: Node3D = door.get_node_or_null(^"UsePoint") as Node3D
	var stand: Vector3 = use.global_position if use != null else door.to_global(Vector3(0, 0, -0.9))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, stand + Vector3(0, 0.05, 0)))
	await wait_physics_frames(3)
	# A cop 2 m to the side of the door, in view (inside the shout cone, outside the interaction cone).
	var side: Vector3 = door.global_basis.x.normalized() * 2.0
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(door.global_position.x + side.x,
		stand.y + 0.05, door.global_position.z + side.z)), {})
	for n: String in ["Brain", "Motor"]:
		var node: Node = cop.get_node_or_null(n)
		if node != null:
			node.set_physics_process(false)
	await wait_physics_frames(3)
	var pin: PlayerInput = c.get_node(^"PlayerInput") as PlayerInput
	var to: Vector3 = comp.global_position - c.eye_position()
	pin.set(&"_yaw", atan2(-to.x, -to.z))
	pin.set(&"_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	await wait_physics_frames(2)
	assert_true(_rt.interaction.aimed_component(c) == comp, "the door's lockpick is the aimed interactable")
	Input.action_press(&"interact")
	var limit: float = Tweak.interaction().lockpick_door_s * Modifiers.mult(0, &"interaction.lockpick_speed_mult") + MARGIN_S
	var picked: bool = await wait_until(func() -> bool: return not door.locked, limit + 1.0)
	Input.action_release(&"interact")
	var sur: PoliceSurrender = PoliceSurrender.of(cop)
	var dominated: bool = sur != null and sur.is_surrendered()
	assert_true(picked, "holding F picked the lock with a cop beside the door")
	assert_false(dominated, "the cop beside the door was not dominated by the F hold")
