## A3-09 (5): device cues without their own EventBus signal reach the audio player through
## EventBus.audio_cue_requested(cue_id, pos, net_id): keypad_accept, c4_armed / c4_explode,
## time_lock_start / time_lock_done, zipline_attach, laser_trip (bag lift and hack: their own tests).
extends TestCase

var _rt: HeistRuntime = null
var _cues: Array[Array] = []
var _cb: Callable = Callable()


func before_each() -> void:
	Engine.time_scale = 1.0
	_cues.clear()
	_rt = await HeistLauncher.launch(&"unit_device_cues", 6060, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	_cb = func(cue_id: StringName, _p: Vector3, id: int) -> void: _cues.append([cue_id, id])
	EventBus.audio_cue_requested.connect(_cb)


func after_each() -> void:
	Engine.time_scale = 1.0
	if EventBus.audio_cue_requested.is_connected(_cb):
		EventBus.audio_cue_requested.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _has_cue(cue_id: StringName, source: int) -> bool:
	for e: Array in _cues:
		if e[0] == cue_id and int(e[1]) == source:
			return true
	return false


func _crew() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _use(p: GameplayPrefab, seconds: float) -> void:
	_crew()
	_rt.teleport_crew(0, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.15)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)


func test_keypad_and_time_lock_cues() -> void:
	var pad: Keypad = ATestMaps.add_prefab(_rt, "keypad", Vector3(-4, 1.2, -6), func(n: Node) -> void:
		(n as Keypad).code_group = &"office") as Keypad
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(3, 0, -6), func(n: Node) -> void:
		var s: Safe = n as Safe
		s.methods = [&"code"] as Array[StringName]
		s.code_group = &"vault"
		s.time_lock_s = 0.5) as Safe
	await wait_physics_frames(2)
	CodeRegistry.of(_rt).reveal(&"office", 0)
	CodeRegistry.of(_rt).reveal(&"vault", 0)
	await _use(pad, Tweak.interaction().keypad_s)
	assert_true(_has_cue(&"cue.keypad_accept", pad.net_id), "keypad_accept")
	await _use(safe, Tweak.interaction().keypad_s)
	await _use(safe, Tweak.interaction().time_lock_start_s)
	assert_true(_has_cue(&"cue.time_lock_start", safe.net_id), "time_lock_start")
	var ok: bool = await wait_until(func() -> bool: return safe.opened, 2.0)
	assert_true(ok, "time lock done")
	assert_true(_has_cue(&"cue.time_lock_done", safe.net_id), "time_lock_done")


func test_c4_cues() -> void:
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(3, 0, -6), func(n: Node) -> void:
		(n as Safe).methods = [&"c4"] as Array[StringName]) as Safe
	await wait_physics_frames(2)
	_crew().add_item(Safe.C4_ITEM, 1)
	await _use(safe, Tweak.interaction().c4_place_s)
	assert_true(_has_cue(&"cue.c4_armed", safe.net_id), "c4_armed")
	Engine.time_scale = 4.0
	var ok: bool = await wait_until(func() -> bool: return safe.opened, Tweak.interaction().c4_fuse_s + 2.0)
	Engine.time_scale = 1.0
	assert_true(ok)
	assert_true(_has_cue(&"cue.c4_explode", safe.net_id), "c4_explode")


func test_zipline_and_laser_cues() -> void:
	var end: Marker3D = Marker3D.new()
	end.name = "ZipEnd"
	_rt.map.get_node(^"Gameplay").add_child(end)
	end.global_position = Vector3(10, 1.0, -4)
	var zip: Zipline = ATestMaps.add_prefab(_rt, "zipline", Vector3(0, 0, -4), func(n: Node) -> void:
		(n as Zipline).end = NodePath("../ZipEnd")) as Zipline
	var grid: LaserGrid = ATestMaps.add_prefab(_rt, "laser_grid", Vector3(-6, 0, 6)) as LaserGrid
	await wait_physics_frames(2)
	var c: CrewController = _crew()
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	assert_true(loot.carry(loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, c.global_position)), c))
	await _use(zip, Tweak.interaction().zipline_attach_s)
	assert_true(_has_cue(&"cue.zipline_attach", zip.net_id), "zipline_attach")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(-6, 0.05, 6)))
	var ok: bool = await wait_until(func() -> bool: return grid.tripped, 1.0)
	assert_true(ok)
	assert_true(_has_cue(&"cue.laser_trip", grid.net_id), "laser_trip")
