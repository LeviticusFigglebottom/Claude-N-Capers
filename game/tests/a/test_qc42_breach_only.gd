## QC-42 (D-064): police enter only via ENTRY points; a POLICE_SPAWN / ENTRY point tagged `breach_only`
## (interior entries) is never a spawn candidate.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_breach_only_entry_points_are_not_spawns() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4201, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var tac: Node = _rt.map.get_node_or_null(^"Tactical")
	if tac == null:
		tac = Node3D.new()
		tac.name = "Tactical"
		_rt.map.add_child(tac)
	var outdoor: TacticalPoint = TacticalPoint.new()
	outdoor.kind = TacticalPoint.Kind.ENTRY
	outdoor.name = "EntryOutdoor"
	tac.add_child(outdoor)
	outdoor.global_position = Vector3(12, 0, 12)
	var interior: TacticalPoint = TacticalPoint.new()
	interior.kind = TacticalPoint.Kind.ENTRY
	interior.name = "EntryInterior"
	interior.tags = [AssaultDirector.BREACH_ONLY_TAG] as Array[StringName]
	tac.add_child(interior)
	interior.global_position = Vector3(-12, 0, 12)
	ATestMaps.add_wall(_rt.map, Vector3(0, 1.5, 0), Vector3(30, 3, 0.4))  # L1.4: no crew LOS to the points
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -12)))
	await wait_physics_frames(2)
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var pts: Array[Node3D] = d.valid_spawn_points()
	assert_true(pts.has(outdoor), "a plain ENTRY point is a spawn candidate")
	assert_false(pts.has(interior), "QC-42: breach_only entries never spawn police")
