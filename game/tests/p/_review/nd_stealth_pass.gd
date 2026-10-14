## PO pass (lead 2026-10-14): a partial Night Deposit STEALTH run by player input, for the observer's checks
## (crew stacking, prompts, oddities) in stealth. No menus: the heist is launched directly. A's Po5Pilot walks
## (mouse look, WASD, F, G, melee); this script is its driver (note / shot / wait_s, like po5_flow). Plan:
## case for a few seconds, mask, then follow the HUD objective markers and use what is usable at each (doors,
## keycards, keypads, hack, bags); a guard within 2.5 m who is noticing us gets the knife; a pager within 15 m
## is answered; D-111 coverage: a civilian within 6 m is shouted down (F tap) and tied (up to 3), and the weapon
## is swapped every 45 s (draw / holster, the secondary's set); it ends at the alarm (went loud), the heist end or
## --budget heist seconds. A partial run is fine.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 \
##     res://tests/p/_review/nd_stealth_pass.tscn -- --obs-out=/abs/dir [--budget=600] [--seed=1002]
## Prints "[NDS ...]" lines; the observer (po_observer.gd) logs its flags under --obs-out. Owner: ENV P.
extends Node

const SKIP_KINDS: Array[StringName] = [&"revive", &"tie", &"bag_body", &"lockpick_safe"]

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _budget: float = 600.0
var _seed: int = 1002
var _shot: int = 0
var _ended: bool = false
var _knifed: int = 0
var _pagers: int = 0
var _tied: int = 0
var _swaps: int = 0
var _shouted: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"obs-out": runner_out = v
			"budget": _budget = v.to_float()
			"seed": _seed = v.to_int()
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/nd_stealth"
	DirAccess.make_dir_recursive_absolute(runner_out)
	for pair: Array in [["POObserver", "res://tests/p/_review/po_observer.gd"],
			["AnimCoverage", "res://tests/p/_review/anim_coverage.gd"]]:  # D-111: --anim-out=DIR
		var n: Node = Node.new()
		n.name = pair[0]
		n.set_script(load(pair[1]))
		get_tree().root.add_child.call_deferred(n)
	_run.call_deferred()


func note(msg: String) -> void:
	print("[NDS %.1fs t=%.1f] %s" % [Time.get_ticks_msec() / 1000.0, rt.heist_time_s if rt != null else -1.0, msg])


func shot(label: String) -> void:
	_fast(false)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [runner_out, _shot, label])
	_fast(true)


## Like A's po5_flow.set_fast: llvmpipe renders at ~1 fps, which caps game time, so the render loop (and the HUD
## canvas work) is off between screenshots. Window, DisplayServer and input stay real.
func _fast(on: bool) -> void:
	RenderingServer.render_loop_enabled = not on
	for n: Node in get_tree().root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = not on


func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _run() -> void:
	rt = await HeistLauncher.launch(&"night_deposit", _seed, Enums.Difficulty.ROUTINE, self, {})
	if rt == null:
		note("RESULT FAIL no runtime")
		get_tree().quit(1)
		return
	EventBus.heist_ended.connect(func(r: Dictionary) -> void:
		_ended = true
		note("EVENT heist_ended success=%s" % r.get("success", false)))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		note("EVENT objective %s -> %d" % [id, st]))
	EventBus.alarm_raised.connect(func(reason: StringName, _src: int) -> void:
		note("EVENT alarm_raised %s" % reason))
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(2.0)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	await pilot.calibrate()
	await shot("casing")
	# Casing: a few metres toward the first marker, unmasked.
	var first: Array[Dictionary] = rt.hud_model.objective_markers
	if not first.is_empty():
		await pilot.goto(pilot.stand_point(first[0]["position"]), 2.0, 20.0)
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	note("masked")
	var t0: float = rt.heist_time_s
	var last_shot: float = -100.0
	var last_swap: float = rt.heist_time_s
	while not _ended and not rt.went_loud and rt.heist_time_s - t0 < _budget:
		if c.crew_state != Enums.CrewState.NORMAL:
			note("crew state %d: stopping" % c.crew_state)
			break
		if rt.heist_time_s - last_shot > 30.0:
			last_shot = rt.heist_time_s
			await shot("t%03d" % int(rt.heist_time_s))
		if rt.heist_time_s - last_swap > 45.0:
			last_swap = rt.heist_time_s
			await pilot.inp.tap(&"swap_weapon")
			await wait_s(1.5)
			_swaps += 1
		if await _answer_pager(c) or await _knife_noticer(c) or await _intimidate(c):
			continue
		await _step()
	var how: String = "ended" if _ended else ("went loud" if rt.went_loud else "budget")
	note("RESULT %s at t=%.0f, knifed %d, pagers %d, tied %d, swaps %d, objectives %s" % [how, rt.heist_time_s,
		_knifed, _pagers, _tied, _swaps,
		rt.hud_model.objectives.map(func(o: Dictionary) -> String: return "%s:%d" % [o["id"], o["state"]])])
	await shot("end")
	RenderingServer.render_loop_enabled = true
	get_tree().quit(0)


