## Worker for career_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/career"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 40
	var r: Dictionary = HeistCatalog.sample_result()
	for i: int in range(3):
		Career.record(p, r, PayoutCalculator.compute(r, null, null, false, 0), 0)
	Career.record_card(p, {"type": PaydayCards.CASH, "amount": 24000})
	Career.record_card(p, {"type": PaydayCards.XP, "amount": 5200})
	# D-139 Recent heists: GN long ago, a run of ND, two GH at the end.
	HeistFreshness.record(p, &"gallery_night", true)
	for i: int in range(12):
		HeistFreshness.record(p, &"night_deposit", true)
	for i: int in range(2):
		HeistFreshness.record(p, &"glasshouse", true)
	var screen: CareerScreen = (load("res://content/ui/career/career_screen.tscn") as PackedScene).instantiate() as CareerScreen
	get_tree().root.add_child(screen)
	screen.setup(p)
	await _shot("career")
	# Real pad input: d-pad down from the first panel until a Recent heists row has focus (follow_focus scrolls).
	(screen.focus_chain[0] as Control).grab_focus()
	var target: Control = screen.recent_rows.values()[0] as Control
	for i: int in range(screen.focus_chain.size()):
		if get_viewport().gui_get_focus_owner() == target:
			break
		var ev: InputEventJoypadButton = InputEventJoypadButton.new()
		ev.button_index = JOY_BUTTON_DPAD_DOWN
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		ev = ev.duplicate() as InputEventJoypadButton
		ev.pressed = false
		Input.parse_input_event(ev)
		await get_tree().process_frame
	print("CAREER focus on recent row: ", get_viewport().gui_get_focus_owner() == target)
	await _shot("career_recent")
	var last: Control = screen.recent_rows.values().back() as Control
	last.grab_focus()
	await _shot("career_recent_end")
	print("CAREER done")
	get_tree().quit(0)


func _shot(tag: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("CAREER SHOT ", path)
