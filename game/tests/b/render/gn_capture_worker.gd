## Worker for gn_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"gallery_night"
const HUD_PATH: String = "res://content/ui/hud/hud.tscn"
const CREW_ASSETS: Array[StringName] = [&"asset.intel_list", &"asset.intel_sensors"]
const RADIO: Array[StringName] = [&"vo.vance.gallery_night_radio_lockdown", &"vo.vance.gallery_night_radio_server_door",
	&"vo.vance.gallery_night_radio_vault_drill_new"]

var _out: String = ""
var _n: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/gn_capture"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _log(s: String) -> void:
	print("GN ", s)


func _shot(shot: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, shot, img.get_width(), img.get_height()]
	img.save_png(path)
	_log("shot " + path.get_file())


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://gn_capture_profiles"
	OnboardingTips.persist = false
	if HeistRegistry.get_def(HEIST) == null:
		_log("FAIL no %s def at %s (run on a scratch copy, see gn_capture.gd)" % [HEIST, HeistRegistry.def_path(HEIST)])
		get_tree().quit(1)
		return
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 40
	p.cash = 5000000
	SaveService.save_profile(p, SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _shot("main_menu", 20)
	await _menus()
	_flow.queue_free()
	await get_tree().process_frame
	await _hud()
	SaveService.delete_profile(SLOT)
	_log("done")
	get_tree().quit(0)


func _menus() -> void:
	_flow.show_hub()
	_flow.open_station(&"planning")
	await _shot("heist_select")
	for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.HAZARDOUS]:
		_flow.call(&"_on_heist_chosen", HEIST, d)
		await _shot("briefing_%d" % d)
	var bs: BriefingScreen = _flow.briefing_screen
	bs.toggle_briefing()
	await _shot("briefing_playing", 30)
	bs.toggle_briefing()
	_flow.call(&"_on_briefing_continue", HEIST, Enums.Difficulty.HAZARDOUS)
	var pp: PreplanningScreen = _flow.preplanning_screen
	await _shot("preplan")
	for i: int in range(pp.floor_buttons.size()):
		pp.floor_buttons[i].pressed.emit()
		var ids: Array[StringName] = pp.blueprint_view.marker_ids()
		_log("floor %d markers %s" % [i, ids])
		if not ids.is_empty():
			pp.show_point(ids[0])
		await _shot("preplan_floor_%d" % i)
	pp.floor_buttons[1].pressed.emit()
	pp.show_point(&"pp_insider_registrar")
	_log("buy asset.inside_keycard -> %s" % pp.buy(&"asset.inside_keycard"))
	await _shot("preplan_point_bought")
	pp.show_crew_assets()
	for a: StringName in CREW_ASSETS:
		_log("buy %s -> %s" % [a, pp.buy(a)])
	await _shot("preplan_crew_assets")
	pp.confirm_button.pressed.emit()
	await _shot("loadout")


func _hud() -> void:
	var model: MockHudModel = MockHudModel.new()
	get_tree().root.add_child(model)
	var hud: Hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	get_tree().root.add_child(hud)
	var sub: SubtitleOverlay = SubtitleOverlay.new()  # ContactRadio.spawn mounts it in a heist
	get_tree().root.add_child(sub)
	await get_tree().process_frame
	hud.bind(model)
	model.heist_phase = Enums.HeistPhase.STEALTH
	model.player_mode = &"casing"
	model.objectives = [
		_obj(&"casing", &"objective.gallery_night.casing", {}),
		_obj(&"find_canvases", &"objective.gallery_night.find_canvases", {"found": 1}),
	]
	EventBus.voice_line_requested.emit(&"vance", &"vo.vance.gallery_night_radio_casing", {"source": ContactRadio.SOURCE})
	await _shot("hud_casing", 20)
	model.player_mode = &""
	model.casing = false
	model.masked = true
	model.objectives = [
		_obj(&"hack", &"objective.gallery_night.hack", {}),
		_obj(&"keycard", &"objective.gallery_night.keycard", {}, Enums.ObjectiveState.COMPLETED),
		_obj(&"secure", &"objective.gallery_night.secure", {"count": 2, "total": 4}),
		_obj(&"extras", &"objective.gallery_night.extras", {}),
	]
	model.carried_bag = {"loot_id": &"loot.painting_lantern_bearer", "weight": Enums.LootWeight.MEDIUM}
	await _shot("hud_stealth_masked", 20)
	model.objectives = [
		_obj(&"lockdown", &"objective.gallery_night.lockdown", {}),
		_obj(&"hack", &"objective.gallery_night.hack_loud", {}),
		_obj(&"server_door", &"objective.gallery_night.server_door", {}),
		_obj(&"vault_drill", &"objective.gallery_night.vault_drill", {}),
		_obj(&"secure", &"objective.gallery_night.secure", {"count": 3, "total": 4}),
		_obj(&"escape_wait", &"objective.gallery_night.escape_wait", {}),
	]
	model.heist_phase = Enums.HeistPhase.LOUD
	model.assault_phase = Enums.AssaultPhase.SUSTAIN
	model.assault_wave = 2
	model.carried_bag = {"loot_id": &"loot.painting_study", "weight": Enums.LootWeight.LIGHT}
	for id: StringName in RADIO:
		EventBus.voice_line_requested.emit(&"vance", id, {"source": ContactRadio.SOURCE})
	await _shot("hud_loud_radio", 20)


static func _obj(id: StringName, key: StringName, args: Dictionary, state: int = Enums.ObjectiveState.ACTIVE) -> Dictionary:
	return {"id": id, "text_key": key, "args": args, "state": state}
