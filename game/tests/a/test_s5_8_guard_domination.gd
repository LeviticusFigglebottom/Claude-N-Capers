## A4-01 / S5.8: guard domination in stealth. One shout from crew with `stealth.can_dominate_guards`
## inside guard_dominate_window_s (1.5 s) after the guard's "!" makes him kneel and cuff himself
## (DOMINATED, 100% inside the window, guard_dominated [R], a hostage); the radio call is cancelled
## and his pager still fires (S5.2). Without the flag, or after the window, the shout does nothing.
extends TestCase

var _rt: HeistRuntime = null
var _cuffs_was: bool = true


func before_each() -> void:
	_cuffs_was = Tweak.stealth().guard_cuffs_enabled
	Tweak.stealth().guard_cuffs_enabled = false
	Modifiers.clear_all()
	_rt = await HeistLauncher.launch(&"unit_map", 58, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false})
	await wait_physics_frames(2)


func after_each() -> void:
	Tweak.stealth().guard_cuffs_enabled = _cuffs_was
	Modifiers.clear_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _guard() -> NpcBase:
	return _rt.npcs(&"guard")[0] as NpcBase


func _brain() -> GuardBrain:
	return _guard().get_node("Brain") as GuardBrain


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


## Crew 0 masked, 6 m from the guard, looking at his chest. Returns the idle intent.
func _face_guard() -> CrewIntent:
	var g: NpcBase = _guard()
	_crew().set_masked(true)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g.global_position + Vector3(0, 0.05, 6.0)))
	await wait_physics_frames(1)
	var d: Vector3 = g.global_position + Vector3(0, 1.2, 0) - _crew().eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	return i


func _shout(i: CrewIntent) -> void:
	var s: CrewIntent = CrewIntent.from_dict(i.to_dict())
	s.shout = true
	_rt.set_bot_intent(0, s)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(1)


func test_s5_8_shout_in_window_dominates_and_pager_fires() -> void:
	Modifiers.set_source(0, &"skills", {&"stealth.can_dominate_guards": true})
	var i: CrewIntent = await _face_guard()
	var dominated: Array = []
	var cb: Callable = func(id: int, slot: int) -> void: dominated.append([id, slot])
	EventBus.guard_dominated.connect(cb)
	var hostages: Array[int] = []
	var hcb: Callable = func(n: int) -> void: hostages.append(n)
	EventBus.hostage_count_changed.connect(hcb)
	_guard().notify_crew_spotted(_crew())
	await wait_physics_frames(1)
	assert_eq(_brain().state_name(), &"alarmed", "! -> ALARMED (radio call)")
	assert_near(_brain().dominate_window_left, Tweak.stealth().guard_dominate_window_s, 0.1, "window open")
	await _shout(i)
	EventBus.guard_dominated.disconnect(cb)
	EventBus.hostage_count_changed.disconnect(hcb)
	assert_eq(_brain().state_name(), &"dominated", "S5.8: shout in the window dominates")
	assert_eq(dominated, [[_guard().net_id, 0]], "guard_dominated(npc, slot)")
	assert_eq(_brain().dominated_by_slot, 0)
	assert_eq(_brain().anim_hint, &"kneel_cuffed", "kneels and cuffs himself")
	assert_true(_guard().is_in_group(G.HOSTAGE), "a hostage")
	assert_eq(hostages, [1] as Array[int], "hostage_count_changed")
	var pagers: PagerSystem = HeistRuntime.get_service(G.SVC_PAGERS) as PagerSystem
	assert_true(pagers != null and pagers.blocks_body(_guard()), "S5.8: his pager still fires")
	await wait_seconds(Tweak.stealth().guard_radio_call_s + 0.3)
	assert_false(_rt.stealth.alarm_raised, "radio call cancelled")
	assert_eq(_brain().state_name(), &"dominated", "permanent")


func test_s5_8_needs_the_flag() -> void:
	var i: CrewIntent = await _face_guard()
	_guard().notify_crew_spotted(_crew())
	await wait_physics_frames(1)
	await _shout(i)
	assert_eq(_brain().state_name(), &"alarmed", "no can_dominate_guards: the shout does nothing")


