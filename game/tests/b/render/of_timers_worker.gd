## Worker for of_timers_capture.gd (real_input_run_worker's keyboard helpers; loaded at runtime for the autoloads).
extends "res://tests/b/render/real_input_run_worker.gd"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = &"ostrander_federal"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/of_timers").path_join(String(_heist))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	SaveService.root_dir = "user://of_timers_%d" % OS.get_process_id()
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _frames(30)
	await _press(_flow.main_menu.safehouse_button, "Safehouse")
	await _press(_flow.hub.station_button(&"planning"), "Planning")
	var hs: HeistSelect = _flow.heist_select
	await _nav_to(hs.heist_buttons[HeistCatalog.ids().find(_heist)], String(_heist))
	await _key(KEY_ENTER)
	await _press(hs.next_button, "Next")
	await _frames(30)
	await _press(_flow.briefing_screen.continue_button, "briefing Continue")
	await _frames(30)
	await _press(_flow.preplanning_screen.confirm_button, "pre-planning Confirm")
	await _frames(20)
	await _press(_flow.loadout_screen.launch_button, "Launch")
	var t0: int = Time.get_ticks_msec()
	while _flow.runtime == null and Time.get_ticks_msec() - t0 < 90000:
		await _frames(5)
	if _flow.runtime == null:
		print("RUN NOTE the heist did not launch")
		get_tree().quit(1)
		return
	await get_tree().create_timer(3.0).timeout
	var mission: Node = _flow.runtime.mission
	await _key(_key_of(&"mask_up"), 2.6)
	_complete_before(mission, &"time_lock")  # setup: the steps ahead of the time lock are done
	mission.call(&"_start_time_lock", &"code")  # setup: the console code went in
	await get_tree().create_timer(2.0).timeout
	_print_objective()
	await _shot("time_lock", 10)
	var sd: Array[Node] = get_tree().root.find_children("*", "StealthDirector", true, false)
	if not sd.is_empty():
		sd[0].call(&"raise_alarm", &"setup")
	await get_tree().create_timer(2.0).timeout
	_complete_before(mission, &"escape_wait")
	mission.call(&"_call_escape")  # setup: [secure] is done
	await get_tree().create_timer(2.0).timeout
	_print_objective()
	await _shot("escape_eta", 10)
	SaveService.delete_profile(0)
	print("TIMERS DONE")
	get_tree().quit(0)


func _print_objective() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for n: Node in get_tree().root.find_children("*", "ObjectivesPanel", true, false):
		for l: Node in n.find_children("*", "Label", true, false):
			if (l as Label).is_visible_in_tree() and (l as Label).text != "":
				parts.append((l as Label).text)
	print("TIMERS ", " | ".join(parts))


## Completes every ACTIVE objective that comes before `upto` in the mission's order (HUD shows the first open step).
func _complete_before(mission: Node, upto: StringName) -> void:
	var def: HeistDef = HeistRegistry.get_def(_heist)
	for id: StringName in def.objectives:
		if id == upto:
			return
		if int(mission.call(&"objective_state", id)) == Enums.ObjectiveState.ACTIVE:
			mission.call(&"complete", id)
