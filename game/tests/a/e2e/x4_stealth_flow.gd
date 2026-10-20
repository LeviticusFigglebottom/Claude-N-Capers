## X-4 (docs/process/heist_completion.md): stealth end-to-end flows for Nightfall Depository (night_deposit), Shadow
## Ledger (shadow_ledger), Gallery Night (gallery_night) and Ostrander Federal (ostrander_federal; its loud line too,
## x4_of_loud.gd). Owner: ENV A (test support).
## One bot crew member (slot 0, no AI teammates) wins the heist without the alarm: it masks up, then takes the
## heist's stealth objectives in order through the real InteractionSystem (CrewIntent held through
## HeistRuntime.set_bot_intent, interact + interact_target_net_id, as the P1 gate bot), carries every bag on its
## back to the rolled escape's SecureZone and drops it there (drop_bag), and stands in the EscapeZone.
## Harness shortcuts (stated, so the run fits the headless budget):
##   * travel is a teleport onto the navmesh next to the next UsePoint (HeistRuntime.teleport_crew, as the P1
##     gate); a teleport into or out of the room behind a laser grid waits for the grid's off window (timed lasers);
##   * detection is kept out of the way with `CrewController.stealth_hidden` (the D-014 "hidden crew" flag the
##     crew AI uses): guards, civilians and cameras stay alive and keep their routes, they just never see the bot.
##     Nothing else is touched: no NPC is removed, no camera is turned, no alarm group is switched off by the
##     test, and every lock, laser, sensor and timer is the mission's own;
##   * long waits (time lock, hack, heli approach, laser off window) run at Engine.time_scale FAST.
## The per-heist routes are x4_stealth_routes.gd (X4StealthRoutes.play). Used by test_x4_<heist>_stealth.gd (headless
## asserts) and x4_stealth_capture.gd (windowed end-of-heist PNG).
class_name X4StealthFlow
extends RefCounted

const FAST: float = 4.0
const RISE_FRAMES: int = 3
const MARGIN_S: float = 2.0
## A laser crossing waits for at least this much of the off window to be left (heist seconds).
const LASER_OFF_LEFT_S: float = 1.0
## A sweeping grid is crossed when no beam is closer than this to the crossing (crew capsule radius 0.35 m + margin).
const SWEEP_CLEAR_M: float = 0.8

var host: Node = null
var rt: HeistRuntime = null
var crew: CrewController = null
var heist: StringName = &""
var failures: Array[String] = []
var alarms: Array[StringName] = []
var lasers_tripped: int = 0
var pagers: int = 0
var ended: Array[Dictionary] = []
## Objectives completed when heist_ended arrived (events.md v1.7: escape completes before it).
var completed_at_end: Array[StringName] = []
## Objective ids in the order they completed.
var completed: Array[StringName] = []
var secured_loot: Array[StringName] = []
var laser_waits: int = 0
## AI teammates launched with the bot (0: the stealth routes go solo; the OF loud flow takes the PD2 bots, L6.1).
var ai_teammates: int = 0
## Route facts a test asserts on (e.g. the GN curator card branch: &"curator_card_*").
var facts: Dictionary = {}
## Laser grids the route crosses (guard_lasers) and the sign of their guarded side (local z).
var guarded: Array[LaserGrid] = []
var _inner_side: Dictionary = {}
## Optional guarded-room tests per grid (guard_lasers `region`).
var _region: Dictionary = {}
## The current move crouches under a static grid (stand up after it).
var _crouch_through: bool = false
var _conns: Array[Array] = []


func _init(p_host: Node) -> void:
	host = p_host


func note(msg: String) -> void:
	var t: float = rt.heist_time_s if rt != null and is_instance_valid(rt) else 0.0
	print("[X4] %s %6.1f s  %s" % [heist, t, msg])


func check(ok: bool, msg: String) -> bool:
	if not ok:
		failures.append(msg)
		note("FAIL " + msg)
	return ok


# --- Launch / teardown ---------------------------------------------------------------------------

