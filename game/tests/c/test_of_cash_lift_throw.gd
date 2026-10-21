## Ostrander Federal cash lift: a bag thrown in from the landing door lands in the car (ENV P's Hazardous ghost note,
## step 6: "a throw from the door hits GL's back wall and rests just outside the car's 2.2 m count box"). On the built
## map in a real HeistRuntime, at each landing (B: CashLiftDoorB, from CQ; G: CashLiftDoorG) a crew member standing in
## the open doorway throws a bag of every weight across GL, level and looking down: once it settles the lift counts it
## (BagLift.bags_in_car). Owner: ENV C.
extends TestCase

const HEIST: StringName = &"ostrander_federal"
const SEED: int = 1002
## [landing index, door, where the thrower stands (outside the door, on its leaf line), look yaw (rad)].
const THROWS: Array[Array] = [
	[0, ^"Gameplay/Doors/CashLiftDoorB", Vector3(11.5, -4.0, 3.45), 0.0],          # facing -z into GL
	[1, ^"Gameplay/Doors/CashLiftDoorG", Vector3(9.55, 0.0, 1.5), -PI * 0.5],      # facing +x into GL
]
const PITCHES_DEG: Array[float] = [0.0, -35.0]
const SETTLE_S: float = 3.0

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_door_throws_land_in_the_car() -> void:
	_rt = await HeistLauncher.launch(HEIST, SEED, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch %s" % HEIST)
		return
	_rt.isolate_npc(null)
	var lift: BagLift = _rt.map.get_node(^"Gameplay/Lifts/CashLift") as BagLift
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var n: int = 0
	for t: Array in THROWS:
		if lift.landing != int(t[0]):
			assert_true(lift.send(int(t[0])), "send the car to landing %d" % t[0])
			assert_true(await wait_until(func() -> bool: return not lift.is_moving(), lift.travel_s + 5.0), "car arrives")
		var d: Door = _rt.map.get_node(t[1] as NodePath) as Door
		d.unlock()
		d.set_open(true, true)
		d.finish_swing()
		for w: int in 4:
			for pitch: float in PITCHES_DEG:
				# the yaw through the teleport basis (it also sets the held intent's yaw, PI-06)
				_rt.teleport_crew(0, Transform3D(Basis(Vector3.UP, float(t[3])), t[2] as Vector3))
				await wait_physics_frames(3)
				var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, c.global_position), true, w)
				await wait_physics_frames(1)
				loot.carry(bag, c)
				await wait_physics_frames(2)
				c.look_pitch = deg_to_rad(pitch)   # read by the throw this same frame
				loot.drop_bag(c, true)
				await wait_seconds(SETTLE_S)
				var in_car: bool = lift.bags_in_car().has(bag)
				var at: Vector3 = lift.car_transform().affine_inverse() * bag.global_position
				assert_true(in_car, "%s: weight %d pitch %.0f lands outside the car (car-local %s, car %s)" % [
					String(t[1]).get_file(), w, pitch, at, lift.car_size_m])
				bag.queue_free()
				await wait_physics_frames(2)
				n += 1
	assert_eq(n, THROWS.size() * 4 * PITCHES_DEG.size(), "throws made")
