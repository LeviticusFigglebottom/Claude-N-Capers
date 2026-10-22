## Worker for melee_capture.gd (loaded at runtime so autoloads exist when it compiles).
## Frames: 01 the melee picker (fresh profile, folding knife), 02 the same with the sledgehammer tile focused.
extends Node

const LOADOUT_SCENE: String = "res://content/ui/menus/loadout.tscn"

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/melee"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://capture_profiles_%d" % OS.get_process_id()
	var s: LoadoutScreen = (load(LOADOUT_SCENE) as PackedScene).instantiate() as LoadoutScreen
	s.setup(PlayerProfile.new_default())
	add_child(s)
	await get_tree().process_frame
	var picker: ItemPicker = s.melee_option.open_picker()
	await _shot("01_melee_picker")
	for i: int in range(mini(s.melee_option.item_count, picker.tiles.size())):
		if s.melee_option.get_item_text(i) == UiText.t(&"item.melee.sledgehammer.name"):
			picker.tiles[i].grab_focus()
	await _shot("02_melee_picker_sledgehammer_focused")
	SaveService.delete_profile(0)
	get_tree().quit()


func _shot(tag: String) -> void:
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("MELEE SHOT ", path)
