## P1 GATE (part B): roadmap steps 3, 5, 6, 7, 10, 11 end-to-end on the real Glasshouse map.
## Owner: LEAD. Spec: docs/roadmap.md "P1 gate". Part A (steps 1, 2, 4, 8, 9) is
## test_p1_vertical_slice.gd. The bot acts only through contracts/test_hooks.md (HeistLauncher,
## HeistRuntime hooks, CrewIntent held through set_bot_intent) and facts are observed on EventBus.
## Setup shortcuts outside the step under test: step 10 raises the alarm with
## StealthDirector.raise_alarm and downs the bot with a lethal CrewController.take_hit; step 6 marks
## the bot stealth_hidden after it leaves the body (back at the van, D-014) so only the bag is
## watched. ENV A classes are referenced statically: a missing mechanic is a parse error (LOAD FAIL)
## or an assertion failure, never a skip.
##   test_03_sprint_jump_behind_guard_no_noise   step 3  (seed 1001)
##   test_05_pager_released_early_alarm          step 5  (seed 1003)
##   test_06_body_bag_hidden_never_discovered    step 6  (seed 1001, 60 s of patrols at x4)
##   test_07_display_case_and_secure_bag         step 7  (seed 1002, extra_loot = xl_delivery)
##   test_10_ai_teammate_revives_bot             step 10 (seed 1001, loud)
##   test_11_escape_success_and_payout           step 11 (seed 1002 on TENSE, payout x2.0)
## Teleports stand in for walking (the bot carries what it holds); witnesses are despawned with
## isolate_npc() where the step does not test detection (QA-9, D-032), never in step 6 (patrols).
extends TestCase

const HEIST: StringName = &"glasshouse"
const SEED_A: int = 1001
const SEED_PAGER: int = 1003
const SEED_LOOT: int = 1002
const RISE_FRAMES: int = 3

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _t0: int = 0


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_t0 = Time.get_ticks_msec()


func after_each() -> void:
	Engine.time_scale = 1.0
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	await _teardown()


# --- Harness ------------------------------------------------------------------------------------

func _launch(seed_value: int, difficulty: Enums.Difficulty = Enums.Difficulty.ROUTINE) -> bool:
	_rt = await HeistLauncher.launch(HEIST, seed_value, difficulty, self, {"ai_teammates": 3})
	if _rt == null:
		fail("HeistLauncher.launch(%s, %d) returned null" % [HEIST, seed_value])
		return false
	var crew: Node3D = _rt.crew_controller(0) as Node3D
	var nav_ok: bool = await wait_until(func() -> bool: return BotUtil.nav_ready(crew), 10.0)
	assert_true(nav_ok, "navigation map ready")
	await wait_physics_frames(2)
	_listen_all([&"alarm_raised", &"heist_ended"])
	return nav_ok


## Tear the heist down (rt.teardown()) and report the test's wall-clock runtime.
func _teardown() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
		print("[P1-B] %s: %.1f s" % [_current, float(Time.get_ticks_msec() - _t0) / 1000.0])
	_rt = null
	await wait_frames(2)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
		_events.append([tag, a, b, c])
	sig.connect(cb)
	_conns.append([sig, cb])


func _listen_all(tags: Array[StringName]) -> void:
	for tag: StringName in tags:
		_listen(Signal(EventBus, tag), tag)


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _guards() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for n: Node in _rt.npcs(&"guard"):
		out.append(n as NpcBase)
	return out


## Hold the mask-up key until the bot is masked (S1.2).
func _mask_up() -> bool:
	var i: CrewIntent = CrewIntent.new()
	i.mask_up = true
	i.look_yaw = _crew().look_yaw
	_rt.set_bot_intent(0, i)
	var ok: bool = await wait_until(func() -> bool: return _crew().masked, 5.0)
	_rt.set_bot_intent(0, _still())
	assert_true(ok, "bot masks up")
	return ok


## Idle intent that keeps the current view (clear_bot_intent would snap the view to yaw 0).
func _still() -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = _crew().look_yaw
	i.look_pitch = _crew().look_pitch
	return i