## One decision: walk to the first non-generic active marker and use what is there.
func _step() -> void:
	var markers: Array[Dictionary] = rt.hud_model.objective_markers
	if markers.is_empty():
		await pilot.hold_position(2.0)
		return
	var m: Dictionary = markers[0]
	for mk: Dictionary in markers:
		if not (StringName(mk["id"]) in [&"secure", &"escape", &"casing"]):
			m = mk
			break
	var pos: Vector3 = m["position"]
	var comp: InteractableComponent = _usable_near(pos, 2.5)
	if comp != null:
		note("use %s/%s (%s) for %s" % [comp.get_parent().name, comp.name, comp.kind, m["id"]])
		await pilot.use(comp, 30.0, func() -> bool: return not comp.enabled or comp.availability(pilot.crew) != &"")
		return
	if pilot.flat_dist(pilot.crew.global_position, pos) > 3.0:
		if not await pilot.goto(pilot.stand_point(pos), 2.0, 30.0):
			note("marker %s at %s not reached" % [m["id"], Po5Pilot._v(pos)])
		return
	await pilot.hold_position(3.0)


func _usable_near(pos: Vector3, radius: float) -> InteractableComponent:
	var best: InteractableComponent = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var comp: InteractableComponent = n as InteractableComponent
		if comp == null or not comp.enabled or comp.kind in SKIP_KINDS or not rt.is_ancestor_of(comp):
			continue
		if comp.availability(pilot.crew) != &"":
			continue
		var d: float = comp.global_position.distance_to(pos)
		if d < radius and d < best_d:
			best = comp
			best_d = d
	return best


func _answer_pager(c: CrewController) -> bool:
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var comp: InteractableComponent = n as InteractableComponent
		if comp != null and comp.enabled and comp.kind == &"answer_pager" and rt.is_ancestor_of(comp) \
				and comp.global_position.distance_to(c.global_position) < 15.0:
			note("answering a pager at %s" % Po5Pilot._v(comp.global_position))
			if await pilot.use(comp, 20.0, func() -> bool: return not comp.enabled):
				_pagers += 1
			return true
	return false


## D-111: shout a civilian within 6 m (in sight) to the floor and tie them (PD2: F at a civilian, then hold F).
func _intimidate(c: CrewController) -> bool:
	if _tied >= 3:
		return false
	for n: Node in rt.npcs(&"civilian"):
		var civ: NpcBase = n as NpcBase
		var b: CivilianBrain = civ.get_node_or_null(^"Brain") as CivilianBrain if civ != null else null
		if b == null or b.mode in [CivilianBrain.Mode.TIED, CivilianBrain.Mode.DEAD, CivilianBrain.Mode.LEAVE]:
			continue
		if pilot.flat_dist(civ.global_position, c.global_position) > 6.0:
			continue
		var head: Vector3 = civ.global_position + Vector3(0, 1.5, 0)
		if not pilot.has_los(head, civ):
			continue
		var id: int = civ.get_instance_id()
		if int(_shouted.get(id, 0)) >= 4:
			continue
		_shouted[id] = int(_shouted.get(id, 0)) + 1
		if b.mode != CivilianBrain.Mode.DOWN:
			note("shouting %s (mode %d)" % [civ.name, b.mode])
			await pilot.face(head, 0.05, 1.0)
			await pilot.inp.tap(&"shout")
			await wait_s(1.2)
		if b.mode == CivilianBrain.Mode.DOWN:
			for comp: Node in civ.find_children("*", "InteractableComponent", true, false):
				var ic: InteractableComponent = comp as InteractableComponent
				if ic.kind == &"tie" and ic.enabled and ic.availability(pilot.crew) == &"":
					note("tying %s" % civ.name)
					if await pilot.use(ic, 15.0, func() -> bool: return b.mode == CivilianBrain.Mode.TIED):
						_tied += 1
					break
		return true
	return false


## A guard closer than 2.5 m with detection on us rising gets the knife (PD2: melee a guard who is on to you).
func _knife_noticer(c: CrewController) -> bool:
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g == null or pilot.flat_dist(g.global_position, c.global_position) > 2.5:
			continue
		if rt.detection_value(g, c.slot) <= 0.05:
			continue
		note("knifing %s (detection %.2f)" % [g.name, rt.detection_value(g, c.slot)])
		await pilot.face(g.global_position + Vector3(0, 1.1, 0), 0.05, 1.0)
		await pilot.inp.hold(&"melee", 1.05)
		await wait_s(0.6)
		if not g.is_alive():
			_knifed += 1
		return true
	return false
