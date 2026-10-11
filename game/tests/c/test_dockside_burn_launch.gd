## Dockside Burn smoke launch (C3 G1): HeistLauncher loads the map at seed 1001 / Routine, the
## variants resolve deterministically, the cartel posts and the night shift spawn, the mission
## publishes its objectives, inactive variant content is gone; then the burn -> fire shutters ->
## secure -> escape chain on the real prefabs. Owner: ENV C. Pattern: test_shadow_ledger_launch.gd.
extends TestCase

const HEIST: StringName = &"dockside_burn"
const SEED: int = 1001
const SHUTTERS: Dictionary = {
	&"prod_chamber_a": ["ChamberANorth", "PKChamberA", "ChamberASpine"],
	&"prod_chamber_b": ["ChamberBNorth", "SpineChamberB", "ChamberBSouth"],
	&"prod_packing": ["PKChamberA", "PKRoller", "PKQuay", "PKPlant", "PKWorkshop"],
}

var _launcher: Script = null


func before_all() -> void:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == &"HeistLauncher":
			_launcher = load(c["path"]) as Script
	Engine.time_scale = 1.0


func after_all() -> void:
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
	assert_true(rt != null, "HeistLauncher.launch(dockside_burn, 1001, ROUTINE) returns a runtime")
	if rt == null:
		return
	var v: Dictionary = (rt.get(&"variants") as Dictionary).duplicate(true)
	Log.info(&"test", "dockside_burn seed %d Routine resolved: %s" % [SEED, _table(v)])
	assert_eq((v.get(&"guard_post", []) as Array).size(), 3, "Routine: 3 cartel posts")
	for g: StringName in [&"cash_location", &"product_location", &"escape", &"east_gangway", &"night_shift"]:
		assert_eq((v.get(g, []) as Array).size(), 1, "group %s resolved to one slot" % g)
	for s: StringName in [&"police_delay_s", &"cash_bags", &"product_bags", &"escape_eta_s"]:
		assert_true(v.has(s), "scalar %s rolled" % s)
	assert_true(bool(rt.get(&"went_loud")), "loud-only heist starts LOUD (S11.3)")
	var guards: Array = rt.call(&"npcs", &"cartel")  # LEAD: QC-36 landed (A 878d35f): gunmen have role cartel
	assert_eq(guards.size(), 6, "3 posts x 2 gunmen spawned (QC-36 cartel role)")
	var map: HeistMap = rt.get(&"map") as HeistMap
	var mission: HeistMission = rt.get(&"mission") as HeistMission
	assert_true(mission != null, "mission bound")
	if mission != null:
		var ids: Array[StringName] = []
		for o: Dictionary in mission.objectives():
			ids.append(StringName(o["id"]))
		for tag: StringName in [&"cartel", &"breach", &"product", &"burn", &"containers", &"secure", &"escape"]:
			assert_has(ids, tag, "objective %s published" % tag)
	if map != null:
		var burn: int = map.get_node("Variants/Group_product_location").find_children("BurnPoint", "", true, false).size()
		assert_eq(burn, 1, "one burn point after variant resolution")
		var esc: int = map.get_node("Variants/Group_escape").find_children("*", "EscapeZone", true, false).size()
		assert_eq(esc, 1, "one escape zone after variant resolution")
	await _teardown(rt)
	rt = await _launch(SEED)
	if rt != null:
		assert_eq(rt.get(&"variants"), v, "same seed resolves identically")
	await _teardown(rt)


## The burn finishing drops the burning room's fire shutters 5 s later (D-064 Q6); four secured bags
## after the burn call the escape (D-064 Q2).
func test_burn_shutters_and_escape_call() -> void:
	if _launcher == null:
		skip("HeistLauncher not available")
		return
	var rt: Object = await _launch(SEED)
	if rt == null:
		fail("no runtime")
		return
	var map: HeistMap = rt.get(&"map") as HeistMap
	var mission: HeistMission = rt.get(&"mission") as HeistMission
	var v: Dictionary = rt.get(&"variants") as Dictionary
	var sid: StringName = StringName((v.get(&"product_location", [&"prod_chamber_a"]) as Array)[0])
	var bp: Node = map.get_node("Variants/Group_product_location").find_child("BurnPoint", true, false)
	assert_true(bp != null, "burn point live")
	if bp == null or mission == null:
		await _teardown(rt)
		return
	EventBus.device_finished.emit(int(bp.get(&"net_id")))
	await wait_physics_frames(2)
	assert_eq(mission.objective_state(&"burn"), Enums.ObjectiveState.COMPLETED, "burn objective")
	Engine.time_scale = 4.0
	await wait_until(func() -> bool: return mission.timer_left(&"fire_shutters") <= 0.0, 5.0)
	await wait_physics_frames(3)
	Engine.time_scale = 1.0
	for dn: String in SHUTTERS[sid]:
		var d: Door = map.get_node_or_null("Gameplay/Doors/" + dn) as Door
		assert_true(d != null and not d.is_open, "fire shutter %s closed" % dn)
		var it: Node = d.get_node_or_null(^"Interactable") if d != null else null
		assert_true(it != null and not bool(it.get(&"enabled")), "fire shutter %s barred (interaction off)" % dn)
	for i: int in range(4):
		EventBus.loot_secured.emit(9000 + i, &"loot.cash_bricks", 1000)
	await wait_physics_frames(2)
	assert_eq(mission.objective_state(&"secure"), Enums.ObjectiveState.COMPLETED, "4 bags secured")
	assert_eq(mission.objective_state(&"escape_wait"), Enums.ObjectiveState.ACTIVE, "escape called after burn + secure")
	await _teardown(rt)


static func _table(v: Dictionary) -> String:
	var keys: Array = v.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys:
		parts.append("%s=%s" % [k, v[k]])
	return ", ".join(parts)