## `options` are extra HeistLauncher options (e.g. "preplan" force_variants, "variant_table"); `ai_teammates` AI crew.
func launch(heist_id: StringName, seed_value: int, options: Dictionary = {}) -> bool:
	heist = heist_id
	Engine.time_scale = 1.0
	var opts: Dictionary = options.duplicate()
	opts["ai_teammates"] = ai_teammates
	rt = await HeistLauncher.launch(heist_id, seed_value, Enums.Difficulty.ROUTINE, host, opts)
	if not check(rt != null, "HeistLauncher.launch(%s, %d)" % [heist_id, seed_value]):
		return false
	crew = rt.crew_controller(0) as CrewController
	var nav_ok: bool = await wait_until(func() -> bool: return BotUtil.nav_ready(crew), 10.0)
	if not check(nav_ok, "navigation map ready"):
		return false
	_listen(EventBus.alarm_raised, func(reason: StringName, src: int) -> void:
		alarms.append(reason)
		note("ALARM %s%s" % [reason, _alarm_source(src)]))
	_listen(EventBus.laser_tripped, func(_id: int) -> void: lasers_tripped += 1)
	_listen(EventBus.pager_started, func(_p: int, _g: int) -> void: pagers += 1)
	_listen(EventBus.heist_ended, func(r: Dictionary) -> void:
		completed_at_end = completed.duplicate()
		ended.append(r))
	_listen(EventBus.loot_secured, func(_b: int, loot_id: StringName, _v: int) -> void:
		secured_loot.append(loot_id)
		note("secured %s (%d)" % [loot_id, secured_loot.size()]))
	_listen(EventBus.objective_updated, func(id: StringName, state: int, _d: Dictionary) -> void:
		if state == Enums.ObjectiveState.COMPLETED and not completed.has(id):
			completed.append(id)
			note("objective %s COMPLETED" % id))
	note("launched seed %d, variants %s" % [seed_value, rt.variants])
	await _physics_frames(2)
	return true


## Who raised an alarm and why (a guard's alarm_cause), for the run log.
func _alarm_source(src: int) -> String:
	var n: Node = Ids.lookup(src) if src != 0 else null
	if n == null:
		return ""
	var brain: Node = n.get_node_or_null(^"Brain")
	var cause: Variant = brain.get(&"alarm_cause") if brain != null else null
	return " by %s at %s (cause %s)" % [n.name, (n as Node3D).global_position if n is Node3D else "?", cause]


func teardown() -> void:
	Engine.time_scale = 1.0
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if rt != null and is_instance_valid(rt):
		rt.clear_bot_intent(0)
		rt.teardown()
	rt = null
	await host.get_tree().process_frame


