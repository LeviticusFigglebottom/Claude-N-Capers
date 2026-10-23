## RT goods lift (P's r305 lift rerun: bags "released behind the roof landing's east wall"): two bags thrown into the
## car from the ground and from the Deck 2 door ride to the roof in one send and come out where they rode, inside
## the car (C: interior x 19.4-21.6, the shaft wall at x 22.1), and stay there. On the built map. Owner: ENV A.
extends TestCase

const LANDINGS: Array[Array] = [[0, ^"Gameplay/Doors/LiftDoorG", 0.0], [1, ^"Gameplay/Doors/LiftDoor2", 3.5]]
const ROOF: int = 2
const SETTLE_FRAMES: int = 60

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_thrown_bags_come_out_in_the_car_at_the_roof() -> void:
	_rt = await HeistLauncher.launch(&"rolling_thunder", 1002, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch rolling_thunder")
		return
	_rt.isolate_npc(null)
	var lift: BagLift = _rt.map.get_node(^"Gameplay/Lifts/GoodsLift") as BagLift
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	for src: Array in LANDINGS:
		if lift.landing != int(src[0]):
			lift.send(int(src[0]))
			assert_true(await wait_until(func() -> bool: return not lift.is_moving(), lift.travel_s * 2.0 + 5.0), "car back")
		var d: Door = _rt.map.get_node(src[1] as NodePath) as Door
		d.unlock()
		d.set_open(true, true)
		d.finish_swing()
		var bags: Array[LootBag] = []
		for pitch: float in [0.0, -35.0]:
			_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(20.5, float(src[2]), -46.55)))
			await wait_physics_frames(3)
			var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, c.global_position), true, 0)
			await wait_physics_frames(1)
			loot.carry(bag, c)
			await wait_physics_frames(2)
			c.look_pitch = deg_to_rad(pitch)
			loot.drop_bag(c, true)
			await wait_seconds(3.0)
			bags.append(bag)
		_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(14, float(src[2]), -40)))
		var rode: Array[Vector3] = []
		for b: LootBag in bags:
			assert_true(lift.bags_in_car().has(b), "landing %d: thrown bag in the car" % src[0])
			rode.append(lift.car_transform().affine_inverse() * b.global_position)
		assert_true(lift.send(ROOF), "send from landing %d to the roof" % src[0])
		assert_true(await wait_until(func() -> bool: return not lift.is_moving(), lift.travel_s * 2.0 + 5.0), "arrived")
		await wait_physics_frames(SETTLE_FRAMES)
		for k: int in bags.size():
			var local: Vector3 = lift.car_transform().affine_inverse() * bags[k].global_position
			assert_true(local.distance_to(rode[k]) < 0.1, "landing %d bag %d: out where it rode (%s, rode %s)"
				% [src[0], k, local, rode[k]])
			assert_true(lift.bags_in_car().has(bags[k]), "landing %d bag %d: still in the car at the roof (%s)"
				% [src[0], k, bags[k].global_position])
		for b: LootBag in bags:
			b.queue_free()
		await wait_physics_frames(2)
