## Worker for ui_audit_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"glasshouse"

var _out: String = ""
var _only: String = ""
var _n: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/ui_audit"
	_only = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(shot: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	if _only != "" and _only != "heist" and _only != "menus" and _only != "screens" and not shot.begins_with(_only):
		return
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, shot, img.get_width(), img.get_height()]
	img.save_png(path)
	print("AUDIT SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://ui_audit_profiles"
	var p: PlayerProfile = PlayerProfile.new_default()
	SaveService.save_profile(p, SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	if _only == "screens":
		await _screens()
	elif _only != "heist":
		await _menus()
	if _only != "menus" and _only != "screens":
		await _heist()
	SaveService.delete_profile(SLOT)
	get_tree().quit(0)


func _menus() -> void:
	await _shot("main_menu", 20)
	_flow.show_hub()
	await _shot("hub", 30)
	_flow.open_station(&"board")
	await _shot("board")
	_flow.show_hub()
	_flow.open_station(&"planning")
	await _shot("heist_select")
	_flow.call(&"_on_heist_chosen", HEIST, Enums.Difficulty.ROUTINE)
	await _shot("briefing")
	_flow.call(&"_on_briefing_continue", HEIST, Enums.Difficulty.ROUTINE)
	await _shot("preplanning")
	_flow.call(&"_on_preplan_confirmed", {})
	await _shot("loadout")
	_flow.show_hub()
	_flow.open_station(&"armory")
	await _shot("armory")
	_flow.show_hub()
	_flow.options_menu.open()
	await _shot("options")
	_close_options()
	await _shot("hub_after_options", 4)
	_flow.call(&"_show_sample_payday")
	await _shot("payday_sample", 20)
	_flow.show_hub()


## Every other station / sub-screen (PO-4 rest of the restyle).
func _screens() -> void:
	for st: StringName in [&"masks", &"crew", &"jukebox", &"notoriety", &"profile"]:
		_flow.show_hub()
		_flow.open_station(st)
		await _shot("st_" + String(st), 16)
	_flow.show_hub()
	_flow.call(&"_open_achievements")
	await _shot("achievements", 16)
	_flow.show_hub()
	_flow.open_station(&"armory")
	await _shot("armory", 8)
	_flow.open_progression(_flow.SKILLS_SCENE)
	await _shot("skills", 16)
	_flow.close_progression()
	_flow.open_progression(_flow.PERKS_SCENE)
	await _shot("perks", 16)
	_flow.close_progression()
	var ls: LoadoutScreen = _flow.loadout_screen
	if ls != null:
		ls.open_workshop()
		await _shot("workshop", 30)


func _heist() -> void:
	_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 42)
	var t0: int = Time.get_ticks_msec()
	while _hud() == null and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	await _shot("hud_casing", 20)
	var crew: CrewController = _local_crew()
	if crew != null:
		crew.set_masked()
	await _shot("hud_masked_stealth", 12)
	var rt: HeistRuntime = _flow.runtime as HeistRuntime
	if rt != null and rt.service(G.SVC_STEALTH) != null:
		rt.service(G.SVC_STEALTH).call(&"raise_alarm", &"audit")
	await _shot("hud_loud", 30)
	var pm: PauseMenu = _flow.options_menu.open_pause()
	await _shot("pause_in_heist")
	if pm != null:
		pm.options_button.pressed.emit()
		await _shot("pause_options")
	_flow.options_menu.close_pause()
	await get_tree().process_frame
	if rt != null:
		rt.call(&"end_heist", true, [Net.local_slot()] as Array[int])
	await _shot("payday", 20)
	var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
	if pd != null and is_instance_valid(pd):
		pd.show_cards()
		await _shot("payday_cards", 12)
	_flow.call(&"_leave_heist")
	await _shot("after_heist", 12)


func _close_options() -> void:
	for s: Node in get_tree().root.find_children("*", "OptionsScreen", true, false):
		if s.has_signal(&"back_requested"):
			s.emit_signal(&"back_requested")


func _hud() -> Hud:
	for n: Node in get_tree().root.find_children("*", "Hud", true, false):
		if n is Hud and (n as Hud).model != null:
			return n as Hud
	return null


func _local_crew() -> CrewController:
	for n: Node in get_tree().root.find_children("*", "CrewController", true, false):
		var c: CrewController = n as CrewController
		if c != null and c.slot == Net.local_slot():
			return c
	return null
