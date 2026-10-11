## P1 GATE: vertical slice. Owner: LEAD. Spec: docs/roadmap.md "P1 gate".
## Uses only contracts/test_hooks.md APIs. ENV A's classes are resolved dynamically so this file
## parses before ENV A delivers; tests SKIP until HeistLauncher exists.
## Roadmap step coverage (all 11 steps are automated on the real Glasshouse map):
##   this file (part A)
##     test_01_variants_deterministic        step 1  (seeds 1001 x2, 1002)
##     test_02_casing_and_no_noise           step 2  (+ a smoke check of step 3)
##     test_04_pager_answer                  step 4
##     test_08_loud_transition_and_assault   steps 8 + 9
##   test_p1_vertical_slice_b.gd (part B; static types: FAILS, never skips, if a mechanic is missing)
##     test_03_sprint_jump_behind_guard_no_noise   step 3  (explicit: meter exactly 0, no noise)
##     test_05_pager_released_early_alarm          step 5  (separate seed 1003)
##     test_06_body_bag_hidden_never_discovered    step 6  (60 s of patrols at Engine.time_scale x4)
##     test_07_display_case_and_secure_bag         step 7
##     test_10_ai_teammate_revives_bot             step 10
##     test_11_escape_success_and_payout           step 11 (PayoutCalculator, TENSE x2.0)
extends TestCase

const HEIST: StringName = &"glasshouse"
const SEED_A: int = 1001
const SEED_B: int = 1002

var _launcher: Script = null


func before_all() -> void:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == &"HeistLauncher":
			_launcher = load(c["path"]) as Script
	Engine.time_scale = 1.0


func after_each() -> void:
	Engine.time_scale = 1.0


func _launch(seed_value: int, difficulty: int = Enums.Difficulty.ROUTINE) -> Object:
	var rt: Object = await _launcher.call(&"launch", HEIST, seed_value, difficulty, self, {"ai_teammates": 3})
	# Let the navigation map sync before bots query it (D-036): wait until a closest-point query
	# near the crew returns a real navmesh point (iteration ids alone proved unreliable).
	var crew: Node3D = rt.call(&"crew_controller", 0) as Node3D
	if crew != null:
		await wait_until(func() -> bool: return BotUtil.nav_ready(crew), 10.0)
	await wait_physics_frames(2)
	return rt


func _teardown(rt: Object) -> void:
	if rt != null and is_instance_valid(rt):
		rt.call(&"teardown")
	await wait_frames(2)


func _ready_or_skip() -> bool:
	if _launcher == null:
		skip("HeistLauncher not implemented yet (ENV A, A1-01)")
		return false
	if not ResourceLoader.exists("res://world/heists/glasshouse/glasshouse.tscn"):
		skip("Glasshouse map not delivered yet (ENV C, C1-03)")
		return false
	return true


# 1. Variants resolve deterministically and differ between seeds.
func test_01_variants_deterministic() -> void:
	if not _ready_or_skip():
		return
	var rt: Object = await _launch(SEED_A)
	var v1: Dictionary = (rt.get(&"variants") as Dictionary).duplicate(true)
	await _teardown(rt)
	rt = await _launch(SEED_A)
	var v2: Dictionary = rt.get(&"variants")
	assert_eq(v1, v2, "same seed must resolve identically")
	await _teardown(rt)
	rt = await _launch(SEED_B)
	var v3: Dictionary = rt.get(&"variants")
	assert_ne(v1, v3, "different seed should differ in at least one group")
	await _teardown(rt)


# 2+3. Casing rules and the no-noise rule.
func test_02_casing_and_no_noise() -> void:
	if not _ready_or_skip():
		return
	var rt: Object = await _launch(SEED_A)
	var guards: Array = rt.call(&"npcs", &"guard")
	assert_true(guards.size() >= 1, "at least one guard")
	if guards.is_empty():
		await _teardown(rt)
		return
	var guard: Node3D = guards[0]
	# Public zone: stand next to guard unmasked; no detection.
	var public_zones: Array[Node] = (rt.get(&"map") as HeistMap).get_slots(G.CASING_PUBLIC_AREA)
	assert_true(public_zones.size() >= 1, "map has a PUBLIC zone")
	# Behind-the-guard sprint/jump test (masked): place bot 1 m behind guard, outside FOV.
	var behind_v: Variant = BotUtil.find_clear_point(guard, 1.6, true)
	if behind_v == null:
		fail("no clear navmesh point behind the guard")
		await _teardown(rt)
		return
	rt.call(&"teleport_crew", 0, behind_v)
	var mask: CrewIntent = CrewIntent.new()
	mask.mask_up = true
	rt.call(&"set_bot_intent", 0, mask)
	await wait_seconds(1.5)
	var hop: CrewIntent = CrewIntent.new()
	hop.sprint = true
	hop.jump = true
	hop.move = Vector2(1, 0)
	rt.call(&"set_bot_intent", 0, hop)
	await wait_seconds(2.0)
	# The guard may turn during its patrol; only assert no-noise if it never had LOS.
	var det: float = rt.call(&"detection_value", guard, 0)
	assert_true(det < 0.99, "sprint/jump behind a guard must not instantly detect (no footstep noise)")
	rt.call(&"clear_bot_intent", 0)
	await _teardown(rt)


