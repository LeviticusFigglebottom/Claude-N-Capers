## A1-04: stimuli (S4.1, S6.3) and noise propagation (S4.3).
extends TestCase


## Loot-bag-like stimulus source (S4.1 pre-placed flag, S6.3 hidden flag).
class FakeBag extends Node3D:
	var moved: bool = false
	var hidden_from_stealth: bool = false


var _rt: HeistRuntime = null
var _st: StealthDirector = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0})
	_st = _rt.stealth
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(25, 0.05, 25)))


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _guard(pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> NpcBase:
	return ATestMaps.add_npc_observer(_rt, &"guard", pos, facing)


func _bag(pos: Vector3, moved: bool) -> FakeBag:
	var b: FakeBag = FakeBag.new()
	b.moved = moved
	_rt.dynamic_root.add_child(b)
	b.global_position = pos
	return b


func test_s4_1_corpse_in_view_is_noticed() -> void:
	var g: NpcBase = _guard(Vector3.ZERO)
	var victim: NpcBase = _guard(Vector3(0, 0, -5), Vector3.BACK)
	var seen: Array[StringName] = []
	g.stimulus_spotted.connect(func(_id: int, k: StringName, _p: Vector3) -> void: seen.append(k))
	var noticed: Array[int] = []
	_st.stimulus_noticed.connect(func(o: Node, id: int) -> void:
		if o == g:
			noticed.append(id))
	victim.die()
	assert_true(victim.corpse_stimulus_id != 0, "death registers a corpse stimulus")
	var ok: bool = await wait_until(func() -> bool: return seen.has(&"corpse"), 3.0)
	assert_true(ok, "S4.1 guard notices the corpse")
	assert_eq(noticed, [victim.corpse_stimulus_id] as Array[int], "stimulus_noticed once")
	await wait_seconds(0.5)
	assert_eq(seen.size(), 1, "notified once")


func test_s4_1_corpse_behind_wall_not_noticed() -> void:
	var g: NpcBase = _guard(Vector3.ZERO)
	var victim: NpcBase = _guard(Vector3(0, 0, -6), Vector3.BACK)
	ATestMaps.add_wall(_rt.map, Vector3(0, 2, -3), Vector3(6, 4, 0.4))
	var seen: Array[StringName] = []
	g.stimulus_spotted.connect(func(_id: int, k: StringName, _p: Vector3) -> void: seen.append(k))
	victim.die()
	await wait_seconds(2.0)
	assert_eq(seen.size(), 0, "LOS required for corpses")


func test_s4_1_preplaced_bag_ignored_until_moved() -> void:
	var g: NpcBase = _guard(Vector3.ZERO)
	var seen: Array[StringName] = []
	g.stimulus_spotted.connect(func(_id: int, k: StringName, _p: Vector3) -> void: seen.append(k))
	var bag: FakeBag = _bag(Vector3(0, 0, -5), false)
	_st.register_stimulus(bag, &"bag")
	var hidden: FakeBag = _bag(Vector3(1, 0, -5), true)
	hidden.hidden_from_stealth = true
	_st.register_stimulus(hidden, &"body_bag")
	var flagged: FakeBag = _bag(Vector3(-1, 0, -5), true)
	_st.register_stimulus(flagged, &"bag", {"hidden": true})
	await wait_seconds(2.5)
	assert_eq(seen.size(), 0, "pre-placed (moved = false) and hidden bags are ignored")
	bag.moved = true
	var ok: bool = await wait_until(func() -> bool: return seen.has(&"bag"), 3.0)
	assert_true(ok, "S4.1 the bag is noticed once moved")
	assert_false(seen.has(&"body_bag"), "S6.3 hidden_from_stealth body bag never noticed")


func test_s4_3_noise_radius_and_no_los_halving() -> void:
	var near: NpcBase = _guard(Vector3(5, 0, 0))
	var far: NpcBase = _guard(Vector3(-15, 0, 0))
	var walled_far: NpcBase = _guard(Vector3(0, 0, 8))
	var walled_near: NpcBase = _guard(Vector3(0, 0, 4))
	ATestMaps.add_wall(_rt.map, Vector3(0, 2, 2), Vector3(20, 4, 0.5))
	await wait_physics_frames(2)
	var heard: Dictionary[int, int] = {}
	for g: NpcBase in [near, far, walled_far, walled_near]:
		var gid: int = g.get_instance_id()
		heard[gid] = 0
		g.noise_heard.connect(func(_p: Vector3, _k: StringName, _s: int) -> void: heard[gid] += 1)
	_rt.make_noise(Vector3(0, 1, 0), 10.0, &"glass")
	assert_eq(heard[near.get_instance_id()], 1, "within radius with LOS hears")
	assert_eq(heard[far.get_instance_id()], 0, "beyond radius does not hear")
	assert_eq(heard[walled_far.get_instance_id()], 0, "no LOS: radius halved (8 m > 5 m)")
	assert_eq(heard[walled_near.get_instance_id()], 1, "no LOS but within half radius hears")
	near.die()
	_rt.make_noise(Vector3(0, 1, 0), 10.0, &"glass")
	assert_eq(heard[near.get_instance_id()], 1, "dead NPCs do not hear")