## Hold interact on `target_net_id` (explicit target, crew_intent.md) until `done` or `timeout_s`,
## then release for a few frames (interactions need a release between completions).
func _interact(target_net_id: int, look_to: Vector3, done: Callable, timeout_s: float) -> bool:
	var i: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), look_to)
	i.interact = true
	i.interact_target_net_id = target_net_id
	_rt.set_bot_intent(0, i)
	var ok: bool = await wait_until(done, timeout_s)
	_rt.set_bot_intent(0, _still())
	await wait_physics_frames(RISE_FRAMES)
	return ok


## One rising edge of a CrewIntent button (drop_bag / throw_bag / fire), then idle.
func _press(i: CrewIntent) -> void:
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(RISE_FRAMES)
	_rt.set_bot_intent(0, _still())


## Teleport the bot onto the navmesh next to a gameplay prefab's UsePoint, facing it.
func _go_to_prefab(prefab: GameplayPrefab) -> bool:
	var at: Vector3 = prefab.use_point.global_position if prefab.use_point != null else prefab.global_position
	var p: Variant = BotUtil.nav_point_near(prefab, at, 1.2)
	if p == null:
		fail("no navmesh point near %s" % prefab.name)
		return false
	var stand: Vector3 = p
	_rt.teleport_crew(0, BotUtil.facing(stand, prefab.global_position))
	await wait_physics_frames(2)
	return true


## Shoot `guard` in the head from ~3 m behind with the default suppressed pistol (as in step 4).
func _kill_from_behind(guard: NpcBase) -> bool:
	var shot_v: Variant = BotUtil.find_clear_point(guard, 3.0, true, 1.65, true)
	if shot_v == null:
		fail("no clear firing point behind %s" % guard.name)
		return false
	_rt.teleport_crew(0, shot_v)
	await wait_physics_frames(2)
	var aim: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), guard.head_position())
	aim.fire = true
	await _press(aim)
	var dead: bool = await wait_until(func() -> bool: return not guard.alive, 1.0)
	assert_true(dead, "%s killed by a suppressed headshot" % guard.name)
	return dead


## Step 4 sub-flow: wait for the dead guard's pager, answer it for the full hold.
func _answer_pager(guard: NpcBase) -> bool:
	var started: bool = await wait_until(func() -> bool: return not _of(&"pager_started").is_empty(), 5.0)
	assert_true(started, "pager_started after the kill")
	if not started:
		return false
	var ans_v: Variant = BotUtil.find_clear_point(guard, 1.0, true)
	if ans_v != null:
		_rt.teleport_crew(0, ans_v)
		await wait_physics_frames(2)
	var answered: bool = await _interact(guard.net_id, guard.global_position,
		func() -> bool: return not _of(&"pager_answered").is_empty(), Tweak.stealth().pager_answer_s + 4.0)
	assert_true(answered, "pager answered")
	return answered


## A spot from which a bag dropped forward (LootTweak.drop_forward_m) lands inside `zone`, with no
## world geometry between the bot and the drop point. Returns [stand Vector3, look Vector3] or [].
func _drop_spot(zone: Area3D) -> Array:
	var tw: LootTweak = LootTweak.get_default()
	var center: Vector3 = BotUtil.zone_center(zone)
	var space: PhysicsDirectSpaceState3D = zone.get_world_3d().direct_space_state
	for d: float in [0.3, 0.6, 0.9, 1.2, 1.6, 2.0, 2.5]:
		for deg: int in range(0, 360, 30):
			var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg)))
			var p: Variant = BotUtil.nav_point_near(zone, center - dir * d, 0.3)
			if p == null:
				continue
			var stand: Vector3 = p
			var drop: Vector3 = stand + dir * tw.drop_forward_m + Vector3.UP * tw.drop_height_m
			if not ZoneUtil.contains(zone, drop + Vector3.UP * tw.zone_probe_up_m):
				continue
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(stand + Vector3.UP * 0.6, drop, 1 | 2)
			if not space.intersect_ray(q).is_empty():
				continue
			return [stand, stand + dir]
	return []


