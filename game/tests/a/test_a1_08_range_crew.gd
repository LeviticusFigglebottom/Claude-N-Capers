## A1-08 / QB-25: CrewController.spawn_for_range + set_loadout work without a HeistRuntime.
extends TestCase

const L3: Script = preload("res://tests/a/test_l3_weapons.gd")

var _root: Node3D = null


func before_each() -> void:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	_root.name = "RangeRoot"
	add_child(_root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
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


func test_qb_25_range_crew_fires_and_swaps_loadout() -> void:
	assert_true(HeistRuntime.current() == null, "no heist running")
	var c: CrewController = CrewController.spawn_for_range(_root,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), null) as CrewController
	await wait_physics_frames(2)
	assert_true(c.masked, "masked")
	assert_true(c.get_node_or_null("PlayerInput") is PlayerInput, "PlayerInput")
	assert_true(c.weapons != null and c.health != null, "Weapons + Health")
	assert_true(c.loadout != null and c.loadout.resolved_secondary != null, "default loadout resolved on crew.loadout")
	var t: Node3D = L3.make_take_hit_target(_root, Vector3(0, 1.0, -5))
	await wait_physics_frames(2)
	var pin: PlayerInput = c.get_node("PlayerInput") as PlayerInput
	pin.enabled = false  # drive the intent directly
	var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), Vector3(0, 1.0, -5))
	i.fire = true
	c.apply_intent(i)
	await wait_physics_frames(2)
	c.apply_intent(CrewIntent.new())
	assert_eq((t.get(&"hits") as Array).size(), 1, "range target hit via take_hit")
	var l: Loadout = Loadout.new()
	l.secondary = &"weapon.kestrel_p9"
	c.set_loadout(l)
	assert_false(c.weapons.is_suppressed(Enums.WeaponSlot.SECONDARY), "instant swap: no suppressor")
	assert_eq(c.weapons.mag(Enums.WeaponSlot.SECONDARY), c.weapons.mag_size(Enums.WeaponSlot.SECONDARY), "re-armed")
	c.queue_free()
