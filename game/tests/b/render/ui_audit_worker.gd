## Worker for ui_audit_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const HEIST: StringName = &"glasshouse"

var _out: String = ""
var _only: String = ""
var _n: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/ui_audit"
	_only = args[1] if args.size() > 1 else ""
	# Lane 13: `expand` previews window/stretch/aspect="expand" (21:9 / 16:10 get a wider / taller canvas
	# instead of black bars); the project default ("keep") letterboxes to 1920x1080.
	if args.size() > 2 and args[2] == "expand":
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(shot: String, frames: int = 12) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	if _only != "" and _only != "heist" and _only != "menus" and _only != "screens" and _only != "fail" \
			and _only != "range" and _only != "feedback" and _only != "assault" and not shot.begins_with(_only):
		return
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%02d_%s_%dx%d.png" % [_out, _n, shot, img.get_width(), img.get_height()]
	img.save_png(path)
	print("AUDIT SHOT ", path)


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://ui_audit_profiles"
	OnboardingTips.persist = false  # PO-4 lane 11: cards show, the save is never touched
	var p: PlayerProfile = PlayerProfile.new_default()
	SaveService.save_profile(p, SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	if _only == "screens":
		await _screens()
	elif _only == "fail":
		await _fail()
	elif _only == "range":
		await _range()
	elif _only == "feedback":
		await _feedback()
	elif _only == "assault":
		await _assault()
	elif _only != "heist":
		await _menus()
	if _only != "menus" and _only != "screens" and _only != "fail" and _only != "range" \
			and _only != "feedback" and _only != "assault":
		await _heist()
	SaveService.delete_profile(SLOT)
	get_tree().quit(0)


func _menus() -> void:
	await _shot("main_menu", 20)
	_flow.show_hub()
	await _shot("hub", 30)
	_flow.open_station(&"board")
	await _shot("board")
	_flow.show_hub()
	_flow.open_station(&"planning")
	await _shot("heist_select")
	_flow.call(&"_on_heist_chosen", HEIST, Enums.Difficulty.ROUTINE)
	await _shot("briefing")
	_flow.call(&"_on_briefing_continue", HEIST, Enums.Difficulty.ROUTINE)
	await _shot("preplanning")
	_flow.call(&"_on_preplan_confirmed", {})
	await _shot("loadout")
	var lsp: ItemPicker = (_flow.loadout_screen.armor_option as ItemSlot).open_picker()
	await _shot("loadout_picker")
	lsp.close()
	# §B (Jay roster): the heister picker lists every heister (6) with accents / portraits at this resolution.
	var hp: ItemPicker = (_flow.loadout_screen.heister_option as ItemSlot).open_picker()
	await _shot("loadout_heister_picker")
	hp.close()
	_flow.show_hub()
	_flow.open_station(&"armory")
	await _shot("armory")
	_flow.show_hub()
	_flow.options_menu.open()
	await _shot("options")
	_close_options()
	await _shot("hub_after_options", 4)
	_flow.call(&"_show_sample_payday")
	await _shot("payday_sample", 20)
	_flow.show_hub()


## Every other station / sub-screen (PO-4 rest of the restyle).
func _screens() -> void:
	for st: StringName in [&"masks", &"crew", &"jukebox", &"notoriety", &"profile"]:
		_flow.show_hub()
		_flow.open_station(st)
		await _shot("st_" + String(st), 16)
	_flow.show_hub()
	_flow.call(&"_open_achievements")
	await _shot("achievements", 16)
	_flow.show_hub()
	_flow.open_station(&"armory")
	await _shot("armory", 8)
	_flow.open_progression(_flow.SKILLS_SCENE)
	await _shot("skills", 16)
	_flow.close_progression()
	_flow.open_progression(_flow.PERKS_SCENE)
	await _shot("perks", 16)
	_flow.close_progression()
	var ls: LoadoutScreen = _flow.loadout_screen
	if ls != null:
		ls.open_workshop()
		await _shot("workshop", 30)


func _heist() -> void:
	_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 42)
	var t0: int = Time.get_ticks_msec()
	while _hud() == null and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	await _shot("hud_casing", 20)
	var crew: CrewController = _local_crew()
	if crew != null:
		crew.set_masked()
	await _shot("hud_masked_stealth", 12)
	var rt: HeistRuntime = _flow.runtime as HeistRuntime
	if rt != null and rt.service(G.SVC_STEALTH) != null:
		rt.service(G.SVC_STEALTH).call(&"raise_alarm", &"audit")
	await _shot("hud_loud", 30)
	var hud: Hud = _hud()
	if hud != null:
		hud.scoreboard.set_process(false)  # no Tab held in a capture
		hud.scoreboard.set_shown(true)
		await _shot("hud_scoreboard", 10)
		hud.scoreboard.set_shown(false)
		hud.scoreboard.set_process(true)
	var pm: PauseMenu = _flow.options_menu.open_pause()
	await _shot("pause_in_heist")
	if pm != null:
		pm.options_button.pressed.emit()
		await _shot("pause_options")
	_flow.options_menu.close_pause()
	await get_tree().process_frame
	if rt != null:
		rt.call(&"end_heist", true, [Net.local_slot()] as Array[int])
	await _shot("payday", 20)
	var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
	if pd != null and is_instance_valid(pd):
		pd.show_cards()
		await _shot("payday_cards", 12)
	_flow.call(&"_leave_heist")
	await _shot("after_heist", 12)


