# gdlint:disable=max-public-methods,max-file-lines
## D-128 feel check (ENV P, 2026-10-17): windowed REAL-INPUT detection samples on Golden Hour / Shadow Ledger.
## Po5Pilot only (mouse look, WASD, crouch, mask_up hold); no teleports, no intents, no state writes.
## Stated shortcut: direct launch (HeistLauncher.launch, no menus), crew_ai off, B's real HUD instanced.
## Method per sample: walk UNMASKED (casing: civilians never notice, guards / cameras only in RESTRICTED or inside
## casing_too_close_m) to a nav point at the wanted distance / angle in the observer's view, stand still (crouch held
## for crouch samples), face the observer, hold mask_up: the meter starts the moment the mask is on. Logged per tick:
## A's meter (StealthDirector.detection_value), the HUD row (LocalHudModel.detection) and B's ring (DetectionRings),
## the live geometry and A's live rate (fill_rate). Decay samples crouch out of range at ~70 % and time the drain to 0.
## A detection (meter 1.0) or an alarm ends the run: the next sample relaunches (same seed).
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/d128_feel.tscn -- --heist=glasshouse --out=/abs/dir [--seed=1002] [--mode=survey|samples|careful]
##     [--samples=Obs:d:ang:stand|crouch[:decay][:chain],...] [--route=x,y,z;x,y,z;...] [--shots=6]
## Owner: ENV P.
extends Node

const HUD_SCENE: String = "res://content/ui/hud/hud.tscn"
const KIND_NAMES: Array[String] = ["guard", "civilian", "camera", "police"]
## A sample gives up waiting for a fill after this much game time with the mask on (s).
const NEVER_S: float = 6.0
## Decay samples crouch out of range once the shown meter passes this.
const DECAY_AT: float = 0.7

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var hud: Node = null
var runner_out: String = ""
var heist: StringName = &"glasshouse"
var mode: String = "survey"
var samples_arg: String = ""
var route_arg: String = ""
var difficulty: int = Enums.Difficulty.ROUTINE
var pre_arg: String = ""
var shoot_arg: String = ""
var post_arg: String = ""
var _nomask: bool = false  # --nomask (D-142): careful walk unmasked (glass LOS survey)
var _seed: int = 1002
var _shots_left: int = 6
var _shot: int = 0
var _alarm: StringName = &""
var _t0_ms: int = 0
var _runs: int = 0
var _log: FileAccess = null
var _rows: Array[String] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"seed": _seed = v.to_int()
			"heist": heist = StringName(v)
			"mode": mode = v
			"samples": samples_arg = v
			"route": route_arg = v
			"shots": _shots_left = v.to_int()
			"difficulty": difficulty = Enums.Difficulty.LETHAL if v == "lethal" else Enums.Difficulty.ROUTINE
			"pre": pre_arg = v
			"shoot": shoot_arg = v
			"post": post_arg = v
			"nomask": _nomask = true
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/d128_feel"
	DirAccess.make_dir_recursive_absolute(runner_out)
	_log = FileAccess.open("%s/%s_log.txt" % [runner_out, mode], FileAccess.WRITE)
	_run.call_deferred()


func note(msg: String) -> void:
	var line: String = "[D128 %.1fs t=%.2f] %s" % [(Time.get_ticks_msec() - _t0_ms) / 1000.0,
		rt.heist_time_s if rt != null and is_instance_valid(rt) else -1.0, msg]
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	var p: String = "%s/%s_%02d_%s.png" % [runner_out, heist, _shot, label]
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path(p))
	note("shot %s" % p.get_file())


func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _run() -> void:
	_t0_ms = Time.get_ticks_msec()
	match mode:
		"survey":
			await _launch()
			await _survey()
		"samples":
			await _samples()
		"careful":
			await _careful()
	note("DONE runs=%d" % _runs)
	for r: String in _rows:
		print("[D128ROW] " + r)
		if _log != null:
			_log.store_line("[D128ROW] " + r)
	if _log != null:
		_log.flush()
	print("[D128] RESULT DONE")
	get_tree().quit(0)


# --- launch -------------------------------------------------------------------------------------------

