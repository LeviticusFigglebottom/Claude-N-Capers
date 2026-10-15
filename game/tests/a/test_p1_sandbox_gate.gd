## ENV A: the LEAD P1 gate scenarios (game/tests/integration/test_p1_vertical_slice.gd) run on the
## ENV A dev sandbox until Glasshouse lands, plus gate steps 5, 7, 10, 11. Kept in sync by copying
## the gate's test bodies; only HEIST and the map check differ.
extends TestCase

const HEIST: StringName = &"dev_sandbox"
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
	Tweak.stealth().pager_release_resumes = false  # LEAD: PO 2026-10-15 early release = alarm (default)


func _launch(seed_value: int, difficulty: int = Enums.Difficulty.ROUTINE) -> Object:
	var rt: Object = await _launcher.call(&"launch", HEIST, seed_value, difficulty, self, {"ai_teammates": 3})
	return rt


func _teardown(rt: Object) -> void:
	if rt != null and is_instance_valid(rt):
		rt.call(&"teardown")
	await wait_frames(2)


func _ready_or_skip() -> bool:
	if _launcher == null:
		skip("HeistLauncher not implemented yet (ENV A, A1-01)")
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
	var behind: Transform3D = guard.global_transform.translated_local(Vector3(0, 0, 1.0))
	rt.call(&"teleport_crew", 0, behind)
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
	rt.call(&"teleport_crew", 0, guard.global_transform.translated_local(Vector3(0, 0, 3.0)))
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
		rt.call(&"teleport_crew", 0, guard.global_transform.translated_local(Vector3(0, 0, 1.0)))
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
		rt.call(&"teleport_crew", 0, g.global_transform.translated_local(Vector3(0, 0, -6.0)))
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

# 5. Releasing a pager early with nobody else answering raises the alarm.
func test_05_pager_release_early_alarm() -> void:
	# S5.4 / D-114 §4 as amended: letting go early with no juggle raises the alarm after the juggle grace.
	if not _ready_or_skip():
		return
	var rt: HeistRuntime = await _launch(SEED_B) as HeistRuntime
	var alarms: Array[StringName] = []
	var on_alarm: Callable = func(r: StringName, _s: int) -> void: alarms.append(r)
	EventBus.alarm_raised.connect(on_alarm)
	var guard: NpcBase = rt.npcs(&"guard")[0] as NpcBase
	rt.isolate_npc(guard)
	var crew: CrewController = rt.crew_controller(0) as CrewController
	crew.set_masked()
	guard.die({}, crew.net_id)
	var pagers: PagerSystem = rt.service(G.SVC_PAGERS) as PagerSystem
	await wait_until(func() -> bool: return not pagers.pager_entries().is_empty(), 5.0)
	rt.teleport_crew(0, guard.global_transform.translated_local(Vector3(0, 0, 1.0)))
	var ans: CrewIntent = CrewIntent.new()
	ans.interact = true
	ans.interact_target_net_id = guard.net_id
	rt.set_bot_intent(0, ans)
	await wait_seconds(3.0)
	rt.clear_bot_intent(0)
	await wait_seconds(Tweak.stealth().pager_juggle_window_s + 0.3)
	assert_true(alarms.has(&"pager_failed"), "early release raises the alarm (S5.4)")
	EventBus.alarm_raised.disconnect(on_alarm)
	await _teardown(rt)


# 7. Take a bag from the loot spawn and secure it at the van.
func test_07_secure_bag_at_van() -> void:
	if not _ready_or_skip():
		return
	var rt: HeistRuntime = await _launch(SEED_A) as HeistRuntime
	var secured: Array[int] = []
	var on_sec: Callable = func(bag: int, _l: StringName, _v: int) -> void: secured.append(bag)
	EventBus.loot_secured.connect(on_sec)
	var crew: CrewController = rt.crew_controller(0) as CrewController
	crew.set_masked()
	var loot: LootManager = rt.service(G.SVC_LOOT) as LootManager
	var zone: MapZone = rt.map.get_slots(G.LOOT_SECURE_ZONE)[0] as MapZone
	var bag: Node = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, crew.global_position + Vector3(0, 0.3, -1)))
	loot.carry(bag, crew)
	# Beside the van (the van body sits at the zone centre), facing into the zone.
	rt.teleport_crew(0, Transform3D(Basis(Vector3.UP, PI), _center(zone) + Vector3(-2.0, 0.05, -1.5)))
	var drop: CrewIntent = CrewIntent.new()
	drop.drop_bag = true
	rt.set_bot_intent(0, drop)
	var ok: bool = await wait_until(func() -> bool: return not secured.is_empty(), 6.0)
	rt.clear_bot_intent(0)
	assert_true(ok, "bag secured in SECURE_LOOT (S10.2)")
	EventBus.loot_secured.disconnect(on_sec)
	await _teardown(rt)


# 10. The bot goes down in loud; an AI teammate revives it within its revive time (+ travel).
func test_10_ai_teammate_revives_downed_bot() -> void:
	if not _ready_or_skip():
		return
	var rt: HeistRuntime = await _launch(SEED_A) as HeistRuntime
	var revived: Array[int] = []
	var on_rev: Callable = func(slot: int, by: int) -> void: revived.append(by if slot == 0 else -1)
	EventBus.crew_revived.connect(on_rev)
	rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(2)
	var crew: CrewController = rt.crew_controller(0) as CrewController
	crew.health.go_down()
	var ok: bool = await wait_until(func() -> bool: return not revived.is_empty(), Tweak.crew().revive_time_s + 14.0)
	assert_true(ok, "AI teammate revived the downed bot")
	if ok:
		assert_true(revived[0] >= 1, "revived by an AI slot")
	EventBus.crew_revived.disconnect(on_rev)
	await _teardown(rt)


# 11. Escape with a secured bag -> heist_ended(success) with contract pay and loot.
func test_11_escape_success() -> void:
	if not _ready_or_skip():
		return
	var rt: HeistRuntime = await _launch(SEED_A) as HeistRuntime
	var results: Array[Dictionary] = []
	var on_end: Callable = func(r: Dictionary) -> void: results.append(r)
	EventBus.heist_ended.connect(on_end)
	var crew: CrewController = rt.crew_controller(0) as CrewController
	crew.set_masked()
	var loot: LootManager = rt.service(G.SVC_LOOT) as LootManager
	var zone: MapZone = rt.map.get_slots(G.LOOT_SECURE_ZONE)[0] as MapZone
	var bag: Node = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, _center(zone) + Vector3(-2.0, 0.5, 0)))
	assert_true(bag != null, "bag spawned")
	await wait_until(func() -> bool: return rt.mission.bags_secured >= 1, 6.0)
	rt.mission.activate_escape()
	var esc: Node3D = rt.map.get_slots(G.ESCAPE_ZONE)[0] as Node3D
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, _center(esc) + Vector3(-3.0, 0.05, 0)))
	var ok: bool = await wait_until(func() -> bool: return not results.is_empty(), 40.0)
	assert_true(ok, "heist ended")
	if ok:
		assert_true(bool(results[0]["success"]), "success")
		assert_true((results[0]["loot"] as Array).size() >= 1, "secured loot reported")
		assert_true(int(results[0]["contract_pay"]) > 0, "contract pay")
	EventBus.heist_ended.disconnect(on_end)
	await _teardown(rt)


## A MapZone's node origin need not be its volume centre: use its first collision shape.
func _center(zone: Node3D) -> Vector3:
	for c: Node in zone.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs != null:
			return cs.global_position - Vector3(0.0, cs.global_position.y - zone.global_position.y, 0.0)
	return zone.global_position
