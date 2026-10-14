## D-102: PD2 bag carry (carrytweakdata.lua / playercarry.lua). Per weight, with real input (PInputDriver):
## walk speed x bag_speed_mult, sprint only with a light bag, jump never blocked but its velocity x bag_jump_mult,
## head bob x the raw move_speed_modifier.
extends TestCase

const WEIGHTS: Array[int] = [Enums.LootWeight.LIGHT, Enums.LootWeight.MEDIUM, Enums.LootWeight.HEAVY,
	Enums.LootWeight.VERY_HEAVY]

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 102, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _carry(c: CrewController, w: int) -> LootBag:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(3)
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, c.global_position), true, w)
	await wait_physics_frames(1)
	loot.carry(bag, c)
	await wait_physics_frames(2)
	return bag


func _drop(c: CrewController, bag: LootBag) -> void:
	(_rt.service(G.SVC_LOOT) as LootManager).drop_bag(c, false)
	bag.queue_free()
	await wait_physics_frames(2)


func test_tweak_is_pd2() -> void:
	var tw: CrewTweak = Tweak.crew()
	assert_eq(Array(tw.bag_speed_mult), [1.0, 0.75, 0.5, 0.25], "move_speed_modifier")
	assert_eq(tw.bag_can_sprint, [true, false, false, false] as Array[bool], "can_run")
	assert_eq(Array(tw.bag_jump_mult), [1.0, 1.0, 0.5, 0.25], "jump_modifier")
	var thr: Array = Array(tw.bag_throw_distance_m)
	for k: int in 4:
		assert_near(float(thr[k]), [4.0, 4.0, 2.0, 1.2][k], 1e-4, "throw distance %d" % k)


func test_walk_sprint_per_weight() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	for w: int in WEIGHTS:
		var bag: LootBag = await _carry(c, w)
		_inp.press(&"move_forward")
		_inp.press(&"sprint")
		await wait_physics_frames(45)
		var v: float = Vector2(c.velocity.x, c.velocity.z).length()
		var sprint: bool = c.sprinting
		_inp.release(&"sprint")
		await wait_physics_frames(45)
		var walk: float = Vector2(c.velocity.x, c.velocity.z).length()
		_inp.release(&"move_forward")
		assert_eq(sprint, tw.bag_can_sprint[w], "weight %d sprint" % w)
		var top: float = tw.sprint_speed if sprint else tw.walk_speed
		assert_near(v, top * tw.bag_speed_mult[w], 0.15, "weight %d top speed %.2f" % [w, v])
		assert_near(walk, tw.walk_speed * tw.bag_speed_mult[w], 0.15, "weight %d walk %.2f" % [w, walk])
		await wait_physics_frames(30)
		await _drop(c, bag)


func test_jump_height_per_weight() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	for w: int in WEIGHTS:
		var bag: LootBag = await _carry(c, w)
		await wait_physics_frames(30)
		var y0: float = c.global_position.y
		_inp.press(&"jump")
		var apex: float = 0.0
		for _k: int in 70:
			await wait_physics_frames(1)
			apex = maxf(apex, c.global_position.y - y0)
		_inp.release(&"jump")
		var v: float = tw.jump_velocity * tw.bag_jump_mult[w]
		var want: float = v * v / (2.0 * tw.gravity)
		assert_true(apex > 0.03, "weight %d still jumps (%.3f m)" % [w, apex])
		assert_near(apex, want, maxf(want * 0.15, 0.03), "weight %d apex %.3f m (v^2/2g %.3f)" % [w, apex, want])
		await wait_physics_frames(30)
		await _drop(c, bag)


func test_head_bob_scales_with_carry() -> void:
	var gs: GameSettings = GameSettings.current()
	if gs != null and gs.has_method(&"head_bob") and not bool(gs.call(&"head_bob")):
		skip("head bob switched off in Options")
		return
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	var head: Node3D = c.get_node(^"Head") as Node3D
	var amp: Array[float] = []
	for w: int in [Enums.LootWeight.LIGHT, Enums.LootWeight.HEAVY]:
		var bag: LootBag = await _carry(c, w)
		_inp.press(&"move_forward")
		await wait_physics_frames(40)
		var max_x: float = 0.0
		for _k: int in 120:
			await wait_physics_frames(1)
			max_x = maxf(max_x, absf(head.position.x))
		_inp.release(&"move_forward")
		amp.append(max_x)
		await wait_physics_frames(40)
		await _drop(c, bag)
	assert_near(amp[0], tw.head_bob_lateral_m, tw.head_bob_lateral_m * 0.15, "light bag: full walk bob %.4f" % amp[0])
	assert_near(amp[1], amp[0] * tw.bag_speed_mult[Enums.LootWeight.HEAVY], tw.head_bob_lateral_m * 0.12,
		"heavy bag bob %.4f = light %.4f x 0.5" % [amp[1], amp[0]])
