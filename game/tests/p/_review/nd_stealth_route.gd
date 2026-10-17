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
##     res://tests/p/_review/nd_stealth_route.tscn -- --out=/abs/dir [--seed=21] [--bags=4] [--obs-out=DIR] [--render]
## Fast mode (default; --render turns it off): the render loop is off and the HUD canvas layers are hidden between
## screenshots (as A's po5_flow set_fast; presentation only, input and gameplay untouched: under llvmpipe the route
## ran ~80 wall-s per game-s rendered). Stated shortcut: the time-lock wait (standing still at the panel) runs at
## Engine.time_scale TIME_LOCK_SCALE, as X4StealthFlow's long waits.
## Owner: ENV P.
extends Node

const GRATE_AT: Vector3 = Vector3(16.95, 0.0, -1.4)
const MASK_AT: Vector3 = Vector3(18.5, -4.0, 3.0)
const GATE_AT: Vector3 = Vector3(14.0, -4.0, 6.9)
const C6_AT: Vector3 = Vector3(9.1, -1.4, 8.8)
## Cash lift: where to stand in B1 to throw a bag through the hatch (west shaft wall x 5.6, z 1.2-2.4, sill 0.45 /
## head 1.25 m) into the car (6.25, 1.8); G1 just inside the sally door; C4 looks at that door from 6 m.
const B1_HATCH_STAND: Vector3 = Vector3(4.6, -4.0, 1.8)
const SALLY_IN: Vector3 = Vector3(5.0, 0.0, 1.8)
const C4_AT: Vector3 = Vector3(3.5, 2.6, 5.9)
## Just inside the vault gate (antechamber side), where C6 can be shot; short of the laser_static plane at z 8.5
## (capsule r 0.35: z 8.3 tripped it, ND run 2026-10-17 t=120.7).
const GATE_IN: Vector3 = Vector3(14.0, -4.0, 7.95)
const LASER_GAP_X: float = 9.575
const TIME_LOCK_SCALE: float = 4.0
## B3 side of PlantDoor (18.5, -4, 6.0), off the doorway's sight line; the corridor point just through the door.
const B3_HIDE_AT: Vector3 = Vector3(17.3, -4.0, 3.5)
const PLANT_THROUGH: Vector3 = Vector3(18.3, -4.0, 6.9)
## C6 (9.1, -1.4, 8.8, facing +x) sees the B5 corridor through the vault gate bars for x ~14.4-17, his post
## (14.3, 7.7) included: a body or a pager answer there is on camera (ND run 2026-10-17 t=81: camera alarm at the
## kill). Knife him on his walk west, before he turns at x 9.8, so he drops out of C6's sight.
const KNIFE_WEST_OF_X: float = 14.1
## His post and the east end of his B5 patrol (seed 21).
const GUARD_POST_X: float = 14.3
const PATROL_EAST_X: float = 17.9

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _seed: int = 21
var _bags: int = 4  # MIN_BAGS (night_deposit_mission)
var _shot: int = 0
var _alarm: StringName = &""
var _t0_ms: int = 0
var _fast: bool = true
var _lift_probe: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"seed": _seed = v.to_int()
			"bags": _bags = v.to_int()
			"render": _fast = false
			"lift-probe": _lift_probe = true
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
	if _fast:
		_set_fast(false)
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [runner_out, _shot, label])
	if _fast:
		_set_fast(true)


## Render loop off + HUD canvas layers hidden (A's po5_flow set_fast / _hud_redraw_widgets): presentation only.
func _set_fast(on: bool) -> void:
	RenderingServer.render_loop_enabled = not on
	for n: Node in get_tree().root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = not on


