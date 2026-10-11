## QC-37 (G.SAW_TARGET, gameplay_prefabs v1.3): the handheld saw cuts deposit boxes, padlocks, saw-capable
## safes and SAW drill_points (`saw_cut(seconds, attacker_net_id)`, InteractionTweak hand_saw_*).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 3701, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	ContentDB.clear_cache()
	await wait_frames(1)


func _cut(p: Node, total_s: float) -> void:
	var steps: int = int(ceil(total_s / 0.5))
	for i: int in range(steps):
		p.call(&"saw_cut", 0.5, 0)


func test_deposit_box_locked_until_cut() -> void:
	var box: DepositBox = ATestMaps.add_prefab(_rt, "deposit_box", Vector3(0, 1, -3)) as DepositBox
	await wait_physics_frames(1)
	assert_true(box.is_in_group(G.SAW_TARGET), "in G.SAW_TARGET")
	assert_false(box.interactable.enabled, "locked: no take_loot yet")
	_cut(box, Tweak.interaction().hand_saw_deposit_box_s - 1.0)
	assert_false(box.opened, "not yet")
	_cut(box, 1.0)
	assert_true(box.opened and box.interactable.enabled, "cut open: the small loot can be taken")


func test_padlock_saw_or_lockpick_opens_targets() -> void:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(4, 0, -6), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.LOCKPICK) as Door
	var lock: Padlock = ATestMaps.add_prefab(_rt, "padlock", Vector3(4, 1, -5.8)) as Padlock
	lock.targets = [lock.get_path_to(door)]
	await wait_physics_frames(1)
	assert_true(door.locked, "door locked")
	assert_eq(lock.interactable.kind, &"lockpick", "a padlock is lockpicked by hand")
	_cut(lock, Tweak.interaction().hand_saw_padlock_s)
	assert_true(lock.opened, "sawn off")
	assert_false(door.locked, "the target unlocked")
	assert_true(door.is_open, "...and opened")


func test_safe_with_saw_method_and_without() -> void:
	var sawable: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(-3, 0, -4), func(p: GameplayPrefab) -> void:
		(p as Safe).methods = [&"saw"] as Array[StringName]) as Safe
	var drill_only: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(3, 0, -4)) as Safe
	await wait_physics_frames(1)
	assert_true(sawable.is_in_group(G.SAW_TARGET), "methods has saw: a saw target")
	assert_false(drill_only.is_in_group(G.SAW_TARGET), "drill-only safes are not")
	var need: float = Tweak.interaction().hand_saw_safe_s[sawable.size]
	_cut(sawable, need - 1.0)
	assert_false(sawable.opened, "still locked")
	_cut(sawable, 1.0)
	assert_true(sawable.opened, "cut open")
	assert_eq(sawable.beaten_by, &"saw")


func test_saw_drill_point_cut_by_hand_opens_target() -> void:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-4, 0, -6), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.LOCKPICK) as Door
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(-4, 1, -5.8), func(p: GameplayPrefab) -> void:
		(p as DrillPoint).device = DrillPoint.Device.SAW
		(p as DrillPoint).duration_s = 4.0) as DrillPoint
	dp.target = dp.get_path_to(door)
	await wait_physics_frames(1)
	assert_true(dp.is_in_group(G.SAW_TARGET), "SAW drill points are saw targets")
	_cut(dp, 4.0 * Tweak.interaction().hand_saw_drill_point_mult)
	assert_false(door.locked, "the cut saw spot opens its target")


func test_rotor_saw_weapon_cuts_a_deposit_box() -> void:
	var d: WeaponDef = WeaponDef.new()
	d.id = &"weapon.test_saw_qc37"
	d.weapon_class = Enums.WeaponClass.SPECIAL
	d.slot = Enums.WeaponSlot.PRIMARY
	d.fire_modes = [&"auto"] as Array[StringName]
	d.params = {"saw": {"range_m": 1.8, "wear_per_tick_object": 1.0}}
	var st: WeaponStats = WeaponStats.new()
	st.damage = 30.0
	st.fire_rate_rpm = 600.0
	st.mag_size = 200
	st.total_ammo = 400
	st.falloff_start_m = 9999.0
	st.falloff_end_m = 9999.0
	st.falloff_min_mult = 1.0
	d.base = st
	ContentDB.inject(ContentDB.WEAPONS, d.id, d)
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var w: CrewWeapons = ACombatSpecials.arm(_rt, 0, d.id)
	await wait_physics_frames(40)
	var box: DepositBox = ATestMaps.add_prefab(_rt, "deposit_box", Vector3(0, 1.5, -1.0)) as DepositBox
	await wait_physics_frames(2)
	var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), box.global_position)
	aim.fire = true
	_rt.set_bot_intent(0, aim)
	await wait_seconds(Tweak.interaction().hand_saw_deposit_box_s + 1.5)
	_rt.set_bot_intent(0, BotUtil.look_at_intent(c.eye_position(), box.global_position))
	assert_true(box.opened, "the saw weapon opened the box (saw_cut per tick)")
	assert_true(w.mag(Enums.WeaponSlot.PRIMARY) < 200, "cutting wears the blade")