## Lead failure pass (`fail`): launch, pause -> Leave Heist -> Confirm (the solo abort), the failure
## payday, Continue, then the hub; then a second run ended as all-custody.
func _fail() -> void:
	for reason: StringName in [&"abort", &"all_custody"]:
		_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 43)
		var t0: int = Time.get_ticks_msec()
		while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < 60000:
			await get_tree().process_frame
		await _shot("fail_live_" + String(reason), 20)
		if reason == &"abort":
			var pm: PauseMenu = _flow.options_menu.open_pause()
			if pm != null:
				pm.open_confirm()
				await _shot("fail_leave_confirm", 8)
				pm.confirm_button.pressed.emit()
		else:
			(_flow.runtime as HeistRuntime).call(&"end_heist", false, [] as Array[int], reason)
		await _shot("fail_payday_" + String(reason), 30)
		var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
		if pd != null and is_instance_valid(pd):
			pd.continue_button.pressed.emit()
		await _shot("fail_home_" + String(reason), 20)


## Lead round 67 `feedback`: the round-62/64 widgets driven by the REAL systems (A's local_net_id,
## revive_progress / reviver_slot, crew-row bleedout_s): the local crew hits a guard (hit marker; the
## head for a headshot), a guard hits the local crew (damage arc), an AI teammate goes down (badge ring),
## then the local player goes down (grey screen + bleedout).
func _feedback() -> void:
	_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 44)
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	await _shot("fb_live", 20)
	var rt: HeistRuntime = _flow.runtime as HeistRuntime
	var me: CrewController = _local_crew()
	if me != null:
		me.set_masked()
	await _shot("fb_masked", 10)
	var guard: NpcBase = null
	for n: Node in rt.npcs():
		if n is NpcBase:
			guard = n as NpcBase
			break
	if me != null and guard != null:
		guard.take_hit({"amount": 1.0, "zone": Enums.HitZone.HEAD, "type": Enums.DamageType.BULLET,
			"direction": (guard.global_position - me.global_position).normalized(), "position": guard.global_position}, me.net_id)
		await _shot("fb_headshot_marker", 2)
		var dir: Vector3 = (me.global_position - guard.global_position).normalized()
		me.take_hit({"amount": 15.0, "zone": Enums.HitZone.BODY, "type": Enums.DamageType.BULLET, "direction": dir,
			"position": me.global_position}, guard.net_id)
		await _shot("fb_damage_arc", 4)
	var mate: CrewController = rt.crew_controller(1) as CrewController if rt != null else null
	if mate != null and mate.get(&"health") != null:
		(mate.get(&"health") as Object).call(&"go_down")
		await _shot("fb_teammate_down", 20)
	if me != null and me.get(&"health") != null:
		(me.get(&"health") as Object).call(&"go_down")
		await _shot("fb_local_down", 30)
	_flow.call(&"_leave_heist")