func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## Physics-frame wait for `cond` (game time, llvmpipe-safe). Returns whether it became true.
func wait_until(cond: Callable, timeout_s: float) -> bool:
	for _i: int in int(timeout_s * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _fail(step: String) -> void:
	note("FAIL %s (alarm %s)" % [step, _alarm])
	await shot("fail_" + step.replace(" ", "_"))
	print("[NDR] RESULT FAIL at %s" % step)
	RenderingServer.render_loop_enabled = true
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
	# A player brings a melee weapon: without a "loadouts" option every swing was the gun bash (30 of a Routine
	# guard's 50; ENV A 2026-10-17). Folding knife: 50 quick, reach 1.8 m.
	var lo: Loadout = CrewWeapons.build_loadout(null).duplicate()
	lo.melee = &"melee.folding_knife"
	rt = await HeistLauncher.launch(&"night_deposit", _seed, Enums.Difficulty.ROUTINE, self, {
		"crew_ai": false, "loadouts": {0: lo},
		"preplanning": {&"asset.alternate_entry": &"pp_spawn_lot", &"asset.vent_access": &"pp_vent"}})
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
	if _lift_probe:  # --lift-probe: print the cash lift's landings and panels, then quit
		for n: Node in rt.find_children("*", "BagLift", true, false):
			var bl: BagLift = n as BagLift
			note("lift %s at %s landing %d count %d car %s" % [bl.get_path(), Po5Pilot._v(bl.global_position), bl.landing,
				bl.landing_count(), Po5Pilot._v(bl.car_transform().origin)])
			for i: int in bl.landing_count():
				note("  landing %d %s" % [i, Po5Pilot._v(bl.landing_transform(i).origin)])
			for c: Node in bl.find_children("*", "InteractableComponent", true, false):
				note("  panel %s %s kind %s" % [c.name, Po5Pilot._v((c as Node3D).global_position), c.get(&"kind")])
		var map: RID = get_tree().root.get_world_3d().navigation_map
		for q: Vector3 in [Vector3(5.5, -2.5, 1.8), B1_HATCH_STAND, Vector3(3.5, -4.0, 3.0)]:
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(12.0, -4.0, 6.9), q, true)
			note("  nav closest to %s: %s; path from B5 %d pts, ends %s" % [Po5Pilot._v(q),
				Po5Pilot._v(NavigationServer3D.map_get_closest_point(map, q)), path.size(),
				Po5Pilot._v(path[path.size() - 1]) if path.size() > 0 else "-"])
		get_tree().quit(0)
		return
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(2.0)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	await pilot.calibrate()
	note("spawn %s" % Po5Pilot._v(c.global_position))
	_watch_detection.call_deferred()
	await shot("spawn_lot")
	if _fast:
		note("fast mode: render loop off between shots")
		_set_fast(true)
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


## Every 0.25 s: log each observer whose meter on the pilot crosses 0.05 / 0.5 / 1.0 (who saw the pilot, where).
func _watch_detection() -> void:
	var sd: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
	var seen: Dictionary = {}
	var alert: Dictionary = {}
	while sd != null and is_inside_tree() and _alarm == &"":
		for role: StringName in [&"guard", &"civilian"]:
			for n: Node in rt.npcs(role):
				var npc: NpcBase = n as NpcBase
				if npc != null and int(alert.get(npc, 0)) != npc.alert_state:
					note("ALERT %s %d -> %d at %s (pilot %s)" % [npc.name, int(alert.get(npc, 0)), npc.alert_state,
						Po5Pilot._v(npc.global_position), Po5Pilot._v(pilot.crew.global_position)])
					alert[npc] = npc.alert_state
		for e: Dictionary in sd.detection_entries(pilot.crew.slot):
			var v: float = float(e["value"])
			var id: int = int(e["observer_net_id"])
			var band: int = 3 if v >= 1.0 else (2 if v >= 0.5 else (1 if v >= 0.05 else 0))
			if band > int(seen.get(id, 0)):
				note("DETECT %s kind %d meter %.2f at %s, pilot %s crouched %s" % [_observer_name(id),
					int(e["kind"]), v, Po5Pilot._v(e["world_pos"]), Po5Pilot._v(pilot.crew.global_position),
					pilot.crew.crouched])
			seen[id] = band if band > 0 else 0
		await wait_s(0.25)


func _observer_name(net_id: int) -> String:
	for n: Node in rt.find_children("*", "Node3D", true, false):
		if (n is NpcBase or n.has_method(&"take_hit")) and NetIds.of(n) == net_id:
			return String(n.name)
	return str(net_id)


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
	if not await _climb_down_near(GRATE_AT):
		note("ladder not climbed down (at %s)" % Po5Pilot._v(pilot.crew.global_position))
		return false
	if not await pilot.goto(MASK_AT, 0.8, 40.0):
		return false
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	note("masked in B3 (masked %s)" % pilot.crew.masked)
	await shot("b3_masked")
	return pilot.crew.masked


