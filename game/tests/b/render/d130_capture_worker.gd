## Worker for d130_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"glasshouse"

var _out: String = ""
## Held so the cached list (with Lethal unlocked) is the one the screens load.
var _list: UiHeistList = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/d130"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	SaveService.root_dir = "user://d130_capture_profiles"
	var def: HeistDef = HeistRegistry.get_def(HEIST)
	if def.pager_max_by_difficulty.is_empty():
		def.pager_max_by_difficulty = [4, 4, 3, 3, 2, 1] as Array[int]  # D-130 GH row (fixture until C lands it)
	if def.camera_titan_min_difficulty < 0:
		def.camera_titan_min_difficulty = Enums.Difficulty.HAZARDOUS
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 40
	p.cash = 5000000
	SaveService.save_profile(p, SLOT)
	_list = HeistCatalog.heist_list()
	if not _list.unlocked_difficulties.has(Enums.Difficulty.LETHAL):
		_list.unlocked_difficulties.append(Enums.Difficulty.LETHAL)  # behind progression on a fresh profile
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(flow)
	for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.LETHAL]:
		var tag: String = String(UiText.t(UiText.difficulty_key(d))).to_lower()
		flow.show_hub()
		flow.open_station(&"planning")
		var hs: HeistSelect = flow.heist_select
		hs.select_heist_id(HEIST)
		hs.select_difficulty(d)
		await _shot("heist_select_%s" % tag)
		flow.call(&"_on_heist_chosen", HEIST, d)
		await _shot("briefing_%s" % tag)
		var sec: Control = get_tree().root.find_child("KnownSecurity", true, false) as Control
		if sec != null and sec.visible:
			var sc: Node = sec.get_parent()
			while sc != null and not sc is ScrollContainer:
				sc = sc.get_parent()
			if sc != null:
				(sc as ScrollContainer).ensure_control_visible(sec)
				await get_tree().process_frame
				(sc as ScrollContainer).scroll_vertical = int((sc as ScrollContainer).get_v_scroll_bar().max_value)
			await _shot("security_%s" % tag)
	SaveService.delete_profile(SLOT)
	print("D130 done")
	get_tree().quit(0)


func _shot(tag: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("D130 SHOT ", path)
