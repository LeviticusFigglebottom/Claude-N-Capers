## Worker for unhide_review_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

var _out: String = ""
var _heists: Array[StringName] = [&"rolling_thunder", &"afterhours"]
var _flow: MenuFlow


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/unhide_review"
	if args.size() > 1:
		_heists.clear()
		for i: int in range(1, args.size()):
			_heists.append(StringName(args[i]))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(step: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/unhide_%s_%dx%d.png" % [_out, step, img.get_width(), img.get_height()]
	img.save_png(path)
	print("UNHIDE SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://unhide_review_%d" % OS.get_process_id()
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 60
	p.cash = 500000
	SaveService.save_profile(p, 0)
	for h: StringName in _heists:
		if not HeistCatalog.ids().has(h):
			print("UNHIDE ISSUE %s is not offered (apply the un-hide patch)" % h)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _shot("main_menu", 20)
	await _board()
	_flow.board_screen.back_button.pressed.emit()
	await get_tree().process_frame
	for h: StringName in _heists:
		(_flow.main_menu.station_buttons[&"planning"] as Button).pressed.emit()
		await get_tree().process_frame
		var hs: HeistSelect = _flow.heist_select
		hs.select_heist_id(h)
		hs.select_difficulty(Enums.Difficulty.HAZARDOUS)
		await _shot("select_%s" % h)
		hs.next_button.pressed.emit()
		await _shot("briefing_%s" % h, 30)
		_flow.briefing_screen.back_button.pressed.emit()
		await get_tree().process_frame
		hs.back_button.pressed.emit()
		await get_tree().process_frame
	print("UNHIDE DONE")
	get_tree().quit(0)


## The Board at a rotation that shows every heist in _heists (searched forward an hour at a time), one shot per card.
func _board() -> void:
	(_flow.main_menu.station_buttons[&"board"] as Button).pressed.emit()
	await get_tree().process_frame
	var b: BoardScreen = _flow.board_screen
	var t0: float = Time.get_unix_time_from_system()
	var found: float = -1.0
	for i: int in range(5000):
		var t: float = t0 + float(i) * 3600.0
		var ids: Array[StringName] = []
		for c: Dictionary in BoardContracts.generate(t, b._level(), b.heist_pool, b.tweak, b.city, b.build_gate):
			ids.append(StringName(c["heist_id"]))
		if _heists.all(func(h: StringName) -> bool: return ids.has(h)):
			found = t
			break
	if found < 0.0:
		print("UNHIDE ISSUE no board rotation shows all of %s" % [_heists])
		await _shot("board")
		return
	b.clock = func() -> float: return found
	b.refresh_board()
	for h: StringName in _heists:
		for c: Dictionary in b.contracts:
			if StringName(c["heist_id"]) == h:
				b.select_slot(int(c["slot"]))
				print("UNHIDE board %s: %s" % [h, c])
				await _shot("board_%s" % h)
				break