## The ladder under the grate, by real input: walk to its top (ground side), face it, hold W down to the bottom
## (the ladder's NavigationLink3D is on Ladder.NAV_LAYER, which the pilot's layer-1 nav paths do not use).
func _climb_down_near(at: Vector3) -> bool:
	var lad: Ladder = null
	for n: Node in rt.find_children("*", "Ladder", true, false):
		var l: Ladder = n as Ladder
		if lad == null or l.global_position.distance_to(at) < lad.global_position.distance_to(at):
			lad = l
	if lad == null:
		return false
	var top: Vector3 = lad.top_position()
	var bottom: Vector3 = lad.bottom_position()
	var away: Vector3 = Vector3(top.x - lad.global_position.x, 0.0, top.z - lad.global_position.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	if not await pilot.goto(top + away * 0.5, 0.4, 40.0):
		note("ladder top not reached (%s)" % Po5Pilot._v(top))
		return false
	await pilot.face(Vector3(lad.global_position.x, top.y + 0.2, lad.global_position.z), 0.05, 1.5)
	pilot.inp.press(&"move_forward")
	var t: float = 0.0
	while t < lad.climb_time() + 8.0:
		await wait_s(0.1)
		t += 0.1
		if pilot.crew.global_position.y < bottom.y + 0.3 and not lad.is_climbing(pilot.crew.slot):
			break
	pilot.inp.release(&"move_forward")
	note("ladder %s: down %s in %.1f s" % [lad.name, pilot.crew.global_position.y < bottom.y + 0.3, t])
	return pilot.crew.global_position.y < bottom.y + 0.3


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
	var hits: Array[int] = [0, 0]
	var c: CrewController = pilot.crew
	c.melee.hit_landed.connect(func(_t: Object) -> void: hits[0] += 1)
	c.melee.swung.connect(func(_ch: bool) -> void: hits[1] += 1)
	var sd: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
	# His loop (seed 21, ND runs 2026-10-17): idle ~6 s at his post (14.3, 7.7) facing the vault gate (+z), walk west
	# to x 9.8, turn, walk east to x 17.9 (by PlantDoor), turn, walk west back to the post. D-128: within 2 m he
	# uncovers at once, a pilot in his view at 3-4 m fills in ~1 s, and a knife hit after that does 30 of his 50 (no
	# S3.6 one-shot). C6 sees his post through the gate bars (KNIFE_WEST_OF_X), and a navmesh leg through the closed
	# PlantDoor took 2.6 s (he reached his turn first and radioed). So: open PlantDoor while he is far west, hide in B3
	# while he comes east, step just inside the corridor as he walks back to the post (behind him: outside his cone
	# while he faces the gate), and sprint at his back the moment he leaves the post westward (5.75 vs ~1.6 m/s).
	var plant: Door = _door("PlantDoor")
	for _k: int in 4:
		if not g.is_alive() or g.alert_state > Enums.AlertState.CURIOUS:
			break
		if plant != null and not plant.is_open:
			if not await wait_until(func() -> bool: return g.global_position.x < 12.0 and _back_turned_to(g, PLANT_THROUGH),
					60.0):
				note("gate guard never went far west (at %s)" % Po5Pilot._v(g.global_position))
				break
			await pilot.use(_comp(plant), 10.0, func() -> bool: return plant.is_open)
			note("PlantDoor open %s (guard at %s)" % [plant.is_open, Po5Pilot._v(g.global_position)])
		if pilot.flat_dist(c.global_position, B3_HIDE_AT) > 0.4:
			await pilot.goto(B3_HIDE_AT, 0.3, 10.0)
		var x_prev: Array[float] = [g.global_position.x]
		var back_to_post: Callable = func() -> bool:
			var west: bool = g.global_position.x < x_prev[0] - 0.005
			x_prev[0] = g.global_position.x
			return not g.is_alive() or (west and g.global_position.x > GUARD_POST_X + 0.3
				and g.global_position.x < PATROL_EAST_X - 1.0 and _back_turned_to(g, PLANT_THROUGH))
		if not await wait_until(back_to_post, 60.0):
			note("gate guard never walked back to his post (at %s)" % Po5Pilot._v(g.global_position))
			break
		await pilot.goto(PLANT_THROUGH, 0.4, 3.0)
		note("in the corridor at %s, guard %s" % [Po5Pilot._v(c.global_position), Po5Pilot._v(g.global_position)])
		x_prev[0] = g.global_position.x
		var leaves: Callable = func() -> bool:
			var west: bool = g.global_position.x < x_prev[0] - 0.005
			x_prev[0] = g.global_position.x
			return not g.is_alive() or _faces_me(g) or (west and g.global_position.x < KNIFE_WEST_OF_X)
		await wait_until(leaves, 15.0)
		if _faces_me(g):
			note("he faced the corridor before leaving the post (at %s); back to B3" % Po5Pilot._v(g.global_position))
			continue
		note("go: guard %s leaving west, me %s" % [Po5Pilot._v(g.global_position), Po5Pilot._v(c.global_position)])
		if await _chase_and_knife(g, sd, hits):
			break
	if g.is_alive():
		note("gate guard not knifed (alert %d, meter %.2f, dist %.2f)" % [g.alert_state,
			sd.detection_value(g, c.slot) if sd != null else -1.0, pilot.flat_dist(g.global_position, c.global_position)])
		return false
	await shot("gate_guard_knifed")
	for _k: int in 60:
		var pc: InteractableComponent = _comp(g, &"answer_pager")
		if pc != null and pc.enabled:
			note("answering the pager")
			var answered: Callable = func() -> bool: return not pc.enabled
			if await pilot.use(pc, 20.0, answered) or answered.call():
				return true
			# The body fell inside the vault gate: answer through the bars from the corridor side, nearest the body.
			var b: Vector3 = pc.global_position
			await pilot.goto(Vector3(clampf(b.x, GATE_AT.x - 1.0, GATE_AT.x + 1.0), GATE_AT.y, GATE_AT.z - 0.3), 0.4,
				10.0)
			note("answering through the gate from %s (pager at %s, %.2f m)" % [Po5Pilot._v(c.global_position),
				Po5Pilot._v(b), c.eye_position().distance_to(b)])
			return await pilot.use(pc, 20.0, answered, false) or answered.call()
		if _alarm != &"":
			return false
		await wait_s(0.25)
	note("no pager came")
	return true


## Steer at the guard's back with W held and swing on the move once he is in reach (stopping to face him first let
## him walk 0.6 m out of reach, ND run 2026-10-17 t=66). False when he turns toward the pilot or no swing lands.
func _chase_and_knife(g: NpcBase, sd: StealthDirector, hits: Array[int]) -> bool:
	var c: CrewController = pilot.crew
	pilot.inp.press(&"move_forward")
	var frames: int = 0
	var swings: int = 0
	var alert_before: int = g.alert_state
	while g.is_alive() and _back_turned(g) and frames < 4 * Engine.physics_ticks_per_second and swings < 2:
		var d: float = pilot.flat_dist(g.global_position, c.global_position)
		if frames % 30 == 0:
			note("knife trace: me %s guard %s dist %.2f alert %d meter %.2f" % [Po5Pilot._v(c.global_position),
				Po5Pilot._v(g.global_position), d, g.alert_state, sd.detection_value(g, c.slot) if sd != null else -1.0])
		if d > 2.5:
			pilot.inp.press(&"sprint")
		else:
			pilot.inp.release(&"sprint")
		pilot.steer_at(g.global_position + Vector3(0, 1.1, 0))
		if d <= 1.6:
			alert_before = g.alert_state
			await pilot.inp.tap(&"melee")  # quick swing: S3.6 kills an unaware guard on any hit
			swings += 1
			frames += 3
			for _f: int in 20:  # keep closing while the swing plays out
				if not g.is_alive():
					break
				pilot.steer_at(g.global_position + Vector3(0, 1.1, 0))
				await get_tree().physics_frame
			frames += 20
			note("swing: me %s guard %s fwd %s dist %.2f, swings %d, hits %d, health %.2f alive %s alert %d -> %d" % [
				Po5Pilot._v(c.global_position), Po5Pilot._v(g.global_position), Po5Pilot._v(-g.global_basis.z),
				pilot.flat_dist(g.global_position, c.global_position), hits[1], hits[0], g.health, g.is_alive(),
				alert_before, g.alert_state])
			continue
		await get_tree().physics_frame
		frames += 1
	pilot.inp.release(&"sprint")
	pilot.inp.release(&"move_forward")
	if g.is_alive():
		note("chase broke off: dist %.2f back %s alert %d swings %d" % [
			pilot.flat_dist(g.global_position, c.global_position), _back_turned(g), g.alert_state, swings])
	return not g.is_alive()


## True when the pilot is within ~70 deg of the guard's forward (inside his view cone at 3-5 m, S2.2: +-60 deg from
## 8.5 m, wider closer). At his post he faces the vault gate, ~105 deg from the pilot inside the corridor door.
func _faces_me(g: NpcBase) -> bool:
	var to_me: Vector3 = pilot.crew.global_position - g.global_position
	to_me.y = 0.0
	var fwd: Vector3 = -g.global_basis.z
	fwd.y = 0.0
	return to_me.length() < 0.05 or fwd.normalized().dot(to_me.normalized()) > 0.34


## True when the guard faces away from the pilot (his forward and the pilot are > ~110 deg apart).
func _back_turned(g: NpcBase) -> bool:
	return _back_turned_to(g, pilot.crew.global_position)


## True when the guard faces away from `p` (his forward and `p` are > ~110 deg apart).
func _back_turned_to(g: NpcBase, p: Vector3) -> bool:
	var to_me: Vector3 = p - g.global_position
	to_me.y = 0.0
	var fwd: Vector3 = -g.global_basis.z
	fwd.y = 0.0
	return to_me.length() < 0.05 or fwd.normalized().dot(to_me.normalized()) < -0.35


## Stand still until the guard's back is turned, or `timeout` game-seconds.
func _wait_back_turned(g: NpcBase, timeout: float) -> bool:
	return await wait_until(func() -> bool: return not g.is_alive() or _back_turned(g), timeout)


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
		# Through the open vault gate first: from the corridor the antechamber wall (B_Z7_5_06) is in the way.
		var spots: Array[Vector3] = [GATE_IN, GATE_IN + Vector3(-0.6, 0, 0), GATE_IN + Vector3(0.6, 0, 0)]
		var k_spot: int = 0
		await pilot.goto(spots[0], 0.3, 6.0)
		for _k: int in 8:
			if _cam_down(cam):
				break
			var aim_at: Vector3 = _cam_aim_point(cam)
			await pilot.face(aim_at, 0.01, 1.0)
			var c: CrewController = pilot.crew
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c.eye_position(),
				c.eye_position() + c.aim_direction() * 30.0)
			q.exclude = [c.get_rid()]
			var hit: Dictionary = c.get_world_3d().direct_space_state.intersect_ray(q)
			var on_cam: bool = not hit.is_empty() and (hit["collider"] == cam or cam.is_ancestor_of(hit["collider"]))
			note("C6 shot from %s at %s (%.1f m): ray hits %s" % [Po5Pilot._v(c.global_position), Po5Pilot._v(aim_at),
				c.eye_position().distance_to(aim_at), (hit["collider"] as Node).get_path() if not hit.is_empty() else ^"-"])
			if not on_cam and k_spot + 1 < spots.size():
				k_spot += 1
				await pilot.goto(spots[k_spot], 0.3, 4.0)
				continue
			await pilot.inp.tap(&"fire")
			await wait_s(0.4)
		note("camera C6 %s" % ("down" if _cam_down(cam) else "still up"))
	else:
		note("no C6 camera found near %s" % Po5Pilot._v(C6_AT))
	return true


