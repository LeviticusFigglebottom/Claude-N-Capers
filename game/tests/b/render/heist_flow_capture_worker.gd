## Worker for heist_flow_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0

var _out: String = ""
var _heist: StringName = &"glasshouse"
var _n: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = StringName(args[1]) if args.size() > 1 else &"glasshouse"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/heist_flow").path_join(String(_heist))
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
	print("FLOW SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://heist_flow_profiles"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	_flow.show_hub()
	_flow.open_station(&"board")
	await _shot("board")
	_flow.show_hub()
	_flow.open_station(&"planning")
	await _shot("heist_select_open")
	for n: Node in get_tree().root.find_children("*", "HeistSelect", true, false):
		if n.has_method(&"select_heist_id"):
			n.call(&"select_heist_id", _heist)
	await _shot("heist_select")
	_flow.heist_select.set_last_breath(true)  # C4: the Last Breath toggle on
	await _shot("heist_select_last_breath")
	_flow.heist_select.set_last_breath(false)
	_flow.call(&"_on_heist_chosen", _heist, Enums.Difficulty.ROUTINE)
	await _shot("briefing")
	_flow.call(&"_on_briefing_continue", _heist, Enums.Difficulty.ROUTINE)
	await _shot("preplanning")
	_flow.call(&"_on_preplan_confirmed", {})
	await _shot("loadout")
	_flow.call(&"_on_launch_requested", _flow.loadout_screen.current_loadout())
	await _shot("load_in", 4)
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	await _shot("in_heist", 30)
	var me: CrewController = _local_crew()
	if me != null:
		me.set_masked()
	await _shot("in_heist_masked", 30)
	var hud: Hud = _hud()
	if hud != null and hud.scoreboard != null:
		hud.scoreboard.set_process(false)
		hud.scoreboard.set_shown(true)
		await _shot("tab_sheet", 6)
		hud.scoreboard.set_shown(false)
	var pm: PauseMenu = _flow.options_menu.open_pause()
	if pm != null:
		pm.open_confirm()
		await _shot("abort_confirm", 8)
		pm.confirm_button.pressed.emit()
	await _shot("payday", 30)
	var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
	if pd != null and is_instance_valid(pd):
		pd.continue_button.pressed.emit()
	await _shot("home", 20)
	print("FLOW DONE %s %d frames" % [_heist, _n])
	get_tree().quit(0)


func _hud() -> Hud:
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
