## A3-10 (QC-19, D-042): escape_zone `escape_type` set, `arrival_delay_s` (heli / boat approach:
## no escape before arrival, time left exposed) and `bag_only` (secures bags, crew cannot escape).
extends TestCase

var _rt: HeistRuntime = null
var _results: Array[Dictionary] = []
var _secured: Array[int] = []
var _cues: Array[StringName] = []
var _conns: Array[Array] = []


func before_each() -> void:
	_results.clear()
	_secured.clear()
	_cues.clear()
	_rt = await HeistLauncher.launch(&"unit_escape_types", 1200, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	_connect(EventBus.heist_ended, func(r: Dictionary) -> void: _results.append(r))
	_connect(EventBus.loot_secured, func(b: int, _l: StringName, _v: int) -> void: _secured.append(b))
	_connect(EventBus.audio_cue_requested, func(c: StringName, _p: Vector3, _i: int) -> void: _cues.append(c))


func _connect(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_conns.append([sig, cb])


func after_each() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_types_listed() -> void:
	for t: StringName in [&"van", &"boat", &"heli", &"lift", &"zipline", &"walk"]:
		assert_has(EscapeZone.ESCAPE_TYPES, t)
	var ez: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(0, 0, -6), func(n: Node) -> void:
		(n as EscapeZone).escape_type = &"walk") as EscapeZone
	await wait_physics_frames(1)
	assert_eq(ez.required_visual_nodes().size(), 0, "placeholder: no per-type nodes required")


func test_heli_arrival_delay_blocks_escape_until_arrival() -> void:
	var ez: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(0, 0, -6), func(n: Node) -> void:
		var e: EscapeZone = n as EscapeZone
		e.escape_type = &"heli"
		e.arrival_delay_s = 1.0
		e.objective_tag = &"escape_heli") as EscapeZone
	await wait_physics_frames(2)
	assert_eq(ez.arrival_time_left(), 0.0, "inactive: nothing pending")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	_rt.mission.activate_escape(&"escape_heli")
	await wait_physics_frames(3)
	assert_true(ez.active, "active")
	assert_false(ez.has_arrived(), "approaching")
	assert_true(ez.arrival_time_left() > 0.8, "HUD time left (%.2f)" % ez.arrival_time_left())
	assert_false(ez.visual_root.visible, "vehicle not there yet")
	await wait_seconds(0.5)
	assert_true(_results.is_empty(), "no escape before arrival")
	assert_true(ez.arrival_time_left() < 0.6, "counts down")
	var ok: bool = await wait_until(func() -> bool: return not _results.is_empty(), 1.5)
	assert_true(ok, "escape after arrival")
	assert_true(ez.has_arrived())
	assert_has(_cues, &"cue.escape_arrive")
	if ok:
		assert_true(bool(_results[0]["success"]), "success")


func test_bag_only_secures_bags_and_never_ends_heist() -> void:
	var drop: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(8, 0, -6), func(n: Node) -> void:
		var e: EscapeZone = n as EscapeZone
		e.escape_type = &"zipline"
		e.bag_only = true) as EscapeZone
	await wait_physics_frames(2)
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var early: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, Vector3(8, 0.1, -6)))
	await wait_seconds(LootTweak.get_default().secure_rest_s + 0.4)
	assert_true(_secured.is_empty(), "inactive drop does not secure")
	assert_true(is_instance_valid(early))
	drop.activate()
	var ok: bool = await wait_until(func() -> bool: return not _secured.is_empty(), LootTweak.get_default().secure_rest_s + 1.5)
	assert_true(ok, "active bag_only zone secures the bag")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(8, 0.05, -6)))
	await wait_physics_frames(10)
	assert_true(_results.is_empty(), "crew inside a bag_only zone do not escape")
	assert_ne(_rt.phase, Enums.HeistPhase.ENDED, "not ended")
