## PT-02 Glasshouse end-to-end by real input only (PInputDriver): every player action is a key, mouse button
## or mouse motion. The walker steers by mouse-look along the navmesh path and holds W, like a person.
## Setup-only shortcuts (documented, never player actions): isolate_npc(null) so the scripted walker is not
## shot/spotted mid-route; the loud run's "downed" is a lethal Damage hit (no deterministic way to get shot).
## Every stuck / confusing spot is printed as "[PT-02] FINDING ..." and fails the step.
## Owner: ENV P.
extends TestCase

const HEIST: StringName = &"glasshouse"
const SEED: int = 1002

var _rt: HeistRuntime = null
var _inp: PInputDriver = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _findings: Array[String] = []


func before_each() -> void:
	_inp = PInputDriver.new(self)
	_events = []
	_findings = []
	Engine.time_scale = 1.0


func after_each() -> void:
	_inp.release_all()
	Engine.time_scale = 1.0
	for c: Array in _conns:
		if (c[0] as Signal).is_connected(c[1]):
			(c[0] as Signal).disconnect(c[1])
	_conns = []
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	for f: String in _findings:
		print("[PT-02] FINDING ", f)
	await wait_frames(2)


func _launch(ai: int) -> bool:
	if OS.get_environment("CNC_E2E") != "1":
		skip("PT-02 Glasshouse E2E is opt-in (CNC_E2E=1): open blockers PP-P-7 (C), PP-P-8 (A), PP-P-12 (C)")
		return false
	_rt = await HeistLauncher.launch(HEIST, SEED, Enums.Difficulty.ROUTINE, self, {"ai_teammates": ai})
	if _rt == null:
		fail("launch")
		return false
	var ok: bool = await wait_until(func() -> bool: return BotUtil.nav_ready(_c()), 10.0)
	for tag: StringName in [&"alarm_raised", &"heist_ended", &"loot_secured", &"crew_downed", &"crew_revived",
			&"interaction_completed", &"device_finished", &"item_picked_up"]:
		var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
			_events.append([tag, a, b, c, d])
		Signal(EventBus, tag).connect(cb)
		_conns.append([Signal(EventBus, tag), cb])
	_inp.capture_mouse()
	await wait_physics_frames(5)
	var dr: DrillPoint = _tagged(&"safe_drill") as DrillPoint
	if dr != null:
		print("[PT-02] start: SafeDrill interactable enabled=%s kind=%s" % [dr.interactable.enabled, dr.interactable.kind])
	return ok


func _c() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _find(msg: String) -> void:
	var p: Vector3 = _c().global_position if _rt != null else Vector3.ZERO
	_findings.append("%s @ (%.1f, %.1f, %.1f) phase %s" % [msg, p.x, p.y, p.z, Enums.HeistPhase.keys()[_rt.phase]])


func _tagged(tag: StringName) -> Node3D:
	var t: Array[Node] = _rt.find_by_tag(tag)
	return t[0] as Node3D if not t.is_empty() else null


# --- real-input primitives ---------------------------------------------------------------------

## Mouse-look until the view points at `p` (yaw and pitch).
func _look_at(p: Vector3) -> bool:
	var c: CrewController = _c()
	var d: Vector3 = p - c.eye_position()
	var ok: bool = await _inp.turn_to_yaw(c, atan2(-d.x, -d.z), 0.03, 3.0)
	var pitch: float = atan2(d.y, Vector2(d.x, d.z).length())
	var rpp: float = PInputDriver.mouse_radians_per_px()
	for _i: int in 12:
		var err: float = pitch - c.look_pitch
		if absf(err) < 0.03:
			return ok
		_inp.look(0.0, -err / rpp)
		await wait_physics_frames(4)
	return ok and absf(pitch - c.look_pitch) < 0.06


func _nearest_closed_door(r: float) -> Door:
	var best: Door = null
	for n: Node in _rt.map.find_children("*", "Door", true, false):
		var d: Door = n as Door
		if not d.is_open and d.global_position.distance_to(_c().global_position) < r:
			if best == null or d.global_position.distance_to(_c().global_position) < best.global_position.distance_to(_c().global_position):
				best = d
	return best


