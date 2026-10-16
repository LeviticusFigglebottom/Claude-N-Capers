## Shadow Ledger smoke launch (C2 G1): HeistLauncher loads the map at seed 1001 / Routine, the
## variants resolve deterministically, NPCs spawn, the mission publishes its objectives, and the
## inactive variant content is gone. Owner: ENV C. Pattern: tests/integration/test_p1_vertical_slice.gd.
extends TestCase

const HEIST: StringName = &"shadow_ledger"
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
	assert_true(rt != null, "HeistLauncher.launch(shadow_ledger, 1001, ROUTINE) returns a runtime")
	if rt == null:
		return
	var v: Dictionary = (rt.get(&"variants") as Dictionary).duplicate(true)
	for g: StringName in [&"laptop", &"escape", &"laser_pattern", &"camera", &"server_room", &"vent_open", &"gondola"]:
		assert_eq((v.get(g, []) as Array).size(), 1, "group %s resolved to one slot" % g)
	assert_eq((v.get(&"keycard", []) as Array).size(), 2, "two keycards")
	assert_true(v.has(&"time_lock_s"), "time_lock_s rolled")
	var guards: Array = rt.call(&"npcs", &"guard")
	assert_true(guards.size() >= 2, "reception post + a rover spawned (got %d)" % guards.size())
	var map: HeistMap = rt.get(&"map") as HeistMap
	assert_true(map != null and map.heist_def.id == HEIST, "shadow_ledger map is live")
	var mission: HeistMission = rt.get(&"mission") as HeistMission
	assert_true(mission != null, "mission bound")
	if mission != null:
		var ids: Array[StringName] = []
		for o: Dictionary in mission.objectives():
			ids.append(StringName(o["id"]))
		for tag: StringName in [&"laptop", &"keycard", &"server_door", &"cage", &"hack", &"drives", &"secure", &"escape"]:
			assert_has(ids, tag, "objective %s published" % tag)
	# Inactive variant content is stripped: one laptop, two keycards, one art-hall grid.
	if map != null:
		var laptops: int = map.get_node("Variants/Group_laptop").find_children("Laptop", "", true, false).size()
		assert_eq(laptops, 1, "one laptop after variant resolution")
		var cards: int = map.get_node("Variants/Group_keycard").find_children("Keycard", "", true, false).size()
		assert_eq(cards, 2, "two keycards after variant resolution")
		var lasers: int = map.get_node("Variants/Group_laser_pattern").find_children("ArtHallLasers", "", true, false).size()
		assert_eq(lasers, 1, "one art-hall laser grid")
	await _teardown(rt)
	rt = await _launch(SEED)
	if rt != null:
		assert_eq(rt.get(&"variants"), v, "same seed resolves identically")
	await _teardown(rt)


## Brutal: both rovers and a walked extra spawn; then the cage -> hack -> drives chain on the real
## prefabs (the mission gates the hack terminal on the cage and the drive sleds on the hack).
func test_launch_brutal_seed_1001() -> void:
	if _launcher == null:
		skip("HeistLauncher not available")
		return
	var rt: Object = await _launch(SEED, Enums.Difficulty.BRUTAL)
	assert_true(rt != null, "HeistLauncher.launch(shadow_ledger, 1001, BRUTAL) returns a runtime")
	if rt == null:
		return
	var v: Dictionary = (rt.get(&"variants") as Dictionary).duplicate(true)
	Log.info(&"test", "shadow_ledger seed %d Brutal resolved: %s" % [SEED, _table(v)])
	assert_eq((v.get(&"guard_post", []) as Array).size(), 2, "Brutal: both rovers")
	var extras: Array = v.get(&"guard_extra", [])
	assert_true(extras.size() == 1 and not extras.has(&"extra_none"), "Brutal: one walked extra (%s)" % [extras])
	var guards: Array = rt.call(&"npcs", &"guard")
	assert_true(guards.size() >= 4, "Brutal: reception + 2 rovers + 1 extra spawned (got %d)" % guards.size())
	var map: HeistMap = rt.get(&"map") as HeistMap
	var mission: HeistMission = rt.get(&"mission") as HeistMission
	if map != null and mission != null:
		await _check_cage_and_hack(map, mission)
	await _teardown(rt)


func _check_cage_and_hack(map: HeistMap, mission: HeistMission) -> void:
	var cage: Safe = map.get_node_or_null("Gameplay/Server/CageLock") as Safe
	var ht: HackTerminal = map.get_node_or_null("Gameplay/Server/HackTerminal") as HackTerminal
	var drives: Node = map.get_node_or_null("Gameplay/Server/Drives1")
	assert_true(cage != null and ht != null and drives != null, "cage lock, hack terminal and drive sleds are live")
	if cage == null or ht == null or drives == null:
		return
	assert_false(_enabled(ht), "hack terminal locked until the cage opens")
	assert_false(_enabled(drives), "drive sleds locked until the hack")
	# In play the saw's DrillPoint swings the lock (open_by_device) and then reports device_finished;
	# SL-6 counts the cage open only on a real lock swing.
	cage.open_by_device()
	EventBus.device_finished.emit(int(cage.get(&"net_id")))
	await wait_physics_frames(2)
	assert_eq(mission.objective_state(&"cage"), Enums.ObjectiveState.COMPLETED, "cage objective")
	assert_eq(mission.objective_state(&"hack"), Enums.ObjectiveState.ACTIVE, "hack objective shown")
	assert_true(_enabled(ht), "hack terminal usable once the cage is open")
	var gate: Door = map.get_node_or_null("Gameplay/Doors/CageGate") as Door
	assert_true(gate != null and gate.is_open, "cage gate swung open")
	ht.start_hack(0)
	assert_eq(int(ht.state), int(HackTerminal.State.RUNNING), "hack running")
	ht.pending_interruptions.clear()
	ht.progress = 0.999
	await wait_until(func() -> bool: return ht.state == HackTerminal.State.DONE, 3.0)
	await wait_physics_frames(2)
	assert_eq(mission.objective_state(&"hack"), Enums.ObjectiveState.COMPLETED, "hack objective on device_finished")
	assert_eq(mission.objective_state(&"drives"), Enums.ObjectiveState.ACTIVE, "drives objective shown")
	assert_true(_enabled(drives), "drive sleds released by the hack")


static func _enabled(prefab: Node) -> bool:
	var it: Node = prefab.get_node_or_null(^"Interactable")
	return it != null and bool(it.get(&"enabled"))


static func _table(v: Dictionary) -> String:
	var keys: Array = v.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys:
		parts.append("%s=%s" % [k, v[k]])
	return ", ".join(parts)
