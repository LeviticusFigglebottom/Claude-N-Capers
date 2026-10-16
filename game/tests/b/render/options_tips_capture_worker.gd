## Worker for options_tips_capture.gd (loaded at runtime so autoloads exist when it compiles).
## Frames: 01 the Controls tab with the row focused, 02 the confirm dialog, 03 after confirming.
extends Node

const SCREEN_SCENE: String = "res://content/ui/menus/options_screen.tscn"

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/options_tips"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	OnboardingTips.mark_seen(&"casing")
	var o: OptionsScreen = (load(SCREEN_SCENE) as PackedScene).instantiate() as OptionsScreen
	o.settings = GameSettings.new()
	o.save_on_apply = false
	add_child(o)
	await get_tree().process_frame
	o.tips_button.grab_focus()
	await _shot("01_controls_tips_row")
	o.tips_button.pressed.emit()
	await _shot("02_tips_confirm")
	o.tips_confirm_button.pressed.emit()
	o.tips_button.grab_focus()
	await _shot("03_tips_reset_done")
	get_tree().quit()


func _shot(tag: String) -> void:
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("TIPS SHOT ", path)
