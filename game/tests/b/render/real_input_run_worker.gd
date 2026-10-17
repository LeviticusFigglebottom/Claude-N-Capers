## Worker for real_input_run_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const MAX_STEPS: int = 60

var _out: String = ""
var _heist: StringName = &"glasshouse"
var _n: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = StringName(args[1]) if args.size() > 1 else &"glasshouse"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/real_input_run").path_join(String(_heist))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _key(code: Key, hold_s: float = 0.0) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	if hold_s > 0.0:
		await get_tree().create_timer(hold_s).timeout
	else:
		await _frames(2)
	var u: InputEventKey = e.duplicate() as InputEventKey
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _nav_to(target: Control, label: String) -> bool:
	await _frames(2)
	var keys: Array[Key] = [KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_LEFT]
	var d: int = 0
	var seen: Dictionary = {}
	for _i: int in range(MAX_STEPS):
		if _focus() == target:
			return true
		seen[_focus()] = true
		await _key(keys[d])
		if seen.has(_focus()):
			d = (d + 1) % keys.size()
	print("RUN NOTE %s not reachable by arrows (focus on %s)" % [label, _focus()])
	return false


func _press(target: Control, label: String) -> bool:
	if not await _nav_to(target, label):
		return false
	await _key(KEY_ENTER)
	return true


func _shot(tag: String, frames: int = 20) -> void:
	await _frames(frames)
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("RUN SHOT ", path, " focus=", _focus())


func _key_of(action: StringName) -> Key:
	for ev: InputEvent in InputMap.action_get_events(action):
		var k: InputEventKey = ev as InputEventKey
		if k != null:
			return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	return KEY_NONE


func _run() -> void:
	SaveService.root_dir = "user://real_input_run_%d" % OS.get_process_id()
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	SaveService.save_profile(p, 0)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _shot("main_menu", 30)
	await _press(_flow.main_menu.safehouse_button, "Safehouse")
	await _shot("hub")
	await _press(_flow.hub.station_button(&"planning"), "Planning")
	var hs: HeistSelect = _flow.heist_select
	var idx: int = HeistCatalog.ids().find(_heist)
	await _nav_to(hs.heist_buttons[idx], String(_heist))
	await _key(KEY_ENTER)
	await _shot("heist_select")
	await _press(hs.next_button, "Next")
	await _shot("briefing", 30)
	await _press(_flow.briefing_screen.continue_button, "briefing Continue")
	await _shot("preplanning", 30)
	await _press(_flow.preplanning_screen.confirm_button, "pre-planning Confirm")
	await _shot("loadout")
	var lo: LoadoutScreen = _flow.loadout_screen
	if await _press(lo.weapon_option, "secondary slot"):
		await _shot("loadout_secondary_picker")
		await _key(KEY_RIGHT)
		await _shot("loadout_picker_locked_preview")
		await _key(KEY_ESCAPE)
	await _press(lo.launch_button, "Launch")
	var t0: int = Time.get_ticks_msec()
	while _flow.runtime == null and Time.get_ticks_msec() - t0 < 90000:
		await _frames(5)
	if _flow.runtime == null:
		print("RUN NOTE the heist did not launch")
		get_tree().quit(1)
		return
	await get_tree().create_timer(4.0).timeout
	await _shot("in_heist_casing", 5)
	await _key(_key_of(&"mask_up"), 2.6)
	await get_tree().create_timer(1.5).timeout
	await _shot("in_heist_masked", 5)
	var tab: Key = _key_of(&"scoreboard")
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = tab
	e.keycode = tab
	e.pressed = true
	Input.parse_input_event(e)
	await _shot("tab_sheet", 20)
	var u: InputEventKey = e.duplicate() as InputEventKey
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(5)
	_flow.runtime.call(&"end_heist", true, [Net.local_slot()] as Array[int])  # setup: the heist ends
	var pd: PaydayScreen = null
	t0 = Time.get_ticks_msec()
	while pd == null and Time.get_ticks_msec() - t0 < 15000:
		for n: Node in get_tree().root.find_children("*", "PaydayScreen", true, false):
			if (n as PaydayScreen).is_visible_in_tree():
				pd = n as PaydayScreen
		await _frames(3)
	if pd == null:
		print("RUN NOTE no payday")
		get_tree().quit(1)
		return
	await get_tree().create_timer(3.5).timeout  # the count-up lands on its own
	await _shot("payday", 5)
	await _press(pd.continue_button, "payday Continue")
	if pd.cards_stage:
		await get_tree().create_timer(PaydayScreen.INPUT_GRACE_S + 0.3).timeout
		await _shot("payday_cards")
		await _press(pd.card_views[0], "card 1")
		await _shot("payday_card_picked")
		await _press(pd.continue_button, "cards Continue")
	t0 = Time.get_ticks_msec()
	while not (_flow.current == (_flow.hub as Control) and _flow.visible) and Time.get_ticks_msec() - t0 < 10000:
		await _frames(3)
	await _shot("hub_after", 30)
	SaveService.delete_profile(0)
	print("RUN DONE")
	get_tree().quit(0)
