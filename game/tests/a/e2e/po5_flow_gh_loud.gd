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
	EventBus.alarm_raised.connect(func(reason: StringName, _src: int) -> void: f.note("EVENT alarm_raised %s" % reason))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		f.note("EVENT objective %s -> %d" % [id, st]))
	EventBus.assault_phase_changed.connect(func(ph: int, w: int) -> void:
		f.note("EVENT assault phase %d wave %d t=%.0f" % [ph, w, rt.heist_time_s]))
	await p.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	await p.inp.ticks(10)
	f.note("masked=%s phase=%d" % [p.crew.masked, rt.phase])
	if not p.crew.masked:
		return await fail("PO-5.mask: holding mask_up did not mask")
	p.combat = true
	# Go loud like a player: fire into the shop air.
	await p.face(p.crew.eye_position() + Vector3(0, 3, -5))
	for _i: int in 3:
		await p.inp.tap(&"fire")
		await p.inp.ticks(10)
	await f.wait_s(2.0)
	f.note("after shots: phase=%d went_loud=%s" % [rt.phase, rt.went_loud])
	await f.shot("loud_start")
	var wdoor: InteractableComponent = comp_tagged(&"workshop_door")
	if not await p.goto(p.stand_point(wdoor.global_position + Vector3(0, 0, 1.0)), 0.6, 90.0):
		await f.shot("workshop_unreachable")
		return await fail("PO-5.route: could not reach the workshop door")
	var door: Door = wdoor.owner_node() as Door
	await p.hold_position(4.0, func() -> bool: return p.nearest_enemy(30.0) == null)
	if not door.is_open:
		await p.use(wdoor, 40.0, func() -> bool: return door.is_open)
	f.note("workshop door open=%s" % door.is_open)
	await f.shot("workshop_door")
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
			f.note("crew state %d (downed?) at %.0f s" % [p.crew.crew_state, rt.heist_time_s])
			await f.shot("player_down")
			return await fail("PO-5.down: player went down while drilling")
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
		return await fail("PO-5.drill: safe loot never enabled (state %d progress %.2f)" % [dp.runner.state, dp.runner.progress])
	f.note("safe open after %.0f s" % (rt.heist_time_s - t0))
	return 0


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