## Carry the bag the bot holds into `zone`: teleport to a drop spot and drop it.
func _drop_into(zone: Area3D) -> bool:
	var spot: Array = _drop_spot(zone)
	if spot.is_empty():
		fail("no spot to drop a bag into %s" % zone.get_path())
		return false
	_rt.teleport_crew(0, BotUtil.facing(spot[0], spot[1]))
	await wait_physics_frames(2)
	var d: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), spot[1] + Vector3.UP * 0.3)
	d.drop_bag = true
	await _press(d)
	assert_false(_crew().is_carrying_bag(), "bag dropped")
	return not _crew().is_carrying_bag()


func _secure_zone() -> Area3D:
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		if _rt.is_ancestor_of(n):
			return n as Area3D
	return null


## Bag one loot bag from `spawn` (LootSpawn) and secure it at the van. Returns the secured value.
func _bag_and_secure(spawn: LootSpawn, zone: Area3D) -> int:
	if not await _go_to_prefab(spawn):
		return -1
	var picked: bool = await _interact(spawn.net_id, spawn.global_position,
		func() -> bool: return _crew().is_carrying_bag(), Tweak.interaction().bag_loot_s + 2.0)
	assert_true(picked, "bag taken from %s" % spawn.name)
	if not picked:
		return -1
	var bag: LootBag = _crew().carried_bag as LootBag
	var bag_id: int = bag.net_id
	var n_before: int = _of(&"loot_secured").size()
	if not await _drop_into(zone):
		return -1
	var ok: bool = await wait_until(func() -> bool: return _of(&"loot_secured").size() > n_before, 5.0)
	assert_true(ok, "bag secured in the van's SECURE_LOOT zone")
	if not ok:
		return -1
	var e: Array = _of(&"loot_secured")[n_before]
	assert_eq(int(e[1]), bag_id, "loot_secured bag id")
	assert_eq(e[2], spawn.loot_id, "loot_secured loot id")
	assert_eq(int(e[3]), int(LootManager.loot_info(spawn.loot_id)["value"]), "loot_secured value (ContentDB)")
	return int(e[3])


func _delivery_spawn() -> LootSpawn:
	var tagged: Array[Node] = _rt.find_by_tag(&"delivery_loot")
	if tagged.is_empty():
		fail("seed %d: variant extra_loot != xl_delivery (variants %s)" % [_rt.run_seed, _rt.variants])
		return null
	return tagged[0] as LootSpawn


# --- Step 3 -------------------------------------------------------------------------------------

