## D-122 (C's GN bronze-doors stall): in loud a locked breachable door's link is on Door.NAV_LAYER_BREACH, so police
## path through it (they breach) while crew / bot / pilot queries (layer 1) find no way through a shut door they
## cannot open; an unlocked door is on layer 1 for everyone.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)



func test_d122_locked_door_police_only_in_loud() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 2122, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0, Vector2(4, 6)), "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.LOCKPICK) as Door
	await wait_physics_frames(2)
	var link: NavigationLink3D = door.get_node("NavLink") as NavigationLink3D
	assert_false(link.enabled, "stealth: a locked shut door has no link")
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_true(_rt.went_loud, "loud")
	assert_true(link.enabled, "loud: the breachable door is linked")
	assert_eq(link.navigation_layers, Door.NAV_LAYER_BREACH, "... on the police-only breach layer")
	assert_eq(link.navigation_layers & 1, 0, "crew / bot / pilot queries (layer 1) never use it")
	var cop: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", Vector3(0, 0.05, 3))
	await wait_physics_frames(3)
	var agent: NavigationAgent3D = cop.get_node_or_null(^"NavAgent") as NavigationAgent3D
	assert_true(agent != null and agent.navigation_layers & Door.NAV_LAYER_BREACH != 0 and agent.navigation_layers & 1 != 0,
		"police agents walk layer 1 and the breach layer")
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(1, 0.05, 3)), {})
	await wait_physics_frames(3)
	var cagent: NavigationAgent3D = civ.get_node_or_null(^"NavAgent") as NavigationAgent3D
	assert_true(cagent != null and cagent.navigation_layers & Door.NAV_LAYER_BREACH == 0, "civilians do not")
	door.unlock()
	assert_eq(link.navigation_layers, 1, "unlocked: layer 1 for everyone")
	var bar: Door = ATestMaps.add_prefab(_rt, "door", Vector3(8, 0, 0), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.BARRED) as Door
	await wait_physics_frames(2)
	assert_false((bar.get_node("NavLink") as NavigationLink3D).enabled, "BARRED stays unlinked in loud")