func _listen(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_conns.append([sig, cb])


# --- Timing --------------------------------------------------------------------------------------

func _physics_frames(n: int) -> void:
	for i: int in range(n):
		await host.get_tree().physics_frame


## Heist seconds (scaled physics time).
func wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not cond.call():
		await host.get_tree().physics_frame
		t += host.get_physics_process_delta_time()
		if t >= timeout_s:
			return false
	return true


## wait_until at Engine.time_scale FAST (long mission timers).
func fast_until(cond: Callable, timeout_s: float) -> bool:
	Engine.time_scale = FAST
	var ok: bool = await wait_until(cond, timeout_s)
	Engine.time_scale = 1.0
	return ok


# --- Crew actions (CrewIntent through the InteractionSystem) -------------------------------------

## The stealth detection shortcut (see the header): observers never see the bot.
func hide_from_observers() -> void:
	crew.stealth_hidden = true
	note("detection shortcut: crew.stealth_hidden = true (NPCs, cameras, lasers, sensors untouched)")


## Hold the mask-up key until masked (S1.2/S1.3): casing -> stealth.
func mask_up() -> bool:
	var i: CrewIntent = _still()
	i.mask_up = true
	rt.set_bot_intent(0, i)
	var ok: bool = await wait_until(func() -> bool: return crew.masked, 6.0)
	rt.set_bot_intent(0, _still())
	return check(ok, "bot masks up")


## Idle intent keeping the current view.
func _still() -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = crew.look_yaw
	i.look_pitch = crew.look_pitch
	return i


## Teleport to `at` facing `look`; a move into / out of a room behind a guarded laser grid waits for its off window.
func _move_to(at: Vector3, look: Vector3) -> void:
	_crouch_through = false
	await _wait_lasers(crew.global_position, at)
	rt.teleport_crew(0, BotUtil.facing(at, look))
	await _physics_frames(3)
	if _crouch_through:  # stand up again past the grid
		_crouch_through = false
		rt.set_bot_intent(0, _still())
		await wait_until(func() -> bool: return not crew.crouched, 2.0)


## A navmesh spot next to `prefab`'s UsePoint (or `near` when given), on the side of `toward` when given.
func _stand_spot(prefab: Node3D, near: Variant = null, toward: Variant = null) -> Variant:
	var gp: GameplayPrefab = prefab as GameplayPrefab
	var base: Vector3 = prefab.global_position
	if near is Vector3:
		base = near
	elif gp != null and gp.use_point != null:
		base = gp.use_point.global_position
	var floor_y: float = _floor_y(base)
	var want: Vector3 = Vector3(base.x, floor_y, base.z)
	if toward is Vector3:
		var d: Vector3 = (toward as Vector3) - prefab.global_position
		d.y = 0.0
		want = Vector3(prefab.global_position.x, floor_y, prefab.global_position.z) + d.normalized() * 0.9
	for off: float in [0.4, 0.8, 1.2, 1.6]:
		var p: Variant = BotUtil.nav_point_near(prefab, want, off)
		if p != null:
			return p
	return null


func go_to(prefab: Node3D, near: Variant = null, toward: Variant = null) -> bool:
	var p: Variant = _stand_spot(prefab, near, toward)
	if not check(p != null, "a navmesh spot next to %s" % prefab.name):
		return false
	await _move_to(p as Vector3, prefab.global_position)
	return true


## Hold interact on `target` (explicit net id, crew_intent.md) looking at it until `done` or `timeout_s`, then
## release (interactions need a release between completions). Restarts the hold when a session ends without `done`
## (a jammed hack is restarted the same way).
func use(target: Node3D, done: Callable, timeout_s: float, what: String) -> bool:
	var nid: Variant = target.get(&"net_id")
	if not check(nid != null and int(nid) != 0, "%s has a net id" % what):
		return false
	var look: Vector3 = target.global_position
	var comp: InteractableComponent = target.get_node_or_null(^"Interactable") as InteractableComponent
	if comp != null:
		look = comp.global_position
	var t: float = 0.0
	var ok: bool = false
	var idle_s: float = 0.0
	var had_session: bool = false
	while t < timeout_s:
		var i: CrewIntent = BotUtil.look_at_intent(crew.eye_position(), look)
		i.interact = true
		i.interact_target_net_id = int(nid)
		rt.set_bot_intent(0, i)
		await host.get_tree().physics_frame
		var dt: float = host.get_physics_process_delta_time()
		t += dt
		if done.call():
			ok = true
			break
		if not rt.interaction.session(0).is_empty():
			had_session = true
			idle_s = 0.0
			continue
		idle_s += dt
		var blocked: StringName = rt.interaction.blocked_reason(0)
		if blocked != &"" or had_session or idle_s > 0.5:
			if blocked != &"":
				note("%s blocked: %s" % [what, blocked])
			had_session = false
			idle_s = 0.0
			rt.set_bot_intent(0, _still())  # release, then hold again (a finished hold, a refusal, a jammed hack)
			await _physics_frames(RISE_FRAMES)
	rt.set_bot_intent(0, _still())
	await _physics_frames(RISE_FRAMES)
	note("%s: %s" % [what, "done" if ok else "NOT done"])
	return check(ok, what)


## Walk up to `spawn` and bag one bag from it (it goes on the bot's back).
func _bag_from(spawn: LootSpawn) -> bool:
	if not await go_to(spawn):
		return false
	var before: int = spawn.remaining
	return await use(spawn, func() -> bool: return crew.is_carrying_bag(),
		Tweak.interaction().bag_loot_s + MARGIN_S + maxf(spawn.interactable.interaction_time_s, 0.0),
		"bag %s (%d left)" % [spawn.name, before])


## Carry the bag on the bot's back into `zone` (a SecureZone's Zone) and drop it there; waits for loot_secured.
func _secure_carried(zone: Area3D) -> bool:
	if not check(crew.is_carrying_bag(), "carrying a bag to secure"):
		return false
	var spot: Array = _drop_spot(zone)
	if not check(not spot.is_empty(), "a drop spot into %s" % zone.get_path()):
		return false
	var n_before: int = secured_loot.size()
	await _move_to(spot[0], spot[1])
	var d: CrewIntent = BotUtil.look_at_intent(crew.eye_position(), (spot[1] as Vector3) + Vector3.UP * 0.3)
	d.drop_bag = true
	rt.set_bot_intent(0, d)
	await _physics_frames(RISE_FRAMES)
	rt.set_bot_intent(0, _still())
	var ok: bool = await wait_until(func() -> bool: return secured_loot.size() > n_before, 5.0)
	return check(ok, "bag secured in %s" % zone.get_parent().name)


## Bag one bag from `spawn` and secure it in `zone`.
func bag_and_secure(spawn: LootSpawn, zone: Area3D) -> bool:
	if not await _bag_from(spawn):
		return false
	return await _secure_carried(zone)


## Walk up to `target` and hold interact on it until `done` (go_to + use).
func take(target: Node3D, done: Callable, hold_s: float, what: String) -> bool:
	if not check(target != null, "%s: target in the map" % what):
		return false
	if not await go_to(target):
		return false
	return await use(target, done, hold_s + MARGIN_S, what)


## The rolled variant slot `slot_id` of `group` is active.
func slot(group: StringName, slot_id: StringName) -> bool:
	var v: Variant = rt.mission.variant(group)
	return v is Array and (v as Array).has(slot_id)


## Stand in the escape zone once its vehicle is there; true when heist_ended came.
func escape(ez: EscapeZone) -> bool:
	if not check(ez != null, "escape zone"):
		return false
	var arrived: bool = await fast_until(func() -> bool: return ez.has_arrived(), 120.0)
	if not check(arrived, "the %s escape is there" % ez.name):
		return false
	var inside: Variant = BotUtil.nav_point_in_zone(ez.zone)
	if not check(inside != null, "a navmesh point inside %s" % ez.name):
		return false
	await _move_to(inside as Vector3, ez.global_position)
	var ok: bool = await wait_until(func() -> bool: return not ended.is_empty(), 5.0)
	return check(ok, "heist_ended after standing in %s" % ez.name)


## Start a HackTerminal and stay with it until DONE, restarting every interruption (QC-12).
func run_hack(ht: HackTerminal) -> bool:
	if not await go_to(ht):
		return false
	if not await use(ht, func() -> bool: return ht.state != HackTerminal.State.IDLE,
			Tweak.interaction().hack_start_s + MARGIN_S, "start the %s hack" % ht.name):
		return false
	var restarts: int = 0
	var budget: float = ht.effective_duration() * 2.0 + 30.0
	var t0: float = rt.heist_time_s
	while ht.state != HackTerminal.State.DONE and rt.heist_time_s - t0 < budget:
		await fast_until(func() -> bool: return ht.state != HackTerminal.State.RUNNING, budget)
		if ht.state == HackTerminal.State.INTERRUPTED:
			restarts += 1
			if not await use(ht, func() -> bool: return ht.state != HackTerminal.State.INTERRUPTED,
					Tweak.interaction().hack_restart_s + MARGIN_S, "restart the %s hack (#%d)" % [ht.name, restarts]):
				return false
	note("hack %s finished after %d restart(s)" % [ht.name, restarts])
	return check(ht.state == HackTerminal.State.DONE, "%s hack done" % ht.name)


# --- Map lookups ---------------------------------------------------------------------------------

func tagged(tag: StringName) -> Node3D:
	for n: Node in rt.mission.find_tagged(tag):
		return n as Node3D
	return null


func all_tagged(tag: StringName) -> Array[Node]:
	return rt.mission.find_tagged(tag)


## The Area3D `Zone` of the SecureZone tagged `tag`.
func secure_zone(tag: StringName) -> Area3D:
	var sz: Node3D = tagged(tag)
	return sz.get_node_or_null(^"Zone") as Area3D if sz != null else null


func objective(id: StringName) -> int:
	return rt.mission.objective_state(id)


# --- Internals -----------------------------------------------------------------------------------

func _floor_y(p: Vector3) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.DOWN * 3.0, 1)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else p.y


