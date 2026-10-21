## A5-01 (Rolling Thunder QC-80) armored_truck: a vehicle-shaped Safe LARGE (saw + C4, 4 charges, G.SAW_TARGET), the
## early-alarm lockdown (saws x truck_lockdown_saw_mult, placed and by hand; C4 unchanged), cargo inside until the
## rear doors open; QC-81: a burn_point with `target` opens the truck and, with fire_volume_size ZERO, lights no fire.
extends TestCase

const DRILL_POINT: PackedScene = preload("res://systems/prefabs/drill_point/drill_point.tscn")
const LOOT_SPAWN: PackedScene = preload("res://systems/prefabs/loot_spawn/loot_spawn.tscn")

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_trucks", 501, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _truck(pos: Vector3, extra: Callable = Callable()) -> ArmoredTruck:
	return ATestMaps.add_prefab(_rt, "armored_truck", pos, func(n: Node) -> void:
		if extra.is_valid():
			extra.call(n)) as ArmoredTruck


func test_defaults_hand_saw_and_lockdown() -> void:
	var t: ArmoredTruck = _truck(Vector3(0, 0, -10))
	await wait_physics_frames(2)
	assert_eq(t.size, Safe.Size.LARGE, "a LARGE safe")
	assert_eq(t.methods, [&"saw", &"c4"] as Array[StringName], "saw or C4")
	assert_eq(t.charges_required, 4, "PD2: 4 charges")
	assert_true(t.is_in_group(G.SAW_TARGET) and t.is_in_group(ArmoredTruck.GROUP), "saw target, truck group")
	assert_near(t.saw_duration(), 120.0, 0.001, "cash van placed saw 120 s")
	assert_near(t.hand_saw_duration(), 60.0, 0.001, "cash van hand saw 60 s")
	var mult: float = Tweak.interaction().truck_lockdown_saw_mult
	t.lockdown()
	assert_true(t.locked_down, "locked down")
	assert_near(t.saw_duration(), 120.0 * mult, 0.001, "placed saw x lockdown")
	assert_near(t.hand_saw_duration(), 60.0 * mult, 0.001, "hand saw x lockdown")
	t.saw_cut(60.0, 0)
	assert_false(t.opened, "60 s of cutting is not enough in lockdown")
	t.saw_cut(60.0 * mult - 60.0 + 0.01, 0)
	assert_true(t.opened, "the rest of the lockdown time opens the rear doors")
	assert_eq(t.beaten_by, &"saw")
	t.lockdown()
	assert_near(t.saw_time_mult, mult, 0.001, "idempotent")


func test_lockdown_slows_a_saw_point_targeting_the_truck_not_c4() -> void:
	var made: Array[Node] = []
	var t: ArmoredTruck = _truck(Vector3(0, 0, -10), func(x: Node) -> void:
		var dp: DrillPoint = DRILL_POINT.instantiate() as DrillPoint
		dp.name = "RearSaw"
		dp.device = DrillPoint.Device.SAW
		dp.target = NodePath("..")
		dp.duration_s = 120.0
		dp.position = Vector3(0.0, 1.5, -3.9)
		x.add_child(dp)
		made.append(dp))
	var other: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(6, 0, -6), func(n: Node) -> void:
		(n as DrillPoint).device = DrillPoint.Device.SAW
		(n as DrillPoint).duration_s = 30.0) as DrillPoint
	await wait_physics_frames(2)
	var dp: DrillPoint = made[0] as DrillPoint
	assert_eq(t.saw_points(), [dp] as Array[DrillPoint], "the truck's own rear saw point")
	var c4_place: float = t._duration_for(_rt.crew_controller(0), Tweak.interaction().c4_place_s)
	t.lockdown()
	var mult: float = Tweak.interaction().truck_lockdown_saw_mult
	assert_near(dp.effective_duration(), 120.0 * mult, 0.001, "the placed saw runs longer")
	assert_near(other.effective_duration(), 30.0, 0.001, "a saw point on something else is untouched")
	assert_eq(t.charges_required, 4, "C4 unchanged")
	assert_near(t._duration_for(_rt.crew_controller(0), Tweak.interaction().c4_place_s), c4_place, 0.001,
		"C4 placing time unchanged")


func test_cargo_inside_until_the_rear_doors_open() -> void:
	var made: Array[Node] = []
	var t: ArmoredTruck = _truck(Vector3(0, 0, -10), func(x: Node) -> void:
		var ls: GameplayPrefab = LOOT_SPAWN.instantiate() as GameplayPrefab
		ls.name = "Cargo"
		ls.set(&"loot_id", &"loot.cash_bricks")
		ls.position = Vector3(0.0, 0.0, -6.0)  # placed behind the truck by the map: snapped inside
		x.add_child(ls)
		made.append(ls))
	await wait_physics_frames(3)
	var cargo: GameplayPrefab = made[0] as GameplayPrefab
	assert_false(cargo.interactable.enabled, "cargo locked while shut")
	assert_false(cargo.visible, "cargo not drawn while shut")
	assert_true(t.interior_aabb().has_point(t.to_local(cargo.global_position)), "cargo snapped inside the box")
	t.open_by_device()
	await wait_physics_frames(1)
	assert_true(t.opened, "rear doors open")
	assert_true(cargo.visible and cargo.interactable.enabled, "cargo usable once open")


func test_qc81_burn_point_target_opens_the_truck_without_fire() -> void:
	var t: ArmoredTruck = _truck(Vector3(0, 0, -10))
	var bp: BurnPoint = ATestMaps.add_prefab(_rt, "burn_point", Vector3(0, 0, -14.2), func(n: Node) -> void:
		(n as BurnPoint).duration_s = 0.5
		(n as BurnPoint).fire_volume_size = Vector3.ZERO) as BurnPoint
	await wait_physics_frames(2)
	bp.target = bp.get_path_to(t)
	bp.start_burn()
	var ok: bool = await wait_until(func() -> bool: return bp.stage == BurnPoint.Stage.LIT,
		0.5 + Tweak.interaction().burn_warning_s + 2.0)
	assert_true(ok, "burnt through")
	assert_true(t.opened, "the burn opened its target")
	assert_eq(t.beaten_by, &"device")
	assert_false(bp.is_in_group(BurnPoint.GROUP), "no fire volume")
	assert_true(bp.find_child("FireObstacle", true, false) == null, "no nav obstacle")
	assert_false(bp.contains(bp.global_position + Vector3(0, 0.3, 0)), "nothing burns at the lock")
