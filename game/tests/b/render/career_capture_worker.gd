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
	var screen: CareerScreen = (load("res://content/ui/career/career_screen.tscn") as PackedScene).instantiate() as CareerScreen
	get_tree().root.add_child(screen)
	screen.setup(p)
	await _shot("career")
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