func _launch() -> bool:
	if rt != null and is_instance_valid(rt):
		await _teardown()
	_runs += 1
	_alarm = &""
	var opts: Dictionary = {"crew_ai": false, "ai_teammates": 0}
	if heist == &"shadow_ledger":  # sl_pass's dev preplan: start in the PUBLIC L40 service lobby
		opts["preplanning"] = [&"asset.alternate_entry@pp_spawn_service", &"asset.escape_position@pp_escape_service"]
	rt = await HeistLauncher.launch(heist, _seed, difficulty as Enums.Difficulty, self, opts)
	if rt == null:
		note("FAIL no runtime")
		return false
	if not EventBus.alarm_raised.is_connected(_on_alarm):
		EventBus.alarm_raised.connect(_on_alarm)
	hud = (load(HUD_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(hud)
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(1.5)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	pilot.no_blind_press = true
	await pilot.calibrate()
	note("run %d: difficulty %d pagers_max %s" % [_runs, difficulty, rt.hud_model.get(&"pagers_max")])
	note("run %d: %s seed %d phase %d crew %s masked %s mode %s DR %d" % [_runs, heist, _seed, rt.phase,
		Po5Pilot._v(c.global_position), c.masked, c.player_mode if &"player_mode" in c else "-", _dr()])
	return true


func _teardown() -> void:
	if pilot != null:
		pilot.inp.release_all()
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null
	rt.teardown()
	rt = null
	for _i: int in 4:
		await get_tree().process_frame


func _on_alarm(reason: StringName, _src: int) -> void:
	if _alarm == &"":
		_alarm = reason
	note("ALARM %s" % reason)


func _crew() -> CrewController:
	return pilot.crew


func _dr() -> int:
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	return c.loadout.detection_risk if c != null and c.loadout != null else -1


# --- observers ----------------------------------------------------------------------------------------

func _observers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group(G.OBSERVER):
		var n3: Node3D = n as Node3D
		if n3 != null and n3.has_method(&"eye_position") and rt.is_ancestor_of(n3):
			out.append(n3)
	return out


## `@guard` / `@camera` / `@civilian`: the nearest active observer of that kind on the crew's floor.
func _find_obs(obs_name: String) -> Node3D:
	if obs_name.begins_with("@"):
		var best: Node3D = null
		var cp: Vector3 = _crew().global_position
		for o: Node3D in _observers():
			if _kind_name(o) != obs_name.substr(1) or absf(o.global_position.y - cp.y) > 4.0:
				continue
			if o.has_method(&"can_observe") and not bool(o.call(&"can_observe")):
				continue
			if best == null or o.global_position.distance_to(cp) < best.global_position.distance_to(cp):
				best = o
		return best
	for o: Node3D in _observers():
		if String(o.name) == obs_name:
			return o
	return null


func _kind(o: Node3D) -> int:
	return int(o.call(&"observer_kind")) if o.has_method(&"observer_kind") else 0


func _kind_name(o: Node3D) -> String:
	return KIND_NAMES[clampi(_kind(o), 0, 3)]


func _fwd(o: Node3D) -> Vector3:
	return (o.call(&"look_forward") as Vector3) if o.has_method(&"look_forward") else -o.global_basis.z


## The point the director looks at on a crew member standing at `feet` (S2.2: up to 1 m above the feet).
func _target_at(feet: Vector3, crouched: bool) -> Vector3:
	var c: CrewController = _crew() if pilot != null else null
	var h: float = 1.0
	if c != null:
		h = minf(1.0, c.eye_height()) if crouched == c.crouched else (0.9 if crouched else 1.0)
	return feet + Vector3.UP * h


## (distance m, angle deg) of `target` in `o`'s view: horizontal angle for NPCs, 3D cone angle for cameras.
func _geom(o: Node3D, target: Vector3) -> Vector2:
	var eye: Vector3 = o.call(&"eye_position") as Vector3
	var to: Vector3 = target - eye
	var f: Vector3 = _fwd(o)
	var ang: float = 0.0
	if _kind(o) == Enums.ObserverKind.CAMERA:
		ang = rad_to_deg(f.angle_to(to)) if to.length_squared() > 1e-6 else 0.0
	else:
		var f2: Vector2 = Vector2(f.x, f.z)
		var t2: Vector2 = Vector2(to.x, to.z)
		ang = rad_to_deg(absf(f2.angle_to(t2))) if t2.length_squared() > 1e-6 and f2.length_squared() > 1e-6 else 0.0
	return Vector2(to.length(), ang)


func _crew_geom(o: Node3D) -> Vector2:
	var c: CrewController = _crew()
	return _geom(o, c.global_position + Vector3.UP * minf(1.0, c.eye_height()))


func _meter(o: Node3D) -> float:
	return rt.stealth.detection_value(o, _crew().slot)


func _hud_value(o: Node3D) -> float:
	var id: int = NetIds.of(o)
	for r: Dictionary in rt.hud_model.detection:
		if int(r.get("observer_net_id", -1)) == id:
			return float(r.get("value", -1.0))
	return -1.0


func _ring(o: Node3D) -> Dictionary:
	if hud == null:
		return {}
	var rings: DetectionRings = null
	for n: Node in hud.find_children("*", "DetectionRings", true, false):
		rings = n as DetectionRings
	if rings == null:
		return {}
	var id: int = NetIds.of(o)
	for r: Dictionary in rings.rings:
		if int(r.get("observer_net_id", -1)) == id:
			return r
	return {}


func _ring_s(o: Node3D) -> String:
	var r: Dictionary = _ring(o)
	if r.is_empty():
		return "ring -"
	return "ring %s %.2f %s%s" % [r.get("glyph", ""), float(r.get("value", 0.0)),
		"on" if bool(r.get("on_screen", false)) else "off", "+arc" if bool(r.get("arc", false)) else ""]


func _preset_key(o: Node3D) -> StringName:
	var p: Variant = o.get(&"detection_preset")
	if p is StringName or p is String:
		return StringName(p)
	return StringName(_kind_name(o))


## Highest meter on the local crew over every observer, and who.
func _max_meter() -> Array:
	var best: float = 0.0
	var who: Node3D = null
	for o: Node3D in _observers():
		var v: float = _meter(o)
		if v > best:
			best = v
			who = o
	return [best, who]


# --- survey ---------------------------------------------------------------------------------------------

func _survey() -> void:
	var c: CrewController = _crew()
	note("SURVEY crew %s zones %s DR %d mask_up %.2f s" % [Po5Pilot._v(c.global_position),
		rt.stealth.zone_kinds_at(c.global_position), _dr(), Tweak.crew().mask_up_time_s])
	var start: Dictionary = {}
	for o: Node3D in _observers():
		start[o] = o.global_position
	await wait_s(3.0)
	for o: Node3D in _observers():
		var extra: String = ""
		if _kind(o) == Enums.ObserverKind.CAMERA:
			extra = " fov %.0f range %.1f pan %.0f titan %s" % [float(o.get(&"fov_deg")), float(o.get(&"range_m")),
				float(o.get(&"pan_deg")), o.call(&"is_titan") if o.has_method(&"is_titan") else "-"]
		var moved: float = (o.global_position - (start.get(o, o.global_position) as Vector3)).length()
		note("OBS %s %s at %s eye %s fwd %s moved3s %.1f zones %s path %.1f m%s" % [_kind_name(o), o.name,
			Po5Pilot._v(o.global_position), Po5Pilot._v(o.call(&"eye_position") as Vector3), Po5Pilot._v(_fwd(o)), moved,
			rt.stealth.zone_kinds_at(o.global_position), _path_len(o.global_position), extra])
	for o: Node3D in _observers():
		for want: Vector2 in [Vector2(1.5, 0), Vector2(5, 0), Vector2(10, 0), Vector2(15, 0), Vector2(20, 0),
				Vector2(5, 45), Vector2(10, 45)]:
			var w: Vector2 = want
			if _kind(o) == Enums.ObserverKind.CAMERA and w.y > 0.0:
				w.y = 22.0
			var p: Dictionary = _pick_point(o, w.x, w.y, false)
			if p.is_empty():
				note("  %s %.0fm %.0fdeg: no point" % [o.name, w.x, w.y])
			else:
				note("  %s %.0fm %.0fdeg: %s d %.1f ang %.0f zones %s path %.1f" % [o.name, w.x, w.y,
					Po5Pilot._v(p["pos"]), p["d"], p["ang"], p["zones"], p["path"]])
	await shot("survey_spawn")


func _path_len(to: Vector3) -> float:
	var path: PackedVector3Array = pilot.nav_path(to)
	if path.is_empty():
		return -1.0
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	if path[path.size() - 1].distance_to(to) > 1.0:
		return -1.0
	return total


## A nav point (reachable from the crew) where a crew member would be about `want_d` m from `o`'s eye and `want_ang`
## deg off its view, with sight. {} if none within tolerance.
func _pick_point(o: Node3D, want_d: float, want_ang: float, crouched: bool) -> Dictionary:
	var map: RID = _crew().get_world_3d().navigation_map
	var base: Vector3 = o.global_position
	var best: Dictionary = {}
	var best_score: float = INF
	var eye: Vector3 = o.call(&"eye_position") as Vector3
	var excl: Array[RID] = []
	if o is CollisionObject3D:
		excl.append((o as CollisionObject3D).get_rid())
	var step: float = 0.5 if want_d <= 6.0 else 1.0
	var r_max: float = want_d * 1.3 + 1.0
	var x: float = -r_max
	while x <= r_max:
		var z: float = -r_max
		while z <= r_max:
			var q: Vector3 = Vector3(base.x + x, base.y, base.z + z)
			z += step
			var s: Vector3 = NavigationServer3D.map_get_closest_point(map, q)
			if Vector2(s.x - q.x, s.z - q.z).length() > step * 0.6 or absf(s.y - _crew().global_position.y) > 6.0:
				continue
			var t: Vector3 = _target_at(s, crouched)
			var g: Vector2 = _geom(o, t)
			if absf(g.x - want_d) > maxf(1.0, want_d * 0.25) or absf(g.y - want_ang) > 12.0:
				continue
			var score: float = absf(g.x - want_d) / maxf(want_d, 1.0) + absf(g.y - want_ang) / 30.0
			if score >= best_score:
				continue
			if not rt.stealth.has_los(eye, t, excl) and not rt.stealth.has_los(eye, s + Vector3.UP * 1.6, excl):
				continue
			var plen: float = _path_len(s)
			if plen < 0.0:
				continue
			best_score = score
			best = {"pos": s, "d": g.x, "ang": g.y, "zones": rt.stealth.zone_kinds_at(s), "path": plen}
		x += step
	return best


# --- samples --------------------------------------------------------------------------------------------

func _parse_samples(arg: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: String in (arg if arg != "" else samples_arg).split(",", false):
		var f: PackedStringArray = s.split(":")
		if f.size() < 4:
			continue
		out.append({"obs": f[0], "d": f[1].to_float(), "ang": f[2].to_float(), "crouch": f[3] == "crouch",
			"decay": f.has("decay"), "strafe": f.has("strafe"), "chain": f.has("chain"), "id": s})
	return out


func _samples() -> void:
	var list: Array[Dictionary] = _parse_samples()
	var need_launch: bool = true
	for smp: Dictionary in list:
		if not smp["chain"] or need_launch or _alarm != &"":
			if not await _launch():
				return
		need_launch = await _sample(smp)
	if rt != null:
		await _teardown()


## One sample; returns true when the run is spent (detected / alarm) and the next sample needs a new launch.
func _sample(smp: Dictionary) -> bool:
	var o: Node3D = _find_obs(smp["obs"])
	var c: CrewController = _crew()
	var id: String = smp["id"]
	if o == null:
		note("SAMPLE %s: SKIP observer not found" % id)
		_rows.append("%s|%s|SKIP no observer" % [heist, id])
		return false
	var crouch: bool = smp["crouch"]
	var p: Dictionary = _pick_point(o, smp["d"], smp["ang"], crouch)
	for _r: int in 6:  # a panning camera: try again as the cone swings
		if not p.is_empty():
			break
		await wait_s(1.0)
		p = _pick_point(o, smp["d"], smp["ang"], crouch)
	if p.is_empty():
		note("SAMPLE %s: SKIP no reachable point with sight at %.1f m / %.0f deg" % [id, smp["d"], smp["ang"]])
		_rows.append("%s|%s|%s|SKIP unreachable" % [heist, id, _kind_name(o)])
		return false
	note("SAMPLE %s (%s %s): walk to %s (planned d %.1f ang %.0f zones %s path %.1f) masked %s" % [id, _kind_name(o),
		o.name, Po5Pilot._v(p["pos"]), p["d"], p["ang"], p["zones"], p["path"], c.masked])
	# Masked already: approach crouched when the crouched range does not reach the point, then stand up there
	# (standing up is the start, like the mask going on).
	var sneak: bool = c.masked and not crouch
	if sneak:
		note("  sneak approach (crouched range %.1f m, point %.1f m)" % [_range(o, true), p["d"]])
	if crouch or sneak:
		pilot.inp.press(&"crouch")
	var pre_max: float = 0.0
	var arrived: bool = await pilot.goto(p["pos"], 0.3, 90.0)
	pre_max = maxf(pre_max, _max_meter()[0])
	await pilot.face(o.call(&"eye_position") as Vector3, 0.04, 1.5)
	await wait_s(0.3)
	# A patrolling guard walks on: wait where we stand (unmasked, PUBLIC: no fill) until he lines up again.
	var want_d: float = smp["d"]
	var want_a: float = smp["ang"]
	var lined: Callable = func() -> bool:
		var g: Vector2 = _crew_geom(o)
		return absf(g.x - want_d) <= maxf(1.0, want_d * 0.3) and absf(g.y - want_a) <= 15.0
	if (not c.masked or sneak) and not lined.call():
		var waited: float = 0.0
		while not lined.call() and waited < 20.0 and _alarm == &"":
			pilot.steer_at(o.call(&"eye_position") as Vector3)
			await get_tree().physics_frame
			waited += 1.0 / Engine.physics_ticks_per_second
		note("  waited %.1f s for %s to line up (%s)" % [waited, o.name, "ok" if lined.call() else "gave up"])
	var g0: Vector2 = _crew_geom(o)
	note("  arrived %s at %s d %.2f ang %.1f crouched %s meter %.2f (max any %.2f) alarm %s" % [arrived,
		Po5Pilot._v(c.global_position), g0.x, g0.y, c.crouched, _meter(o), pre_max, _alarm])
	if _alarm != &"" or _max_meter()[0] >= 1.0:
		_rows.append("%s|%s|%s|ABORT detected on approach (%s)" % [heist, id, _kind_name(o), _alarm])
		return true
	# Mask up (G hold) unless already masked: the meter can only start once the mask is on.
	var t_mask: float = -1.0
	var t: float = 0.0
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	if not c.masked:
		pilot.inp.press(&"mask_up")
		while not c.masked and t < Tweak.crew().mask_up_time_s + 2.0:
			await get_tree().physics_frame
			t += dt
		pilot.inp.release(&"mask_up")
		if not c.masked:
			note("  FAIL mask did not go on")
			_rows.append("%s|%s|%s|FAIL no mask" % [heist, id, _kind_name(o)])
			return true
	if sneak:
		pilot.inp.release(&"crouch")
		note("  stood up (sneak approach) at d %.2f ang %.1f" % [_crew_geom(o).x, _crew_geom(o).y])
	t_mask = 0.0
	t = 0.0
	var t_start: float = rt.heist_time_s
	var t_first: float = -1.0
	var t_full: float = -1.0
	var t_exit: float = -1.0
	var t_los_lost: float = -1.0
	var t_zero: float = -1.0
	var v_exit: float = 0.0
	var p_live: float = 0.0
	var t_live_full: float = -1.0
	var g_first: Vector2 = Vector2.ZERO
	var g_full: Vector2 = Vector2.ZERO
	var shot_mid: bool = false
	var hud_at_first: String = ""
	var hud_mid: String = ""
	var hud_full: String = ""
	var dr: int = _dr()
	var tbl: float = rt.stealth.fill_time(_preset_key(o), float(dr), g0.x, g0.y, crouch)
	var exited: bool = false
	var strafe: StringName = &""
	var limit: float = NEVER_S
	while t < limit:
		await get_tree().physics_frame
		var t_now: float = rt.heist_time_s - t_start  # game time: screenshot awaits skip physics frames
		var step: float = t_now - t
		t = t_now
		var v: float = _meter(o)
		var rate: float = rt.stealth.fill_rate(o, c)
		if not exited:
			p_live += rate * step
			if p_live >= 1.0 and t_live_full < 0.0:
				t_live_full = t
		if v > 0.0 and t_first < 0.0:
			t_first = t
			g_first = _crew_geom(o)
			hud_at_first = "meter %.2f hud %.2f %s" % [v, _hud_value(o), _ring_s(o)]
			limit = t + 12.0
		if v >= 0.55 and hud_mid == "":
			hud_mid = "meter %.2f hud %.2f %s" % [v, _hud_value(o), _ring_s(o)]
			if _shots_left > 0 and not shot_mid:
				shot_mid = true
				_shots_left -= 1
				await shot("%s_%s_%dm_%s_mid" % [_kind_name(o), o.name, roundi(smp["d"]), "crouch" if crouch else "stand"])
		if v >= 1.0 and t_full < 0.0:
			t_full = t
			g_full = _crew_geom(o)
			await get_tree().process_frame
			hud_full = "meter %.2f hud %.2f %s" % [v, _hud_value(o), _ring_s(o)]
			if shot_mid and _shots_left > 0:
				_shots_left -= 1
				await shot("%s_%s_%dm_full" % [_kind_name(o), o.name, roundi(smp["d"])])
			break
		if (smp["decay"] or smp["strafe"]) and not exited and v >= (DECAY_AT if smp["decay"] else 0.5):
			exited = true
			t_exit = t
			v_exit = v
			if smp["decay"]:
				pilot.inp.press(&"crouch")  # out of the stand range: PD2's crouch attention setting (S2.5)
			else:
				strafe = _strafe_out_action(o)
				pilot.inp.press(strafe)  # sideways out of the camera cone
			limit = t + 15.0
		if strafe != &"" and rate <= 0.0:
			pilot.inp.release(strafe)
			strafe = &""
		if exited and t_los_lost < 0.0 and rate <= 0.0:
			t_los_lost = t
		if exited and t_los_lost >= 0.0 and v <= 0.0:
			t_zero = t
			break
		if _alarm != &"":
			break
	if strafe != &"":
		pilot.inp.release(strafe)
	var g_end: Vector2 = _crew_geom(o)
	var fill: float = (t_full - t_first) if t_full >= 0.0 and t_first >= 0.0 else -1.0
	var decay: float = (t_zero - t_los_lost) if t_zero >= 0.0 else -1.0
	if fill < 0.0 and exited and t_first >= 0.0 and t_exit > t_first:
		# Left before "!": the meter is linear in time (D-128), so extrapolate first -> exit to the full fill.
		var off2: float = dr / 100.0
		fill = (t_exit - t_first) * (1.0 - off2) / maxf(v_exit - off2, 0.01)
		note("    fill extrapolated from %.2f s to shown %.2f: %.2f s" % [t_exit - t_first, v_exit, fill])
	var exp_decay: float = -1.0
	if exited:
		var off: float = dr / 100.0
		var prog: float = (v_exit - off) / (1.0 - off)
		exp_decay = prog * (float(Tweak.stealth().observer_presets[&"camera"]["delay_max"])
			if _kind(o) == Enums.ObserverKind.CAMERA else 1.0 / Tweak.stealth().npc_decay_per_s)
	note("  RESULT %s: first %.2f full %.2f -> fill %.2f s (live-rate integral %.2f, formula at start geom %.2f) "
		% [id, t_first, t_full, fill, t_live_full, tbl]
		+ "geom start d %.2f/%.1f first %.2f/%.1f full %.2f/%.1f end %.2f/%.1f crouched %s DR %d" % [g0.x, g0.y,
			g_first.x, g_first.y, g_full.x, g_full.y, g_end.x, g_end.y, c.crouched, dr])
	note("    HUD first: %s | mid: %s | full: %s" % [hud_at_first, hud_mid, hud_full])
	if exited:
		note("    DECAY exit at %.2f (shown %.2f) out-of-range at %.2f -> 0 at %.2f: %.2f s (PD2 expect %.2f s)" % [
			t_exit, v_exit, t_los_lost, t_zero, decay, exp_decay])
	_rows.append("%s|%s|%s|%s|d %.1f|ang %.0f|%s|DR %d|fill %s|live %s|formula %s|decay %s (exp %s)|%s" % [heist, id,
		_kind_name(o), o.name, g0.x, g0.y, "crouch" if crouch else "stand", dr, _fmt(fill), _fmt(t_live_full),
		_fmt(tbl), _fmt(decay), _fmt(exp_decay), hud_full if hud_full != "" else hud_mid])
	if crouch or exited:
		pilot.inp.release(&"crouch")
		await wait_s(0.2)
	var spent: bool = t_full >= 0.0 or _alarm != &"" or _max_meter()[0] >= 1.0
	if not spent and not exited:
		# Step back out of view and let it drain before the next chained sample.
		await wait_s(0.1)
	return spent


## PD2 detection range (m) of `o` on the local crew (S2.2 / S2.3), stand or crouched.
func _range(o: Node3D, crouched: bool) -> float:
	var cam: bool = _kind(o) == Enums.ObserverKind.CAMERA
	var civ: bool = _kind(o) == Enums.ObserverKind.CIVILIAN
	var far: float = float(o.get(&"range_m")) if cam else (20.0 if civ else 40.0)
	var cap: float = (15.0 if crouched else INF) if civ else (12.0 if crouched else 20.0)
	return minf(far, cap) * sqrt(1.0 / rt.stealth.detection_risk_mult(float(_dr())))


## move_left / move_right: whichever side takes the crew further off `o`'s view axis.
func _strafe_out_action(o: Node3D) -> StringName:
	var c: CrewController = _crew()
	var right: Vector3 = c.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var base: Vector3 = c.global_position + Vector3.UP * minf(1.0, c.eye_height())
	return &"move_right" if _geom(o, base + right).y > _geom(o, base - right).y else &"move_left"


## True when no observer could fill on a crouched crew member standing at `feet` (in range, in view, with sight).
func _leg_safe(feet: Vector3) -> String:
	var t: Vector3 = feet + Vector3.UP * 0.9
	for o: Node3D in _observers():
		if o.has_method(&"can_observe") and not bool(o.call(&"can_observe")):
			continue
		var g: Vector2 = _geom(o, t)
		var ft: float = rt.stealth.fill_time(_preset_key(o), float(_dr()), g.x, g.y, true)
		if is_inf(ft):
			continue
		if _kind(o) == Enums.ObserverKind.CAMERA:
			var rng: float = float(o.get(&"range_m"))
			if g.x > minf(rng, 12.0) * sqrt(1.0 / rt.stealth.detection_risk_mult(float(_dr()))) or g.y > 30.0:
				continue
		var excl: Array[RID] = []
		if rt.stealth.has_los(o.call(&"eye_position") as Vector3, t, excl):
			return String(o.name)
	return ""


## Opens (lockpicks, masked) the named Door with real input, like sl_pass.
func _open_door(door_name: String) -> void:
	var d: Door = rt.find_child(door_name, true, false) as Door
	if d == null:
		note("careful: no door %s" % door_name)
		return
	var comp: InteractableComponent = null
	for n: Node in d.find_children("*", "InteractableComponent", true, false):
		comp = n as InteractableComponent
		break
	if not d.is_open and comp != null:
		await pilot.use(comp, 30.0, func() -> bool: return d.is_open)
	note("careful: door %s open %s" % [door_name, d.is_open])


## D-130: shoot `cam` with the secondary (suppressed pistol) from where the crew is, crouched. Titan cameras
## (Lethal on Golden Hour) do not break.
func _shoot_camera(cam: Node3D) -> void:
	if cam == null:
		note("shoot: no camera")
		return
	pilot.inp.press(&"crouch")
	await pilot.inp.tap(&"slot_secondary")
	await wait_s(1.0)
	var wpn: Variant = _crew().get(&"weapons")
	note("shoot: %s titan %s at %.1f m, secondary %s" % [cam.name, cam.call(&"is_titan") if cam.has_method(&"is_titan")
		else "-", _crew().eye_position().distance_to(cam.global_position), wpn.get(&"current_id") if wpn is Object else "-"])
	var hits: int = 0
	for _k: int in 6:
		if bool(cam.get(&"destroyed")):
			break
		var aim: Vector3 = cam.global_position - cam.global_basis.z * 0.2
		for n: Node in cam.find_children("*", "CollisionShape3D", true, false):
			aim = (n as Node3D).global_position
			break
		await pilot.face(aim, 0.01, 1.0)
		await pilot.inp.tap(&"fire")
		hits += 1
		await wait_s(0.5)
	note("shoot: %s after %d shots: destroyed %s (titan %s) alarm %s" % [cam.name, hits, cam.get(&"destroyed"),
		cam.call(&"is_titan") if cam.has_method(&"is_titan") else "-", _alarm])
	await shot("shoot_%s_%s" % [cam.name, "broken" if bool(cam.get(&"destroyed")) else "intact"])
	_rows.append("%s|shoot|%s|diff %d|destroyed %s|titan %s" % [heist, cam.name, difficulty, cam.get(&"destroyed"),
		cam.call(&"is_titan") if cam.has_method(&"is_titan") else "-"])
	pilot.inp.release(&"crouch")


static func _fmt(v: float) -> String:
	if is_inf(v):
		return "never"
	return "-" if v < 0.0 else "%.2f" % v


# --- careful route ------------------------------------------------------------------------------------

## Crouched masked walk along `--route` (first point: where to mask up, unobserved). Logs every observer's peak meter.
func _careful() -> void:
	if not await _launch():
		return
	var pts: Array[Vector3] = []
	var doors: Dictionary = {}  # index in pts -> door name to open (lockpick) before walking to that point
	for s: String in route_arg.split(";", false):
		if s.begins_with("door:"):
			doors[pts.size()] = s.substr(5)
			continue
		var f: PackedStringArray = s.split(",")
		if f.size() == 3:
			pts.append(Vector3(f[0].to_float(), f[1].to_float(), f[2].to_float()))
	if pts.is_empty():
		note("careful: no route")
		return
	var c: CrewController = _crew()
	await wait_s(0.5)
	await shot("hud_pagers_%s" % ("lethal" if difficulty == Enums.Difficulty.LETHAL else "routine"))
	for smp: Dictionary in (_parse_samples(pre_arg) if pre_arg != "" else ([] as Array[Dictionary])):
		if await _sample(smp):
			note("careful: pre-sample spent the run")
			return
	if c.masked:
		pilot.inp.press(&"crouch")
	await pilot.goto(pts[0], 0.5, 90.0)
	note("careful: at mask spot %s, max meter %.2f" % [Po5Pilot._v(c.global_position), _max_meter()[0]])
	if not _nomask:
		pilot.inp.press(&"crouch")
		await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	note("careful: masked %s" % c.masked)
	await shot("careful_masked")
	var peak: Dictionary = {}
	var closest: Dictionary = {}
	pilot.hook_need = func() -> bool:
		for o: Node3D in _observers():
			var v: float = _meter(o)
			if v > float(peak.get(o.name, 0.0)):
				peak[o.name] = v
			var g: Vector2 = _crew_geom(o)
			if g.x < float((closest.get(o.name, Vector2(INF, 0)) as Vector2).x):
				closest[o.name] = g
		return false
	pilot.hook = func() -> bool: return false
	var ok: bool = true
	for i: int in range(1, pts.size()):
		var waited: float = 0.0
		var who: String = _leg_safe(pts[i])
		while who != "" and waited < 40.0 and _alarm == &"":
			await pilot.hold_position(0.5)
			waited += 0.5
			who = _leg_safe(pts[i])
		if waited > 0.0:
			note("careful: waited %.1f s before leg %d (%s)" % [waited, i, who if who != "" else "clear"])
		if doors.has(i):
			await _open_door(String(doors[i]))
		var got: bool = await pilot.goto(pts[i], 0.5, 120.0)
		var mm: Array = _max_meter()
		note("careful: leg %d -> %s reached %s, max meter now %.2f (%s) alarm %s" % [i, Po5Pilot._v(pts[i]), got, mm[0],
			(mm[1] as Node3D).name if mm[1] != null else "-", _alarm])
		if _alarm != &"" or mm[0] >= 1.0:
			ok = false
			await shot("careful_detected")
			break
		if not got:
			ok = false
			break
	await shot("careful_end")
	for o: Node3D in _observers():
		var g: Vector2 = closest.get(o.name, Vector2(INF, 0)) as Vector2
		if g.x < 25.0:
			note("careful: %s %s closest %.1f m (ang %.0f) peak meter %.2f" % [_kind_name(o), o.name, g.x, g.y,
				float(peak.get(o.name, 0.0))])
	note("careful: RESULT %s (alarm %s)" % ["CLEAN" if ok else "DETECTED/FAILED", _alarm])
	_rows.append("%s|careful|%s|alarm %s" % [heist, "CLEAN" if ok else "FAIL", _alarm])
	pilot.hook_need = Callable()
	pilot.inp.release(&"crouch")
	if not ok or samples_arg == "":
		return
	# Chained samples in the same run (masked: sneak approaches).
	for smp: Dictionary in _parse_samples():
		if _alarm != &"":
			note("careful+samples: alarm, stopping")
			break
		if await _sample(smp):
			break
	if shoot_arg != "" and _alarm == &"":
		await _shoot_camera(_find_obs(shoot_arg))
	for smp: Dictionary in (_parse_samples(post_arg) if post_arg != "" else ([] as Array[Dictionary])):
		if _alarm != &"" or await _sample(smp):
			break
