## PP audit (headless): real maps (Glasshouse, Night Deposit). Interact reach from each prompt's UsePoint with
## aimed resolution (what a player gets), door widths for followers. Prints AUDIT lines; asserts nothing yet.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _aim(c: CrewController, at: Vector3) -> CrewIntent:
	var d: Vector3 = at - c.eye_position()
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	return i


func _audit_reach(heist: StringName) -> void:
	_rt = await HeistLauncher.launch(heist, 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched %s" % heist)
	await wait_physics_frames(5)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var total: int = 0
	var bad: int = 0
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var comp: InteractableComponent = n as InteractableComponent
		if comp == null or not _rt.is_ancestor_of(comp) or not comp.enabled:
			continue
		var owner: Node = comp.owner_node()
		var p: GameplayPrefab = owner as GameplayPrefab
		if p == null or p.use_point == null or String(comp.name).begins_with(BagLift.PANEL_PREFIX):
			continue  # other-landing lift panels are not at landing 0's UsePoint
		total += 1
		_rt.teleport_crew(0, p.use_point.global_transform)
		await wait_physics_frames(1)
		_rt.set_bot_intent(0, _aim(c, comp.global_position))
		await wait_physics_frames(2)
		var got: InteractableComponent = _rt.interaction.aimed_component(c)
		if got != comp:
			bad += 1
			var d: float = c.eye_position().distance_to(comp.global_position)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c.eye_position(), comp.global_position, 1)
			q.exclude = [c.get_rid()]
			var hit: Dictionary = c.get_world_3d().direct_space_state.intersect_ray(q)
			var hit_name: String = "none"
			if not hit.is_empty():
				hit_name = str((hit.get("collider") as Node).get_path())
			var hit_d: float = (hit.get("position", comp.global_position) as Vector3).distance_to(comp.global_position)
			print("AUDIT   los hit: %s at %.2f m from comp eye=%s comp=%s" % [hit_name, hit_d,
				str(c.eye_position()), str(comp.global_position)])
			print("AUDIT %s reach FAIL %s kind=%s eye_dist=%.2f got=%s" % [heist, p.get_path(), comp.kind, d,
				str(got.owner_node().name) if got != null else "null"])
	print("AUDIT %s reach %d/%d prompts reachable from their UsePoint" % [heist, total - bad, total])
	for d: Node in get_tree().get_nodes_in_group(Door.GROUP):
		var door: Door = d as Door
		if door != null and _rt.is_ancestor_of(door) and door.effective_width() < 0.95:
			print("AUDIT %s door %s width %.2f" % [heist, door.name, door.effective_width()])


func test_pp_audit_reach_glasshouse() -> void:
	await _audit_reach(&"glasshouse")


func test_pp_audit_reach_night_deposit() -> void:
	await _audit_reach(&"night_deposit")


## Stands crew 0 `dist` m in front of guard `g` (on the guard's facing, nav-snapped), facing him.
func _front_of(g: NpcBase, dist: float) -> bool:
	var fwd: Vector3 = -g.global_basis.z
	fwd.y = 0.0
	var p: Vector3 = g.global_position + fwd.normalized() * dist
	var nav: RID = g.get_world_3d().navigation_map
	p = NavigationServer3D.map_get_closest_point(nav, p)
	if p.distance_to(g.global_position) < dist * 0.6:
		return false
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.05, 0)))
	await wait_physics_frames(1)
	_rt.set_bot_intent(0, _aim(c, g.global_position + Vector3(0, 1.2, 0)))
	await wait_physics_frames(2)
	return _rt.stealth.has_los(c.eye_position(), g.eye_position(), [c.get_rid(), g.get_rid()])


