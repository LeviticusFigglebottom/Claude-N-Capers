## Worker for rt_hud_capture.gd (loaded at runtime so the autoloads exist when it compiles).
extends Node

const RT: StringName = &"rolling_thunder"
const WIP_DEF: String = "res://world/heists/rolling_thunder/rolling_thunder_wip_def.tres"

var _out: String = ""
var _flow: MenuFlow = null
var _issues: int = 0
## Test-only fixture (as test_heist_screens_text): held so the cache keeps them for the run.
var _wip: Resource = null
var _list: UiHeistList = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/rt_hud"
	DirAccess.make_dir_recursive_absolute(_out)
	SaveService.root_dir = "user://rt_hud_profiles_%d" % OS.get_process_id()  # never the player's profile
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	_run.call_deferred()


func _run() -> void:
	_stage_rt()
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _frames(20)
	_flow.launch(RT, Enums.Difficulty.HAZARDOUS, SaveService.load_profile(0).loadout, 42)
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < 120000:
		await _frames(5)
	if _flow.runtime == null or _hud() == null:
		_issue("launch", "RT did not launch (runtime %s, hud %s)" % [_flow.runtime, _hud()])
		_done()
		return
	var rt: HeistRuntime = _flow.runtime as HeistRuntime
	var mission: Node = rt.mission
	await _seconds(3.0)
	_state("casing")
	await _shot("01_casing")
	var me: CrewController = rt.crew_controller(Net.local_slot() if Net.local_slot() >= 0 else 0) as CrewController
	if me != null:
		me.set_masked()
	await _seconds(1.0)
	_state("masked")
	await _shot("02_masked")
	mission.call(&"_convoy_arrives")  # stated shortcut: the convoy now, not at its ETA
	t0 = Time.get_ticks_msec()
	while int(mission.call(&"objective_state", &"ambush")) != Enums.ObjectiveState.ACTIVE \
			and Time.get_ticks_msec() - t0 < 60000:
		await _seconds(0.5)
	_state("convoy stopped")
	await _shot("03_convoy_stopped")
	var sd: Node = rt.service(G.SVC_STEALTH)
	if sd != null:
		sd.call(&"raise_alarm", &"rt_hud_audit")
	await _seconds(6.0)
	_state("ambush / loud")
	await _shot("04_loud")
	var trucks: Array[Node] = get_tree().get_nodes_in_group(ArmoredTruck.GROUP)
	print("RTHUD trucks %d" % trucks.size())
	for n: Node in trucks:
		var t: ArmoredTruck = n as ArmoredTruck
		if t != null and t.runner != null and not t.opened:
			t.runner.place(0, t.saw_duration())  # stated shortcut: the saw interaction's result
	await _seconds(3.0)
	var hud: Hud = _hud()
	print("RTHUD timers %s" % [hud.device_timers.drawn.map(func(d: Dictionary) -> String: return "%s %.0f%%" % [
			d.get("label", "?"), float(d.get("progress", 0.0)) * 100.0])])
	if trucks.size() > 0 and hud.device_timers.drawn.is_empty():
		_issue("timers", "trucks have saws running but the HUD draws no device timer")
	_state("saws")
	await _shot("05_truck_saws")
	var dir: AssaultDirector = rt.service(G.SVC_DIRECTOR) as AssaultDirector
	if dir != null and dir.events != null:
		dir.events.run(&"heli", {"drop": false, "sniper": false})
		await _seconds(3.0)
		print("RTHUD assault markers %s" % [hud.assault_events.drawn.map(func(d: Dictionary) -> String: return str(d.get(
				"label", d.get("kind", "?"))))])
		await _shot("06_assault_event")
	hud.scoreboard.set_process(false)
	hud.scoreboard.set_shown(true)
	await _frames(6)
	_state("tab sheet")
	await _shot("07_tab_sheet")
	hud.scoreboard.set_shown(false)
	rt.call(&"end_heist", true, [0] as Array[int])
	await _seconds(2.0)
	var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
	if pd == null or not is_instance_valid(pd):
		_issue("payday", "no in-heist payday after end_heist")
	else:
		pd.show_result(_scripted_result())
		pd.skip_count()
		await _frames(10)
		print("RTHUD payday achievements %s" % [pd.achievements_unlocked])
		for id: StringName in [&"achievement.rt_heavy_haul", &"achievement.rt_iron_crew"]:
			if not pd.achievements_unlocked.has(id):
				_issue("payday", "%s did not unlock on the scripted clear" % id)
		await _shot("08_payday")
	_done()


## Test-only fixture: RT's WIP def at the convention def path, RT un-hidden on the cached heist list.
func _stage_rt() -> void:
	_list = HeistCatalog.heist_list()
	if ResourceLoader.exists(HeistRegistry.def_path(RT)) or not ResourceLoader.exists(WIP_DEF):
		return
	_wip = load(WIP_DEF)
	_wip.take_over_path(HeistRegistry.def_path(RT))
	(_list.heists[RT] as Dictionary)["hidden"] = false


## A Hazardous RT clear: 4 gold + 2 cash secured, nobody down, signals rigged (the mission's facts do the rest).
func _scripted_result() -> Dictionary:
	var r: Dictionary = HeistCatalog.sample_result()
	var loot: Array = []
	for b: Array in [[&"loot.gold", 4], [&"loot.cash_bricks", 2]]:
		for i: int in range(int(b[1])):
			loot.append({"loot_id": b[0], "value": int(LootManager.loot_info(b[0]).get("value", 0))})
	var crew: Array = []
	for slot: int in range(4):
		crew.append({"slot": slot, "is_ai": slot > 0, "name": "", "kills": 6, "specials_killed": 1, "downs": 0,
			"civilians_killed": 0, "shots": 0, "hits": 0, "headshots": 0, "in_custody": false, "escaped": true})
	r.merge({"heist_id": RT, "success": true, "stealth": false, "time_s": 1080.0, "difficulty": Enums.Difficulty.HAZARDOUS,
		"contract_pay": HeistRegistry.get_def(RT).base_payout, "loot": loot, "small_loot": 1200, "crew": crew,
		"pagers_answered": 0, "fail_reason": &"", "loot_available": 9}, true)
	return r


func _state(tag: String) -> void:
	var hud: Hud = _hud()
	if hud == null:
		return
	var texts: PackedStringArray = PackedStringArray()
	for l: Node in hud.objectives.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text.strip_edges() != "":
			texts.append((l as Label).text.replace("\n", " / "))
	print("RTHUD %s objective: %s" % [tag, " | ".join(texts)])
	var raw: RegEx = RegEx.create_from_string("\\b(objective|ui|vo|heist|item|loot)\\.[a-z_]")
	for c: Node in hud.find_children("*", "Label", true, false):
		var t: String = (c as Label).text
		if (c as Label).is_visible_in_tree() and (raw.search(t) != null or t.contains("{")):
			_issue(tag, "raw text on the HUD: '%s'" % t)


func _hud() -> Hud:
	var h: Array[Node] = get_tree().root.find_children("*", "Hud", true, false)
	return h[0] as Hud if not h.is_empty() else null


func _shot(stem: String) -> void:
	await _frames(4)
	if DisplayServer.get_name() == "headless":  # --headless: the HUD state lines only (no frames to save)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, stem, img.get_width(), img.get_height()]
	img.save_png(path)
	print("RTHUD SHOT ", path)


func _issue(tag: String, what: String) -> void:
	_issues += 1
	print("RTHUD ISSUE %s: %s" % [tag, what])


func _done() -> void:
	print("RTHUD DONE %d" % _issues)
	SaveService.delete_profile(0)
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
