## PO-1/PO-2 windowed playthrough the way a player enters a heist (D-086): main menu -> safehouse -> planning ->
## heist select -> briefing -> pre-planning -> loadout -> Launch, by REAL X input (xdotool clicks and keys), then
## checks the mouse capture, mouse look and holding G to mask up. Run as a scene, never --headless:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1280x720 --path game res://tests/p/_review/po_playthrough.tscn -- --out=/abs/dir [--heist=glasshouse]
## Needs xdotool. Prints "[PO] ..." lines and "[PO] RESULT PASS|FAIL <reasons>"; saves NN_step.png into --out.
## Owner: ENV P.
extends Node

var _out: String = ""
var _heist: StringName = &"glasshouse"
var _flow: MenuFlow = null
var _fails: PackedStringArray = []
var _n: int = 0


func _ready() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = String(args.get("out", OS.get_user_data_dir() + "/po_playthrough"))
	_heist = StringName(String(args.get("heist", "glasshouse")))
	DirAccess.make_dir_recursive_absolute(_out)
	await _run()
	print("[PO] RESULT %s %s" % ["PASS" if _fails.is_empty() else "FAIL", "; ".join(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _run() -> void:
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child.call_deferred(_flow)
	await _frames(20)
	await _shot("main_menu")
	await _click(_flow.main_menu.safehouse_button, "Safehouse")
	await _frames(20)
	await _shot("hub")
	if _flow.current == _flow.hub:
		await _click(_flow.hub.station_button(&"planning"), "Planning station")
	else:
		_log("hub is %s (3D safehouse?): opening planning via the station API" % _flow.current)
		_flow.call(&"open_station", &"planning")
	await _frames(20)
	await _shot("heist_select")
	var hs: HeistSelect = _flow.heist_select
	var idx: int = -1
	var entries: Array = hs.get(&"_entries")
	for i: int in entries.size():
		if StringName((entries[i] as Dictionary)["id"]) == _heist:
			idx = i
	if idx < 0:
		_fail("heist %s not offered" % _heist)
		return
	await _click(hs.heist_buttons[idx], "heist %s" % _heist)
	await _click(hs.next_button, "Next")
	await _frames(20)
	await _shot("briefing")
	if _flow.briefing_screen == null or _flow.current != _flow.briefing_screen:
		_fail("Next did not open the briefing (current %s)" % _flow.current)
		return
	await _click(_flow.briefing_screen.continue_button, "Continue")
	await _frames(20)
	await _shot("preplanning")
	if _flow.current == _flow.preplanning_screen:
		await _click(_flow.preplanning_screen.confirm_button, "Confirm plan")
		await _frames(20)
	await _shot("loadout")
	if _flow.current != _flow.loadout_screen:
		_fail("not on the loadout screen (%s)" % _flow.current)
		return
	await _click(_flow.loadout_screen.launch_button, "Launch")
	var t0: int = Time.get_ticks_msec()
	while (_flow.runtime == null or _crew() == null) and Time.get_ticks_msec() - t0 < 300000:
		await _frames(5)
	if _crew() == null:
		_fail("no local crew after Launch")
		return
	await _frames(30)
	await _in_heist()


func _crew() -> CrewController:
	if _flow.runtime == null or not is_instance_valid(_flow.runtime):
		return null
	return _flow.runtime.crew_controller(Net.local_slot()) as CrewController


func _in_heist() -> void:
	var c: CrewController = _crew()
	_log("in heist: mode=%s civilian=%s masked=%s mouse_mode=%d wants=%s focus_owner=%s" % [c.player_mode,
		c.civilian, c.masked, Input.mouse_mode, MouseCapture.wants_capture(), get_viewport().gui_get_focus_owner()])
	_log("fps %.1f" % Engine.get_frames_per_second())
	await _shot("heist_spawn")
	if not MouseCapture.is_captured():
		_log("not captured after launch: clicking once like a player")
		_xdo(["mousemove", "640", "360", "click", "1"])
		await _frames(10)
	if not MouseCapture.is_captured():
		_fail("mouse not captured in the heist (mode %d)" % Input.mouse_mode)
	var yaw0: float = c.look_yaw
	for _i: int in 10:
		_xdo(["mousemove_relative", "--", "30", "0"])
		await _frames(2)
	await _frames(10)
	_log("mouse look: yaw %.3f -> %.3f" % [yaw0, c.look_yaw])
	if not c.look_yaw < yaw0 - 0.1:
		_fail("mouse motion did not turn the camera")
	await _shot("after_mouse_look")
	# Hold G like a player until masked. Game time (physics ticks), not wall clock: loaded llvmpipe runs at ~1 fps
	# and 30 s of wall clock was under 1 s of game time (the first "can't mask up" repro was this artifact).
	_xdo(["keydown", "g"])
	var t0: int = Time.get_ticks_msec()
	var ticks: int = 0
	var max_ticks: int = int(ceil((Tweak.crew().mask_up_time_s + 1.0) * Engine.physics_ticks_per_second))
	var peak: float = 0.0
	var pin: PlayerInput = c.get_node(^"PlayerInput") as PlayerInput
	var last: String = ""
	var shot_mid: bool = false
	while not c.masked and ticks < max_ticks and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().physics_frame
		ticks += 1
		peak = maxf(peak, c.mask_progress)
		var st: String = "pressed=%s intent=%s enabled=%s supp=%s state=%d civ=%s cap=%s focus=%s bot=%s" % [
			Input.is_action_pressed(&"mask_up"), c.intent.mask_up, pin.enabled, pin.get(&"_suppressed").keys(),
			c.crew_state, c.civilian, MouseCapture.is_captured(), get_viewport().gui_get_focus_owner(),
			_flow.runtime.has_bot_intent(c.slot)]
		if st != last:
			_log("G t=%d prog=%.2f %s" % [Time.get_ticks_msec() - t0, c.mask_progress, st])
			last = st
		if not shot_mid and c.mask_progress > 0.4:
			shot_mid = true
			await _shot("mask_up_mid")
	_xdo(["keyup", "g"])
	_log("hold G %d ticks (%.1f s game, %.1f s wall): masked=%s peak_progress=%.2f ui_has_focus=%s" % [ticks,
		float(ticks) / Engine.physics_ticks_per_second, (Time.get_ticks_msec() - t0) / 1000.0, c.masked, peak,
		(c.get_node(^"PlayerInput") as PlayerInput).ui_has_focus()])
	if not c.masked:
		_fail("holding G for mask_up_time_s + 1 s game time did not mask up (civilian=%s mode=%s)" % [c.civilian, c.player_mode])
	await _frames(30)
	await _shot("masked")
	# Walk forward a bit with W.
	var p0: Vector3 = c.global_position
	_xdo(["keydown", "w"])
	for _i: int in 60:
		await get_tree().physics_frame
	_xdo(["keyup", "w"])
	_log("walk W: moved %.2f m" % c.global_position.distance_to(p0))
	if c.global_position.distance_to(p0) < 0.5:
		_fail("W did not move the player")
	await _shot("walked")
	await _kerb(c)


## PO-3: off the sidewalk kerb onto the street and back up it, by real mouse turns and W (the spawn faces the
## shop; the street is behind it).
func _kerb(c: CrewController) -> void:
	await _turn_by(c, PI)
	var y0: float = c.global_position.y
	var down: bool = await _walk_until(func() -> bool: return c.global_position.y < y0 - 0.08, 6.0)
	await _walk_ticks(20)
	_log("kerb down: %s (y %.2f -> %.2f) at %s" % [down, y0, c.global_position.y, c.global_position])
	if not down:
		_log("no kerb behind the spawn within 6 s (not a failure)")
		return
	await _shot("street")
	await _turn_by(c, PI)
	var y1: float = c.global_position.y
	var up: bool = await _walk_until(func() -> bool: return c.global_position.y > y0 - 0.03, 4.0)
	_log("kerb up: %s (y %.2f -> %.2f, kerb %.2f m) at %s" % [up, y1, c.global_position.y, y0 - y1,
		c.global_position])
	if not up:
		_fail("could not walk back up the %.2f m kerb at %s" % [y0 - y1, c.global_position])
	await _shot("back_on_kerb")


func _turn_by(c: CrewController, rad: float) -> void:
	var target: float = c.look_yaw + rad
	for _i: int in 200:
		var err: float = wrapf(target - c.look_yaw, -PI, PI)
		if absf(err) < 0.03:
			return
		# yaw grows to the left (mouse left = negative x); PlayerInput ~0.0025 rad per px at default sensitivity
		var px: int = clampi(int(-err / 0.0025), -60, 60)
		if px == 0:
			px = -1 if err > 0.0 else 1
		_xdo(["mousemove_relative", "--", str(px), "0"])
		for _t: int in 2:
			await get_tree().physics_frame


func _walk_until(cond: Callable, seconds: float) -> bool:
	_xdo(["keydown", "w"])
	var ok: bool = false
	for _i: int in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		if cond.call():
			ok = true
			break
	_xdo(["keyup", "w"])
	return ok


func _walk_ticks(n: int) -> void:
	_xdo(["keydown", "w"])
	for _i: int in n:
		await get_tree().physics_frame
	_xdo(["keyup", "w"])


func _click(ctrl: Control, what: String) -> void:
	if ctrl == null or not ctrl.is_visible_in_tree():
		_fail("cannot click %s (missing / hidden)" % what)
		return
	var local: Vector2 = ctrl.get_global_transform_with_canvas() * (ctrl.size * 0.5)
	var screen: Vector2 = get_viewport().get_final_transform() * local
	var wp: Vector2i = DisplayServer.window_get_position()
	var x: int = wp.x + int(screen.x)
	var y: int = wp.y + int(screen.y)
	_log("click %s at (%d,%d)" % [what, x, y])
	_xdo(["mousemove", str(x), str(y)])
	await _frames(3)
	_xdo(["click", "1"])
	await _frames(6)


func _xdo(argv: PackedStringArray) -> void:
	var out: Array = []
	var rc: int = OS.execute("xdotool", argv, out, true)
	if rc != 0:
		_fail("xdotool %s rc=%d %s" % [" ".join(argv), rc, out])


func _shot(step: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var path: String = "%s/%02d_%s.png" % [_out, _n, step]
	get_viewport().get_texture().get_image().save_png(path)
	_log("shot %s" % path)


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().process_frame


func _log(s: String) -> void:
	print("[PO] ", s)


func _fail(s: String) -> void:
	_fails.append(s)
	_log("FAIL " + s)
