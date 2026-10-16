## Worker for briefing_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"dockside_burn", &"shadow_ledger", &"gallery_night"]

var _out: String = ""
var _n: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/briefing_capture"
	DirAccess.make_dir_recursive_absolute(_out)
	var heists: Array[StringName] = []
	for i: int in range(1, args.size()):
		heists.append(StringName(args[i]))
	if heists.is_empty():
		heists = HEISTS
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://briefing_capture_profiles"
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 40
	p.cash = 5000000
	SaveService.save_profile(p, SLOT)
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(flow)
	flow.show_hub()
	flow.open_station(&"planning")
	for h: StringName in heists:
		flow.call(&"_on_heist_chosen", h, Enums.Difficulty.HAZARDOUS)
		await _shot("briefing_" + String(h))
		# LEAD r229: the intel column scrolled to "Known security" (possible surprises at its end).
		var sec: Control = get_tree().root.find_child("KnownSecurity", true, false) as Control
		if sec != null and sec.visible:
			var sc: Node = sec.get_parent()
			while sc != null and not sc is ScrollContainer:
				sc = sc.get_parent()
			if sc != null:
				(sc as ScrollContainer).ensure_control_visible(sec)
				await get_tree().process_frame
				(sc as ScrollContainer).scroll_vertical = int((sc as ScrollContainer).get_v_scroll_bar().max_value)
			await _shot("security_" + String(h))
		# LEAD r229 real-input run: the pre-planning that follows (blueprint labels clear of the markers).
		if flow.briefing_screen != null and flow.briefing_screen.continue_button != null:
			flow.briefing_screen.continue_button.pressed.emit()
			await _shot("preplanning_" + String(h), 30)
	SaveService.delete_profile(SLOT)
	print("BRIEF done")
	get_tree().quit(0)


func _shot(shot: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, shot, img.get_width(), img.get_height()]
	img.save_png(path)
	print("BRIEF shot " + path.get_file())
