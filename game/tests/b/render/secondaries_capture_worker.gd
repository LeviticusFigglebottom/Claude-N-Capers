## Worker for secondaries_capture.gd (loaded at runtime so autoloads exist when it compiles).
## Frames: 01 the loadout's secondary picker (fresh profile), 02 the Workshop list at SECONDARY WEAPONS (level 30).
extends Node

const LOADOUT_SCENE: String = "res://content/ui/menus/loadout.tscn"
const WORKSHOP_SCENE: String = "res://content/ui/workshop/workshop_screen.tscn"

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/secondaries"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://capture_profiles_%d" % OS.get_process_id()
	var s: LoadoutScreen = (load(LOADOUT_SCENE) as PackedScene).instantiate() as LoadoutScreen
	s.setup(PlayerProfile.new_default())
	add_child(s)
	await get_tree().process_frame
	s.weapon_option.open_picker()
	await _shot("01_loadout_secondary_picker_fresh")
	s.queue_free()
	await get_tree().process_frame
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 30
	p.xp = XpCurve.xp_for_level(30)
	p.owned_weapons.append_array([&"weapon.hornet_9", &"weapon.plowman_12", &"weapon.marshal_357"] as Array[StringName])
	var ws: WorkshopScreen = (load(WORKSHOP_SCENE) as PackedScene).instantiate() as WorkshopScreen
	ws.setup(p)
	add_child(ws)
	await get_tree().process_frame
	var head: int = -1
	for i: int in range(ws.weapon_list.item_count):
		if ws.weapon_list.get_item_text(i) == UiText.t(&"ui.workshop.secondaries"):
			head = i
	ws.weapon_list.ensure_current_is_visible()
	await get_tree().process_frame
	ws.weapon_list.get_v_scroll_bar().value = ws.weapon_list.get_item_rect(head).position.y
	await _shot("02_workshop_secondaries")
	SaveService.delete_profile(0)
	get_tree().quit()


func _shot(tag: String) -> void:
	for _i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("SEC SHOT ", path)
