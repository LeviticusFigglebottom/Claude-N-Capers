## Worker for assault_banner_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/assault_banner"
	DirAccess.make_dir_recursive_absolute(out)
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	hud.difficulty = Enums.Difficulty.LETHAL
	hud.last_breath = true
	add_child(hud)
	await get_tree().process_frame
	hud.bind(model)
	model.assault_phase = Enums.AssaultPhase.BUILD
	model.assault_wave = 2
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/assault_banner_%dx%d.png" % [out, img.get_width(), img.get_height()]
	img.save_png(path)
	print("BANNER SHOT ", path)
	get_tree().quit()
