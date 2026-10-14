## PO-5 Glasshouse loud run: mask up, shoot (alarm), lockpick the workshop, drill the safe (fix jams,
## fight), bag the safe loot, throw the bags into the van, escape. Every step is player input.
extends RefCounted

var f: Node = null
var p: Po5Pilot = null
var rt: HeistRuntime = null


func play(flow: Node) -> int:
	f = flow
	p = flow.get(&"pilot") as Po5Pilot
	rt = flow.get(&"rt") as HeistRuntime
	for step: Callable in [_go_loud, _workshop, _drill, _bags]:
		var err: String = await step.call()
		if err != "":
			return fail(err)
	return await escape()


func _go_loud() -> String:
	EventBus.alarm_raised.connect(func(reason: StringName, _src: int) -> void: f.note("EVENT alarm_raised %s" % reason))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		f.note("EVENT objective %s -> %d" % [id, st]))
	EventBus.assault_phase_changed.connect(func(ph: int, w: int) -> void:
		f.note("EVENT assault phase %d wave %d t=%.0f" % [ph, w, rt.heist_time_s]))
	await p.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	await p.inp.ticks(10)
	f.note("masked=%s phase=%d" % [p.crew.masked, rt.phase])
	if not p.crew.masked:
		return "PO-5.mask: holding mask_up did not mask"
	p.combat = true
	# Go loud like a player: fire into the shop air.
	await p.face(p.crew.eye_position() + Vector3(0, 3, -5))
	for _i: int in 3:
		await p.inp.tap(&"fire")
		await p.inp.ticks(10)
	await f.wait_s(2.0)
	f.note("after shots: phase=%d went_loud=%s" % [rt.phase, rt.went_loud])
	await f.shot("loud_start")
	return ""


func _workshop() -> String:
	var wdoor: InteractableComponent = comp_tagged(&"workshop_door")
	if not await p.goto(p.stand_point(wdoor.global_position + Vector3(0, 0, 1.0)), 0.6, 90.0):
		await f.shot("workshop_unreachable")
		return "PO-5.route: could not reach the workshop door"
	var door: Door = wdoor.owner_node() as Door
	await p.hold_position(4.0, func() -> bool: return p.nearest_enemy(30.0) == null)
	if not door.is_open:
		await p.use(wdoor, 40.0, func() -> bool: return door.is_open)
	f.note("workshop door open=%s" % door.is_open)
	await f.shot("workshop_door")
	p.watch_point = wdoor.global_position + Vector3(0, 0.6, 0)
	return ""


func _drill() -> String:
	var drill: InteractableComponent = comp_tagged(&"safe_drill")
	var dp: DrillPoint = drill.owner_node() as DrillPoint
	await p.use(drill, 15.0, func() -> bool: return dp.runner != null and dp.runner.state != DeviceRunner.State.IDLE)
	f.note("drill state=%s" % [dp.runner.state if dp.runner else -1])
	await f.shot("drill_placed")
	var loot: InteractableComponent = comp_tagged(&"safe_loot")
	var t0: float = rt.heist_time_s
	var last_shot: float = t0
	while not loot.enabled and rt.heist_time_s - t0 < 420.0:
		if p.crew.crew_state != Enums.CrewState.NORMAL:
			f.note("player state %d at %.0f s; waiting for a revive" % [p.crew.crew_state, rt.heist_time_s])
			await f.shot("player_down")
			while p.crew.crew_state != Enums.CrewState.NORMAL and p.crew.crew_state != Enums.CrewState.CUSTODY:
				await _act_while_down()
			if p.crew.crew_state == Enums.CrewState.CUSTODY:
				return "PO-5.down: player went down while drilling and ended in custody at %.0f s" % rt.heist_time_s
			f.note("player back up at %.0f s" % rt.heist_time_s)
		if dp.runner != null and dp.runner.state == DeviceRunner.State.JAMMED:
			f.note("drill jammed at %.0f s (progress %.2f)" % [rt.heist_time_s, dp.runner.progress])
			await p.use(drill, 20.0, func() -> bool: return dp.runner.state != DeviceRunner.State.JAMMED)
			continue
		await p.hold_position(3.0, func() -> bool: return loot.enabled or dp.runner.state == DeviceRunner.State.JAMMED)
		if rt.heist_time_s - last_shot > 60.0:
			last_shot = rt.heist_time_s
			f.note("drilling: state=%d progress=%.2f/%.0f t=%.0f" % [dp.runner.state, dp.runner.progress,
				dp.runner.duration, rt.heist_time_s - t0])
			await f.shot("drilling")
	if not loot.enabled:
		return "PO-5.drill: safe loot never enabled (state %d progress %.2f)" % [dp.runner.state, dp.runner.progress]
	f.note("safe open after %.0f s" % (rt.heist_time_s - t0))
	return ""


