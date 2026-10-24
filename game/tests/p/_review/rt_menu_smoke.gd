# gdlint:disable=max-returns
## LEAD (round 311, D-169 Rolling Thunder un-hidden): one windowed smoke from the REAL main menu, the way a player
## reaches the heist: main menu -> All Stations -> the Board -> the Rolling Thunder pin -> Take -> briefing Continue ->
## pre-planning Confirm -> loadout Launch -> about a minute in the heist. Every press is a real mouse click
## (InputEventMouseButton at the control's centre); a control that a click does not trigger is a FAIL row (no emit
## fallback). Stated shortcut: when no Rolling Thunder pin is on the Board this hour, the Board's broker buys it
## (the broker's heist / difficulty pickers are set by index; the Buy press is a real click; the test profile's stash is
## funded first, since a fresh profile has $0).
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --resolution 960x540 --path game \
##     res://tests/p/_review/rt_menu_smoke.tscn -- --out=/abs/dir
## Rows: "[RTM] ROW <step> | PASS|FAIL|NOTE | <detail>"; "[RTM] RESULT". Owner: ENV P.
extends Node

const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const RT_ID: StringName = &"rolling_thunder"
const IN_HEIST_S: float = 60.0
const STASH_FOR_BROKER: int = 50000

var _out: String = "user://rt_menu_smoke"
var _ok: bool = true
var _n: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().process_frame


func _shot(nm: String) -> void:
	_n += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path("%s/%02d_%s.png" % [_out, _n, nm]))


func _row(step: String, good: bool, detail: String, note: bool = false) -> void:
	_ok = _ok and (good or note)
	print("[RTM] ROW %s | %s | %s" % [step, "NOTE" if note else ("PASS" if good else "FAIL"), detail])


## A real left click at the centre of `c` (mouse move, press, release). True when `fired` turned true.
func _click(c: Control, fired: Array[bool]) -> bool:
	if c == null or not c.is_visible_in_tree():
		return false
	# Window coordinates: the project stretches a 1920x1080 canvas (canvas_items) into the window, and input events
	# are in window pixels, so map the control's canvas centre through the viewport's final (stretch) transform.
	var at: Vector2 = c.get_viewport().get_final_transform() * c.get_global_rect().get_center()
	var mv: InputEventMouseMotion = InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	await _frames(2)
	for down: bool in [true, false]:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)
		await _frames(2)
	await _frames(6)
	return fired[0]


## Click button `b` and report whether its `pressed` signal fired.
func _press(step: String, b: Button) -> bool:
	var fired: Array[bool] = [false]
	if b == null:
		_row(step, false, "no button")
		return false
	var cb: Callable = func() -> void: fired[0] = true
	b.pressed.connect(cb)
	var ok: bool = await _click(b, fired)
	if b.pressed.is_connected(cb):
		b.pressed.disconnect(cb)
	_row(step, ok, "'%s' at %s (window %s), visible %s, disabled %s" % [b.text, b.get_global_rect().get_center().round(),
		(b.get_viewport().get_final_transform() * b.get_global_rect().get_center()).round(),
		b.is_visible_in_tree(), b.disabled])
	return ok