## Crossing a guarded LaserGrid (`guard_lasers`) when the move goes from one side of it to the other (into or out
## of the room it guards), the way its pattern allows (ND doc §Lasers): timed_off waits (fast) for the off window,
## sweeping for the beams to be away from the crossing, static steps through the bypass gap at a grid end first.
func _wait_lasers(from: Vector3, to: Vector3) -> void:
	for g: LaserGrid in guarded:
		if not is_instance_valid(g) or not g.active or _beyond(g, from) == _beyond(g, to):
			continue
		laser_waits += 1
		match g.pattern:
			LaserGrid.PATTERN_TIMED_OFF:
				var gap: Callable = func() -> bool:
					return not g.beams_on() and g.period_s - fposmod(g.time_s, g.period_s) >= LASER_OFF_LEFT_S
				check(await fast_until(gap, g.period_s + 1.0), "%s off window" % g.name)
				note("crossing %s in its off window" % g.name)
			LaserGrid.PATTERN_SWEEPING:
				var x: float = clampf((g.global_transform.affine_inverse() * to).x, -g.size_m.x * 0.5, g.size_m.x * 0.5)
				var clear: Callable = func() -> bool:
					for i: int in range(g.beam_total()):
						if absf(g.beam_offset(i) - x) < SWEEP_CLEAR_M:
							return false
					return true
				check(await fast_until(clear, g.period_s + 1.0), "%s sweep window" % g.name)
				note("crossing %s between its sweeping beams" % g.name)
			_:
				if _crouch_under(g):
					var c: CrewIntent = _still()
					c.crouch = true
					rt.set_bot_intent(0, c)
					check(await wait_until(func() -> bool: return crew.crouched, 2.0), "crouched under %s" % g.name)
					_crouch_through = true
					note("crossing %s crouched under its lowest beam" % g.name)
					continue
				var p: Variant = _laser_gap(g)
				if not check(p != null, "%s (static) has a bypass gap at an end (doc: >= 0.8 m)" % g.name):
					continue
				rt.teleport_crew(0, BotUtil.facing(p as Vector3, to))
				await _physics_frames(3)
				note("crossing %s through its bypass gap at %s" % [g.name, p])


