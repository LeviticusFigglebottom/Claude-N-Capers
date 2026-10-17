## OF-X2 (DB-7 q6, P r236): after the burn, the burning room's fire shutters drop BARRED (dockside_burn_mission
## _drop_shutters). No nav link survives through them: crew (layer 1) and police (every layer, breach included, loud)
## paths into chamber B end outside it. Before the shutters close, the room is reachable through its doors.
extends TestCase

const SHUTTERS: Array[String] = ["ChamberBNorth", "SpineChamberB", "ChamberBSouth"]
const OUTSIDE: Vector3 = Vector3(41.2, 0.0, 25.8)  # south of ChamberBSouth
const INSIDE: Vector3 = Vector3(41.0, 0.0, 17.0)  # chamber B floor, by the burn point

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_of_x2_chamber_b_shutters_seal_the_room() -> void:
	_rt = await HeistLauncher.launch(&"dockside_burn", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(5)
	_rt.stealth.raise_alarm(&"test")  # loud: breachable locks get police links (P3); BARRED must not
	await wait_physics_frames(3)
	for layers: int in [1, 0xFFFF]:
		assert_true(_end(layers).distance_to(INSIDE) < 0.6, "open doors: chamber B reachable (layers %d)" % layers)
	for dn: String in SHUTTERS:
		var d: Door = _rt.map.get_node(NodePath("Gameplay/Doors/" + dn)) as Door
		d.set(&"lock", Door.Lock.BARRED)  # as _drop_shutters
		d.set(&"locked", true)
		d.call(&"set_open", false)
	await wait_physics_frames(5)
	for layers: int in [1, 0xFFFF]:
		var e: Vector3 = _end(layers)
		assert_true(e.distance_to(INSIDE) > 3.0, "shutters barred: no path into chamber B (layers %d, ends %s)" % [layers, e])


func _end(layers: int) -> Vector3:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_rt.map.get_world_3d().navigation_map, OUTSIDE, INSIDE,
		true, layers)
	return Vector3(path[path.size() - 1].x, 0.0, path[path.size() - 1].z) if not path.is_empty() else Vector3.INF
