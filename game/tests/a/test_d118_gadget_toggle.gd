## D-118: CrewIntent.gadget (edge) flips the equipped weapon's laser / flashlight on the server
## (CrewWeapons.gadget_on / gadget_changed); a weapon without one ignores it; the state rides the crew net
## state ("gd") and a client copy re-emits gadget_changed.
extends TestCase

var _root: Node3D = null


func before_each() -> void:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	_root.name = "GadgetRoot"
	add_child(_root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	_root.add_child(floor_body)
	await wait_physics_frames(1)


func after_each() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	await wait_frames(1)


func _crew(x: float) -> CrewController:
	var c: CrewController = CrewController.spawn_for_range(_root,
		Transform3D(Basis.IDENTITY, Vector3(x, 0.05, 0)), null) as CrewController
	(c.get_node("PlayerInput") as PlayerInput).enabled = false
	return c


func _press(c: CrewController) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.gadget = true
	c.apply_intent(i)
	await wait_physics_frames(2)
	c.apply_intent(CrewIntent.new())
	await wait_physics_frames(2)


func test_d118_gadget_edge_toggles_and_replicates() -> void:
	var c: CrewController = _crew(0.0)
	await wait_physics_frames(2)
	var ws: int = c.weapons.equipped_slot
	var st: WeaponStats = c.weapons.stats(ws)
	assert_true(st != null, "equipped weapon has stats")
	st.gadgets = [] as Array[StringName]
	await _press(c)
	assert_false(c.weapons.gadget_on(ws), "no laser / flashlight: the press does nothing")
	st.gadgets = [&"flashlight"] as Array[StringName]
	var seen: Array = []
	c.weapons.gadget_changed.connect(func(w: int, on: bool) -> void: seen.append([w, on]))
	await _press(c)
	assert_true(c.weapons.gadget_on(ws), "press: flashlight on")
	assert_eq(seen, [[ws, true]], "one gadget_changed(on)")
	var held: CrewIntent = CrewIntent.new()
	held.gadget = true
	c.apply_intent(held)
	await wait_physics_frames(4)
	assert_eq(seen.size(), 2, "holding the key toggles once (edge)")
	assert_false(c.weapons.gadget_on(ws), "second press: off")
	c.apply_intent(CrewIntent.new())
	await wait_physics_frames(2)
	await _press(c)
	assert_true(c.weapons.gadget_on(ws), "third press: on again")
	var d: Dictionary = NetEntityCodec.state_of(c)
	assert_eq(int(d.get("gd", -1)), 1 << ws, "net state carries the gadget bit")
	var mirror: CrewController = _crew(3.0)
	await wait_physics_frames(2)
	var mirror_seen: Array = []
	mirror.weapons.gadget_changed.connect(func(w: int, on: bool) -> void: mirror_seen.append([w, on]))
	NetEntityCodec.apply_state(mirror, {"gd": d["gd"]})
	assert_true(mirror.weapons.gadget_on(ws), "applied state: gadget on")
	assert_eq(mirror_seen, [[ws, true]], "client copy emits gadget_changed")
	NetEntityCodec.apply_state(mirror, {"gd": 0})
	assert_false(mirror.weapons.gadget_on(ws), "applied 0: off")
	assert_eq(mirror.weapons.toggle_gadgets(ws).size(), 0, "mirror's own stats have no gadget (state only)")
	c.queue_free()
	mirror.queue_free()
