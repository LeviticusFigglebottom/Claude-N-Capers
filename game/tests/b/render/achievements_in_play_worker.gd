## Worker for achievements_in_play_capture.gd (loaded at runtime so autoloads exist when it compiles).
## Frames: 01 summary with the first toast, 02 the second (queued) toast, 03 the section after the toasts,
## 04 the card stage with a toast over it, 05 a payday that unlocked nothing (section hidden, no toast).
extends Node

const PAYDAY_SCENE: String = "res://content/ui/results/payday.tscn"
const OPEN: Array[StringName] = [&"achievement.first_score", &"achievement.cataclysm_clear"]

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/achievements_in_play"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://capture_profiles_%d" % OS.get_process_id()
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	r["difficulty"] = 5
	var pd: PaydayScreen = (load(PAYDAY_SCENE) as PackedScene).instantiate() as PaydayScreen
	add_child(pd)
	await get_tree().process_frame
	pd.setup(_profile_except(OPEN))
	pd.show_result(r)
	pd.skip_count()
	print("ACH unlocked=", pd.achievements_unlocked)
	await _shot("01_payday_toast_first")
	pd.toast.tick(AchievementToast.SHOW_S)
	await _shot("02_payday_toast_second")
	pd.toast.tick(AchievementToast.SHOW_S + 0.1)
	await _shot("03_payday_section")
	pd.toast.push(pd.achievements_unlocked)
	pd.show_cards()
	await _shot("04_cards_with_toast")
	pd.queue_free()
	await get_tree().process_frame
	var none: PaydayScreen = (load(PAYDAY_SCENE) as PackedScene).instantiate() as PaydayScreen
	add_child(none)
	await get_tree().process_frame
	none.setup(_profile_except([]))
	none.show_result(r)
	none.skip_count()
	await _shot("05_payday_no_unlocks")
	SaveService.delete_profile(0)
	get_tree().quit()


func _profile_except(open: Array[StringName]) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	for a: AchievementDef in Achievements.all():
		if not open.has(a.id):
			p.achievements[a.id] = {"progress": Achievements.target_of(a), "unlocked": true}
	return p


func _shot(tag: String) -> void:
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("ACH SHOT ", path)