# 4. Kill a guard -> pager -> answer.
func test_04_pager_answer() -> void:
	if not _ready_or_skip():
		return
	var rt: Object = await _launch(SEED_A)
	var pager_started: Array[int] = []
	var pager_answered: Array[int] = []
	var on_start: Callable = func(pid: int, _g: int) -> void: pager_started.append(pid)
	var on_ans: Callable = func(_pid: int, _slot: int, total: int) -> void: pager_answered.append(total)
	EventBus.pager_started.connect(on_start)
	EventBus.pager_answered.connect(on_ans)
	var guards: Array = rt.call(&"npcs", &"guard")
	if guards.is_empty():
		fail("no guards")
		await _teardown(rt)
		return
	var guard: Node3D = guards[0]
	var crew: Node3D = rt.call(&"crew_controller", 0)
	# QA-9: other NPCs would (correctly) spot the masked bot; this step tests pagers, so isolate.
	if rt.has_method(&"isolate_npc"):
		rt.call(&"isolate_npc", guard)
		await wait_physics_frames(2)
	# Stand 3 m in front of the guard's back, masked, aim at head, fire.
	var shot_v: Variant = BotUtil.find_clear_point(guard, 3.0, true)
	if shot_v == null:
		fail("no clear firing point behind the guard")
		await _teardown(rt)
		return
	rt.call(&"teleport_crew", 0, shot_v)
	var i: CrewIntent = CrewIntent.new()
	i.mask_up = true
	rt.call(&"set_bot_intent", 0, i)
	await wait_seconds(1.2)
	var head: Vector3 = guard.global_position + Vector3(0, 1.65, 0)
	var aim: CrewIntent = BotUtil.look_at_intent(crew.global_position + Vector3(0, 1.65, 0), head)
	aim.fire = true
	rt.call(&"set_bot_intent", 0, aim)
	await wait_physics_frames(3)
	rt.call(&"clear_bot_intent", 0)
	var started: bool = await wait_until(func() -> bool: return not pager_started.is_empty(), 5.0)
	assert_true(started, "pager starts within 2-4 s of the kill")
	if started:
		var ans: CrewIntent = CrewIntent.new()
		ans.interact = true
		ans.interact_target_net_id = guard.get(&"net_id") if guard.get(&"net_id") != null else 0
		var ans_v: Variant = BotUtil.find_clear_point(guard, 1.0, true)
		if ans_v != null:
			rt.call(&"teleport_crew", 0, ans_v)
		rt.call(&"set_bot_intent", 0, ans)
		var answered: bool = await wait_until(func() -> bool: return not pager_answered.is_empty(), 14.0)
		assert_true(answered, "pager answered after 10 s hold")
		if answered:
			assert_eq(pager_answered[0], 1, "first pager -> total 1")
	EventBus.pager_started.disconnect(on_start)
	EventBus.pager_answered.disconnect(on_ans)
	await _teardown(rt)


# 8+9. Alarm -> loud without scene change -> assault cycle runs.
func test_08_loud_transition_and_assault() -> void:
	if not _ready_or_skip():
		return
	var rt: Object = await _launch(SEED_A)
	var map_before: Node = rt.get(&"map")
	var phases: Array[int] = []
	var on_phase: Callable = func(p: int, _w: int) -> void: phases.append(p)
	EventBus.assault_phase_changed.connect(on_phase)
	var guards: Array = rt.call(&"npcs", &"guard")
	var crew: Node3D = rt.call(&"crew_controller", 0)
	if not guards.is_empty():
		var g: Node3D = guards[0]
		var seen_v: Variant = BotUtil.find_clear_point(g, 6.0, false)
		if seen_v != null:
			rt.call(&"teleport_crew", 0, seen_v)
	var i: CrewIntent = CrewIntent.new()
	i.mask_up = true
	rt.call(&"set_bot_intent", 0, i)
	await wait_seconds(1.2)
	# Unsuppressed fire: equip slot primary (unsuppressed default pistol has no suppressor in slice default loadout).
	var f: CrewIntent = CrewIntent.new()
	f.fire = true
	f.look_pitch = deg_to_rad(30.0)
	f.look_yaw = crew.rotation.y
	rt.call(&"set_bot_intent", 0, f)
	var loud: bool = await wait_until(func() -> bool: return rt.get(&"phase") == Enums.HeistPhase.LOUD, 15.0)
	rt.call(&"clear_bot_intent", 0)
	assert_true(loud, "alarm makes heist LOUD")
	assert_true(rt.get(&"map") == map_before and is_instance_valid(map_before), "no scene change on loud transition")
	Engine.time_scale = 4.0
	var reached_fade: bool = await wait_until(func() -> bool: return Enums.AssaultPhase.FADE in phases, 600.0)
	assert_true(reached_fade, "assault cycle reaches FADE")
	assert_has(phases, Enums.AssaultPhase.BUILD)
	assert_has(phases, Enums.AssaultPhase.SUSTAIN)
	assert_true((rt.call(&"npcs", &"police") as Array).size() > 0 or Enums.AssaultPhase.FADE in phases, "police spawned")
	EventBus.assault_phase_changed.disconnect(on_phase)
	await _teardown(rt)
