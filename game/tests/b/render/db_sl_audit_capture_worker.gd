## Worker for db_sl_audit_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const PAYDAY_SCENE: String = "res://content/ui/results/payday.tscn"
## [heist, frame tag, success, fail_reason, stealth, pagers answered]
const CASES: Array[Array] = [
	[&"dockside_burn", "14_payday_success", true, &"", false, 0],
	[&"dockside_burn", "15_payday_failed", false, &"all_custody", false, 0],
	[&"shadow_ledger", "14_payday_alarm_failed", false, &"stealth_only_alarm", false, 2],
]

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/heist_audit"
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://capture_profiles_%d" % OS.get_process_id()
	for c: Array in CASES:
		var r: Dictionary = HeistCatalog.sample_result()
		r["heist_id"] = c[0]
		r["success"] = c[2]
		r["fail_reason"] = c[3]
		r["stealth"] = c[4]
		r["pagers_answered"] = c[5]
		var pd: PaydayScreen = (load(PAYDAY_SCENE) as PackedScene).instantiate() as PaydayScreen
		pd.apply_to_profile = false
		add_child(pd)
		await get_tree().process_frame
		pd.setup(PlayerProfile.new_default())
		pd.show_result(r)
		pd.skip_count()
		var dir: String = "%s/%s" % [_out, c[0]]
		DirAccess.make_dir_recursive_absolute(dir)
		await _shot(dir, String(c[1]))
		var chips: Label = pd.find_child("SummaryChips", true, false) as Label
		print("DBSL chips ", c[0], ": ", chips.text if chips != null else "<none>")
		pd.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _shot(dir: String, tag: String) -> void:
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [dir, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("DBSL SHOT ", path)