## Where to shoot a camera: its collision box sits on the room side of the mount pivot (QA-26), so aim at the
## shape's centre (the pivot is on the wall / ceiling plane: shots there hit the mount surface).
static func _cam_aim_point(cam: Node3D) -> Vector3:
	for n: Node in cam.find_children("*", "CollisionShape3D", true, false):
		return (n as Node3D).global_position
	var head: Node3D = cam.find_child("Head", true, false) as Node3D
	return head.global_position if head != null else cam.global_position - cam.global_basis.z * 0.2


## A shot camera keeps its mesh: SecurityCamera.destroyed (S8.1) is the state.
static func _cam_down(cam: Node3D) -> bool:
	return not is_instance_valid(cam) or bool(cam.get(&"destroyed")) or not cam.is_visible_in_tree()


func _time_lock() -> bool:
	var panel: Node3D = _tagged(&"time_lock")
	if panel == null:
		return false
	# laser_static (nd_gameplay._variants_lasers): the grid spans x 10.05-18.9 at z 8.5 in front of the panel; the
	# bypass gap is x 9.1-10.05 by the west wall (capsule r 0.35: centre x 9.45-9.7). Through the gap, then east
	# behind the plane (the navmesh ignores beams: walking straight at the panel tripped it, ND run 4 t=97.7).
	for wp: Vector3 in [Vector3(LASER_GAP_X, GATE_AT.y, 7.9), Vector3(LASER_GAP_X, GATE_AT.y, 9.15)]:
		if not await pilot.goto(wp, 0.12, 20.0):
			note("laser gap: could not reach %s (at %s)" % [Po5Pilot._v(wp), Po5Pilot._v(pilot.crew.global_position)])
			return false
	var stand: Vector3 = Vector3(panel.global_position.x - 0.9, GATE_AT.y, clampf(panel.global_position.z, 9.0, 9.8))
	if not await pilot.goto(stand, 0.25, 30.0):
		note("TL: could not reach the stand point %s (at %s)" % [Po5Pilot._v(stand),
			Po5Pilot._v(pilot.crew.global_position)])
	var ok: bool = await pilot.use(_comp(panel), 40.0, func() -> bool: return _objective(&"time_lock") == 2, false)
	if not ok:
		return false
	var vault: Door = _tagged(&"vault_door") as Door
	var t: float = 0.0
	Engine.time_scale = TIME_LOCK_SCALE  # stated shortcut: standing still through the time lock
	note("time lock running: waiting at x%.0f" % TIME_LOCK_SCALE)
	var t0: float = rt.heist_time_s
	while vault != null and not vault.is_open and t < 120.0 and _alarm == &"":
		await pilot.hold_position(2.0)
		t = rt.heist_time_s - t0
	Engine.time_scale = 1.0
	note("vault open %s after %.0f s" % [vault != null and vault.is_open, t])
	await shot("vault_open")
	return vault != null and vault.is_open


