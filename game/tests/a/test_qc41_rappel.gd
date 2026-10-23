## QC-41: RAPPEL TacticalPoints get one-way NavigationLink3Ds down to the floor below (RappelLinks), and
## NpcMotor descends them (`rappelling`) through skylights.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4101, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)


func test_links_built_one_way_to_the_floor() -> void:
	await _launch()
	# A roof slab at +8 m with the RAPPEL point at its edge (the skylight is beside the slab here).
	ATestMaps.add_wall(_rt.map, Vector3(-3, 7.9, -5), Vector3(4, 0.2, 4))
	var tp: TacticalPoint = TacticalPoint.new()
	tp.kind = TacticalPoint.Kind.RAPPEL
	tp.name = "RappelSkylight"
	_rt.map.add_child(tp)
	tp.global_position = Vector3(0, 8.0, -5)
	await wait_physics_frames(2)
	assert_eq(RappelLinks.build(_rt.map), 1, "one link per RAPPEL point")
	var link: NavigationLink3D = tp.get_node_or_null(RappelLinks.LINK_NAME) as NavigationLink3D
	assert_true(link != null, "RappelLink child")
	if link == null:
		return
	assert_false(link.bidirectional, "one-way: police come down only")
	assert_true(link.has_meta(RappelLinks.META), "marked for NpcMotor")
	assert_eq(link.navigation_layers, Door.NAV_LAYER_BREACH, "police / specials only: the crew never paths down it")
	var end: Vector3 = link.global_transform * link.end_position
	assert_near(end.y, 0.0, 0.1, "ends on the floor 8 m below")
	assert_eq(RappelLinks.build(_rt.map), 0, "idempotent")


func test_motor_rappels_down() -> void:
	await _launch()
	ATestMaps.add_wall(_rt.map, Vector3(0, 7.9, -5), Vector3(3, 0.2, 3))
	await wait_physics_frames(2)
	var npc: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 8.05, -5)), {})
	for nm: String in ["Brain", "Gunner"]:
		var c: Node = npc.get_node_or_null(nm)
		if c != null:
			c.set_physics_process(false)
	await wait_physics_frames(3)
	assert_true(npc.global_position.y > 7.5, "standing on the roof")
	var m: NpcMotor = npc.get_node("Motor") as NpcMotor
	m.start_rappel(Vector3(0.5, 0.0, -2.5))
	await wait_physics_frames(2)
	assert_true(m.rappelling, "rappelling through the roof slab")
	var ad: AnimDriver = AnimDriver.of(npc)
	if ad != null:
		assert_eq(ad.choose_clip(), &"rappel", "characters.md v1.8: the rappel loop while descending")
	await wait_seconds(8.0 / m.rappel_speed + 0.6)
	assert_false(m.rappelling, "landed")
	assert_near(npc.global_position.y, 0.0, 0.15, "on the floor below")
