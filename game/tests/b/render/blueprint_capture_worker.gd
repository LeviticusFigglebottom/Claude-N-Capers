## Worker for blueprint_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0

var _out: String = ""
var _heist: StringName = &"glasshouse"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = StringName(args[1]) if args.size() > 1 else &"glasshouse"
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/blueprints"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(step: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%s_%dx%d.png" % [_out, _heist, step, img.get_width(), img.get_height()]
	img.save_png(path)
	print("BLUEPRINT SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://blueprint_capture_profiles"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(flow)
	flow.show_hub()
	flow.open_station(&"planning")
	await _shot("select", 6)
	flow.call(&"_on_heist_chosen", _heist, Enums.Difficulty.ROUTINE)
	await _shot("briefing", 6)
	flow.call(&"_on_briefing_continue", _heist, Enums.Difficulty.ROUTINE)
	await _shot("floor0", 20)
	var views: Array[Node] = get_tree().root.find_children("*", "BlueprintView", true, false)
	if not views.is_empty():
		var view: Node = views[0]
		var floors: int = 1
		var board: Variant = view.get(&"board")
		if board != null:
			floors = (board as PreplanBoard).blueprint.floor_count()
		for f: int in range(1, floors):
			view.call(&"set_floor", f)
			await _shot("floor%d" % f, 8)
	print("BLUEPRINT DONE %s" % _heist)
	get_tree().quit(0)
