## Night Deposit smoke launch (C2 G1): HeistLauncher loads the map at seed 1001 / Routine, the
## variants resolve deterministically, NPCs spawn, the mission publishes its objectives, and the
## inactive variant content is gone. Owner: ENV C. Pattern: tests/integration/test_p1_vertical_slice.gd.
extends TestCase

const HEIST: StringName = &"night_deposit"
const SEED: int = 1001

var _launcher: Script = null


func before_all() -> void:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == &"HeistLauncher":
			_launcher = load(c["path"]) as Script
	Engine.time_scale = 1.0


func _launch(seed_value: int, difficulty: int = Enums.Difficulty.ROUTINE) -> Object:
	var rt: Object = await _launcher.call(&"launch", HEIST, seed_value, difficulty, self, {"ai_teammates": 3})
	if rt == null:
		return null
	var crew: Node3D = rt.call(&"crew_controller", 0) as Node3D
	if crew != null:
		await wait_until(func() -> bool: return BotUtil.nav_ready(crew), 10.0)
	await wait_physics_frames(2)
	return rt


func _teardown(rt: Object) -> void:
	if rt != null and is_instance_valid(rt):
		rt.call(&"teardown")
	await wait_frames(2)


func test_launch_routine_seed_1001() -> void:
	if _launcher == null:
		skip("HeistLauncher not available")
		return
	var rt: Object = await _launch(SEED)
	assert_true(rt != null, "HeistLauncher.launch(night_deposit, 1001, ROUTINE) returns a runtime")
	if rt == null:
		return
	var v: Dictionary = (rt.get(&"variants") as Dictionary).duplicate(true)
	Log.info(&"test", "night_deposit seed %d Routine resolved: %s" % [SEED, _table(v)])
	for g: StringName in [&"keycard", &"escape", &"laser_pattern", &"camera", &"server_room", &"vent_open"]:
		assert_eq((v.get(g, []) as Array).size(), 1, "group %s resolved to one slot" % g)
	assert_true(v.has(&"time_lock_s") and v.has(&"depository_bags") and v.has(&"deposit_boxes"), "scalars rolled")
	var guards: Array = rt.call(&"npcs", &"guard")
	assert_true(guards.size() >= 2, "hall + basement guards spawned (got %d)" % guards.size())
	var map: HeistMap = rt.get(&"map") as HeistMap
	assert_true(map != null and map.heist_def.id == HEIST, "night_deposit map is live")
	var mission: HeistMission = rt.get(&"mission") as HeistMission
	assert_true(mission != null, "mission bound")
	if mission != null:
		var ids: Array[StringName] = []
		for o: Dictionary in mission.objectives():
			ids.append(StringName(o["id"]))
		for tag: StringName in [&"keycard", &"code", &"server", &"vault_gate", &"secure", &"escape"]:
			assert_has(ids, tag, "objective %s published" % tag)
	# Inactive variant content is stripped: exactly one keycard pickup and one laser grid remain.
	if map != null:
		var cards: int = 0
		for n: Node in map.get_node("Variants/Group_keycard").find_children("Keycard", "", true, false):
			cards += 1
		assert_eq(cards, 1, "one keycard after variant resolution")
		var lasers: int = map.get_node("Variants/Group_laser_pattern").find_children("AntechamberLasers", "", true, false).size()
		assert_eq(lasers, 1, "one antechamber laser grid")
	await _teardown(rt)
	rt = await _launch(SEED)
	if rt != null:
		assert_eq(rt.get(&"variants"), v, "same seed resolves identically")
	await _teardown(rt)


## Brutal at the same seed: the per-difficulty weights / gates take effect (logged next to Routine),
## then the real prefabs: the server hack (device_finished -> server done + time lock) and the lift.
func test_launch_brutal_seed_1001() -> void:
	if _launcher == null:
		skip("HeistLauncher not available")
		return
	var rt: Object = await _launch(SEED, Enums.Difficulty.BRUTAL)
	assert_true(rt != null, "HeistLauncher.launch(night_deposit, 1001, BRUTAL) returns a runtime")
	if rt == null:
		return
	var v: Dictionary = (rt.get(&"variants") as Dictionary).duplicate(true)
	Log.info(&"test", "night_deposit seed %d Brutal resolved: %s" % [SEED, _table(v)])
	var rovers: int = 0
	for sid: Variant in (v.get(&"guard_post", []) as Array):
		rovers += 0 if StringName(sid) == &"rover_none" else 1
	assert_true(rovers >= 1 and rovers <= 2, "Brutal: 1-2 rovers (got %d)" % rovers)
	var guards: Array = rt.call(&"npcs", &"guard")
	assert_true(guards.size() >= 3, "Brutal: hall + basement + >= 1 rover spawned (got %d)" % guards.size())
	var map: HeistMap = rt.get(&"map") as HeistMap
	var mission: HeistMission = rt.get(&"mission") as HeistMission
	if map != null and mission != null:
		await _check_hack(map, mission)
		await _check_lift(map)
	await _teardown(rt)


func _check_hack(map: HeistMap, mission: HeistMission) -> void:
	var hacks: Array[Node] = map.get_node("Variants/Group_server_room").find_children("HackTerminal", "", true, false)
	assert_eq(hacks.size(), 1, "one hack terminal after variant resolution")
	if hacks.is_empty():
		return
	var ht: HackTerminal = hacks[0] as HackTerminal
	assert_true(ht != null, "the active server_room slot holds a HackTerminal")
	if ht == null:
		return
	ht.start_hack(0)
	assert_eq(int(ht.state), int(HackTerminal.State.RUNNING), "hack running")
	assert_eq(ht.rolled_interruptions, 2, "2 reboot interruptions rolled")
	assert_eq(mission.objective_state(&"server"), Enums.ObjectiveState.ACTIVE, "starting the hack does not finish it")
	# Skip the run: past the reboots, then finish (device_finished drives the mission).
	ht.pending_interruptions.clear()
	ht.progress = 0.999
	await wait_until(func() -> bool: return ht.state == HackTerminal.State.DONE, 3.0)
	assert_eq(int(ht.state), int(HackTerminal.State.DONE), "hack finished")
	await wait_physics_frames(2)
	assert_eq(mission.objective_state(&"server"), Enums.ObjectiveState.COMPLETED, "server objective on device_finished")
	assert_eq(mission.objective_state(&"time_lock_wait"), Enums.ObjectiveState.ACTIVE, "the hack starts the time lock")


func _check_lift(map: HeistMap) -> void:
	var lift: BagLift = map.get_node_or_null("Gameplay/Misc/CashLift") as BagLift
	assert_true(lift != null, "CashLift is a live BagLift")
	if lift == null:
		return
	await wait_physics_frames(2)
	assert_eq(lift.landing_count(), 2, "B1 + G1 landings")
	assert_eq(lift.panels.size(), 2, "a call/send panel per landing")
	assert_false(lift.using_placeholder, "greybox lift visual (cash_lift_visual.tscn)")
	assert_eq(lift.landing, 0, "car waits at G1")
	assert_true(lift.send(1, 0), "send the car G1 -> B1")
	assert_near(lift.travel_left(), 8.0, 0.1, "8 s trip")
	await wait_until(func() -> bool: return not lift.is_moving(), 12.0)
	assert_eq(lift.landing, 1, "car at B1")
	assert_near(lift.car_transform().origin.y, -3.95, 0.01, "car floor at B1")


static func _table(v: Dictionary) -> String:
	var keys: Array = v.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys:
		parts.append("%s=%s" % [k, v[k]])
	return ", ".join(parts)