## 3. Masked, sprinting and jumping 1 m behind a guard (outside his 120 deg FOV): the meter stays at
## exactly 0, no NoiseEvent is ever made by movement (S1.5) and the guard stays CALM.
func test_03_sprint_jump_behind_guard_no_noise() -> void:
	if not await _launch(SEED_A):
		return
	var noises: Array[Array] = []
	var on_noise: Callable = func(pos: Vector3, r: float, kind: StringName, src: int) -> void:
		noises.append([pos, r, kind, src])
	_rt.noise_made.connect(on_noise)
	_conns.append([_rt.noise_made, on_noise])
	_listen(EventBus.npc_alert_state_changed, &"alert")
	var guards: Array[NpcBase] = _guards()
	assert_true(not guards.is_empty(), "a guard")
	if guards.is_empty():
		return
	var guard: NpcBase = guards[0]
	_rt.isolate_npc(guard)  # QA-9: nobody else may see the masked bot
	await wait_physics_frames(2)
	if not await _mask_up():
		return
	var motor: NpcMotor = guard.get_node(^"Motor") as NpcMotor
	# Wait for a patrol pause (every Glasshouse PatrolPoint pauses >= 2 s): guard arrived and settled.
	var fwd0: Array[Vector3] = [guard.look_forward()]
	var settled: Callable = func() -> bool:
		var f: Vector3 = guard.look_forward()
		var still: bool = motor.arrived and f.angle_to(fwd0[0]) < 0.01 and guard.velocity.length() < 0.05
		fwd0[0] = f
		return still
	assert_true(await wait_until(settled, 40.0), "guard reaches a patrol pause")
	var half_fov: float = deg_to_rad(float((Tweak.stealth().observer_presets[&"guard"] as Dictionary)["fov_deg"]) * 0.5)
	var crew: CrewController = _crew()
	var frames: int = 0
	var sprint_frames: int = 0
	var air_frames: int = 0
	var max_det: float = 0.0
	var cycle: int = -1
	while frames < 120:
		if floori(frames / 30.0) != cycle:  # every 0.5 s: back to 2.5 m straight behind, facing away
			cycle = floori(frames / 30.0)
			var back: Vector3 = -guard.look_forward()
			# LEAD (D-128): PD2 NPCs see all round inside npc_all_round_m (1.5 m), so stand outside it.
			var behind_m: float = Tweak.stealth().npc_all_round_m + 1.0
			var p: Variant = BotUtil.nav_point_near(guard, guard.global_position + back * behind_m, 0.35)
			if p == null:
				break
			var stand: Vector3 = p
			_rt.teleport_crew(0, BotUtil.facing(stand, stand + back))
			var run: CrewIntent = BotUtil.look_at_intent(crew.eye_position(), crew.eye_position() + back)
			run.move = Vector2(0.0, 1.0)
			run.sprint = true
			run.jump = true
			_rt.set_bot_intent(0, run)
		await get_tree().physics_frame
		var to_bot: Vector3 = crew.global_position - guard.global_position
		var f2: Vector2 = Vector2(guard.look_forward().x, guard.look_forward().z)
		if not motor.arrived or absf(f2.angle_to(Vector2(to_bot.x, to_bot.z))) <= half_fov:
			break  # the guard walks on / turns: the precondition "outside his FOV" no longer holds
		max_det = maxf(max_det, _rt.detection_value(guard, 0))
		sprint_frames += 1 if crew.sprinting else 0
		air_frames += 0 if crew.is_on_floor() else 1
		frames += 1
	_rt.set_bot_intent(0, _still())
	_rt.teleport_crew(0, (_rt.map.get_slots(G.PLAYER_SPAWN)[0] as Node3D).global_transform)  # leave his path
	print("[P1-B] step 3: %d frames behind the guard, %d sprinting, %d airborne" % [frames, sprint_frames, air_frames])
	assert_true(frames >= 45, "at least 0.75 s behind the paused guard (got %d frames)" % frames)
	assert_true(sprint_frames > 10, "bot sprinted")
	assert_true(air_frames > 5, "bot jumped")
	assert_eq(max_det, 0.0, "detection stays exactly 0 behind the guard")
	await wait_seconds(1.0)
	var own: Array[Array] = []
	for nz: Array in noises:
		if int(nz[3]) == crew.net_id or (nz[0] as Vector3).distance_to(guard.global_position) < 6.0:
			own.append(nz)
	assert_eq(own, [] as Array[Array], "movement makes no noise (S1.5)")
	for e: Array in _of(&"alert"):
		assert_ne(int(e[1]), guard.net_id, "guard alert state changed to %s" % [e[3]])
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm")


# --- Step 5 -------------------------------------------------------------------------------------

