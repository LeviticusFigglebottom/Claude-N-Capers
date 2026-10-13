## S9.5: trip mine deployable. Placed from the deployable slot, arms after trip_mine_arm_s, then an enemy within
## trip_mine_trigger_m (LOS) blows it: explosion noise and a blast, the mine is spent.
extends TestCase

var _rt: HeistRuntime = null
var _noises: Array = []


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func test_s9_5_trip_mine_arms_and_triggers_on_enemy() -> void:
	var l: Loadout = Loadout.new()
	l.deployable = &"deployable.trip_mine"
	_rt = await HeistLauncher.launch(&"unit_map", 95, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "ai_teammates": 0, "skip_casing": true, "crew_ai": false,
			"loadouts": {0: l}})
	_rt.noise_made.connect(func(p: Vector3, r: float, k: StringName, s: int) -> void: _noises.append(k))
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var sys: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	assert_eq(sys.count_of_kind(0, &"trip_mine"), 3, "3 base")
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	g.max_health = 100000.0
	g.health = g.max_health
	var mine: DeployablePrefab = sys.place(c) as DeployablePrefab
	assert_true(mine != null, "placed")
	assert_eq(sys.count_of_kind(0, &"trip_mine"), 2)
	assert_false(mine.interactable.enabled, "no use interaction")
	g.global_position = mine.global_position + Vector3(0.8, 0, 0)  # inside the trigger, before arming
	await wait_physics_frames(3)
	assert_true(is_instance_valid(mine), "not armed yet")
	g.global_position = mine.global_position + Vector3(6, 0, 0)
	await wait_seconds(DeployableTweak.data().trip_mine_arm_s + 0.2)
	assert_true(is_instance_valid(mine) and not mine._trip_fired, "armed, nobody near")
	var hp: float = g.health
	g.global_position = mine.global_position + Vector3(0.8, 0, 0)
	var ref: WeakRef = weakref(mine)
	mine = null
	var ok: bool = await wait_until(func() -> bool: return ref.get_ref() == null, 2.0)
	assert_true(ok, "detonated and spent")
	assert_has(_noises, &"explosion")
	assert_true(g.health < hp, "blast hurt the guard")
