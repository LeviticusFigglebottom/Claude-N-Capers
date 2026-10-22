## Rolling Thunder goods lift: two bags thrown in from a landing door both land in the car (ENV P's real-input pass,
## r278: "a 2nd bag thrown in rests against the back wall, visibly in the car but not counted"; the w240 car's 2.2 m
## count box in LF's 2.8 m shaft). On the built map in a real HeistRuntime, at each landing (G, deck 2, roof) a crew
## member standing in the open doorway throws two bags in a row (the lightest and the heaviest weight), level and
## looking down: once they settle the lift counts both (BagLift.bags_in_car). As test_of_cash_lift_throw. Owner: ENV C.
extends TestCase

const HEIST: StringName = &"rolling_thunder"
const SEED: int = 1002
## [landing index, door, where the thrower stands (outside the door), look yaw (rad): facing -z into LF].
const THROWS: Array[Array] = [
	[0, ^"Gameplay/Doors/LiftDoorG", Vector3(20.5, 0.0, -46.55), 0.0],
	[1, ^"Gameplay/Doors/LiftDoor2", Vector3(20.5, 3.5, -46.55), 0.0],
	[2, ^"Gameplay/Doors/LiftDoorR", Vector3(20.5, 7.0, -46.55), 0.0],
]
const PITCHES_DEG: Array[float] = [0.0, -35.0]
const WEIGHTS: Array[int] = [0, 3]
const SETTLE_S: float = 3.0

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_two_door_throws_land_in_the_car() -> void:
	_rt = await HeistLauncher.launch(HEIST, SEED, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch %s" % HEIST)
		return
	_rt.isolate_npc(null)
	var lift: BagLift = _rt.map.get_node(^"Gameplay/Lifts/GoodsLift") as BagLift
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var n: int = 0
	for t: Array in THROWS:
		if lift.landing != int(t[0]):
			assert_true(lift.send(int(t[0])), "send the car to landing %d" % t[0])
			assert_true(await wait_until(func() -> bool: return not lift.is_moving(), lift.travel_s * 2.0 + 5.0),
				"car arrives")
		var d: Door = _rt.map.get_node(t[1] as NodePath) as Door
		d.unlock()
		d.set_open(true, true)
		d.finish_swing()
		for w: int in WEIGHTS:
			for pitch: float in PITCHES_DEG:
				var bags: Array[LootBag] = []
				for k: int in 2:
					_rt.teleport_crew(0, Transform3D(Basis(Vector3.UP, float(t[3])), t[2] as Vector3))
					await wait_physics_frames(3)
					var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, c.global_position), true,
						w)
					await wait_physics_frames(1)
					loot.carry(bag, c)
					await wait_physics_frames(2)
					c.look_pitch = deg_to_rad(pitch)   # read by the throw this same frame
					loot.drop_bag(c, true)
					await wait_seconds(SETTLE_S)
					bags.append(bag)
				for k2: int in bags.size():
					var bag2: LootBag = bags[k2]
					var at: Vector3 = lift.car_transform().affine_inverse() * bag2.global_position
					assert_true(lift.bags_in_car().has(bag2), "%s: bag %d, weight %d, pitch %.0f lands outside the car "
						% [String(t[1]).get_file(), k2 + 1, w, pitch] + "(car-local %s, car %s)" % [at, lift.car_size_m])
				for b: LootBag in bags:
					b.queue_free()
				await wait_physics_frames(2)
				n += 1
	assert_eq(n, THROWS.size() * WEIGHTS.size() * PITCHES_DEG.size(), "throw pairs made")
