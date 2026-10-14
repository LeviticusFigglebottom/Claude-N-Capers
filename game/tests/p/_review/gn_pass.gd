## GN-P1 round 187 pass (lead 2026-10-14): Gallery Night through the real menus (A's PO-5 driver: clicks, Po5Pilot
## input only, render loop off between screenshots), stealth to last call, then a loud lockdown. Stealth: unmasked
## casing tour of the gala's PUBLIC rooms (a guest at the party) until `last_call_s` + --after s, with shots at the
## warning, at last call and after it, and notes on what last call does to the player (zones, patrons leaving,
## doors relocked, detection of a guest who stayed). Loud: A's auto_loud flow (mask, shoot, lockdown, loud hack /
## drill, secure, escape, payday). Same --po5-* / --anim-out / --obs-out arguments as anim_coverage.tscn plus
## --after=S (default 40). Run (windowed):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 \
##     res://tests/p/_review/gn_pass.tscn -- --po5-out=/abs/dir --po5-budget=6000 [--po5-seed=N]
## Owner: ENV P (A's driver and flows are used unchanged).
extends "res://tests/a/e2e/po5_flow.gd"

var _after_s: float = 40.0


func _run() -> void:
	heist_name = "Gallery Night"
	runner_flow = "gn_pass"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--po5-difficulty="):
			difficulty_name = a.substr(17)
		elif a.begins_with("--po5-seed="):
			HeistLauncher.next_seed_override = a.substr(11).to_int()
		elif a.begins_with("--po5-budget="):
			_budget_s = a.substr(13).to_float()
		elif a.begins_with("--after="):
			_after_s = a.substr(8).to_float()
	if _budget_s > 0.0:
		_watchdog.call_deferred()
	if not await enter_heist():
		return
	var outcome: Array[int] = [-1]
	EventBus.heist_ended.connect(func(r: Dictionary) -> void: outcome[0] = 1 if bool(r.get("success", false)) else 0)
	EventBus.alarm_raised.connect(func(reason: StringName, src: int) -> void:
		note("EVENT alarm_raised %s by %d at t=%.0f" % [reason, src, rt.heist_time_s]))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		note("EVENT objective %s -> %d t=%.0f" % [id, st, rt.heist_time_s]))
	await _stealth_to_last_call()
	if outcome[0] != -1:
		_finish(1 if outcome[0] == 0 else 0)
		return
	note("LOUD: handing over to auto_loud at t=%.0f (went_loud=%s)" % [rt.heist_time_s, rt.went_loud])
	var sc: Object = (load("res://tests/a/e2e/po5_flow_auto_loud.gd") as GDScript).new()
	var code: int = await sc.call(&"play", self)
	if code == 0 and outcome[0] == 0:
		note("FAIL the heist ended in failure (success=false)")
		code = 1
	await shot("end")
	_finish(code)


func _public_zones() -> Array[MapZone]:
	var out: Array[MapZone] = []
	for z: Node in rt.map.find_children("*", "Area3D", true, false):
		if z is MapZone and (z as MapZone).kind == MapZone.Kind.PUBLIC:
			out.append(z as MapZone)
	return out


func _leaving_patrons() -> int:
	var n: int = 0
	for c: Node in rt.npcs(&"civilian"):
		var b: CivilianBrain = c.get_node_or_null(^"Brain") as CivilianBrain
		if b != null and b.mode == CivilianBrain.Mode.LEAVE:
			n += 1
	return n


func _stealth_to_last_call() -> void:
	var zones: Array[MapZone] = _public_zones()
	var last_call_t: float = float(rt.mission.call(&"_scalar", &"last_call_s", 600))
	note("STEALTH: %d PUBLIC zones, last call at t=%.0f; casing tour unmasked" % [zones.size(), last_call_t])
	await shot("gala")
	var i: int = 0
	var warned: bool = false
	var called: bool = false
	var last_shot: float = rt.heist_time_s
	var end_t: float = last_call_t + _after_s
	while rt.heist_time_s < end_t and not rt.went_loud:
		if crew.crew_state != Enums.CrewState.NORMAL:
			note("crew state %d during casing" % crew.crew_state)
			break
		if not warned and rt.heist_time_s >= last_call_t - 60.0:
			warned = true
			note("LAST CALL WARNING t=%.0f at %s" % [rt.heist_time_s, Po5Pilot._v(crew.global_position)])
			await shot("last_call_warning")
		if not called and bool(rt.mission.get(&"_last_call")):
			called = true
			note("LAST CALL t=%.0f: PUBLIC zones now %d, patrons leaving %d, player at %s, detection max %.2f" % [
				rt.heist_time_s, _public_zones().size(), _leaving_patrons(), Po5Pilot._v(crew.global_position),
				_max_detection()])
			await shot("last_call")
		if rt.heist_time_s - last_shot > 60.0:
			last_shot = rt.heist_time_s
			note("casing t=%.0f zone %s detection max %.2f leaving %d" % [rt.heist_time_s,
				zones[i % zones.size()].name if not zones.is_empty() else "-", _max_detection(), _leaving_patrons()])
			await shot("casing_t%03d" % int(rt.heist_time_s))
		if zones.is_empty():
			await pilot.hold_position(3.0)
			continue
		var z: MapZone = zones[i % zones.size()]
		i += 1
		if not await pilot.goto(pilot.stand_point(z.global_position), 2.0, 40.0):
			note("zone %s at %s not reached" % [z.name, Po5Pilot._v(z.global_position)])
		await pilot.hold_position(4.0, func() -> bool: return rt.went_loud)
	note("STEALTH END t=%.0f went_loud=%s last_call=%s patrons leaving %d detection max %.2f" % [rt.heist_time_s,
		rt.went_loud, called, _leaving_patrons(), _max_detection()])
	await shot("after_last_call")


## Highest detection of the local player across living guards / cameras' NPCs (0..1).
func _max_detection() -> float:
	var best: float = 0.0
	for n: Node in rt.npcs():
		best = maxf(best, rt.detection_value(n as NpcBase, crew.slot))
	return best
