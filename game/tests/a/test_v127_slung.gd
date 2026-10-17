## characters.md v1.27 (D 7dc91bd0): a cartel look's slung gun (Skeleton3D/Slung) hides while a seated clip plays
## and shows again after; a rig without the node is left alone.
extends TestCase


func test_v127_seated_clips() -> void:
	for c: StringName in [&"sit_chair", &"sit_chair_armed", &"sit_chair_watch", &"sit_chair_read", &"desk_work",
			&"phone_seated", &"cower_seated", &"death_seated_slump", &"death_seated_fall"]:
		assert_true(HeldVisuals.seated_clip(c), "%s is seated" % c)
	for c: StringName in [&"idle", &"walk", &"idle_thug", &"aim_rifle", &"death_back", &"desk_type"]:
		assert_false(HeldVisuals.seated_clip(c), "%s is not seated" % c)


func test_v127_slung_hides_while_seated() -> void:
	var rig: Node3D = Node3D.new()
	var sk: Skeleton3D = Skeleton3D.new()
	sk.name = "Skeleton3D"
	rig.add_child(sk)
	var slung: MeshInstance3D = MeshInstance3D.new()
	slung.name = "Slung"
	sk.add_child(slung)
	HeldVisuals.update_slung(rig, &"sit_chair_armed")
	assert_false(slung.visible, "hidden on the chair")
	HeldVisuals.update_slung(rig, &"idle_thug")
	assert_true(slung.visible, "back when he stands")
	var bare: Node3D = Node3D.new()
	HeldVisuals.update_slung(bare, &"sit_chair")  # no Slung node: nothing happens
	HeldVisuals.update_slung(null, &"sit_chair")
	rig.free()
	bare.free()