## 5. Kill a guard, start answering his pager, release early with nobody else answering:
## pager_failed(released) -> alarm_raised(pager_failed) -> LOUD.
func test_05_pager_released_early_alarm() -> void:
	if not await _launch(SEED_PAGER):
		return
	_listen_all([&"pager_started", &"pager_answer_started", &"pager_answered", &"pager_failed"])
	var guards: Array[NpcBase] = _guards()
	assert_true(not guards.is_empty(), "a guard")
	if guards.is_empty():
		return
	var guard: NpcBase = guards[0]
	_rt.isolate_npc(guard)
	await wait_physics_frames(2)
	if not await _mask_up():
		return
	if not await _kill_from_behind(guard):
		return
	var started: bool = await wait_until(func() -> bool: return not _of(&"pager_started").is_empty(), 5.0)
	assert_true(started, "pager_started")
	if not started:
		return
	var pid: int = int(_of(&"pager_started")[0][1])
	var ans_v: Variant = BotUtil.find_clear_point(guard, 1.0, true)
	if ans_v != null:
		_rt.teleport_crew(0, ans_v)
		await wait_physics_frames(2)
	var i: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), guard.global_position)
	i.interact = true
	i.interact_target_net_id = guard.net_id
	_rt.set_bot_intent(0, i)
	var holding: bool = await wait_until(func() -> bool: return not _of(&"pager_answer_started").is_empty(), 2.0)
	assert_true(holding, "bot starts answering")
	await wait_seconds(2.0)  # well short of pager_answer_s
	assert_true(_of(&"pager_failed").is_empty() and _of(&"alarm_raised").is_empty(), "still answering: no alarm yet")
	_rt.set_bot_intent(0, _still())  # release early
	var alarm: bool = await wait_until(func() -> bool: return not _of(&"alarm_raised").is_empty(), 2.0)
	assert_true(alarm, "releasing the pager raises the alarm")
	assert_eq(_of(&"pager_failed").size(), 1, "one pager_failed")
	if not _of(&"pager_failed").is_empty():
		assert_eq(int(_of(&"pager_failed")[0][1]), pid, "pager id")
		assert_eq(_of(&"pager_failed")[0][2], &"released", "S5.4 reason: released")
	if alarm:
		assert_eq(_of(&"alarm_raised")[0][1], &"pager_failed", "alarm reason")
	for e: Array in _of(&"pager_answer_started"):
		assert_eq(int(e[2]), 0, "only the bot ever answered (AI teammates wait in the van)")
	assert_true(_of(&"pager_answered").is_empty(), "never answered")
	await wait_physics_frames(2)
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD, "heist went LOUD")


# --- Step 6 -------------------------------------------------------------------------------------

## 6. Kill the guard farthest from any civilian (unwitnessed), answer his pager, bag the body,
## carry the bag to a map BODY_HIDE zone and drop it there: hidden, and not discovered over 60 s of
## the other NPCs' patrols (Engine.time_scale x4). No NPC is despawned in this step.
func test_06_body_bag_hidden_never_discovered() -> void:
	if not await _launch(SEED_A):
		return
	_listen_all([&"pager_started", &"pager_answered", &"body_bagged", &"body_discovered", &"loot_picked"])
	var noticed: Array[int] = []
	var on_notice: Callable = func(_o: Node, sid: int) -> void: noticed.append(sid)
	_rt.stealth.stimulus_noticed.connect(on_notice)
	_conns.append([_rt.stealth.stimulus_noticed, on_notice])
	var victim: NpcBase = _loneliest_guard()
	if victim == null:
		fail("need >= 2 guards (one victim, one patrolling)")
		return
	var bag: LootBag = await _hide_body_of(victim)
	if bag == null:
		return
	# The bot goes back to the van (a stealth-hidden crew member, D-014): only the bag stays.
	_rt.teleport_crew(0, (_rt.map.get_slots(G.PLAYER_SPAWN)[0] as Node3D).global_transform)
	_crew().stealth_hidden = true
	var patrol: Array[Dictionary] = []
	for n: Node in _rt.npcs():
		patrol.append({"npc": n, "last": (n as Node3D).global_position, "moved": 0.0})
	var min_d: Array[float] = [INF]
	var still_hidden: Array[bool] = [true]
	var watch: Callable = func() -> bool:
		for p: Dictionary in patrol:
			var npc: Node3D = p["npc"] as Node3D
			if is_instance_valid(npc):
				p["moved"] = float(p["moved"]) + npc.global_position.distance_to(p["last"])
				p["last"] = npc.global_position
				if (npc as NpcBase).role == &"guard":
					min_d[0] = minf(min_d[0], npc.global_position.distance_to(bag.global_position))
		still_hidden[0] = still_hidden[0] and is_instance_valid(bag) and bag.hidden_from_stealth
		return false
	Engine.time_scale = 4.0
	var watched: bool = await wait_until(watch, 60.0)
	Engine.time_scale = 1.0
	var guard_moved: float = 0.0
	for p: Dictionary in patrol:
		if is_instance_valid(p["npc"]) and (p["npc"] as NpcBase).role == &"guard":
			guard_moved += float(p["moved"])
	print("[P1-B] step 6: guards patrolled %.1f m, closest guard to the bag %.1f m" % [guard_moved, min_d[0]])
	assert_false(watched, "watched the full 60 s")
	assert_true(guard_moved > 10.0, "the remaining guard(s) patrolled during the 60 s (%.1f m)" % guard_moved)
	assert_true(still_hidden[0], "bag stayed hidden for 60 s")
	assert_true(_of(&"body_discovered").is_empty(), "body never discovered")
	assert_false(noticed.has(bag.stimulus_id()), "hidden body bag never noticed")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm in 60 s")