func _audit_runtime(heist: StringName) -> void:
	_rt = await HeistLauncher.launch(heist, 7, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "skip_casing": true})
	await wait_physics_frames(5)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var guards: Array = _rt.npcs(&"guard")
	print("AUDIT %s guards=%d civilians=%d pager_max=%d" % [heist, guards.size(), _rt.npcs(&"civilian").size(),
		Tweak.stealth().pager_max_answers])
	# 1) Detection timing at 6 m in front of each guard with LOS.
	var spotted_g: NpcBase = null
	for n: Node in guards:
		var g: NpcBase = n as NpcBase
		if not await _front_of(g, 6.0):
			continue
		var t: float = 0.0
		while t < 8.0 and g.alert_state != Enums.AlertState.ALARMED and _rt.stealth.is_stealth():
			await wait_physics_frames(6)
			t += 0.1
		print("AUDIT %s detect guard %d at 6 m: %.1f s state=%s" % [heist, g.net_id, t,
			Enums.AlertState.keys()[g.alert_state]])
		spotted_g = g
		break
	# 2) Pager: kill a (fresh) guard silently and answer it at the body.
	_rt.teardown()
	_rt = await HeistLauncher.launch(heist, 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "skip_casing": true})
	await wait_physics_frames(5)
	c = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var g2: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var started: Array = []
	var answered: Array = []
	var failed: Array = []
	var a: Callable = func(pid: int, _gid: int) -> void: started.append(pid)
	var b: Callable = func(pid: int, _s: int, total: int) -> void: answered.append(total)
	var f: Callable = func(pid: int, reason: StringName) -> void: failed.append(reason)
	EventBus.pager_started.connect(a)
	EventBus.pager_answered.connect(b)
	EventBus.pager_failed.connect(f)
	g2.die({"type": Enums.DamageType.BULLET, "zone": Enums.HitZone.HEAD}, c.net_id)
	var t2: float = 0.0
	while started.is_empty() and t2 < 6.0:
		await wait_physics_frames(6)
		t2 += 0.1
	print("AUDIT %s pager started after %.1f s (%d)" % [heist, t2, started.size()])
	var comp: InteractableComponent = g2.get_node_or_null(^"PagerInteractable") as InteractableComponent
	if comp != null:
		_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g2.global_position + Vector3(0, 0.05, 1.2)))
		await wait_physics_frames(1)
		_rt.set_bot_intent(0, _aim(c, comp.global_position))
		await wait_physics_frames(2)
		var aimed: InteractableComponent = _rt.interaction.aimed_component(c)
		print("AUDIT %s pager aimable from 1.2 m: %s" % [heist, str(aimed == comp)])
		ATestMaps.hold_interact(_rt, 0, g2.net_id)
		await wait_seconds(Tweak.stealth().pager_answer_s + 0.5)
		_rt.clear_bot_intent(0)
	print("AUDIT %s pager answered=%s failed=%s stealth=%s" % [heist, str(answered), str(failed),
		str(_rt.stealth.is_stealth())])
	EventBus.pager_started.disconnect(a)
	EventBus.pager_answered.disconnect(b)
	EventBus.pager_failed.disconnect(f)
	# 3) Domination on the real map: a fresh guard spots crew with the skill, shout inside the window.
	_rt.teardown()
	_rt = await HeistLauncher.launch(heist, 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "skip_casing": true})
	await wait_physics_frames(5)
	c = _rt.crew_controller(0) as CrewController
	c.set_masked()
	Modifiers.set_source(0, &"audit", {&"stealth.can_dominate_guards": true})
	var dom: Array = []
	var dcb: Callable = func(id: int, _s: int) -> void: dom.append(id)
	EventBus.guard_dominated.connect(dcb)
	for n: Node in _rt.npcs(&"guard"):
		var g3: NpcBase = n as NpcBase
		if not await _front_of(g3, 5.0):
			continue
		g3.notify_crew_spotted(c)
		await wait_physics_frames(2)
		var i: CrewIntent = _aim(c, g3.global_position + Vector3(0, 1.2, 0))
		i.shout = true
		_rt.set_bot_intent(0, i)
		await wait_physics_frames(3)
		_rt.clear_bot_intent(0)
		print("AUDIT %s domination guard %d: dominated=%s state=%s hostage=%s" % [heist, g3.net_id,
			str(dom.has(g3.net_id)), Enums.AlertState.keys()[g3.alert_state], str(g3.is_in_group(G.HOSTAGE))])
		break
	EventBus.guard_dominated.disconnect(dcb)
	# 4) Civilians: shout at the nearest one in view, then tie.
	var ints: Array = []
	var ties: Array = []
	var icb: Callable = func(id: int, _s: int) -> void: ints.append(id)
	var tcb: Callable = func(id: int, _s: int) -> void: ties.append(id)
	EventBus.civilian_intimidated.connect(icb)
	EventBus.civilian_tied.connect(tcb)
	for n: Node in _rt.npcs(&"civilian"):
		var cv: NpcBase = n as NpcBase
		if not await _front_of(cv, 4.0):
			continue
		var i2: CrewIntent = _aim(c, cv.global_position + Vector3(0, 1.0, 0))
		await wait_seconds(1.0)
		i2.shout = true
		_rt.set_bot_intent(0, i2)
		await wait_physics_frames(3)
		_rt.clear_bot_intent(0)
		await wait_seconds(2.0)
		_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, cv.global_position + Vector3(0, 0.05, 1.0)))
		await wait_physics_frames(1)
		ATestMaps.hold_interact(_rt, 0, cv.net_id)
		await wait_seconds(Tweak.interaction().tie_s + 0.5 if &"tie_s" in Tweak.interaction() else 3.0)
		_rt.clear_bot_intent(0)
		print("AUDIT %s civilian %d intimidated=%s tied=%s" % [heist, cv.net_id, str(ints.has(cv.net_id)),
			str(ties.has(cv.net_id))])
		break
	EventBus.civilian_intimidated.disconnect(icb)
	EventBus.civilian_tied.disconnect(tcb)


func test_pp_audit_runtime_glasshouse() -> void:
	await _audit_runtime(&"glasshouse")


func test_pp_audit_runtime_night_deposit() -> void:
	await _audit_runtime(&"night_deposit")
