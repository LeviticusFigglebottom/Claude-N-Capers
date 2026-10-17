## SL-P1 (D-115 item 4): the first windowed REAL-INPUT pass of Shadow Ledger (stealth-only). Po5Pilot only (mouse
## look, WASD, crouch, F holds, G mask / bag throw): no teleports, no intent injection, no stealth_hidden on the route.
## Stated shortcuts: direct launch (no menus) with the dev preplan assets a player buys (asset.alternate_entry @
## pp_spawn_service: start in the PUBLIC L40 service lobby; asset.escape_position @ pp_escape_service: the L40 lift)
## and a seed whose rolls fit a stealth line (--scan lists them). Objective order from ENV A's x4_stealth_routes.gd:
## keycard (unless srv_contractor) -> ledger laptop -> secured -> cage code -> server door -> cage -> hack (restarted)
## -> 2 drive bags secured -> escape. Steps:
##   casing: unmasked walk of the PUBLIC / reachable L40 area (S1 lobby corners, S2 refuse, S3, Stair B L40 -> L41 ->
##     L42 landings and back) as a traversal + snag probe, then mask on the Stair B L41 landing;
##   then the route above, each leg walked by the pilot; a "careful" hook stops (crouched) and backs off when a guard
##   with a line of sight is facing the pilot, and waits for his back. Stops at the first failed step ("[SLR] FAIL").
## --tour: a separate traversal / snag tour of the main rooms and stairs of L41, L42 and the roof (masked, and
##   stealth_hidden = true so detection cannot end the walk: a stated shortcut for the snag probe only; movement is
##   still real input). --scan=A-B (headless OK): prints each seed's rolls with the preplan applied.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/sl_pass.tscn -- --out=/abs/dir [--seed=N] [--obs-out=DIR] [--tour] [--scan=1-40]
## Owner: ENV P.
extends Node

## Ids as "asset.<id>@<point>": the {id: point} form loses its point once PreplanPlan.resolve_ids is shipped (it
## takes only the ids; the escape fell back to the first point, pp_escape_heli, in every seed of the first scan).
const PREPLAN: Array[StringName] = [&"asset.alternate_entry@pp_spawn_service", &"asset.escape_position@pp_escape_service"]
const F40: float = 0.0
const F41: float = 3.6
const F42: float = 8.0
const FRF: float = 11.6
## Casing walk (PUBLIC S1/S2/S3 and the Stair B core; doc floor plans, wall centre lines).
const CASING_WPS: Array[Vector3] = [
	Vector3(25.0, F40, 8.5), Vector3(29.0, F40, 8.5), Vector3(29.0, F40, 11.6), Vector3(25.0, F40, 11.6),
	Vector3(24.75, F40, 13.5), Vector3(27.7, F40, 14.5), Vector3(24.75, F40, 15.6), Vector3(22.5, F40, 15.8),
	Vector3(22.5, F41, 15.8), Vector3(22.5, F42, 15.8), Vector3(22.5, F41, 15.8),
]
const MASK_AT: Vector3 = Vector3(22.5, F41, 15.8)
## Tour (masked, hidden): main rooms / corridors / stairs of L41, L42 and the roof.
const TOUR_WPS: Array = [
	["K10", Vector3(24.75, F41, 13.0)], ["K7", Vector3(30.0, F41, 6.75)], ["K12", Vector3(33.5, F41, 10.0)],
	["K7w", Vector3(25.0, F41, 6.75)], ["K3", Vector3(18.0, F41, 4.5)], ["K6", Vector3(6.0, F41, 6.75)],
	["K1", Vector3(3.5, F41, 3.0)], ["K8", Vector3(5.0, F41, 12.0)], ["K9", Vector3(11.25, F41, 12.0)],
	["K16w", Vector3(3.0, F41, 17.25)], ["K18", Vector3(9.0, F41, 21.0)], ["K16e", Vector3(33.0, F41, 17.25)],
	["K24", Vector3(33.0, F41, 21.0)], ["K16m", Vector3(13.0, F41, 17.25)], ["SA_L41", Vector3(13.5, F41, 15.8)],
	["SA_L42", Vector3(13.5, F42, 15.8)], ["M9", Vector3(11.25, F42, 12.0)], ["M1", Vector3(6.0, F42, 4.0)],
	["M2", Vector3(18.0, F42, 4.5)], ["M3w", Vector3(25.5, F42, 4.0)], ["M10", Vector3(24.75, F42, 12.0)],
	["M15", Vector3(20.0, F42, 17.25)], ["M8", Vector3(5.0, F42, 15.5)], ["SA_L42b", Vector3(13.5, F42, 15.8)],
	["SA_RF", Vector3(13.5, FRF, 15.8)], ["roof_s", Vector3(20.0, FRF, 17.0)], ["roof_pad", Vector3(30.0, FRF, 8.0)],
	["roof_n", Vector3(10.0, FRF, 3.0)], ["SA_RFb", Vector3(13.5, FRF, 15.8)], ["SA_L41b", Vector3(13.5, F41, 15.8)],
	["K3feat", Vector3(14.0, F41, 3.5)], ["feat_top", Vector3(19.5, F42, 1.3)],
]
## The west wing (K1 / K8 / K6) by the south spine and the west core corridor, never through K3 reception (run 1:
## the navmesh line K7 -> ReceptionGlassE -> K3 walked into the reception guard and a civilian, civilian_call t=99).
const WEST_VIA: Array[Vector3] = [Vector3(24.75, F41, 15.0), Vector3(20.0, F41, 17.25), Vector3(11.25, F41, 17.25),
	Vector3(11.25, F41, 10.0), Vector3(9.0, F41, 6.75)]