## Step 6 setup: mask, kill `victim`, answer his pager, bag the body, pick the bag up, carry it to a
## map BODY_HIDE zone and drop it there. Returns the hidden body bag (null after a failed assert).
func _hide_body_of(victim: NpcBase) -> LootBag:
	if not await _mask_up():
		return null
	if not await _kill_from_behind(victim):
		return null
	if not await _answer_pager(victim):
		return null
	var crew: CrewController = _crew()
	assert_true(crew.body_bags >= 1, "crew carries a body bag")
	var bagged: bool = await _interact(victim.net_id, victim.global_position,
		func() -> bool: return not _of(&"body_bagged").is_empty(), Tweak.interaction().body_bag_s + 2.0)
	var bag: LootBag = Ids.lookup(int(_of(&"body_bagged")[0][2])) as LootBag if bagged else null
	assert_true(bag != null and bag.is_body_bag(), "body bagged (S6.2): a body bag spawned")
	if bag == null:
		return null
	var picked: bool = await _interact(bag.net_id, bag.global_position,
		func() -> bool: return crew.carried_bag == bag, Tweak.interaction().bag_loot_s + 2.0)
	assert_true(picked, "bot picks up the body bag")
	var zone: Area3D = _map_body_hide_zone()
	assert_true(zone != null, "map has a BODY_HIDE MapZone")
	if not picked or zone == null or not await _drop_into(zone):
		return null
	var hidden: bool = await wait_until(func() -> bool: return bag.hidden_from_stealth, 3.0)
	assert_true(hidden, "body bag in %s is hidden (S6.3)" % zone.name)
	return bag if hidden else null


## The guard with the largest distance to the nearest civilian (unwitnessed kill), if >= 2 guards.
func _loneliest_guard() -> NpcBase:
	var guards: Array[NpcBase] = _guards()
	if guards.size() < 2:
		return null
	var best: NpcBase = null
	var best_d: float = -1.0
	for g: NpcBase in guards:
		var nearest: float = INF
		for c: Node in _rt.npcs(&"civilian"):
			nearest = minf(nearest, g.global_position.distance_to((c as Node3D).global_position))
		if nearest > best_d:
			best = g
			best_d = nearest
	return best


## A map-level BODY_HIDE MapZone (not a body_container's), else any BODY_HIDE zone.
func _map_body_hide_zone() -> Area3D:
	var any: Area3D = null
	for n: Node in get_tree().get_nodes_in_group(G.BODY_HIDE_ZONE):
		if not _rt.is_ancestor_of(n):
			continue
		if not n.get_parent().has_method(&"store_bag"):
			return n as Area3D
		any = n as Area3D if any == null else any
	return any


# --- Step 7 -------------------------------------------------------------------------------------