## Bags leave by the cash lift (design doc: B9 -> B5 -> B1 -> lift -> G1 -> sally door -> van): no ladder with a
## bag (S10.1b), a throw tops out ~2.7 m in the 4 m areaway shaft, and the ground-floor stair carry met an alarm
## button (ND run 2026-10-17 t=234). Per trip: call the car to B1, throw two vault bags in through the hatch, send it
## up, climb out empty-handed (vault gap -> B5 -> B3 -> ladder), in by the sally door (lockpick; C4 shot), take the
## bags out of the car and secure them at the van, send the car back down and climb back in for the next trip.
func _loot() -> bool:
	var zone: SecureZone = pilot.secure_zone()
	var lift: BagLift = rt.find_children("*", "BagLift", true, false).front() as BagLift \
		if not rt.find_children("*", "BagLift", true, false).is_empty() else null
	if zone == null or lift == null:
		note("no secure zone (%s) or no cash lift (%s)" % [zone, lift])
		return false
	for trip: int in ceili(_bags / 2.0):
		var steps: Array[Callable] = [_lift_to.bind(lift, 1), _load_trip.bind(lift, trip), _lift_to.bind(lift, 0),
			_surface, _into_g1, _unload_g1.bind(lift, zone)]
		steps.push_front(_gap_out)  # behind the laser grid since the time lock: out through the gap first
		if trip > 0:
			steps.push_front(_back_to_vault)
		for st: Callable in steps:
			if not await st.call():
				note("trip %d failed at %s" % [trip, st.get_method()])
				return false
		await shot("trip_%d_secured" % trip)
	return true