## A guard with a line of sight within this range, facing within CAREFUL_HALF_FOV of the pilot, makes it stop (m).
const CAREFUL_RANGE_M: float = 14.0
const CAREFUL_HALF_FOV: float = 1.4

## po5_flow's fast mode (read by po_observer as PO5Driver.fast): the render loop is off and the HUD canvas layers
## hidden between screenshots (llvmpipe: a drawn 960x540 frame took ~20 s on the shared box, 1 game s per 150 s).
var fast: bool = false
var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _seed: int = 1
var _tour: bool = false
var _scan: Vector2i = Vector2i.ZERO
var _shot: int = 0
var _alarm: StringName = &""
var _alarm_t: float = -1.0
var _t0_ms: int = 0
var _steps: Array[String] = []
var _det: Dictionary = {}  # observer net id -> {name, first_t, max, marks}
var _safe_pos: Vector3 = Vector3.INF
var _safe_t: float = 0.0
var _waits: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"seed": _seed = v.to_int()
			"tour": _tour = true
			"scan":
				var ab: PackedStringArray = v.split("-")
				_scan = Vector2i(ab[0].to_int(), ab[1].to_int() if ab.size() > 1 else ab[0].to_int())
			"obs-out":
				var n: Node = Node.new()
				n.name = "POObserver"
				n.set_script(load("res://tests/p/_review/po_observer.gd"))
				get_tree().root.add_child.call_deferred(n)
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/sl_pass"
	# Harness only: let physics catch up when a process frame is slow (game logic is untouched; 60 Hz ticks).
	Engine.max_physics_steps_per_frame = 30
	DirAccess.make_dir_recursive_absolute(runner_out)
	if _scan != Vector2i.ZERO:
		_run_scan.call_deferred()
	else:
		_run.call_deferred()


func note(msg: String) -> void:
	print("[SLR %.1fs t=%.1f] %s" % [(Time.get_ticks_msec() - _t0_ms) / 1000.0, rt.heist_time_s if rt != null else -1.0,
		msg])


