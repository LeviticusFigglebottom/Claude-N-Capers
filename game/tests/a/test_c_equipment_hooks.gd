## ENV C equipment art hooks (4993f31d): per-device DrillPoint defaults (thermal / saw, the drill as the thermal
## fallback, never a drill on a saw), the ammo pickup visual (prop or placeholder box), the zipline cable drawn
## between its ends, and the burn barrel's flickering fire light.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1140, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func test_drill_point_device_defaults() -> void:
	await _launch()
	for dev: int in [DrillPoint.Device.DRILL, DrillPoint.Device.THERMAL, DrillPoint.Device.SAW]:
		var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(float(dev) * 2.0, 1, -5), func(p: GameplayPrefab) -> void:
			(p as DrillPoint).device = dev as DrillPoint.Device) as DrillPoint
		await wait_physics_frames(1)
		var ps: PackedScene = dp._device_scene()
		var own: String = DrillPoint.DEFAULT_DEVICE
		if dev == DrillPoint.Device.THERMAL:
			own = DrillPoint.DEFAULT_THERMAL
		elif dev == DrillPoint.Device.SAW:
			own = DrillPoint.DEFAULT_SAW
		if ResourceLoader.exists(G.PROPS_DIR + own):
			assert_eq(ps.resource_path, G.PROPS_DIR + own, "device %d uses its own prop" % dev)
		elif dev == DrillPoint.Device.SAW:
			assert_true(ps == null, "no saw prop yet: nothing, never the drill")
		else:
			assert_true(ps == null or ps.resource_path == G.PROPS_DIR + DrillPoint.DEFAULT_DEVICE, "drill fallback")


func test_ammo_pickup_visual_and_zipline_cable_and_fire_light() -> void:
	await _launch()
	var ap: AmmoPickup = AmmoPickup.new()
	_rt.dynamic_root.add_child(ap)
	assert_true(ap.get_node_or_null(^"Visual") != null, "ammo pickup has a visual (prop or placeholder)")
	var zl: Node3D = ATestMaps.add_prefab(_rt, "zipline", Vector3(0, 0, -6), func(p: GameplayPrefab) -> void:
		var e: Marker3D = Marker3D.new()
		e.name = "End"
		e.position = Vector3(0, -2, -10)
		p.add_child(e)
		p.set(&"end", NodePath("End")))
	await wait_physics_frames(2)
	var cable: MeshInstance3D = zl.get_node_or_null(^"Cable") as MeshInstance3D
	assert_true(cable != null, "the zipline draws its cable")
	var z: Zipline = zl as Zipline
	assert_near((cable.mesh as CylinderMesh).height, z.start_position().distance_to(z.end_position()), 0.01, "cable spans the line")
	var bp: Node = ATestMaps.add_prefab(_rt, "burn_point", Vector3(6, 0, -6))
	await wait_physics_frames(1)
	bp.call(&"_show_fire", true)
	var light: OmniLight3D = bp.get_node_or_null(^"FireLight") as OmniLight3D
	assert_true(light != null and light.visible and bp.is_processing(), "fire light flickers while burning")
	bp.call(&"_show_fire", false)
	assert_true(not light.visible and not bp.is_processing(), "off when out")