## Walk to `goal` along the navmesh path: turn by mouse to each waypoint, hold W (sprint if asked).
func _walk_to(goal: Vector3, label: String, tol: float = 0.6, sprint: bool = false, timeout_s: float = 60.0) -> bool:
	var c: CrewController = _c()
	var nav: RID = c.get_world_3d().navigation_map
	var to: Vector3 = NavigationServer3D.map_get_closest_point(nav, goal)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, c.global_position, to, true)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > 1.0:
		_find("%s: no navmesh path to (%.1f,%.1f,%.1f)" % [label, goal.x, goal.y, goal.z])
		return false
	var t0: int = Time.get_ticks_msec()
	var game_t: float = 0.0
	var idx: int = 1
	var last_p: Vector3 = c.global_position
	var still_t: float = 0.0
	var unstick: int = 0
	_inp.press(&"move_forward")
	if sprint:
		_inp.press(&"sprint")
	while idx < path.size():
		var wp: Vector3 = path[idx]
		var flat: Vector2 = Vector2(wp.x - c.global_position.x, wp.z - c.global_position.z)
		if flat.length() < (tol if idx == path.size() - 1 else 0.45):
			idx += 1
			continue
		var want: float = atan2(-flat.x, -flat.y)
		var err: float = wrapf(want - c.look_yaw, -PI, PI)
		if absf(err) > 0.08:
			_inp.look(-err / PInputDriver.mouse_radians_per_px() * 0.7, 0.0)
		await wait_physics_frames(2)
		var dt: float = 2.0 / Engine.physics_ticks_per_second
		game_t += dt
		if c.global_position.distance_to(last_p) < 0.03:
			still_t += dt
		else:
			still_t = 0.0
		last_p = c.global_position
		if still_t > 1.5:
			still_t = 0.0
			unstick += 1
			var door: Door = _nearest_closed_door(2.5)
			if door != null and unstick <= 2 and not door.is_open:
				_inp.release_all()
				var comp: InteractableComponent = _comp(door)
				if comp != null:
					# A player opens (or lockpicks) the door in the way: hold F until it opens.
					await _look_at(comp.global_position)
					_inp.press(&"interact")
					var opened: bool = await wait_until(func() -> bool: return door.is_open, comp.interaction_time_s + 2.0)
					_inp.release(&"interact")
					await wait_physics_frames(4)
					print("[PT-02] %s: door %s in the way (lock %d) -> %s" % [label, door.name, door.lock,
						"opened" if opened else "still closed"])
				_inp.press(&"move_forward")
				continue
			if unstick <= 4:
				# What a player does on a snag: sidestep left, then right, then hop (PP-P-12: nav radius 0.3 < capsule 0.35).
				var side: StringName = [&"move_left", &"move_right", &"move_right", &"jump"][mini(unstick, 4) - 1]
				if side == &"jump":
					await _inp.tap(&"jump")
				else:
					await _inp.hold(side, 0.35)
				print("[PT-02] %s: snag at (%.1f,%.1f) -> %s" % [label, c.global_position.x, c.global_position.z, side])
				continue
			_inp.release_all()
			print("[PT-02] near snag: %s" % _near_colliders())
			_find("%s: stuck (no progress 1.5 s x%d) heading to waypoint %d/%d (%.1f,%.1f,%.1f)%s%s" % [
				label, unstick, idx, path.size(), wp.x, wp.y, wp.z,
				" next to closed door %s (locked %s, aimed %s, prompt %s)" % [door.name, door.locked, _aimed_name(),
				_comp_diag(door)] if door != null else "", _crowd()])
			return false
		if game_t > timeout_s:
			_inp.release_all()
			_find("%s: walk timeout %.0f s" % [label, timeout_s])
			return false
	_inp.release(&"move_forward")
	_inp.release(&"sprint")
	await wait_physics_frames(15)
	print("[PT-02] walked to %s in %.1f s game / %d ms wall%s" % [label, game_t, Time.get_ticks_msec() - t0,
		" (jumped/doors x%d)" % unstick if unstick > 0 else ""])
	return true


func _comp_diag(n: Node) -> String:
	var ic: InteractableComponent = n.get(&"interactable") as InteractableComponent
	if ic == null:
		return "none"
	return "enabled=%s dist=%.2f m pos=(%.1f,%.1f,%.1f)" % [ic.enabled, ic.global_position.distance_to(_c().eye_position()),
		ic.global_position.x, ic.global_position.y, ic.global_position.z]