func _gap_out() -> bool:
	for wp: Vector3 in [Vector3(LASER_GAP_X, GATE_AT.y, 9.15), Vector3(LASER_GAP_X, GATE_AT.y, 7.9)]:
		if not await pilot.goto(wp, 0.12, 60.0):
			note("laser gap out: could not reach %s (at %s)" % [Po5Pilot._v(wp), Po5Pilot._v(pilot.crew.global_position)])
			return false
	return true


## Up to two vault bags thrown into the car at B1 (in through the laser gap for each).
func _load_trip(lift: BagLift, trip: int) -> bool:
	for b: int in mini(2, _bags - 2 * trip):
		# Along the grid's south side well clear of the beams (z 8.5): the navmesh path in through the vault gate cut
		# the corner at z 8.0 and tripped them (ND run 2026-10-17 t=448).
		for wp: Vector3 in [Vector3(14.0, GATE_AT.y, 7.6), Vector3(10.6, GATE_AT.y, 7.7),
				Vector3(LASER_GAP_X, GATE_AT.y, 7.9), Vector3(LASER_GAP_X, GATE_AT.y, 9.15)]:
			await pilot.goto(wp, 0.12, 60.0)
		if not await _vault_bag_into_lift(lift, 2 * trip + b):
			return false
	note("trip %d: %d bags in the car at B1" % [trip, lift.bags_in_car().size()])
	return true


## G1: take each bag out of the car (through the hatch) and secure it at the van.
func _unload_g1(lift: BagLift, zone: SecureZone) -> bool:
	for _b: int in 2:
		var bag: LootBag = null
		for lb: LootBag in lift.bags_in_car():
			bag = lb
		if bag == null:
			break
		if not await pilot.use(_comp(bag), 20.0, func() -> bool: return pilot.crew.is_carrying_bag(), false):
			note("bag in the car not taken (at %s, bag %s)" % [Po5Pilot._v(pilot.crew.global_position),
				Po5Pilot._v(bag.global_position)])
			await shot("lift_bag_not_taken")
			return false
		if not await pilot.secure_carried_bag(zone):
			note("bag not secured (at %s)" % Po5Pilot._v(pilot.crew.global_position))
			await shot("bag_not_secured")
			return false
		var left: Array[String] = []
		for n: Node in get_tree().get_nodes_in_group(G.LOOT_BAG):
			left.append("%s %s" % [n.name, Po5Pilot._v((n as Node3D).global_position)])
		note("secured (objective secure %d); bags now: %s; in the car %d" % [_objective(&"secure"), left,
			lift.bags_in_car().size()])
		if _b == 0 and not lift.bags_in_car().is_empty():
			await pilot.goto(SALLY_IN, 0.4, 30.0)
	return true


