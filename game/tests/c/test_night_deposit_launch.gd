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


func _launch(seed_value: int) -> Object:
	var rt: Object = await _launcher.call(&"launch", HEIST, seed_value, Enums.Difficulty.ROUTINE, self, {"ai_teammates": 3})
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
