## Rolling Thunder's goods lift (P r305 lift rerun): every BagLift landing marker sits straight above / below the car,
## inside its shaft footprint, so bags released at a landing are in the car, not behind the landing wall. Owner: ENV C.
extends TestCase

const SCENE: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"
## The car interior's half extents in the lift's frame (x 19.4-21.6 at the lift's x 20.5).
const CAR_HALF_X: float = 1.1
const CAR_HALF_Z: float = 1.1
const TOL_M: float = 0.05


func test_landings_inside_the_shaft() -> void:
	var map: Node3D = (load(SCENE) as PackedScene).instantiate() as Node3D
	var lifts: Array[Node] = map.find_children("*", "BagLift", true, false)
	assert_true(not lifts.is_empty(), "RT has a BagLift")
	for l: Node in lifts:
		var lift: Node3D = l as Node3D
		var targets: Array = lift.get(&"targets")
		assert_true(targets.size() >= 2, "%s has its landings" % lift.name)
		for np: NodePath in targets:
			var m: Node3D = lift.get_node_or_null(np) as Node3D
			assert_true(m != null, "%s landing %s resolves" % [lift.name, np])
			if m == null:
				continue
			# landing offset in the lift's own frame: vertical only (the shaft is a straight vertical run)
			var local: Vector3 = lift.transform.affine_inverse() * (lift.transform * m.position)
			assert_true(absf(local.x) <= TOL_M and absf(local.z) <= TOL_M,
				"%s/%s is %.2f / %.2f m off the shaft axis" % [lift.name, m.name, local.x, local.z])
			assert_true(absf(local.x) <= CAR_HALF_X and absf(local.z) <= CAR_HALF_Z, "%s/%s inside the car" % [lift.name, m.name])
	map.free()
