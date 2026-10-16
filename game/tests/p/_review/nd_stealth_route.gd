## ND-2 (D-115 gate 4) route-aware Night Deposit STEALTH pass by real input (LEAD 2026-10-16; route from ENV A's
## layout read-out, 2026-10-16, and x4_stealth_routes.gd's objective order). Po5Pilot only (mouse look, WASD, crouch,
## F holds, melee, fire). Stated shortcuts: direct launch (no menus) with the dev preplan assets a player buys
## (asset.alternate_entry @ pp_spawn_lot, asset.vent_access @ pp_vent) and a seed whose rolls fit the line
## (default 21: cam_c = no C5 on the B5 spine, rover_ground, kc_records + code_records_ledger in B6, sec_empty,
## laser_static; nd_variant_scan.tscn lists others). Route: lot (unmasked, PUBLIC) -> AreawayGrate -> ladder -> B3
## (mask) -> PlantDoor -> B5: knife guard_basement at the gate from behind, answer his pager -> RecordsDoor -> B6:
## keycard + code -> VaultGate (keycard) -> C6 (antechamber camera) shot out (suppressed secondary, no operator)
## -> under the static lasers -> time-lock code -> the time lock runs out -> vault loot bagged and carried back out
## the same way to the lot van's secure zone -> escape. Stops at the first failed step ("[NDR] FAIL ...").
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/nd_stealth_route.tscn -- --out=/abs/dir [--seed=21] [--bags=2] [--obs-out=DIR]
## Owner: ENV P.
extends Node

const GRATE_AT: Vector3 = Vector3(16.95, 0.0, -1.4)
const LADDER_FOOT: Vector3 = Vector3(17.6, -4.0, -0.55)
const MASK_AT: Vector3 = Vector3(18.5, -4.0, 3.0)
const GATE_AT: Vector3 = Vector3(14.0, -4.0, 6.9)
const C6_AT: Vector3 = Vector3(9.1, -1.4, 8.8)

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _seed: int = 21
var _bags: int = 2
var _shot: int = 0
var _alarm: StringName = &""
var _t0_ms: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"seed": _seed = v.to_int()
			"bags": _bags = v.to_int()
			"obs-out":
				var n: Node = Node.new()
				n.name = "POObserver"
				n.set_script(load("res://tests/p/_review/po_observer.gd"))
				get_tree().root.add_child.call_deferred(n)
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/nd_stealth_route"
	DirAccess.make_dir_recursive_absolute(runner_out)
	_run.call_deferred()


func note(msg: String) -> void:
	print("[NDR %.1fs t=%.1f] %s" % [(Time.get_ticks_msec() - _t0_ms) / 1000.0, rt.heist_time_s if rt != null else -1.0,
		msg])


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [runner_out, _shot, label])


func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _fail(step: String) -> void:
	note("FAIL %s (alarm %s)" % [step, _alarm])
	await shot("fail_" + step.replace(" ", "_"))
	print("[NDR] RESULT FAIL at %s" % step)
	get_tree().quit(1)


func _tagged(tag: StringName) -> Node3D:
	for n: Node in rt.mission.find_tagged(tag):
		return n as Node3D
	return null


func _comp(node: Node, kind: StringName = &"") -> InteractableComponent:
	if node == null:
		return null
	if node is InteractableComponent and (kind == &"" or (node as InteractableComponent).kind == kind):
		return node as InteractableComponent
	for c: Node in node.find_children("*", "InteractableComponent", true, false):
		var ic: InteractableComponent = c as InteractableComponent
		if kind == &"" or ic.kind == kind:
			return ic
	return null


func _door(node_name: String) -> Door:
	return rt.find_child(node_name, true, false) as Door


func _objective(id: StringName) -> int:
	for o: Dictionary in rt.hud_model.objectives:
		if StringName(o["id"]) == id:
			return int(o["state"])
	return -1