## Car to `landing` (0 = G1, 1 = B1) from the panel on the pilot's floor; waits for it to arrive.
func _lift_to(lift: BagLift, to: int) -> bool:
	if lift.landing == to and not lift.is_moving():
		return true
	var here: int = 1 if pilot.crew.global_position.y < -2.0 else 0
	var panel: InteractableComponent = lift.interactable if here == 0 else lift.get_node_or_null(
		"%s%d" % [BagLift.PANEL_PREFIX, here]) as InteractableComponent
	if panel == null:
		note("lift panel %d missing" % here)
		return false
	note("lift: landing %d -> %d; panel %d at %s; landings %s" % [lift.landing, to, here, Po5Pilot._v(panel.global_position),
		[Po5Pilot._v(lift.landing_transform(0).origin), Po5Pilot._v(lift.landing_transform(1).origin)]])
	await wait_until(func() -> bool: return not lift.is_moving(), 20.0)
	# Walk to the panel's floor ourselves: Po5Pilot's _use_stand put B1's panel stand on G1 above it (the walk went up
	# the stair through the ground floor into an alarm button, ND run 2026-10-17 t=224).
	var stand: Vector3 = B1_HATCH_STAND if here == 1 else SALLY_IN
	await pilot.goto(stand, 0.3, 60.0)
	if not await pilot.use(panel, 30.0, func() -> bool: return lift.is_moving(), false):
		note("lift panel %d not used (at %s)" % [here, Po5Pilot._v(pilot.crew.global_position)])
		return false
	var ok: bool = await wait_until(func() -> bool: return not lift.is_moving() and lift.landing == to,
		lift.travel_s + 5.0)
	var at: Array[String] = []
	for lb: LootBag in lift.bags_in_car():
		at.append(Po5Pilot._v(lb.global_position))
	note("lift %s landing %d (%d bags in the car: %s; car floor %s)" % ["at" if ok else "NOT at", to,
		lift.bags_in_car().size(), at, Po5Pilot._v(lift.car_transform().origin)])
	return ok


## One vault bag, out through the laser gap to B1, thrown into the car through the hatch (two tries).
func _vault_bag_into_lift(lift: BagLift, i: int) -> bool:
	var src: LootSpawn = null
	for sp: Node in rt.mission.find_tagged(&"vault_loot"):
		var ls: LootSpawn = sp as LootSpawn
		if ls != null and ls.remaining > 0 and (src == null or ls.remaining > src.remaining):
			src = ls
	if src == null or not await pilot.use(_comp(src), 30.0, func() -> bool: return pilot.crew.is_carrying_bag()):
		note("bag %d not taken (loot left %s)" % [i, src != null])
		return false
	# Out through the laser grid's west bypass gap, as on the way in (the navmesh ignores beams: the straight
	# carry tripped AntechamberLasers, ND run 2026-10-17 t=210).
	for wp: Vector3 in [Vector3(LASER_GAP_X, GATE_AT.y, 9.15), Vector3(LASER_GAP_X, GATE_AT.y, 7.9)]:
		await pilot.goto(wp, 0.12, 20.0)
	var before: int = lift.bags_in_car().size()
	for attempt: int in 2:
		if not await pilot.goto(B1_HATCH_STAND, 0.2, 60.0):
			note("B1 hatch stand not reached (at %s)" % Po5Pilot._v(pilot.crew.global_position))
			break
		# Up against the hatch: the throw releases 0.7 m ahead (drop_forward_m), already in the car. From 1 m back the
		# bag (0.3 m tall, released 1.3 m up) hit the 1.25 m hatch head and bounced out (ND run 2026-10-17 t=284).
		var car: Vector3 = lift.car_transform().origin
		await pilot.face(Vector3(car.x, car.y + 0.6, car.z), 0.02, 1.5)
		pilot.inp.press(&"move_forward")
		await wait_s(0.4)
		pilot.inp.release(&"move_forward")
		await pilot.face(Vector3(car.x, car.y + 0.4, car.z), 0.02, 1.0)
		note("hatch throw %d from %s" % [attempt, Po5Pilot._v(pilot.crew.global_position)])
		await pilot.inp.tap(&"drop_bag")
		await wait_s(1.5)
		if lift.bags_in_car().size() > before:
			note("bag %d in the car (%d)" % [i, lift.bags_in_car().size()])
			return true
		var bag: LootBag = null
		for n: Node in get_tree().get_nodes_in_group(G.LOOT_BAG):
			var lb: LootBag = n as LootBag
			if lb != null and (bag == null or lb.global_position.distance_to(pilot.crew.global_position)
					< bag.global_position.distance_to(pilot.crew.global_position)):
				bag = lb
		note("hatch throw %d missed: bag at %s" % [attempt, Po5Pilot._v(bag.global_position) if bag != null else "-"])
		await shot("hatch_miss_%d" % attempt)
		if bag == null or not await pilot.use(_comp(bag), 20.0, func() -> bool: return pilot.crew.is_carrying_bag()):
			return false
	return false