func _bags() -> String:
	var loot: InteractableComponent = comp_tagged(&"safe_loot")
	await f.shot("safe_open")
	var zone: SecureZone = p.secure_zone()
	if zone == null:
		return "PO-5.van: no active secure zone"
	f.note("secure zone %s at %s" % [zone.get_path(), Po5Pilot._v(zone.global_position)])
	var bags: int = 0
	var tries: int = 0
	while bags < 2 and tries < 5:
		tries += 1
		if not p.crew.is_carrying_bag():
			await p.use(loot, 20.0, func() -> bool: return p.crew.is_carrying_bag())
		if not p.crew.is_carrying_bag():
			f.note("could not bag the safe loot (try %d)" % tries)
			continue
		if await p.secure_carried_bag(zone):
			bags += 1
			f.note("bag %d secured t=%.0f" % [bags, rt.heist_time_s])
			await f.shot("bag_%d" % bags)
	if bags < 2:
		return "PO-5.bags: only %d bags secured" % bags
	return ""


func escape() -> int:
	var t0: float = rt.heist_time_s
	var ended: Array[bool] = [false]
	EventBus.heist_ended.connect(func(r: Dictionary) -> void:
		ended[0] = true
		f.note("EVENT heist_ended %s" % [r]))
	var is_over: Callable = func() -> bool: return ended[0] or rt.phase == Enums.HeistPhase.ENDED
	while p.active_escape() == null and rt.heist_time_s - t0 < 400.0 and not is_over.call():
		await p.hold_position(5.0, func() -> bool: return p.active_escape() != null)
	var ez: EscapeZone = p.active_escape()
	if ez == null and not is_over.call():
		return fail("PO-5.escape: escape never activated (%.0f s after bags)" % (rt.heist_time_s - t0))
	if ez != null:
		f.note("escape active at %s after %.0f s" % [Po5Pilot._v(ez.global_position), rt.heist_time_s - t0])
	# Walk into the zone in short legs: the heist ends as soon as every human stands inside it.
	var t1: float = rt.heist_time_s
	while not is_over.call() and rt.heist_time_s - t1 < 120.0:
		await p.goto(p.stand_point(ez.global_position), 0.8, 3.0)
		if not is_over.call():
			await p.hold_position(1.0, is_over)
	if not is_over.call():
		await f.shot("escape_stuck")
		return fail("PO-5.escape: standing in the escape zone did not end the heist")
	f.note("heist over (phase %d) at t=%.0f" % [rt.phase, rt.heist_time_s])
	return await f.payday_to_hub()


func comp_tagged(tag: StringName) -> InteractableComponent:
	for n: Node in f.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var o: Node = c.owner_node()
		if o != null and o.get(&"objective_tag") == tag and o.is_inside_tree():
			return c
	return null


func fail(msg: String) -> int:
	f.note("FAIL " + msg)
	return 1


## While downed, keep shooting the nearest enemy in sight like a player (PD2 / L2.12: police only cuff a downed
## crew member who is NOT shooting); any other helpless state just waits. About 1 s per call.
func _act_while_down() -> void:
	if p.crew.crew_state == Enums.CrewState.DOWNED:
		var foe: NpcBase = p.nearest_enemy(25.0)
		if foe != null:
			await p.engage(foe, 1.0)
			return
	await f.wait_s(1.0)