## 7. Break a display case -> take the small loot (small_loot_taken = the case's value); bag one
## loot bag and secure it at the van (loot_secured).
func test_07_display_case_and_secure_bag() -> void:
	if not await _launch(SEED_LOOT):
		return
	_listen_all([&"glass_broken", &"small_loot_taken", &"loot_secured"])
	_rt.isolate_npc(null)  # QA-9: this step tests loot, not detection (breaking glass is a stimulus)
	await wait_physics_frames(2)
	if not await _mask_up():
		return
	var cases: Array[Node] = _rt.map.find_children("*", "DisplayCase", true, false)
	assert_true(not cases.is_empty(), "map has display cases")
	if cases.is_empty():
		return
	var dc: DisplayCase = cases[0] as DisplayCase
	if not await _go_to_prefab(dc):
		return
	var broke: bool = await _interact(dc.net_id, dc.global_position + Vector3.UP,
		func() -> bool: return dc.glass_broken, 2.0)
	assert_true(broke, "glass broken (S9.9)")
	assert_eq(_of(&"glass_broken").size(), 1, "glass_broken fact")
	var took: bool = await _interact(dc.net_id, dc.global_position + Vector3.UP,
		func() -> bool: return not _of(&"small_loot_taken").is_empty(), Tweak.interaction().small_loot_s + 2.0)
	assert_true(took, "small loot taken (S10.3)")
	if took:
		var e: Array = _of(&"small_loot_taken")[0]
		assert_eq(int(e[1]), dc.loot_value(), "small_loot_taken value = case value")
		assert_true(int(e[1]) > 0, "small loot is worth something")
		assert_eq(int(e[2]), 0, "taken by the bot")
	var spawn: LootSpawn = _delivery_spawn()
	var zone: Area3D = _secure_zone()
	assert_true(zone != null, "van SECURE_LOOT zone")
	if spawn == null or zone == null:
		return
	var value: int = await _bag_and_secure(spawn, zone)
	assert_true(value > 0, "1 bag secured at the van")
	assert_eq(_rt.mission.bags_secured, 1, "mission counts 1 secured bag")
	assert_true(_of(&"alarm_raised").is_empty(), "still stealth")


# --- Step 10 ------------------------------------------------------------------------------------

## 10. Loud: the bot takes a lethal hit and goes down; an AI teammate walks over and revives it
## (full revive hold) before the bleedout timer runs out.
func test_10_ai_teammate_revives_bot() -> void:
	if not await _launch(SEED_A):
		return
	_listen_all([&"crew_downed", &"crew_revived", &"crew_custody", &"interaction_started"])
	_rt.isolate_npc(null)  # nobody shoots the downed bot or its rescuer
	_rt.stealth.raise_alarm(&"p1_gate_step10")
	assert_true(await wait_until(func() -> bool: return _rt.phase == Enums.HeistPhase.LOUD, 2.0), "LOUD")
	# Down the bot on the sales floor, away from the AI teammates (they start at the van).
	var cases: Array[Node] = _rt.map.find_children("*", "DisplayCase", true, false)
	if not cases.is_empty():
		await _go_to_prefab(cases[0] as DisplayCase)
	await wait_physics_frames(3)
	var crew: CrewController = _crew()
	var hit: Dictionary = Damage.info(crew.health.health + 1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY,
		&"test.p1_gate", crew.global_position, Vector3.FORWARD)
	hit["pierced_armor"] = true
	crew.take_hit(hit, 0)
	var nearest_ai: float = INF
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			nearest_ai = minf(nearest_ai, c.global_position.distance_to(crew.global_position))
	assert_true(nearest_ai > 3.0, "the AI teammates must walk over (nearest %.1f m)" % nearest_ai)
	assert_eq(crew.crew_state, Enums.CrewState.DOWNED, "bot DOWNED by a lethal hit (L2.5)")
	assert_eq(_of(&"crew_downed").size(), 1, "crew_downed")
	Engine.time_scale = 2.0
	var t_down: float = _rt.heist_time_s
	var bleed: float = crew.health.bleedout_left
	var ok: bool = await wait_until(func() -> bool: return not _of(&"crew_revived").is_empty(), bleed + 2.0)
	var t_rev: float = _rt.heist_time_s
	Engine.time_scale = 1.0
	assert_true(ok, "an AI teammate revived the bot")
	if not ok:
		return
	var by: int = int(_of(&"crew_revived")[0][2])
	assert_eq(int(_of(&"crew_revived")[0][1]), 0, "slot 0 revived")
	assert_true(_crew(by) != null and _crew(by).is_ai, "reviver slot %d is an AI teammate" % by)
	assert_true(t_rev - t_down < bleed, "revived within the bleedout time (%.1f of %.1f s)" % [t_rev - t_down, bleed])
	assert_true(t_rev - t_down >= Tweak.crew().revive_time_s - 0.1, "full revive hold (%.1f s)" % (t_rev - t_down))
	assert_true(_of(&"crew_custody").is_empty(), "no custody")
	assert_eq(crew.crew_state, Enums.CrewState.NORMAL, "bot back on its feet")
	var held: bool = false
	for e: Array in _of(&"interaction_started"):
		held = held or (int(e[2]) == by and e[3] == &"revive")
	assert_true(held, "the AI held the revive interaction")
	print("[P1-B] step 10: AI %.1f m away, revived by slot %d after %.1f s (bleedout %.1f s)" % [
		nearest_ai, by, t_rev - t_down, bleed])