func _run() -> void:
	_t0_ms = Time.get_ticks_msec()
	rt = await HeistLauncher.launch(&"night_deposit", _seed, Enums.Difficulty.ROUTINE, self, {
		"crew_ai": false, "preplanning": {&"asset.alternate_entry": &"pp_spawn_lot", &"asset.vent_access": &"pp_vent"}})
	if rt == null:
		print("[NDR] RESULT FAIL no runtime")
		get_tree().quit(1)
		return
	EventBus.alarm_raised.connect(func(reason: StringName, _s: int) -> void:
		if _alarm == &"":
			_alarm = reason
		note("ALARM %s" % reason))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		note("objective %s -> %d" % [id, st]))
	note("variants %s" % rt.variants)
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(2.0)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	await pilot.calibrate()
	note("spawn %s" % Po5Pilot._v(c.global_position))
	await shot("spawn_lot")
	for step: Callable in [_to_b3, _gate_guard, _records, _vault_gate, _antechamber, _time_lock, _loot, _escape]:
		if _alarm != &"":
			await _fail("alarm before %s" % step.get_method())
			return
		if not await step.call():
			if get_tree() != null and not get_tree().paused:
				await _fail(step.get_method())
			return
	note("RESULT PASS stealth, alarm %s" % _alarm)
	print("[NDR] RESULT PASS")
	get_tree().quit(0)


## Lot -> AreawayGrate (vent_open: casing-allowed) -> ladder -> AreawayDoor -> B3, mask.
func _to_b3() -> bool:
	var grate: Door = _door("AreawayGrate")
	if grate == null:
		note("no AreawayGrate")
		return false
	if not grate.is_open and not await pilot.use(_comp(grate), 20.0, func() -> bool: return grate.is_open):
		note("grate not opened (%s)" % grate.get(&"lock"))
		return false
	await shot("grate_open")
	if not await pilot.goto(LADDER_FOOT, 0.8, 60.0):
		note("ladder foot not reached (at %s)" % Po5Pilot._v(pilot.crew.global_position))
		return false
	if not await pilot.goto(MASK_AT, 0.8, 40.0):
		return false
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	note("masked in B3 (masked %s)" % pilot.crew.masked)
	await shot("b3_masked")
	return pilot.crew.masked


## B5: guard_basement at the gate (facing S): knife him from behind (the corridor's north side), answer the pager.
func _gate_guard() -> bool:
	var g: NpcBase = null
	for n: Node in rt.npcs(&"guard"):
		var npc: NpcBase = n as NpcBase
		if npc.global_position.distance_to(GATE_AT) < 3.0:
			g = npc
	if g == null:
		note("no guard at the gate (moved / rover); carrying on")
		return true
	var back: Vector3 = g.global_position + g.global_basis.z.normalized() * 0.8
	if not await pilot.goto(Vector3(back.x, g.global_position.y, back.z), 0.5, 40.0):
		note("could not get behind the gate guard")
		return false
	for _k: int in 3:
		if not g.is_alive():
			break
		await pilot.face(g.global_position + Vector3(0, 1.2, 0), 0.03, 1.0)
		await pilot.inp.hold(&"melee", 1.05)
		await wait_s(0.6)
	if g.is_alive():
		note("gate guard not knifed (alert %d)" % g.alert_state)
		return false
	await shot("gate_guard_knifed")
	for _k: int in 60:
		var pc: InteractableComponent = _comp(g, &"answer_pager")
		if pc != null and pc.enabled:
			note("answering the pager")
			return await pilot.use(pc, 20.0, func() -> bool: return not pc.enabled)
		if _alarm != &"":
			return false
		await wait_s(0.25)
	note("no pager came")
	return true


## B6 via RecordsDoor: the keycard and the time-lock code.
func _records() -> bool:
	var kc: Node3D = _tagged(&"keycard")
	var code: Node3D = _tagged(&"code_note")
	for pair: Array in [[kc, &"keycard"], [code, &"code"]]:
		var n: Node3D = pair[0]
		if n == null:
			note("no %s in this roll" % pair[1])
			continue
		var ic: InteractableComponent = _comp(n)
		if ic == null or not ic.enabled:
			continue
		var done: Callable = func() -> bool: return not ic.enabled or _objective(pair[1]) == 2
		if not await pilot.use(ic, 40.0, done):
			note("%s not taken (at %s)" % [pair[1], Po5Pilot._v(n.global_position)])
			return false
	await shot("records_done")
	return true