## Lead HUD readability pass `assault`: Glasshouse (Routine) loud with a full assault wave (alarm through the real event,
## the director pushed to BUILD then SUSTAIN), the Tab sheet, hits both ways, teammates hurt and down, the
## local player down (bleed-out) and in custody (custody timer).
func _assault() -> void:
	_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 45)
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	var rt: HeistRuntime = _flow.runtime as HeistRuntime
	var me: CrewController = _local_crew()
	if me != null:
		me.set_masked()
	EventBus.alarm_raised.emit(&"audit", 0)
	await _shot("as_alarm", 20)
	var dir: AssaultDirector = rt.service(G.SVC_DIRECTOR) as AssaultDirector
	if dir != null:
		dir.begin()
		dir.call(&"_enter", Enums.AssaultPhase.BUILD, 600.0)
		await _shot("as_build", 50)  # spawns arrive (8 physics steps a frame on llvmpipe)
		dir.call(&"_enter", Enums.AssaultPhase.SUSTAIN, 600.0)
		await _shot("as_sustain", 60)
	var hud: Hud = _hud()
	if hud != null and hud.scoreboard != null:
		hud.scoreboard.set_process(false)
		hud.scoreboard.set_shown(true)
		await _shot("as_scoreboard", 6)
		hud.scoreboard.set_shown(false)
	var cop: NpcBase = null
	for n: Node in rt.npcs():
		if n is NpcBase and (n as NpcBase).is_inside_tree():
			cop = n as NpcBase
	if me != null and cop != null:
		cop.take_hit({"amount": 1.0, "zone": Enums.HitZone.HEAD, "type": Enums.DamageType.BULLET,
			"direction": (cop.global_position - me.global_position).normalized(), "position": cop.global_position}, me.net_id)
		var back: Vector3 = (me.global_position - cop.global_position).normalized()
		me.take_hit({"amount": 30.0, "zone": Enums.HitZone.BODY, "type": Enums.DamageType.BULLET, "direction": back,
			"position": me.global_position}, cop.net_id)
		await _shot("as_hits", 3)
	for slot: int in [1, 2]:
		var m: CrewController = rt.crew_controller(slot) as CrewController
		if m != null and m.get(&"health") != null:
			(m.get(&"health") as Object).call(&"apply_damage", {"amount": 120.0, "type": Enums.DamageType.BULLET}, 0)
	var mate: CrewController = rt.crew_controller(3) as CrewController
	if mate != null and mate.get(&"health") != null:
		(mate.get(&"health") as Object).call(&"go_down")
	await _shot("as_mates_hurt_and_down", 20)
	if me != null and me.get(&"health") != null:
		(me.get(&"health") as Object).call(&"go_down")
		await _shot("as_local_down", 40)
		(me.get(&"health") as Object).call(&"go_to_custody")
		await _shot("as_custody", 40)
	_flow.call(&"_leave_heist")


## Lead queue (3) `range`: the firing range from the main menu, panel mode then aim mode.
func _range() -> void:
	_flow.show_home()
	await _shot("range_main", 10)
	_flow.main_menu.firing_range_requested.emit()
	await _shot("range_panel", 90)
	var ov: RangeOverlay = null
	for n: Node in get_tree().root.find_children("*", "RangeOverlay", true, false):
		ov = n as RangeOverlay
	if ov != null:
		ov.set_interactive(false)
		await _shot("range_aim", 30)


func _close_options() -> void:
	for s: Node in get_tree().root.find_children("*", "OptionsScreen", true, false):
		if s.has_signal(&"back_requested"):
			s.emit_signal(&"back_requested")


func _hud() -> Hud:
	for n: Node in get_tree().root.find_children("*", "Hud", true, false):
		if n is Hud and (n as Hud).model != null:
			return n as Hud
	return null


func _local_crew() -> CrewController:
	for n: Node in get_tree().root.find_children("*", "CrewController", true, false):
		var c: CrewController = n as CrewController
		if c != null and c.slot == Net.local_slot():
			return c
	return null