## Vault gap -> B5 -> PlantDoor -> B3 -> AreawayLadder up to the lot (empty-handed).
func _surface() -> bool:
	var lad: Ladder = _ladder_near(GRATE_AT)
	if lad == null:
		return false
	var bottom: Vector3 = lad.bottom_position()
	var away: Vector3 = Vector3(bottom.x - lad.global_position.x, 0.0, bottom.z - lad.global_position.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if not await pilot.goto(bottom + away * 0.5, 0.4, 90.0):
		note("ladder bottom not reached (at %s)" % Po5Pilot._v(pilot.crew.global_position))
		return false
	await pilot.face(Vector3(lad.global_position.x, bottom.y + 1.5, lad.global_position.z), 0.05, 1.5)
	pilot.inp.press(&"move_forward")
	var top_y: float = lad.top_position().y
	var t: float = 0.0
	while t < lad.climb_time() + 8.0 and not (pilot.crew.global_position.y > top_y - 0.3 and not lad.is_climbing(
			pilot.crew.slot)):
		await wait_s(0.1)
		t += 0.1
	pilot.inp.release(&"move_forward")
	note("ladder up: %s in %.1f s (at %s)" % [pilot.crew.global_position.y > top_y - 0.3, t,
		Po5Pilot._v(pilot.crew.global_position)])
	return pilot.crew.global_position.y > top_y - 0.3


## Lot -> SallyPersonnelDoor (lockpick) -> shoot C4 (looks at the door from 6 m) -> in to the lift hatch.
func _into_g1() -> bool:
	var door: Door = _door("SallyPersonnelDoor")
	if door == null:
		note("no SallyPersonnelDoor")
		return false
	if not door.is_open and not await pilot.use(_comp(door), 40.0, func() -> bool: return door.is_open):
		note("sally door not opened (lock %s)" % door.get(&"lock"))
		await shot("sally_door_shut")
		return false
	var cam: Node3D = _camera_near(C4_AT)
	if cam != null and not _cam_down(cam):
		await _shoot_camera(cam, [pilot.crew.global_position, SALLY_IN])
	return await pilot.goto(SALLY_IN, 0.4, 20.0)


## Back down for the next trip: send the empty car to B1 from G1, out the sally door, down the ladder, B3 -> B5 -> gap.
func _back_to_vault() -> bool:
	var lift: BagLift = rt.find_children("*", "BagLift", true, false).front() as BagLift
	if not await _lift_to(lift, 1):
		return false
	if not await _climb_down_near(GRATE_AT):
		note("ladder not climbed down for trip 2 (at %s)" % Po5Pilot._v(pilot.crew.global_position))
		return false
	return true


func _ladder_near(at: Vector3) -> Ladder:
	var lad: Ladder = null
	for n: Node in rt.find_children("*", "Ladder", true, false):
		var l: Ladder = n as Ladder
		if lad == null or l.global_position.distance_to(at) < lad.global_position.distance_to(at):
			lad = l
	return lad


func _camera_near(at: Vector3) -> Node3D:
	for n: Node in rt.find_children("*", "Node3D", true, false):
		var n3: Node3D = n as Node3D
		if n3.has_method(&"take_hit") and n3.global_position.distance_to(at) < 1.0 and String(n3.name).contains("Cam"):
			return n3
	return null


## Secondary out, then from each spot in turn: aim at the camera's collision box, fire only on a ray that reaches it.
func _shoot_camera(cam: Node3D, spots: Array[Vector3]) -> void:
	await pilot.inp.tap(&"slot_secondary")
	var k_spot: int = 0
	await pilot.goto(spots[0], 0.3, 6.0)
	for _k: int in 8:
		if _cam_down(cam):
			break
		var aim_at: Vector3 = _cam_aim_point(cam)
		await pilot.face(aim_at, 0.01, 1.0)
		var c: CrewController = pilot.crew
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c.eye_position(),
			c.eye_position() + c.aim_direction() * 30.0)
		q.exclude = [c.get_rid()]
		var hit: Dictionary = c.get_world_3d().direct_space_state.intersect_ray(q)
		var on_cam: bool = not hit.is_empty() and (hit["collider"] == cam or cam.is_ancestor_of(hit["collider"]))
		note("%s shot from %s at %s (%.1f m): ray hits %s" % [cam.name, Po5Pilot._v(c.global_position),
			Po5Pilot._v(aim_at), c.eye_position().distance_to(aim_at),
			(hit["collider"] as Node).get_path() if not hit.is_empty() else ^"-"])
		if not on_cam and k_spot + 1 < spots.size():
			k_spot += 1
			await pilot.goto(spots[k_spot], 0.3, 4.0)
			continue
		await pilot.inp.tap(&"fire")
		await wait_s(0.4)
	note("camera %s %s" % [cam.name, "down" if _cam_down(cam) else "still up"])


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
