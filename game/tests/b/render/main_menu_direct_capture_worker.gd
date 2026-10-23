## Worker for main_menu_direct_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

var _out: String = ""
var _n: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/main_direct"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(step: String, frames: int = 10) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_n += 1
	var path: String = "%s/main_direct_%02d_%s_%dx%d.png" % [_out, _n, step, img.get_width(), img.get_height()]
	img.save_png(path)
	print("MAIN SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://main_direct_capture_profiles"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	QuickPlay.remember(0, &"glasshouse", Enums.Difficulty.ROUTINE)  # the longest list: Continue shows too
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(flow)
	await _shot("main_menu", 20)
	(flow.main_menu.station_buttons[&"planning"] as Button).pressed.emit()
	await _shot("planning_table")
	flow.heist_select.next_button.pressed.emit()
	await _shot("briefing")
	flow.briefing_screen.continue_button.pressed.emit()
	await _shot("preplan", 20)
	flow.preplanning_screen.back_button.pressed.emit()
	await get_tree().process_frame
	flow.briefing_screen.back_button.pressed.emit()
	await get_tree().process_frame
	flow.heist_select.back_button.pressed.emit()
	await _shot("back_to_main")
	flow.main_menu.stations_button.pressed.emit()
	await _shot("all_stations")
	print("MAIN DONE current=%s" % flow.current.name)
	get_tree().quit(0)
