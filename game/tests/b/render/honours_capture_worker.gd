## Worker for honours_capture.gd (loaded at runtime so autoloads exist when it compiles).
## Frames: 01 a successful payday (honours name Rook, as the stats rows do), 02 a failed one (no Crew Honours).
extends Node

const PAYDAY_SCENE: String = "res://content/ui/results/payday.tscn"
const CREW: Dictionary = {0: &"rook", 1: &"sable", 2: &"dutch", 3: &"wren"}

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/honours"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://capture_profiles_%d" % OS.get_process_id()
	for success: bool in [true, false]:
		var r: Dictionary = HeistCatalog.sample_result()
		r["success"] = success
		if not success:
			r["fail_reason"] = &"custody"
		for row: Dictionary in r["crew"] as Array:
			row["name"] = "Player"  # the generic row name the r228 capture showed
		var pd: PaydayScreen = (load(PAYDAY_SCENE) as PackedScene).instantiate() as PaydayScreen
		pd.apply_to_profile = false
		pd.crew_heisters = CREW
		add_child(pd)
		await get_tree().process_frame
		pd.setup(PlayerProfile.new_default())
		pd.show_result(r)
		pd.skip_count()
		await _shot("01_payday_success" if success else "02_payday_failed")
		print("HONOURS awards=", pd.awards.size(), " labels=", pd.award_labels.keys())
		pd.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _shot(tag: String) -> void:
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("HONOURS SHOT ", path)