func _run() -> void:
	MouseCapture.reset()
	# Stated shortcut: a fresh profile has $0, and the broker (used when no RT pin is up this hour) is paid from the
	# stash; fund the stash so the Buy press can go through. Nothing else in the profile changes.
	var prof: PlayerProfile = SaveService.load_profile(0)
	if prof == null:
		prof = PlayerProfile.new_default()
	if prof.stash < STASH_FOR_BROKER:
		prof.stash = STASH_FOR_BROKER
		SaveService.save_profile(prof, 0)
	_row("profile stash for the broker (stated shortcut)", true, "stash $%d" % prof.stash, true)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await _frames(10)
	await _shot("main_menu")
	if not await _press("main menu: All Stations", f.main_menu.stations_button):
		_finish()
		return
	await _frames(10)
	var hub_board: Button = f.hub.station_buttons.get(&"board") as Button if f.hub != null else null
	if not await _press("stations: the Board", hub_board):
		_finish()
		return
	await _frames(20)
	var board: BoardScreen = f.board_screen
	if board == null or not board.is_visible_in_tree():
		_row("the Board open", false, "board_screen %s" % board)
		_finish()
		return
	await _shot("board")
	var pin: BoardPin = null
	for p: BoardPin in board.map_view.pins:
		if StringName(p.contract.get("heist_id", &"")) == RT_ID:
			pin = p
			break
	var ids: Array[String] = []
	for p: BoardPin in board.map_view.pins:
		ids.append(String(p.contract.get("heist_id", "")))
	if pin != null:
		_row("Rolling Thunder pin on the Board", true, "pins %s" % [ids])
		if not await _press("the RT pin", pin):
			_finish()
			return
		await _frames(6)
		await _shot("rt_pin_selected")
		if not await _press("Take the contract", board.take_button):
			_finish()
			return
	else:
		_row("Rolling Thunder pin on the Board", false, "not pinned this hour: pins %s; broker instead" % [ids], true)
		await _press("open the broker", board.broker_toggle)
		var idx: int = -1
		for i: int in board.heist_pool.size():
			if StringName(board.heist_pool[i].get("id", &"")) == RT_ID:
				idx = i
		_row("RT in the broker's heist list", idx >= 0, "pool %d heists, RT index %d" % [board.heist_pool.size(), idx])
		if idx < 0:
			_finish()
			return
		board.broker_heist.select(idx)
		board.broker_heist.item_selected.emit(idx)
		await _frames(4)
		await _shot("broker_rt")
		if not await _press("broker: Buy", board.buy_button):
			_finish()
			return
	await _frames(20)
	var brief: BriefingScreen = f.briefing_screen
	_row("briefing for Rolling Thunder", brief != null and brief.is_visible_in_tree() and f._heist_id == RT_ID,
		"heist %s, difficulty %d" % [f._heist_id, f._difficulty])
	await _shot("briefing")
	if not await _press("briefing: Continue", brief.continue_button if brief != null else null):
		_finish()
		return
	await _frames(20)
	var pre: PreplanningScreen = f.preplanning_screen
	await _shot("preplanning")
	if not await _press("pre-planning: Confirm", pre.confirm_button if pre != null else null):
		_finish()
		return
	await _frames(20)
	var lo: LoadoutScreen = f.loadout_screen
	await _shot("loadout")
	if not await _press("loadout: Launch", lo.launch_button if lo != null else null):
		_finish()
		return
	var t0: int = Time.get_ticks_msec()
	while (f.runtime == null or not is_instance_valid(f.runtime)) and Time.get_ticks_msec() - t0 < 1200000:
		await _frames(30)
	var rt: HeistRuntime = f.runtime
	_row("the heist is up", rt != null and rt.heist_id == RT_ID, "runtime %s, heist %s" % [rt,
		rt.heist_id if rt != null else &"-"])
	if rt == null:
		_finish()
		return
	# LEAD: is the start view the player's own first-person camera? 2 s of heist time after spawn: the viewport's
	# current Camera3D vs the local crew's Head/Camera, its distance from the eye, and whether the body is visible.
	var hs0: float = rt.heist_time_s
	while rt.heist_time_s - hs0 < 2.0 and is_instance_valid(rt):
		await _frames(5)
	var me: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	var cur: Camera3D = get_viewport().get_camera_3d()
	var own: Camera3D = me.get_node_or_null(^"Head/Camera") as Camera3D if me != null else null
	var d: float = cur.global_position.distance_to(me.eye_position()) if cur != null and me != null else -1.0
	_row("start view is the player's own first-person camera", cur != null and cur == own and d < 0.3,
		"current %s, own Head/Camera %s, %.2f m from the eye, own current %s" % [cur.get_path() if cur != null else
		"none", own.get_path() if own != null else "none", d, own.current if own != null else false])
	await _shot("in_heist_start")
	var h0: float = rt.heist_time_s
	while rt.heist_time_s - h0 < IN_HEIST_S and is_instance_valid(rt) and rt.phase != Enums.HeistPhase.ENDED:
		await _frames(30)
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController if is_instance_valid(rt) else null
	_row("a minute in", is_instance_valid(rt) and rt.phase != Enums.HeistPhase.ENDED and c != null,
		"heist time %.0f s, phase %s, mode %s, wants_capture %s" % [rt.heist_time_s if is_instance_valid(rt) else -1.0,
		Enums.HeistPhase.keys()[rt.phase] if is_instance_valid(rt) else "-", c.player_mode if c != null else &"-",
		MouseCapture.wants_capture()])
	await _shot("a_minute_in")
	_finish()


func _finish() -> void:
	print("[RTM] RESULT %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)
	await get_tree().create_timer(10.0, true, false, true).timeout
	OS.kill(OS.get_process_id())  # finished runs can hang in shutdown under llvmpipe