func _near_colliders() -> String:
	var sp: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = 0.6
	sp.shape = sph
	sp.transform = Transform3D(Basis.IDENTITY, _c().global_position + Vector3.UP * 0.9)
	sp.exclude = [_c().get_rid()]
	var names: Dictionary = {}
	for r: Dictionary in _c().get_world_3d().direct_space_state.intersect_shape(sp, 12):
		var n: Node = r["collider"]
		names[String(_rt.map.get_path_to(n)) if _rt.map.is_ancestor_of(n) else n.name] = true
	return str(names.keys())


func _crowd() -> String:
	var near: float = INF
	for m: CrewController in _rt.crew_members():
		if m != _c():
			near = minf(near, m.global_position.distance_to(_c().global_position))
	return "; nearest teammate %.1f m" % near if near < 1.5 else ""


func _aimed_name() -> String:
	var a: InteractableComponent = _rt.interaction.aimed_component(_c())
	return "%s/%s" % [a.get_parent().name, a.kind] if a != null else "nothing"


func _comp(n: Node) -> InteractableComponent:
	if n is InteractableComponent:
		return n if (n as InteractableComponent).enabled else null
	var ic: Variant = n.get(&"interactable")
	if ic is InteractableComponent:
		return ic if (ic as InteractableComponent).enabled else null
	return null


## Walk to the prefab's UsePoint, look at its interactable and hold F until `done`.
func _use(prefab: Node3D, label: String, done: Callable, hold_s: float) -> bool:
	var comp: InteractableComponent = _comp(prefab)
	if comp == null:
		var ic: Variant = prefab.get(&"interactable")
		_find("%s: %s has %s" % [label, prefab.name, "a disabled interactable" if ic != null else "no interactable"])
		return false
	var gp: GameplayPrefab = prefab as GameplayPrefab
	var at: Vector3 = gp.use_point.global_position if gp != null and gp.use_point != null else comp.global_position
	if not await _walk_to(at, label, 0.5):
		return false
	await _look_at(comp.global_position)
	if _rt.interaction.aimed_component(_c()) != comp:
		var other: InteractableComponent = _rt.interaction.aimed_component(_c())
		_find("%s: looking at the prompt from the UsePoint does not target it (aimed: %s, dist %.2f m)" % [
			label, other.get_parent().name if other != null else "nothing",
			comp.global_position.distance_to(_c().eye_position())])
	_inp.press(&"interact")
	var ok: bool = await wait_until(done, hold_s + comp.interaction_time_s + 1.0)
	_inp.release(&"interact")
	await wait_physics_frames(4)
	if not ok:
		_find("%s: holding F for %.0f s did not finish" % [label, hold_s])
	return ok


## Throw (G) the carried bag toward `p`.
func _throw_bag_at(p: Vector3) -> bool:
	await _look_at(p + Vector3.UP * 0.6)
	await _inp.tap(&"throw_item")
	return await wait_until(func() -> bool: return not _c().is_carrying_bag(), 1.0)


func _mask_up() -> bool:
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	return await wait_until(func() -> bool: return _c().masked, 1.0)


func _bag_from(spawn: Node3D, label: String) -> bool:
	return await _use(spawn, label, func() -> bool: return _c().is_carrying_bag(), Tweak.interaction().bag_loot_s + 4.0)


## Carry a bag to the van's secure zone and throw it in. Returns true once loot_secured fires.
func _secure_bag(zone: Area3D, label: String) -> bool:
	var n0: int = _of(&"loot_secured").size()
	var centre: Vector3 = BotUtil.zone_center(zone)
	if not await _walk_to(centre, label + " (carry)", 3.0):
		return false
	if not await _throw_bag_at(centre):
		_find("%s: G did not throw the bag" % label)
		return false
	var ok: bool = await wait_until(func() -> bool: return _of(&"loot_secured").size() > n0, 4.0)
	if not ok:
		_find("%s: a bag thrown at the secure zone from 3 m did not secure" % label)
	return ok


## Setup only (stealth run): the scripted route does not dodge cameras, so remove them like isolate_npc.
func _no_cameras() -> void:
	for n: Node in _rt.map.find_children("*", "", true, false):
		if n is SecurityCamera:
			n.queue_free()


func _secure_zone() -> Area3D:
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		if _rt.is_ancestor_of(n):
			return n as Area3D
	return null


func _safe_loot_spawn() -> Node3D:
	return _tagged(&"safe_loot")