func test_s5_8_window_closes_after_1_5_s() -> void:
	Modifiers.set_source(0, &"skills", {&"stealth.can_dominate_guards": true})
	var i: CrewIntent = await _face_guard()
	var tw: StealthTweak = Tweak.stealth()
	var call_was: float = tw.guard_radio_call_s
	tw.guard_radio_call_s = 10.0
	_guard().notify_crew_spotted(_crew())
	await wait_seconds(tw.guard_dominate_window_s + 0.2)
	await _shout(i)
	tw.guard_radio_call_s = call_was
	assert_eq(_brain().state_name(), &"alarmed", "after the window the shout fails")
	assert_false(_guard().is_in_group(G.HOSTAGE))


func test_s5_8_calm_guard_cannot_be_dominated() -> void:
	Modifiers.set_source(0, &"skills", {&"stealth.can_dominate_guards": true})
	var i: CrewIntent = await _face_guard()
	await _shout(i)
	assert_ne(_brain().state_name(), &"dominated", "no window without a detection")
	assert_true(not _brain().can_be_dominated_by(_crew()))


## D-079: range 10 m x 1.5 (domination skill) x 1.25 (Crew Chief); cone max(8, 90 -> 30 deg over 0..12 m).
func test_d079_range_and_cone() -> void:
	var c: CrewController = _crew()
	assert_near(ShoutSystem.guard_dominate_range_for(c), 10.0, 0.001, "base 10 m")
	Modifiers.set_source(0, &"skills", {&"ability.intimidate_cops": true})
	assert_near(ShoutSystem.guard_dominate_range_for(c), 15.0, 0.001, "x1.5 skill")
	Modifiers.set_source(0, &"perk", {&"ability.shout_range_mult": 1.25})
	assert_near(ShoutSystem.guard_dominate_range_for(c), 18.75, 0.001, "x1.25 Crew Chief, multiplicative")
	assert_near(ShoutSystem.guard_dominate_cone_half_deg(0.0), 90.0, 0.001)
	assert_near(ShoutSystem.guard_dominate_cone_half_deg(6.0), 60.0, 0.001)
	assert_near(ShoutSystem.guard_dominate_cone_half_deg(12.0), 30.0, 0.001)
	assert_near(ShoutSystem.guard_dominate_cone_half_deg(18.0), 8.0, 0.001, "floor 8 deg")


## D-079: a guard 12 m away is out of base range; with the domination skill he can be dominated.
func test_d079_twelve_metres_needs_the_skill() -> void:
	Modifiers.set_source(0, &"skills", {&"stealth.can_dominate_guards": true})
	var g: NpcBase = _guard()
	_crew().set_masked(true)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g.global_position + Vector3(0, 0.05, 12.0)))
	await wait_physics_frames(1)
	var d: Vector3 = g.global_position + Vector3(0, 1.2, 0) - _crew().eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	g.notify_crew_spotted(_crew())
	await wait_physics_frames(1)
	var shout: ShoutSystem = ShoutSystem.ensure(_rt)
	assert_true(shout.guard_target_for(_crew()) == null, "12 m > 10 m base range")
	Modifiers.set_source(0, &"skills2", {&"ability.intimidate_cops": true})
	assert_true(shout.guard_target_for(_crew()) == _guard(), "15 m with the domination skill")


## D-079: a dominated guard is a hostage a trade can use (PD2).
func test_d079_dominated_guard_is_tradeable_hostage() -> void:
	Modifiers.set_source(0, &"skills", {&"stealth.can_dominate_guards": true})
	_brain().dominate(0)
	await wait_physics_frames(1)
	var cs: CustodySystem = CustodySystem.of(_rt)
	assert_true(cs != null, "custody system")
	assert_has(cs.hostage_candidates(), _guard(), "dominated guard is a trade candidate")


## PP-A-1: the local HUD model exposes the guard a shout would dominate during his window.
func test_pp_a1_hud_dominate_prompt() -> void:
	Modifiers.set_source(0, &"skills", {&"stealth.can_dominate_guards": true})
	await _face_guard()
	_rt.hud_model.refresh()
	assert_eq(_rt.hud_model.dominate_target, 0, "no window yet")
	_guard().notify_crew_spotted(_crew())
	await wait_physics_frames(1)
	_rt.hud_model.refresh()
	assert_eq(_rt.hud_model.dominate_target, _guard().net_id, "prompt on the spotting guard")
	assert_true(_rt.hud_model.dominate_window_s > 0.0)
	await wait_seconds(Tweak.stealth().guard_dominate_window_s + 0.2)
	_rt.hud_model.refresh()
	assert_eq(_rt.hud_model.dominate_target, 0, "window closed")