func shot(label: String) -> void:
	var was_fast: bool = fast
	if was_fast:
		_canvas_layers(true)
		RenderingServer.render_loop_enabled = true
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [runner_out, _shot, label])
	if was_fast and fast:
		RenderingServer.render_loop_enabled = false
		_canvas_layers(false)


func set_fast(on: bool) -> void:
	fast = on
	RenderingServer.render_loop_enabled = not on
	_canvas_layers(not on)


func _canvas_layers(show: bool) -> void:
	for n: Node in get_tree().root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = show


func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func wait_until(cond: Callable, timeout_s: float) -> bool:
	for _i: int in int(timeout_s * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


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
	return int(rt.mission.objective_state(id))


func _slot(group: StringName, slot_id: StringName) -> bool:
	var v: Variant = rt.mission.variant(group)
	return v is Array and (v as Array).has(slot_id)


# --- Scan ---------------------------------------------------------------------------------------

func _run_scan() -> void:
	for s: int in range(_scan.x, _scan.y + 1):
		var r: HeistRuntime = await HeistLauncher.launch(&"shadow_ledger", s, Enums.Difficulty.ROUTINE, self,
			{"crew_ai": false, "preplanning": PREPLAN})
		if r == null:
			print("[SLSCAN] seed %d: no runtime" % s)
			continue
		var keys: Array = [&"camera", &"security_room_staffed", &"server_room", &"keycard", &"code_note", &"laptop",
			&"guard_post", &"guard_extra", &"cleaners", &"late_partner", &"escape", &"kessler"]
		var parts: PackedStringArray = PackedStringArray()
		for k: StringName in keys:
			parts.append("%s=%s" % [k, r.mission.variant(k)])
		print("[SLSCAN] seed %d %s spawn=%s guards=%d civs=%d" % [s, " ".join(parts),
			Po5Pilot._v((r.crew_controller(0) as Node3D).global_position), r.npcs(&"guard").size(),
			r.npcs(&"civilian").size()])
		r.teardown()
		for _i: int in 3:
			await get_tree().process_frame
	get_tree().quit(0)


# --- Run ----------------------------------------------------------------------------------------

func _run() -> void:
	_t0_ms = Time.get_ticks_msec()
	set_fast(true)
	rt = await HeistLauncher.launch(&"shadow_ledger", _seed, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "preplanning": PREPLAN})
	if rt == null:
		print("[SLR] RESULT FAIL no runtime")
		get_tree().quit(1)
		return
	EventBus.alarm_raised.connect(_on_alarm)
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		note("objective %s -> %d" % [id, st]))
	EventBus.detection_progress.connect(_on_detection)
	EventBus.npc_alert_state_changed.connect(func(nid: int, o: int, n: int) -> void:
		var npc: Node = Ids.lookup(nid)
		note("ALERT %s %d -> %d (dist %.1f)" % [npc.name if npc != null else str(nid), o, n,
			(npc as Node3D).global_position.distance_to(pilot.crew.global_position) if npc is Node3D and pilot != null
			else -1.0]))
	EventBus.pager_started.connect(func(_p: int, gid: int) -> void: note("PAGER started (guard %s)" % gid))
	EventBus.heist_ended.connect(func(r: Dictionary) -> void:
		note("HEIST ENDED %s" % r)
		if _alarm != &"":
			_fail.call_deferred("heist ended after the alarm"))
	var vparts: PackedStringArray = PackedStringArray()
	for k: StringName in [&"camera", &"security_room_staffed", &"server_room", &"keycard", &"code_note", &"laptop",
			&"guard_post", &"guard_extra", &"cleaners", &"late_partner", &"escape", &"laser_pattern"]:
		vparts.append("%s=%s" % [k, rt.mission.variant(k)])
	note("seed %d variants %s" % [_seed, " ".join(vparts)])
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(2.0)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	pilot.no_blind_press = true
	pilot.arrive_dy = 1.0
	await pilot.calibrate()
	note("spawn %s masked %s" % [Po5Pilot._v(c.global_position), c.masked])
	await shot("spawn")
	if _tour:
		await _run_tour()
		return
	var steps: Array[Callable] = [_casing, _mask, _enter_l41, _keycard, _laptop, _cage_code, _server_door, _cage,
		_hack, _drives, _escape]
	for step: Callable in steps:
		if _alarm != &"":
			await _fail("alarm before %s" % step.get_method())
			return
		note("STEP %s begin" % step.get_method())
		var ok: bool = await step.call()
		_steps.append("%s=%s" % [step.get_method(), "ok" if ok else "FAIL"])
		note("STEP %s %s" % [step.get_method(), "reached" if ok else "NOT reached"])
		if not ok:
			await _fail(step.get_method())
			return
	_summary()
	print("[SLR] RESULT PASS")
	_quit(0)