func _bag_source() -> Node3D:
	for tag: StringName in [&"safe_loot", &"delivery_loot"]:
		var n: Node3D = _tagged(tag)
		if n != null and _comp(n) != null:
			return n
	return null


func _escape() -> bool:
	var ez: EscapeZone = _tagged(&"escape_van") as EscapeZone
	if ez == null:
		fail("no escape_van")
		return false
	if not await wait_until(func() -> bool: return ez.has_arrived(), 20.0):
		_find("escape van never arrived")
		return false
	if not await _walk_to(BotUtil.zone_center(ez.zone), "escape", 0.8, true):
		return false
	var ok: bool = await wait_until(func() -> bool: return not _of(&"heist_ended").is_empty(), 6.0)
	if not ok:
		_find("standing in the escape zone did not end the heist")
	return ok


# --- runs ---------------------------------------------------------------------------------------

func test_stealth_run() -> void:
	if not await _launch(0):
		return
	_rt.isolate_npc(null)
	_no_cameras()
	var c: CrewController = _c()
	assert_true(c.is_casing(), "casing at spawn")
	# Casing walk: through the public floor to a display case unmasked.
	var cases: Array[Node] = _rt.map.find_children("*", "DisplayCase", true, false)
	if not cases.is_empty():
		await _walk_to((cases[0] as Node3D).global_position, "casing: display case", 1.5)
	assert_true(c.is_casing(), "still casing after walking the shop")
	assert_true(await _mask_up(), "mask up")
	# Keycard (unless the safe variant is open).
	var card: Node3D = _tagged(&"keycard")
	if card == null:
		for n: Node in _rt.map.find_children("*", "KeycardPickup", true, false):
			card = n as Node3D
	if card != null and c.item_count(&"item.keycard") == 0 and _comp(card) != null:
		assert_true(await _use(card, "keycard", func() -> bool: return c.item_count(&"item.keycard") > 0, 5.0), "keycard")
	var wd: Node3D = _tagged(&"workshop_door")
	if wd != null and not (wd as Door).is_open:
		assert_true(await _use(wd, "workshop door", func() -> bool: return (wd as Door).is_open, 8.0), "workshop door")
	var reader: Node3D = _tagged(&"safe_reader")
	if reader != null and _comp(reader) != null:
		var safe_done: Callable = func() -> bool: return _rt.mission.objective_state(&"safe") == Enums.ObjectiveState.COMPLETED
		assert_true(await _use(reader, "safe reader", safe_done, 6.0), "safe opened by keycard")
	var zone: Area3D = _secure_zone()
	assert_true(zone != null, "secure zone")
	for i: int in 2:
		var src: Node3D = _bag_source()
		if src == null:
			_find("bag %d: no loot spawn with an enabled interactable (safe_loot/delivery_loot)" % (i + 1))
			break
		if not await _bag_from(src, "bag %d" % (i + 1)):
			break
		if not await _secure_bag(zone, "bag %d" % (i + 1)):
			break
	assert_true(_rt.mission.bags_secured >= 2, "2 bags secured (%d)" % _rt.mission.bags_secured)
	assert_true(_of(&"alarm_raised").is_empty(), "still stealth")
	if _rt.mission.bags_secured >= 2:
		assert_true(await _escape(), "escape")
	assert_true(_findings.is_empty(), "no stuck/confusing spots: %s" % str(_findings))


