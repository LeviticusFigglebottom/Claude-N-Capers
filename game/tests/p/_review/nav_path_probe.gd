## Navmesh path check (PO pass): for each --from point, the crew-navmesh path to --to on a heist; prints whether the
## path ends near the target and its length / waypoint count (a gap shows as a path that stops short or is empty).
##   /opt/godot/godot --headless --path game res://tests/p/_review/nav_path_probe.tscn -- --heist=night_deposit \
##     --to=3.8,0.2,-5.4 --from="13.6,-4.0,9.4;11.3,-4.0,6.8"
## Owner: ENV P.
extends Node

var _heist: StringName = &"night_deposit"
var _to: Vector3 = Vector3.ZERO
var _from: Array[Vector3] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"heist": _heist = StringName(v)
			"to": _to = _vec(v)
			"from":
				for p: String in v.split(";"):
					_from.append(_vec(p))
	_run.call_deferred()


static func _vec(s: String) -> Vector3:
	var f: PackedFloat64Array = s.split_floats(",")
	return Vector3(f[0], f[1], f[2])


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self, {})
	var c: CrewController = rt.crew_controller(0) as CrewController
	var map: RID = c.get_world_3d().navigation_map
	while NavigationServer3D.map_get_iteration_id(map) < 2:
		await get_tree().physics_frame
	for p: Vector3 in _from:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, p, _to, true)
		var snapped_from: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
		var length: float = 0.0
		for i: int in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		var end: Vector3 = path[path.size() - 1] if not path.is_empty() else Vector3.INF
		print("[NAV] from %s (nav %s) -> %d pts, %.1f m, ends %s, %.2f m from target%s" % [p, snapped_from.snappedf(0.1),
			path.size(), length, end.snappedf(0.1), end.distance_to(_to), "  SHORT" if end.distance_to(_to) > 0.6 else ""])
	print("[NAV] target nav point %s" % NavigationServer3D.map_get_closest_point(map, _to).snappedf(0.1))
	rt.teardown()
	get_tree().quit(0)