func _quit(code: int) -> void:
	set_fast(false)
	get_tree().quit(code)


func _on_alarm(reason: StringName, src: int) -> void:
	if _alarm == &"":
		_alarm = reason
		_alarm_t = rt.heist_time_s
	var n: Node = Ids.lookup(src)
	note("ALARM %s source %s (pilot at %s)" % [reason, n.get_path() if n != null else str(src),
		Po5Pilot._v(pilot.crew.global_position) if pilot != null else "-"])


func _on_detection(oid: int, slot: int, value: float, kind: int) -> void:
	if pilot == null or slot != pilot.crew.slot:
		return
	var e: Dictionary = _det.get(oid, {})
	if e.is_empty():
		var n: Node = Ids.lookup(oid)
		e = {"name": String(n.name) if n != null else str(oid), "kind": kind, "first_t": rt.heist_time_s, "max": 0.0,
			"mark": 0}
		_det[oid] = e
		note("DETECT start: %s (kind %d) at %.1f m, pilot %s crouched %s" % [e["name"], kind,
			(n as Node3D).global_position.distance_to(pilot.crew.global_position) if n is Node3D else -1.0,
			Po5Pilot._v(pilot.crew.global_position), pilot.crew.crouched])
	e["max"] = maxf(float(e["max"]), value)
	var mark: int = int(value * 4.0)
	if mark > int(e["mark"]):
		e["mark"] = mark
		note("DETECT %s meter %.2f (%.1f s after first sight)" % [e["name"], value, rt.heist_time_s - float(e["first_t"])])


func _summary() -> void:
	note("SUMMARY steps: %s" % ", ".join(_steps))
	note("SUMMARY alarm: %s at t=%.1f" % [_alarm, _alarm_t])
	for oid: Variant in _det:
		var e: Dictionary = _det[oid]
		note("SUMMARY detector %s kind %d first t=%.1f max %.2f" % [e["name"], e["kind"], e["first_t"], e["max"]])
	note("SUMMARY careful waits %d, STUCK rows %d" % [_waits, pilot.stuck_spots.size() if pilot != null else 0])
	if pilot != null:
		for r: Dictionary in pilot.stuck_spots:
			note("SUMMARY STUCK at %s toward %s: %s" % [Po5Pilot._v(r["pos"]), Po5Pilot._v(r["toward"]), r["hits"]])


func _fail(step: String) -> void:
	note("FAIL %s (alarm %s)" % [step, _alarm])
	await shot("fail_" + step.replace(" ", "_"))
	_summary()
	print("[SLR] RESULT FAIL at %s" % step)
	_quit(1)


# --- Careful hook -------------------------------------------------------------------------------