## Static beams all above the crouched capsule (CrewTweak.height_crouched): crouch-walk under (SL/GN docs, B4).
func _crouch_under(g: LaserGrid) -> bool:
	if g.beam_total() <= 0:
		return true
	var low: float = INF
	for i: int in range(g.beam_total()):
		low = minf(low, g.beam_offset(i))
	var floor_y: float = _floor_y(g.global_position + Vector3.UP * 0.5)
	var bottom: float = g.global_position.y + low - Tweak.interaction().laser_beam_thickness_m * 0.5 - floor_y
	return bottom > Tweak.crew().height_crouched + 0.01


## A navmesh point in the plane of a static grid just past one of its ends with room for the crew capsule
## (radius 0.35 m, 1.2 m crouched), clear of the beams; null when neither end has one.
func _laser_gap(g: LaserGrid) -> Variant:
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.2
	for side: float in [-1.0, 1.0]:
		var want: Vector3 = g.global_transform * Vector3(side * (g.size_m.x * 0.5 + 0.45), 0.0, 0.0)
		var p: Variant = BotUtil.nav_point_near(g, want, 0.25)
		if p == null:
			continue
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.collision_mask = 1
		q.transform = Transform3D(Basis.IDENTITY, (p as Vector3) + Vector3.UP * 0.65)
		q.exclude = [crew.get_rid()]
		if space.intersect_shape(q, 1).is_empty():
			return p
	return null


## The grids in front of `inner` (a point in the room they guard): later moves into / out of that room wait for the
## grid's off window. `region` (optional, Callable(Vector3) -> bool) states the guarded room itself when it is not
## straight behind the grid (e.g. OF: the concourse and the vault round the corner behind the VC grid).
func guard_lasers(tag: StringName, inner: Vector3, region: Callable = Callable()) -> void:
	for n: Node in all_tagged(tag):
		var g: LaserGrid = n as LaserGrid
		if g != null and g.active:
			guarded.append(g)
			_inner_side[g] = signf((g.global_transform.affine_inverse() * inner).z)
			if region.is_valid():
				_region[g] = region


## True when `p` is in the room behind `g` (its `region`, else same floor, within the grid's width band, on the
## guarded side).
func _beyond(g: LaserGrid, p: Vector3) -> bool:
	if _region.has(g):
		return bool((_region[g] as Callable).call(p))
	var l: Vector3 = g.global_transform.affine_inverse() * p
	var side: float = float(_inner_side.get(g, 1.0))
	return l.y > -1.0 and l.y < g.size_m.y + 1.0 and absf(l.x) <= g.size_m.x * 0.5 + 1.0 \
		and l.z * side > g.size_m.z * 0.5 and l.z * side < 15.0


## A spot from which a bag dropped forward (LootTweak.drop_forward_m) lands inside `zone`, with no world geometry
## between the bot and the drop point (as the P1 gate's _drop_spot). [stand, look] or [].
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