# --- Step 11 ------------------------------------------------------------------------------------

## 11. Secure the bags the mission asks for, reach the van's escape zone -> heist_ended(success);
## PayoutCalculator gives contract + loot, each x the difficulty's payout_mult (TENSE: 2.0).
func test_11_escape_success_and_payout() -> void:
	if not await _launch(SEED_LOOT, Enums.Difficulty.TENSE):
		return
	_listen_all([&"loot_secured"])
	_rt.isolate_npc(null)  # QA-9: this step tests loot/escape, not detection
	await wait_physics_frames(2)
	var secured: int = await _secure_until_escape()
	if secured <= 0:
		return
	var escape: EscapeZone = _rt.find_by_tag(&"escape_van")[0] as EscapeZone
	var inside: Variant = BotUtil.nav_point_in_zone(escape.zone)
	if inside == null:
		fail("no navmesh point inside the escape zone")
		return
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, inside as Vector3))
	var ended: bool = await wait_until(func() -> bool: return not _of(&"heist_ended").is_empty(), 3.0)
	assert_true(ended, "heist_ended")
	if not ended:
		return
	var r: Dictionary = _of(&"heist_ended")[0][1]
	assert_true(bool(r["success"]), "heist_ended(success)")
	assert_true(bool(r["stealth"]), "stealth success")
	assert_eq((r["loot"] as Array).size(), secured, "HeistResult lists the secured bags")
	assert_eq(int(r["contract_pay"]), _rt.map.heist_def.base_payout, "contract_pay = HeistDef.base_payout")
	_check_payout(r, ContentDB.difficulty(Enums.Difficulty.TENSE))


## Step 11 setup: mask up, then bag and secure loot until the mission opens the escape van.
## Returns the number of bags secured (0 after a failed assert).
func _secure_until_escape() -> int:
	if not await _mask_up():
		return 0
	var spawn: LootSpawn = _delivery_spawn()
	var zone: Area3D = _secure_zone()
	var tagged: Array[Node] = _rt.find_by_tag(&"escape_van")
	var escape: EscapeZone = tagged[0] as EscapeZone if not tagged.is_empty() else null
	assert_true(zone != null, "van SECURE_LOOT zone")
	assert_true(escape != null, "escape zone tagged escape_van")
	if spawn == null or zone == null or escape == null:
		return 0
	var secured: int = 0
	while not escape.active and secured < spawn.count:
		if await _bag_and_secure(spawn, zone) <= 0:
			return 0
		secured += 1
	var open: bool = await wait_until(func() -> bool: return escape.has_arrived(), 2.0)
	assert_true(open, "mission activates the escape van after %d secured bags" % secured)
	return secured if open else 0


## PayoutCalculator (ENV B): contract + loot, each x the difficulty's payout_mult.
func _check_payout(r: Dictionary, diff: DifficultyDef) -> void:
	assert_true(diff != null and diff.payout_mult > 1.0, "difficulty has a payout multiplier > 1")
	if diff == null:
		return
	var out: Dictionary = PayoutCalculator.compute(r)
	var want_contract: int = roundi(float(int(r["contract_pay"])) * diff.payout_mult)
	var want_loot: int = 0
	for entry: Dictionary in r["loot"] as Array:
		want_loot += roundi(float(entry["value"]) * diff.payout_mult)
	assert_eq(int(out["contract"]), want_contract, "contract x payout_mult")
	assert_eq(int(out["loot"]), want_loot, "loot x payout_mult")
	assert_true(int(out["loot"]) > 0, "loot pays")
	assert_eq(int(out["subtotal"]), want_contract + want_loot + int(out["small_loot"]), "subtotal = contract + loot")
	print("[P1-B] step 11: %d bags, contract %d, loot %d, total %d" % [
		(r["loot"] as Array).size(), out["contract"], out["loot"], out["total"]])