## A live guard or civilian (both see a masked crew, S1.4) facing the pilot with a line of sight within CAREFUL_RANGE_M.
func _watcher() -> NpcBase:
	var c: CrewController = pilot.crew
	var who: Array[Node] = rt.npcs(&"guard")
	who.append_array(rt.npcs(&"civilian"))
	for n: Node in who:
		var g: NpcBase = n as NpcBase
		var cb: CivilianBrain = g.get_node_or_null(^"Brain") as CivilianBrain if g != null else null
		if cb != null and cb.mode in [CivilianBrain.Mode.TIED, CivilianBrain.Mode.DOWN, CivilianBrain.Mode.DEAD]:
			continue
		if g == null or not g.is_alive() or absf(g.global_position.y - c.global_position.y) > 2.0:
			continue
		var to_me: Vector3 = c.global_position - g.global_position
		to_me.y = 0.0
		if to_me.length() > CAREFUL_RANGE_M:
			continue
		var fwd: Vector3 = -g.global_basis.z
		fwd.y = 0.0
		if to_me.length() > 1.0 and absf(fwd.angle_to(to_me)) > CAREFUL_HALF_FOV:
			continue
		if pilot.has_los(g.head_position(), g):
			return g
	return null


func _careful_need() -> bool:
	if not pilot.crew.masked or _alarm != &"":
		return false
	var w: NpcBase = _watcher()
	if w == null:
		if rt.heist_time_s - _safe_t > 0.5:
			_safe_pos = pilot.crew.global_position
			_safe_t = rt.heist_time_s
		return false
	return true


## Stop, back off to the last unseen spot, crouch and wait (up to 40 s) until no guard faces us with LOS.
func _careful() -> bool:
	var w: NpcBase = _watcher()
	if w == null:
		return false
	_waits += 1
	if w.is_in_group(G.CIVILIAN):
		return await _subdue(w)
	note("careful: %s faces the pilot at %.1f m (alert %d): back off to %s and wait" % [w.name,
		w.global_position.distance_to(pilot.crew.global_position), w.alert_state, Po5Pilot._v(_safe_pos)])
	pilot.inp.release(&"move_forward")
	pilot.inp.press(&"crouch")
	if _safe_pos != Vector3.INF and pilot.flat_dist(_safe_pos, pilot.crew.global_position) > 0.4:
		await pilot.goto(_safe_pos, 0.4, 4.0, false, false)
	var clear: bool = await wait_until(func() -> bool: return _watcher() == null or _alarm != &"", 40.0)
	await wait_s(1.0)
	pilot.inp.release(&"crouch")
	note("careful: %s (waited, watcher now %s)" % ["clear" if clear else "timed out", _watcher()])
	return true


## PD2 (S7.1 / S3.2): a civilian who can see the masked pilot is shouted to the floor (F tap aimed at them) and
## cable-tied (hold F on them). Run 2: crouching and waiting in her view let her meter fill in 3.6 s (civilian_call).
func _subdue(civ: NpcBase) -> bool:
	var b: CivilianBrain = civ.get_node_or_null(^"Brain") as CivilianBrain
	if b == null or b.mode in [CivilianBrain.Mode.TIED, CivilianBrain.Mode.DEAD]:
		return false
	pilot.inp.release(&"move_forward")
	for k: int in 4:
		if b.mode == CivilianBrain.Mode.DOWN or b.mode == CivilianBrain.Mode.TIED:
			break
		note("subdue: shouting %s (mode %d, %.1f m, meter %.2f)" % [civ.name, b.mode,
			civ.global_position.distance_to(pilot.crew.global_position), rt.detection_value(civ, pilot.crew.slot)])
		await pilot.face(civ.global_position + Vector3(0, 1.3, 0), 0.05, 1.0)
		await pilot.inp.tap(&"shout")
		await wait_s(1.0)
		if b.mode != CivilianBrain.Mode.DOWN and k >= 1:
			await pilot.goto(civ.global_position, 3.0, 3.0, false, false)
	if b.mode != CivilianBrain.Mode.DOWN:
		note("subdue: %s not down (mode %d)" % [civ.name, b.mode])
		return true
	for comp: Node in civ.find_children("*", "InteractableComponent", true, false):
		var ic: InteractableComponent = comp as InteractableComponent
		if ic.kind == &"cable_tie" and ic.enabled:
			note("subdue: tying %s (%s)" % [civ.name, ic.availability(pilot.crew)])
			await pilot.use(ic, 20.0, func() -> bool: return b.mode == CivilianBrain.Mode.TIED)
			break
	note("subdue: %s mode %d" % [civ.name, b.mode])
	await shot("subdued_%s" % civ.name)
	return true