func test_loud_run() -> void:
	if not await _launch(3):
		return
	_rt.isolate_npc(null)
	var c: CrewController = _c()
	assert_true(await _mask_up(), "mask up")
	# Go loud the way a player does: unsuppressed shots in the shop (swap to the primary, fire).
	await _inp.tap(&"swap_weapon")
	await wait_seconds(1.0)
	await _inp.hold(&"fire", 1.0)
	if not await wait_until(func() -> bool: return _rt.phase == Enums.HeistPhase.LOUD, 8.0):
		_find("firing %s (slot %d) for 1 s in the shop did not raise the alarm (suppressed=%s)" % [
			c.weapons.weapon_id(c.weapons.equipped_slot), c.weapons.equipped_slot, c.weapons.is_suppressed()])
		_rt.stealth.raise_alarm(&"pt02_setup")
		await wait_until(func() -> bool: return _rt.phase == Enums.HeistPhase.LOUD, 2.0)
	var wd: Node3D = _tagged(&"workshop_door")
	if wd != null and not (wd as Door).is_open:
		await _use(wd, "workshop door (loud)", func() -> bool: return (wd as Door).is_open, 12.0)
	var drill: DrillPoint = _tagged(&"safe_drill") as DrillPoint
	assert_true(drill != null, "safe drill point")
	if drill != null:
		print("[PT-02] loud: SafeDrill interactable enabled=%s kind=%s runner=%s" % [
			drill.interactable.enabled, drill.interactable.kind, drill.runner])
	if drill != null and not drill.interactable.enabled:
		_find("SafeDrill DrillPoint is disabled (Safe._inner_loot treats it as loot); drilling via the Safe itself")
		var safe: Node3D = drill.get_parent() as Node3D
		var placed_s: bool = await _use(safe, "place drill on safe", func() -> bool: return _comp(safe) == null \
			or (safe.get(&"runner") as DeviceRunner).state != 0, 8.0)
		assert_true(placed_s, "drill placed on the safe")
		drill = null
		var runner: DeviceRunner = safe.get(&"runner") as DeviceRunner
		var ok_s: bool = false
		var jams: int = 0
		var left: float = 400.0
		Engine.time_scale = 4.0
		while left > 0.0 and not ok_s:
			ok_s = _rt.mission.objective_state(&"safe") == Enums.ObjectiveState.COMPLETED
			if not ok_s and runner != null and runner.state == DeviceRunner.State.JAMMED:
				Engine.time_scale = 1.0
				jams += 1
				await _use(safe, "fix safe drill", func() -> bool: return runner.state != DeviceRunner.State.JAMMED, 6.0)
				Engine.time_scale = 4.0
			await wait_seconds(0.5)
			left -= 0.5
		Engine.time_scale = 1.0
		print("[PT-02] safe drill: open=%s after %d jam fixes" % [ok_s, jams])
		if not ok_s:
			_find("safe drill not done after 400 s game time: runner state %s, %d jam fixes, safe stage %s" % [
				DeviceRunner.State.keys()[runner.state] if runner != null else "none", jams, safe.get(&"stage")])
		assert_true(ok_s, "safe drilled open")
	if drill != null:
		var placed: bool = await _use(drill, "place drill", func() -> bool: return drill.runner != null, 8.0)
		assert_true(placed, "drill placed")
		Engine.time_scale = 4.0
		var t_end: float = 400.0
		var done: bool = false
		while t_end > 0.0 and not done:
			done = not _of(&"device_finished").is_empty() or _rt.mission.objective_state(&"safe") == Enums.ObjectiveState.COMPLETED
			if not done and drill.device_state() == 2 and _comp(drill) != null:  # jammed: fix it
				Engine.time_scale = 1.0
				await _use(drill, "fix drill", func() -> bool: return drill.device_state() != 2, 10.0)
				Engine.time_scale = 4.0
			await wait_seconds(0.5)
			t_end -= 0.5
		Engine.time_scale = 1.0
		assert_true(done, "drill finished, safe open")
	# Downed + revived by an AI teammate.
	var hit: Dictionary = Damage.info(c.health.health + 1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY,
		&"test.pt02", c.global_position, Vector3.FORWARD)
	hit["pierced_armor"] = true
	c.take_hit(hit, 0)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "downed")
	Engine.time_scale = 2.0
	var rev: bool = await wait_until(func() -> bool: return not _of(&"crew_revived").is_empty(), c.health.bleedout_left + 2.0)
	Engine.time_scale = 1.0
	if not rev:
		_find("downed in the workshop: no AI teammate revived within the bleedout")
	assert_true(rev, "revived")
	var zone: Area3D = _secure_zone()
	for i: int in 2:
		var src: Node3D = _bag_source()
		if src == null or not rev:
			break
		if not await _bag_from(src, "loud bag %d" % (i + 1)):
			break
		if not await _secure_bag(zone, "loud bag %d" % (i + 1)):
			break
	assert_true(_rt.mission.bags_secured >= 2, "2 bags secured loud (%d)" % _rt.mission.bags_secured)
	Engine.time_scale = 8.0
	var ez: EscapeZone = _tagged(&"escape_van") as EscapeZone
	await wait_until(func() -> bool: return ez != null and ez.active, 300.0)
	Engine.time_scale = 1.0
	if _rt.mission.bags_secured >= 2:
		assert_true(await _escape(), "loud escape")
	assert_true(_findings.is_empty(), "no stuck/confusing spots: %s" % str(_findings))
