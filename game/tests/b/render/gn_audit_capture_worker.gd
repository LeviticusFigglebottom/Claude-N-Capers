## Worker for gn_audit_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"gallery_night"
const HUD_PATH: String = "res://content/ui/hud/hud.tscn"
const PAYDAY_SCENE: String = "res://content/ui/results/payday.tscn"
const A: int = Enums.ObjectiveState.ACTIVE
const H: int = Enums.ObjectiveState.HIDDEN
const C: int = Enums.ObjectiveState.COMPLETED
## gallery_night_mission.gd _on_mission_start: [id, state, args] in its _add order (the escape tags are mews here).
const OPT: Dictionary = {"optional": true}
const MISSION_ORDER: Array = [
	[&"casing", A, OPT], [&"find_canvases", A, {"found": 0, "total": 4}], [&"keycard", A, OPT],
	[&"server_code", A, OPT], [&"hack", A, OPT], [&"treasury", A, OPT], [&"art_store", A, OPT],
	[&"centrepiece", A, {}], [&"canvases", A, {}], [&"secure", A, {"count": 0, "total": 2}], [&"extras", A, OPT],
	[&"lockers", A, OPT], [&"curator_safe", A, OPT], [&"lockdown", H, {}], [&"server_door", H, {}],
	[&"vault_drill", H, {}], [&"escape_wait", H, {}], [&"escape", H, {}],
]

var _out: String = ""
var _n: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/gn_audit_capture"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _log(s: String) -> void:
	print("GNA ", s)


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
	SaveService.root_dir = "user://gn_audit_profiles_%d" % OS.get_process_id()
	OnboardingTips.persist = false
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 40
	p.cash = 5000000
	SaveService.save_profile(p, SLOT)
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(flow)
	await get_tree().process_frame
	flow.show_hub()
	flow.open_station(&"planning")
	for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.HAZARDOUS]:
		flow.call(&"_on_heist_chosen", HEIST, d)
		var b: Dictionary = BriefingModel.build(HEIST, d)
		for r: Dictionary in b["objectives"] as Array:
			_log("briefing %d. %s" % [int(r.get("index", 0)), r["text"]])
		_log("briefing more %d; loud: %s" % [int(b["objectives_more"]), b["loud_text"]])
		await _shot("briefing_%d" % d, 20)
	flow.queue_free()
	await get_tree().process_frame
	await _hud()
	await _payday()
	SaveService.delete_profile(SLOT)
	_log("done")
	get_tree().quit(0)


func _list(states: Dictionary, args: Dictionary = {}, keys: Dictionary = {}, tail: Array[StringName] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var later: Array[Dictionary] = []
	for row: Array in MISSION_ORDER:
		var id: StringName = row[0]
		var a: Dictionary = (row[2] as Dictionary).duplicate()
		a.merge(args.get(id, {}) as Dictionary, true)
		var o: Dictionary = {"id": id, "text_key": keys.get(id, StringName("objective.gallery_night.%s" % id)),
			"args": a, "state": int(states.get(id, row[1]))}
		if tail.has(id):
			later.append(o)  # re-added by add_objective: its order moves to the end (heist_mission.gd add_objective)
		else:
			out.append(o)
	out.append_array(later)
	return out


func _hud() -> void:
	var model: MockHudModel = MockHudModel.new()
	get_tree().root.add_child(model)
	var hud: Hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	get_tree().root.add_child(hud)
	await get_tree().process_frame
	hud.bind(model)
	hud.scoreboard.set_process(false)  # no Tab held in a capture
	model.heist_phase = Enums.HeistPhase.CASING
	model.player_mode = &"casing"
	model.objectives = _list({})
	hud.scoreboard.set_shown(true)
	await _shot("objectives_stealth_start", 20)
	hud.scoreboard.set_shown(false)
	await _shot("hud_stealth_start", 8)
	model.heist_phase = Enums.HeistPhase.STEALTH
	model.player_mode = &""
	model.masked = true
	model.objectives = _list({&"casing": C, &"keycard": C, &"centrepiece": C},
			{&"find_canvases": {"found": 2}, &"secure": {"count": 1}})
	await get_tree().create_timer(ObjectivesPanel.FLASH_S + 0.5).timeout
	hud.scoreboard.set_shown(true)
	await _shot("objectives_stealth_mid", 20)
	hud.scoreboard.set_shown(false)
	# Loud as _go_loud leaves it: lockdown done, find_canvases done, hack re-added as hack_loud (order -> end),
	# server_door / vault_drill shown; keycard / treasury / art_store still ACTIVE.
	model.heist_phase = Enums.HeistPhase.LOUD
	model.objectives = _list({&"casing": C, &"find_canvases": C, &"lockdown": C, &"server_door": A, &"vault_drill": A},
			{}, {&"hack": &"objective.gallery_night.hack_loud"}, [&"hack"])
	await get_tree().create_timer(ObjectivesPanel.FLASH_S + 0.5).timeout
	await _shot("hud_loud_current_step", 8)
	hud.scoreboard.set_shown(true)
	await _shot("objectives_loud", 20)
	hud.queue_free()
	model.queue_free()
	await get_tree().process_frame


func _payday() -> void:
	var r: Dictionary = HeistCatalog.sample_result()
	r["heist_id"] = HEIST
	r["contract_pay"] = 57000
	r["success"] = true
	r["stealth"] = true
	r["loot"] = [{"loot_id": &"loot.painting_lantern_bearer", "value": 8000},
		{"loot_id": &"loot.painting_widow_in_blue", "value": 6000}, {"loot_id": &"loot.painting_study", "value": 2800}]
	var pd: PaydayScreen = (load(PAYDAY_SCENE) as PackedScene).instantiate() as PaydayScreen
	pd.apply_to_profile = false
	add_child(pd)
	await get_tree().process_frame
	pd.show_result(r)
	pd.skip_count()
	_log("payday title: %s" % pd.title_label.text)
	await _shot("payday_success")
	r["success"] = false
	r["fail_reason"] = &"all_custody"
	pd.show_result(r)
	pd.skip_count()
	await _shot("payday_failed")
	pd.queue_free()