# --- Steps --------------------------------------------------------------------------------------

func _go(label: String, at: Vector3, timeout_s: float = 90.0) -> bool:
	var ok: bool = await pilot.goto(at, 0.6, timeout_s)
	note("goto %s %s: %s (at %s)" % [label, Po5Pilot._v(at), "reached" if ok else "NOT reached",
		Po5Pilot._v(pilot.crew.global_position)])
	return ok


func _casing() -> bool:
	var missed: int = 0
	for i: int in CASING_WPS.size():
		if not await _go("casing_%d" % i, CASING_WPS[i]):
			missed += 1
			await shot("casing_miss_%d" % i)
		if i in [3, 5, 8, 9]:
			await shot("casing_%d" % i)
	return missed == 0 or pilot.flat_dist(pilot.crew.global_position, MASK_AT) < 1.0


func _mask() -> bool:
	if not pilot.near(pilot.crew.global_position, MASK_AT, 1.0):
		await _go("mask spot", MASK_AT)
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await wait_s(0.5)
	note("masked %s" % pilot.crew.masked)
	pilot.hook_need = _careful_need
	pilot.hook = _careful
	return pilot.crew.masked


## Stair B L41 door: lockpick 8 s from the stair side.
func _enter_l41() -> bool:
	var d: Door = _door("StairBL41")
	if d == null:
		note("no StairBL41")
		return false
	if not d.is_open:
		await pilot.use(_comp(d), 40.0, func() -> bool: return d.is_open)
	note("StairBL41 open %s (lock %s)" % [d.is_open, d.get(&"lock")])
	await shot("stair_b_l41")
	return d.is_open


func _keycard() -> bool:
	if _objective(&"keycard") == 2:
		note("keycard objective already done (srv_contractor)")
		return true
	var best: Node3D = null
	for k: Node in rt.mission.find_tagged(&"keycard"):
		var n3: Node3D = k as Node3D
		var ic: InteractableComponent = _comp(n3)
		if n3 == null or ic == null or not ic.enabled or not n3.is_inside_tree():
			continue
		var dd: float = n3.global_position.distance_to(pilot.crew.global_position) + absf(n3.global_position.y - F41) * 10.0
		if best == null or dd < best.global_position.distance_to(pilot.crew.global_position) \
				+ absf(best.global_position.y - F41) * 10.0:
			best = n3
	if best == null:
		note("no keycard in the map")
		return false
	note("keycard: %s at %s" % [best.get_parent().name, Po5Pilot._v(best.global_position)])
	var ok: bool = await pilot.use(_comp(best), 120.0, func() -> bool: return pilot.crew.item_count(&"item.keycard") > 0)
	await shot("keycard")
	return ok or pilot.crew.item_count(&"item.keycard") > 0


func _carry_and_secure(src: Node3D, what: String) -> bool:
	var ic: InteractableComponent = _comp(src)
	if ic == null:
		note("%s: no interactable" % what)
		return false
	if not pilot.crew.is_carrying_bag() and not await pilot.use(ic, 120.0,
			func() -> bool: return pilot.crew.is_carrying_bag()):
		note("%s not bagged (at %s, target %s)" % [what, Po5Pilot._v(pilot.crew.global_position),
			Po5Pilot._v(src.global_position)])
		return false
	var zone: SecureZone = pilot.secure_zone()
	if zone == null:
		note("no secure zone")
		return false
	note("%s bagged: carrying to %s" % [what, Po5Pilot._v(zone.global_position)])
	var ok: bool = await _secure(zone)
	note("%s secured %s (at %s)" % [what, ok, Po5Pilot._v(pilot.crew.global_position)])
	await shot("%s_secured" % what.replace(" ", "_"))
	return ok


