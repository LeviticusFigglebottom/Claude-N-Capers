## Rolling Thunder convoy seats (ENV D's convoy fit, env_d.md 2026-10-21). On the generated map, in each mover's space
## (+Z = the vehicle's front): every `Seat*` empty faces +Z (spawn_units copies the seat transform and an NPC faces its
## -Z); the escort cars' seats sit on the footwell floor (y about 0.18, sit_vehicle's root) with the rows >= 1.15 m apart;
## the armoured cabs' seats sit on the cab floor (y 1.20); the driver (`Seat0`) sits on +X in every vehicle. Owner: ENV C.
extends TestCase

const MAP: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"
const CARS: Array[StringName] = [&"Lead", &"Rear"]
const CAR_FLOOR_Y: float = 0.18
const CAB_FLOOR_Y: float = 1.20
const ROW_GAP_MIN_M: float = 1.15

var _map: Node = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null
	await wait_frames(2)


func test_convoy_seats_face_forward_at_floor_height() -> void:
	_map = (load(MAP) as PackedScene).instantiate()
	add_child(_map)
	await wait_frames(1)
	var n: int = 0
	for movers: Node in _map.find_children("Movers", "", true, false):
		for v: Node in movers.get_children():
			var veh: Node3D = v as Node3D
			if veh == null:
				continue
			var car: bool = CARS.has(veh.name)
			var rows: Dictionary = {}
			for s: Node in veh.find_children("Seat*", "Node3D", true, false):
				var t: Transform3D = veh.global_transform.affine_inverse() * (s as Node3D).global_transform
				var fwd: Vector3 = -t.basis.z.normalized()
				var where: String = "%s %s" % [veh.get_path(), s.name]
				assert_true(fwd.dot(Vector3.BACK) > 0.99, "%s faces %s, not +Z" % [where, fwd])
				var want: float = CAR_FLOOR_Y if car else CAB_FLOOR_Y
				assert_true(absf(t.origin.y - want) < 0.03, "%s at y %.2f, want %.2f" % [where, t.origin.y, want])
				if s.name == &"Seat0":  # the driver on +X in every vehicle (the LEAD, round 275)
					assert_true(t.origin.x > 0.0, "%s driver at x %.2f, want +X" % [where, t.origin.x])
				rows[snappedf(t.origin.z, 0.01)] = true
				n += 1
			if car:
				var zs: Array = rows.keys()
				zs.sort()
				assert_eq(zs.size(), 2, "%s has two seat rows" % veh.get_path())
				if zs.size() == 2:
					assert_true(float(zs[1]) - float(zs[0]) >= ROW_GAP_MIN_M,
							"%s rows %.2f m apart" % [veh.get_path(), float(zs[1]) - float(zs[0])])
	assert_true(n > 0, "found convoy seats")