func _vault_gate() -> bool:
	var gate: Door = _tagged(&"vault_gate") as Door
	if gate == null:
		return false
	if not gate.is_open:
		await pilot.use(_comp(gate), 30.0, func() -> bool: return gate.is_open)
	note("vault gate open %s" % gate.is_open)
	await shot("vault_gate")
	return gate.is_open


## The antechamber: shoot out C6 (no operator in sec_empty), then crouch under the static lasers to the panel.
func _antechamber() -> bool:
	var cam: Node3D = null
	for n: Node in rt.find_children("*", "Node3D", true, false):
		var n3: Node3D = n as Node3D
		if n3.has_method(&"take_hit") and n3.global_position.distance_to(C6_AT) < 1.0 and String(n3.name).contains("Cam"):
			cam = n3
	if cam != null:
		await pilot.inp.tap(&"slot_secondary")
		await wait_s(1.0)
		for _k: int in 6:
			if not is_instance_valid(cam) or not cam.is_visible_in_tree():
				break
			await pilot.face(cam.global_position, 0.01, 1.0)
			await pilot.inp.tap(&"fire")
			await wait_s(0.4)
		note("camera C6 %s" % ("down" if not is_instance_valid(cam) or not cam.is_visible_in_tree() else "still up"))
	else:
		note("no C6 camera found near %s" % Po5Pilot._v(C6_AT))
	return true


func _time_lock() -> bool:
	var panel: Node3D = _tagged(&"time_lock")
	if panel == null:
		return false
	pilot.inp.press(&"crouch")  # static lasers: under them
	var ok: bool = await pilot.use(_comp(panel), 40.0, func() -> bool: return _objective(&"time_lock") == 2)
	pilot.inp.release(&"crouch")
	if not ok:
		return false
	var vault: Door = _tagged(&"vault_door") as Door
	var t: float = 0.0
	while vault != null and not vault.is_open and t < 120.0 and _alarm == &"":
		await pilot.hold_position(2.0)
		t += 2.0
	note("vault open %s after %.0f s" % [vault != null and vault.is_open, t])
	await shot("vault_open")
	return vault != null and vault.is_open


func _loot() -> bool:
	var zone: SecureZone = pilot.secure_zone()
	if zone == null:
		note("no secure zone")
		return false
	for i: int in _bags:
		var src: LootSpawn = null
		for s: Node in rt.mission.find_tagged(&"vault_loot"):
			var ls: LootSpawn = s as LootSpawn
			if ls != null and ls.remaining > 0 and (src == null or ls.remaining > src.remaining):
				src = ls
		if src == null:
			break
		var ic: InteractableComponent = _comp(src)
		if not await pilot.use(ic, 30.0, func() -> bool: return pilot.crew.is_carrying_bag()):
			note("bag %d not taken" % i)
			return false
		note("carrying bag %d out to %s" % [i, Po5Pilot._v(zone.global_position)])
		if not await pilot.secure_carried_bag(zone):
			note("bag %d not secured (at %s)" % [i, Po5Pilot._v(pilot.crew.global_position)])
			await shot("bag_%d_not_secured" % i)
			return false
	await shot("bags_secured")
	return true


func _escape() -> bool:
	var ez: EscapeZone = pilot.active_escape()
	if ez == null:
		note("no active escape (secure objective %d)" % _objective(&"secure"))
		return false
	var ended: Array[bool] = [false]
	EventBus.heist_ended.connect(func(_r: Dictionary) -> void: ended[0] = true)
	await pilot.goto(ez.global_position, 1.0, 120.0)
	var t: float = 0.0
	while not ended[0] and t < 30.0:
		await pilot.hold_position(1.0)
		t += 1.0
	note("heist ended %s" % ended[0])
	return ended[0]
