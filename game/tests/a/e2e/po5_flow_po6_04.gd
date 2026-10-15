## PO6-04 windowed check (D-114 §1): on Golden Hour the workshop safe opens in stealth WITHOUT the drill.
## Real input from the workshop door on (Po5Pilot: mouse look, WASD, F holds): lockpick the workshop door, read
## the code note (or take the keycard), enter the code at the safe (or swipe the reader). Harness shortcuts, so
## the run stays short on llvmpipe: the crew starts at the workshop door (teleport) and the NPCs and cameras are
## removed (detection is not under test here, the silent route is). Fails on any drill start or alarm.
## usage: game/tests/a/e2e/run_po5.sh po6_04 7 1800 <out_dir>
extends RefCounted

var f: Node = null
var p: Po5Pilot = null
var _drills: int = 0
var _alarms: int = 0


func play(flow: Node) -> int:
	f = flow
	p = flow.get(&"pilot") as Po5Pilot
	var rt: HeistRuntime = f.get(&"rt") as HeistRuntime
	var crew: CrewController = f.get(&"crew") as CrewController
	EventBus.device_started.connect(func(_id: int, kind: StringName, _d: float) -> void:
		if kind == &"drill" or kind == &"saw":
			_drills += 1)
	EventBus.alarm_raised.connect(func(_r: StringName, _s: int) -> void: _alarms += 1)
	for o: Dictionary in rt.mission.objectives():
		f.note("objective %s state %d data %s" % [o["id"], o["state"], o["data"]])
	f.note("markers: %s" % [rt.hud_model.objective_markers.map(func(m: Dictionary) -> String:
		return "%s@%s" % [m["id"], Po5Pilot._v(m["position"])])])
	await f.shot("po6_04_objectives")
	rt.isolate_npc(null)
	for cam: Node in rt.find_by_tag(&"security_camera"):
		cam.get_parent().remove_child(cam)
		cam.queue_free()
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(7.5, 0.05, 6.2)))
	await f.wait_s(1.0)
	await p.inp.hold(&"mask_up", 1.4)
	await f.wait_s(0.5)
	var wdoor: InteractableComponent = _comp(rt, &"workshop_door")
	var door: Door = wdoor.owner_node() as Door
	if not door.is_open:
		await p.use(wdoor, 20.0, func() -> bool: return door.is_open)
	if not door.is_open:
		await f.shot("po6_04_workshop_locked")
		f.note("FAIL workshop door did not open")
		return 1
	var safe: Safe = rt.mission.find_tagged(&"safe")[0] as Safe
	var note_c: InteractableComponent = _comp(rt, &"code_note")
	if note_c != null:
		await p.use(note_c, 10.0, func() -> bool: return CodeRegistry.of(rt).is_known(safe.code_group))
		f.note("code note read: %s (code %s)" % [CodeRegistry.of(rt).is_known(safe.code_group),
			CodeRegistry.of(rt).code_for(safe.code_group)])
		await f.shot("po6_04_code_read")
	f.note("safe offers: %s" % safe.method_for(crew))
	if safe.method_for(crew) == &"code":
		await p.use(safe.interactable, 10.0, func() -> bool: return safe.opened)
	else:
		var card: InteractableComponent = _comp(rt, &"keycard")
		if card != null:
			await p.use(card, 10.0, func() -> bool: return crew.item_count(&"item.keycard") > 0)
		await p.use(_comp(rt, &"safe_reader"), 10.0, func() -> bool: return safe.opened)
	await f.wait_s(1.5)
	await f.shot("po6_04_safe_open" if safe.opened else "po6_04_safe_closed")
	f.note("safe opened=%s beaten_by=%s drills=%d alarms=%d phase=%d objective safe=%d" % [safe.opened, safe.beaten_by,
		_drills, _alarms, rt.phase, rt.mission.objective_state(&"safe")])
	return 0 if safe.opened and _drills == 0 and _alarms == 0 else 1


func _comp(rt: HeistRuntime, tag: StringName) -> InteractableComponent:
	for n: Node in rt.mission.find_tagged(tag):
		var c: InteractableComponent = n.get_node_or_null(^"Interactable") as InteractableComponent
		if c != null:
			return c
	return null
