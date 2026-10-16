## D-118: CrewGadgetVisual draws a teammate's / bot's laser (beam raycast to the first hit + dot) and flashlight
## (SpotLight3D, shadows off) in third person for the equipped slot while its gadget is on (visual_slots v1.3).
extends TestCase

var _root: Node3D = null


func before_each() -> void:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	_root.name = "GadgetVisualRoot"
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


static func _rig() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TestRig"
	var skel: Skeleton3D = Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.add_bone("hand.R")
	root.add_child(skel)
	var hand: BoneAttachment3D = BoneAttachment3D.new()
	hand.name = "HandR"
	hand.bone_name = "hand.R"
	hand.override_pose = false
	skel.add_child(hand)
	var socket: Marker3D = Marker3D.new()
	socket.name = "Socket"
	socket.position = Vector3(0.25, 1.3, -0.3)
	hand.add_child(socket)
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib: AnimationLibrary = AnimationLibrary.new()
	for c: StringName in [&"idle", &"idle_alert", &"aim_rifle", &"aim_pistol", &"walk", &"run"]:
		var a: Animation = Animation.new()
		a.length = 1.0
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(c, a)
	ap.add_animation_library(AnimDriver.LIBRARY, lib)
	root.add_child(ap)
	return root


func _wall(z_face: float) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = CombatTweak.data().hitscan_mask
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10, 6, 1)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(0, 2, z_face - 0.5)
	_root.add_child(wall)
	return wall


func _bot(l: Loadout = null) -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(1, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, l)
	var visual: Node3D = crew.get_node(^"Visual") as Node3D
	for c: Node in visual.get_children():
		c.free()
	visual.add_child(_rig())
	_root.add_child(crew)
	crew.masked = true
	return crew


func _gadgets(c: CrewController, ws: int, kinds: Array[StringName]) -> void:
	var st: WeaponStats = c.weapons.stats(ws)
	if st != null:
		st.gadgets = kinds


func test_d118_toggle_shows_beam_and_light() -> void:
	var c: CrewController = _bot()
	await wait_frames(3)  # CrewView.refresh is deferred
	var g: CrewGadgetVisual = CrewGadgetVisual.of(c)
	assert_true(g != null, "a bot body gets a GadgetVisual")
	if g == null:
		return
	var ws: int = c.weapons.equipped_slot
	_gadgets(c, ws, [&"laser", &"flashlight"] as Array[StringName])
	assert_false(g.beam.visible or g.light.visible or g.dot.visible, "off: nothing shown")
	assert_true(c.weapons.toggle_gadget(), "authority toggle: on")
	assert_true(g.beam.visible, "laser beam visible")
	assert_true(g.light.visible, "flashlight visible")
	assert_false(g.light.shadow_enabled, "flashlight casts no shadows")
	assert_near(g.light.spot_range, 25.0, 0.01, "light range 25 m (contract default)")
	assert_near(g.light.spot_angle, 30.0, 0.01, "cone angle from the params")
	assert_near(g.beam_length, 50.0, 0.01, "nothing in front: capped at the laser range")
	assert_false(g.dot.visible, "no hit: no dot")
	c.weapons.toggle_gadget()
	assert_false(g.beam.visible or g.light.visible, "toggle again: hidden")
	_gadgets(c, ws, [&"flashlight"] as Array[StringName])
	c.weapons.toggle_gadget()
	assert_true(g.light.visible and not g.beam.visible, "flashlight-only weapon: light, no beam")


func test_d118_beam_follows_raycast_to_wall() -> void:
	var c: CrewController = _bot()
	var near: StaticBody3D = _wall(-4.0)
	await wait_frames(3)
	await wait_physics_frames(2)
	var g: CrewGadgetVisual = CrewGadgetVisual.of(c)
	var ws: int = c.weapons.equipped_slot
	_gadgets(c, ws, [&"laser"] as Array[StringName])
	c.weapons.toggle_gadget()
	g.update_now()
	var o: Transform3D = g._origin(CrewGadgetVisual.LASER_MARKER)
	var fwd: Vector3 = -o.basis.orthonormalized().z
	assert_true(fwd.dot(Vector3.FORWARD) > 0.9, "beam points along the body's -Z")
	var expected: float = (o.origin.z - (-4.0)) / fwd.dot(Vector3.FORWARD)
	assert_near(g.beam_length, expected, 0.05, "beam stops at the wall")
	assert_true(g.dot.visible, "dot at the hit")
	assert_near(g.dot.global_position.z, -4.0 + AnimTweak.data().gadget_dot_offset_m, 0.02, "dot on the wall")
	assert_near(g.beam.global_transform.basis.z.length(), g.beam_length, 0.01, "beam mesh scaled to the hit")
	var far: StaticBody3D = _wall(-9.0)
	near.queue_free()
	await wait_physics_frames(3)
	g.update_now()
	assert_near(g.beam_length, (o.origin.z + 9.0) / fwd.dot(Vector3.FORWARD), 0.05, "wall moved: beam follows")
	far.queue_free()


func test_d118_swap_to_slot_with_gadget_off_hides() -> void:
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.corsair_ar"
	l.secondary = &"weapon.kestrel_p9"
	var c: CrewController = _bot(l)
	await wait_frames(3)
	var g: CrewGadgetVisual = CrewGadgetVisual.of(c)
	assert_true(c.weapons.has_weapon(Enums.WeaponSlot.PRIMARY) and c.weapons.has_weapon(Enums.WeaponSlot.SECONDARY),
		"loadout has two weapons")
	var first: int = c.weapons.equipped_slot
	var other: int = Enums.WeaponSlot.SECONDARY if first == Enums.WeaponSlot.PRIMARY else Enums.WeaponSlot.PRIMARY
	_gadgets(c, first, [&"laser", &"flashlight"] as Array[StringName])
	_gadgets(c, other, [&"laser"] as Array[StringName])
	c.weapons.toggle_gadget()
	assert_true(g.beam.visible and g.light.visible, "first slot on")
	assert_true(c.weapons.equip(other), "swap")
	assert_false(g.beam.visible or g.light.visible or g.dot.visible, "other slot's gadget off: hidden")
	assert_true(c.weapons.equip(first), "swap back")
	assert_true(g.beam.visible and g.light.visible, "first slot's gadget is still on")


func test_d118_client_state_and_local_owner() -> void:
	var c: CrewController = _bot()
	await wait_frames(3)
	var g: CrewGadgetVisual = CrewGadgetVisual.of(c)
	var ws: int = c.weapons.equipped_slot
	_gadgets(c, ws, [&"laser"] as Array[StringName])
	c.weapons.apply_gadget_bits(1 << ws)  # client copy of the replicated "gd" state
	assert_true(g.beam.visible, "replicated state shows the beam")
	c.weapons.apply_gadget_bits(0)
	assert_false(g.beam.visible, "replicated off hides it")
	var me: CrewController = CrewController.spawn_for_range(_root, Transform3D(Basis.IDENTITY, Vector3(3, 0, 0)), null) \
		as CrewController
	(me.get_node("PlayerInput") as PlayerInput).enabled = false
	await wait_frames(3)
	var mine: CrewGadgetVisual = CrewGadgetVisual.of(me)
	if mine != null:
		_gadgets(me, me.weapons.equipped_slot, [&"laser"] as Array[StringName])
		me.weapons.toggle_gadget()
		mine.update_now()
		assert_false(mine.beam.visible, "local first-person owner: no third-person beam")
	else:
		assert_true(true, "local first-person owner gets no GadgetVisual")