## Po5Pilot.secure_carried_bag stops 3 m short (run 3: at (24.5, 0, 11.0), 2 m from the lift's nav point, it threw
## the laptop into the lobby wall beside the car opening). Walk to the zone's nearest nav point, face the zone's
## centre and throw (G); one retry from closer after picking the bag back up.
func _secure(zone: SecureZone) -> bool:
	var secured: Array[int] = [0]
	var cb: Callable = func(_b: int, _l: StringName, _v: int) -> void: secured[0] += 1
	EventBus.loot_secured.connect(cb)
	var target: Vector3 = zone.global_position
	for attempt: int in 2:
		var stand: Vector3 = pilot.stand_point(target)
		await pilot.goto(stand, 0.4, 120.0)
		await pilot.face(target + Vector3(0, 0.6, 0), 0.04, 2.0)
		note("secure try %d: throw from %s at %s (stand %s)" % [attempt, Po5Pilot._v(pilot.crew.global_position),
			Po5Pilot._v(target), Po5Pilot._v(stand)])
		await pilot.inp.tap(&"drop_bag")
		await wait_until(func() -> bool: return secured[0] > 0, 6.0)
		if secured[0] > 0:
			break
		var bag: LootBag = null
		for n: Node in get_tree().get_nodes_in_group(G.LOOT_BAG):
			var lb: LootBag = n as LootBag
			if lb != null and (bag == null or lb.global_position.distance_to(pilot.crew.global_position)
					< bag.global_position.distance_to(pilot.crew.global_position)):
				bag = lb
		await shot("secure_miss_%d" % attempt)
		if bag == null:
			note("secure: thrown bag not found")
			break
		note("secure: bag landed at %s; picking it up again" % Po5Pilot._v(bag.global_position))
		await pilot.use(_comp(bag), 30.0, func() -> bool: return pilot.crew.is_carrying_bag())
	EventBus.loot_secured.disconnect(cb)
	return secured[0] > 0


func _laptop() -> bool:
	var lap: Node3D = _tagged(&"laptop")
	if lap == null:
		note("no laptop")
		return false
	note("laptop at %s (%s)" % [Po5Pilot._v(lap.global_position), rt.mission.variant(&"laptop")])
	var west: bool = lap.global_position.x < 12.0 and absf(lap.global_position.y - F41) < 1.0
	if west and not await _via(WEST_VIA, "west wing"):
		return false
	var ic: InteractableComponent = _comp(lap)
	if not await pilot.use(ic, 120.0, func() -> bool: return pilot.crew.is_carrying_bag()):
		note("laptop not bagged (at %s)" % Po5Pilot._v(pilot.crew.global_position))
		return false
	await shot("laptop_bagged")
	if west:
		var back: Array[Vector3] = WEST_VIA.duplicate()
		back.reverse()
		back.append(MASK_AT)
		if not await _via(back, "back to Stair B"):
			return false
	return await _carry_and_secure(lap, "laptop")


## Walks `points` in order (each a pilot goto); false at the first point not reached.
func _via(points: Array[Vector3], label: String) -> bool:
	for i: int in points.size():
		if not await _go("%s %d" % [label, i], points[i], 90.0):
			return false
	return true


func _cage_code() -> bool:
	if _objective(&"cage") == 2 or _objective(&"cage_code") == 2:
		return true
	var n: Node3D = _tagged(&"cage_code")
	if n == null:
		note("no cage code note")
		return false
	note("cage code at %s" % Po5Pilot._v(n.global_position))
	return await pilot.use(_comp(n), 120.0, func() -> bool: return _objective(&"cage_code") == 2)


