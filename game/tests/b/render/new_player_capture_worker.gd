## Worker for new_player_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"glasshouse"
const LOAD_TIMEOUT_MS: int = 600000
const REBINDS: Dictionary = {&"interact": KEY_E, &"mask_up": KEY_Q, &"dismiss_tip": KEY_J}

var _out: String = ""
var _mock: bool = false
var _n: int = 0
var _flow: MenuFlow = null
var _cards: Array[StringName] = []


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/new_player"
	_mock = args.size() > 1 and args[1] == "mock"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(step: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, step, img.get_width(), img.get_height()]
	img.save_png(path)
	print("NPF SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	# A fresh, throw-away profile + settings folder: OnboardingTips persists into it like a real first run.
	var tmp: String = "user://new_player_capture_%d" % OS.get_process_id()
	SaveService.root_dir = tmp.path_join("profiles")
	GameSettings.root_dir = tmp.path_join("settings")
	GameSettings.set_current(GameSettings.new())
	OnboardingTips.persist = true
	OnboardingTips.reset()
	OnboardingTips._loaded = false
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _shot("main_menu", 20)
	_set_hub_mode("menu")
	_flow.main_menu.safehouse_button.pressed.emit()
	await _shot("hub_2d_start_here", 20)
	print("NPF START_HERE 2d=", _flow.hub.start_here != null and _flow.hub.start_here.is_visible_in_tree())
	_set_hub_mode("walk")
	if _flow.safehouse.scene_available():
		_flow.show_hub()
		await _shot("hub_3d_start_here", 30)
		print("NPF START_HERE 3d=", _flow.safehouse.hud.start_here.is_visible_in_tree())
	else:
		print("NPF no 3D safehouse scene in this build: the walk setting falls back to the 2D hub")
	if _mock:
		await _mock_cards()
	else:
		await _real_heist()
	print("NPF CARDS ", _cards)
	print("NPF DISK ", SaveService.load_profile(SLOT).settings.get(OnboardingTips.SETTINGS_KEY, []))
	_set_hub_mode("menu")
	_flow.show_hub()
	await _shot("hub_2d_after_payday", 20)
	print("NPF START_HERE after 2d=", _flow.hub.start_here.is_visible_in_tree())
	print("NPF DONE %d frames" % _n)
	get_tree().quit(0)


func _set_hub_mode(mode: String) -> void:
	GameSettings.current().set_value(GameSettings.CONTROLS, &"safehouse_hub", mode)


func _rebind() -> void:
	var s: GameSettings = GameSettings.current()
	for a: StringName in REBINDS:
		var k: InputEventKey = InputEventKey.new()
		k.physical_keycode = REBINDS[a] as Key
		InputBindings.rebind(s, a, InputEventCodec.to_dict(k), false)
	InputBindings.apply(s)


func _note(hud: Hud) -> void:
	if hud.onboarding.shown != &"" and (_cards.is_empty() or _cards[-1] != hud.onboarding.shown):
		_cards.append(hud.onboarding.shown)


## Waits until the card shows `id`; false on timeout.
func _wait_card(hud: Hud, id: StringName, timeout_s: float = 40.0) -> bool:
	var t0: int = Time.get_ticks_msec()
	while hud.onboarding.shown != id and Time.get_ticks_msec() - t0 < int(timeout_s * 1000.0):
		_note(hud)
		await get_tree().process_frame
	_note(hud)
	return hud.onboarding.shown == id


func _real_heist() -> void:
	_flow.open_station(&"planning")
	for n: Node in get_tree().root.find_children("*", "HeistSelect", true, false):
		if n.has_method(&"select_heist_id"):
			n.call(&"select_heist_id", HEIST)
	_flow.call(&"_on_heist_chosen", HEIST, Enums.Difficulty.ROUTINE)
	await _shot("briefing", 12)
	_flow.call(&"_on_briefing_continue", HEIST, Enums.Difficulty.ROUTINE)
	_flow.call(&"_on_preplan_confirmed", {})
	await _shot("loadout", 12)
	_flow.call(&"_on_launch_requested", _flow.loadout_screen.current_loadout())
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < LOAD_TIMEOUT_MS:
		await get_tree().process_frame
	var hud: Hud = _hud()
	if hud == null:
		print("NPF real heist did not load in %d s: mock HUD for the cards" % (LOAD_TIMEOUT_MS / 1000))
		await _mock_cards()
		return
	if await _wait_card(hud, &"casing", 400.0):
		await _shot("gh_card_casing", 20)
	hud.onboarding.dismiss()
	if await _wait_card(hud, &"heist_glasshouse", 120.0):
		await _shot("gh_card_heist", 20)
	_rebind()
	await _shot("gh_card_heist_rebound", 20)
	var me: CrewController = _local_crew()
	if me != null:
		me.set_masked()
	hud.onboarding.dismiss()
	if await _wait_card(hud, &"stealth", 120.0):
		await _shot("gh_card_stealth_rebound", 20)
	var pm: PauseMenu = _flow.options_menu.open_pause()
	if pm != null:
		pm.open_confirm()
		await get_tree().process_frame
		pm.confirm_button.pressed.emit()
	await _shot("payday", 40)
	var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
	if pd != null and is_instance_valid(pd):
		pd.continue_button.pressed.emit()
	await _shot("home_after_payday", 40)
	if _flow.safehouse.is_active():
		print("NPF START_HERE after 3d=", _flow.safehouse.hud.start_here.is_visible_in_tree())


## The in-heist frames on the real HUD scene over a MockHudModel (no level), then a payday for a failed run.
func _mock_cards() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	get_tree().root.add_child(layer)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.16, 0.17, 0.19)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var model: MockHudModel = MockHudModel.new()
	model.casing = false
	layer.add_child(model)
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	hud.heist_id = HEIST
	layer.add_child(hud)
	await get_tree().process_frame
	hud.hint.capture_probe = func() -> bool: return true
	hud.bind(model)
	model.player_mode = &"casing"
	if await _wait_card(hud, &"casing", 400.0):
		await _shot("gh_card_casing_mockhud", 20)
	hud.onboarding.dismiss()
	if await _wait_card(hud, &"heist_glasshouse", 120.0):
		await _shot("gh_card_heist_mockhud", 20)
	_rebind()
	await _shot("gh_card_heist_rebound_mockhud", 20)
	hud.onboarding.dismiss()
	model.masked = true
	model.player_mode = &"masked"
	model.interaction = {"text_key": &"ui.prompt.pick_lock", "args": {}, "progress": 0.0, "blocked_reason": &""}
	if await _wait_card(hud, &"stealth", 120.0):
		await _shot("gh_card_stealth_rebound_mockhud", 20)
	layer.queue_free()
	await get_tree().process_frame
	var pd: PaydayScreen = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	pd.profile_slot = SLOT
	_flow.add_child(pd)
	await get_tree().process_frame
	_flow.show_screen(pd)
	pd.show_result({"heist_id": String(HEIST), "success": false, "difficulty": Enums.Difficulty.ROUTINE,
			"stealth": false, "time_s": 300.0, "loot": [], "crew": []})
	await _shot("payday_mockrun", 30)
	pd.queue_free()
	_flow.show_hub()
	await _shot("home_after_payday", 30)


func _hud() -> Hud:
	var own: Hud = _flow.get(&"_hud") as Hud if _flow != null else null  # the flow's in-heist HUD (not a stray one)
	if own != null and is_instance_valid(own) and own.model != null:
		return own
	for n: Node in get_tree().root.find_children("*", "Hud", true, false):
		if n is Hud and (n as Hud).model != null:
			return n as Hud
	return null


func _local_crew() -> CrewController:
	for n: Node in get_tree().root.find_children("*", "CrewController", true, false):
		var c: CrewController = n as CrewController
		if c != null and c.slot == Net.local_slot() and not c.is_ai:
			return c
	return null
