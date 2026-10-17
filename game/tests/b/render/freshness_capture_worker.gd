## Worker for freshness_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const ROTATED: StringName = &"gallery_night"
const FILLER: StringName = &"afterhours"

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/freshness"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	SaveService.root_dir = "user://freshness_capture_profiles"
	var result: Dictionary = HeistCatalog.sample_result()
	var tired: StringName = StringName(result["heist_id"])
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 40
	p.cash = 5000000
	HeistFreshness.record(p, ROTATED, true)
	for i: int in range(12):
		HeistFreshness.record(p, FILLER, true)
	for i: int in range(3):
		HeistFreshness.record(p, tired, true)  # tired: -30 %; gallery night: 15 runs ago -> +5 %
	SaveService.save_profile(p, SLOT)
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(flow)
	for id: StringName in [tired, ROTATED]:
		flow.show_hub()
		flow.open_station(&"planning")
		flow.heist_select.select_heist_id(id)
		await _shot("heist_select_%s" % id)
	flow.queue_free()
	await get_tree().process_frame
	var screen: PaydayScreen = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	screen.apply_to_profile = false
	screen.cards_enabled = false
	get_tree().root.add_child(screen)
	screen.setup(p)
	screen.show_result(result)
	await _shot("payday_%s" % tired)
	SaveService.delete_profile(SLOT)
	print("FRESH done")
	get_tree().quit(0)


func _shot(tag: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("FRESH SHOT ", path)