func _server_door() -> bool:
	if _objective(&"server_door") == 2:
		return true
	var r: Node3D = _tagged(&"server_reader")
	if r == null:
		note("no server reader")
		return false
	var ok: bool = await pilot.use(_comp(r), 120.0, func() -> bool: return _objective(&"server_door") == 2)
	await shot("server_door")
	return ok


func _cage() -> bool:
	if _objective(&"cage") == 2:
		return true
	var cage: Node3D = _tagged(&"cage")
	if cage == null:
		return false
	var ok: bool = await pilot.use(_comp(cage), 120.0, func() -> bool: return _objective(&"cage") == 2)
	await shot("cage")
	return ok


func _hack() -> bool:
	var ht: HackTerminal = _tagged(&"hack") as HackTerminal
	if ht == null:
		return false
	if not await pilot.use(_comp(ht), 60.0, func() -> bool: return ht.state != HackTerminal.State.IDLE):
		note("hack not started")
		return false
	await shot("hack_started")
	var restarts: int = 0
	var t: float = 0.0
	while ht.state != HackTerminal.State.DONE and t < 400.0 and _alarm == &"":
		await pilot.hold_position(1.0)
		t += 1.0
		if ht.state == HackTerminal.State.INTERRUPTED:
			restarts += 1
			note("hack interrupted (#%d): restart" % restarts)
			await pilot.use(_comp(ht), 60.0, func() -> bool: return ht.state != HackTerminal.State.INTERRUPTED)
	note("hack state %d after %.0f s, %d restarts" % [ht.state, t, restarts])
	return ht.state == HackTerminal.State.DONE


func _drives() -> bool:
	var done: int = 0
	while done < 2:
		var src: LootSpawn = null
		for d: Node in rt.mission.find_tagged(&"drives"):
			var ls: LootSpawn = d as LootSpawn
			if ls != null and ls.remaining > 0 and (src == null or ls.remaining > src.remaining):
				src = ls
		if src == null:
			note("no drive sled left")
			return false
		if not await _carry_and_secure(src, "drive %d" % done):
			return false
		done += 1
	return true


func _escape() -> bool:
	var ez: EscapeZone = pilot.active_escape()
	if ez == null:
		note("no active escape (secure %d)" % _objective(&"secure"))
		return false
	var ended: Array[bool] = [false]
	EventBus.heist_ended.connect(func(_r: Dictionary) -> void: ended[0] = true)
	await pilot.goto(ez.global_position, 1.0, 120.0)
	var t: float = 0.0
	while not ended[0] and t < 90.0:
		await pilot.hold_position(1.0)
		t += 1.0
	note("heist ended %s at %s" % [ended[0], Po5Pilot._v(pilot.crew.global_position)])
	await shot("escape")
	return ended[0]


# --- Tour ---------------------------------------------------------------------------------------

func _run_tour() -> void:
	await _casing()
	await _mask()
	pilot.hook_need = Callable()
	pilot.hook = Callable()
	pilot.crew.stealth_hidden = true  # stated shortcut: the snag tour must not end on detection
	await _enter_l41()
	var missed: PackedStringArray = PackedStringArray()
	for wp: Array in TOUR_WPS:
		if not await _go(String(wp[0]), wp[1], 120.0):
			missed.append(String(wp[0]))
			await shot("tour_miss_%s" % wp[0])
			if pilot.last_blocked_door != null:
				note("tour: blocked by %s" % pilot.last_blocked_door.name)
		elif String(wp[0]) in ["K3", "K16e", "M2", "M3w", "SA_RF", "roof_pad", "feat_top"]:
			await shot("tour_%s" % wp[0])
	note("TOUR missed: %s" % ", ".join(missed))
	_summary()
	print("[SLR] RESULT TOUR %s" % ("PASS" if missed.is_empty() else "MISSED %d" % missed.size()))
	_quit(0)
