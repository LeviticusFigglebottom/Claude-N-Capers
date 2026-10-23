## Worker for ah_hud_capture.gd (real_input_run_worker's helpers; loaded at runtime for the autoloads).
extends "res://tests/b/render/real_input_run_worker.gd"

const STEALTH_ORDER: Array[StringName] = [&"casing", &"gear", &"keycard", &"office", &"safe_code", &"safe",
	&"safe_loot", &"secure"]

var _rt: HeistRuntime
var _crew: Node3D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = &"afterhours"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/ah_hud").path_join(String(_heist))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	SaveService.root_dir = "user://ah_hud_%d" % OS.get_process_id()
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _frames(30)
	(_flow.main_menu.station_buttons[&"planning"] as Button).pressed.emit()
	await _frames(5)
	var hs: HeistSelect = _flow.heist_select
	if not hs.select_heist_id(_heist):
		print("AH ISSUE afterhours not offered (apply the un-hide)")
		get_tree().quit(1)
		return
	hs.next_button.pressed.emit()
	await _frames(20)
	_flow.briefing_screen.continue_button.pressed.emit()
	await _frames(20)
	_flow.preplanning_screen.confirm_button.pressed.emit()
	await _frames(20)
	_flow.loadout_screen.launch_button.pressed.emit()
	var t0: int = Time.get_ticks_msec()
	while _flow.runtime == null and Time.get_ticks_msec() - t0 < 120000:
		await _frames(5)
	if _flow.runtime == null:
		print("AH ISSUE the heist did not launch")
		get_tree().quit(1)
		return
	_rt = _flow.runtime as HeistRuntime
	await get_tree().create_timer(4.0).timeout
	_crew = _rt.crew_controller(Net.local_slot()) as Node3D
	_crew.set(&"stealth_hidden", true)  # stated shortcut (as A's X4 stealth flow): NPCs / cameras never see the crew
	_report("civilian start")
	await _shot("civilian_start", 10)
	await _gear()
	await _shot("masked_after_gear", 10)
	for id: StringName in STEALTH_ORDER:
		if int(_rt.mission.call(&"objective_state", id)) == Enums.ObjectiveState.ACTIVE:
			_rt.mission.call(&"complete", id)
			await get_tree().create_timer(1.5).timeout
			_report("after %s" % id)
			await _shot("obj_%s_done" % id, 6)
	await _operator()
	await _pager()
	var sd: Array[Node] = get_tree().root.find_children("*", "StealthDirector", true, false)
	if not sd.is_empty():
		sd[0].call(&"raise_alarm", &"setup")
	await get_tree().create_timer(3.0).timeout
	_report("loud")
	await _shot("loud_switch", 10)
	if _rt.mission.has_method(&"_on_secure_wait"):
		_rt.mission.call(&"_on_secure_wait")
		await get_tree().create_timer(2.0).timeout
		_report("van wait")
		await _shot("van_wait", 10)
	_rt.end_heist(true, [Net.local_slot()] as Array[int])
	await get_tree().create_timer(4.0).timeout
	await _shot("payday", 20)
	print("AH DONE")
	get_tree().quit(0)


## Stated shortcut: the crew stands 1.4 m from `target`, looking at it (yaw / pitch on the controller and its input).
func _place_facing(target: Vector3) -> void:
	var away: Vector3 = (_crew.global_position - target)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	_crew.global_position = Vector3(target.x, _crew.global_position.y, target.z) + away * 1.4
	await _frames(3)
	var eye: Vector3 = _crew.global_position + Vector3(0, 1.6, 0)
	var v: Vector3 = target - eye
	var yaw: float = atan2(-v.x, -v.z)
	var pitch: float = atan2(v.y, Vector2(v.x, v.z).length())
	_crew.set(&"look_yaw", yaw)
	_crew.set(&"look_pitch", pitch)
	var pin: Node = _crew.get_node_or_null(^"PlayerInput")
	if pin != null:
		pin.set(&"_yaw", yaw)
		pin.set(&"_pitch", pitch)
	await _frames(10)


func _gear() -> void:
	for n: Node in _rt.find_children("*", "GearPickup", true, false):
		var g: GearPickup = n as GearPickup
		if g == null or not g.is_enabled():
			continue
		await _place_facing(g.global_position + Vector3(0, 0.3, 0))
		_report("gear %s" % g.name)
		await _shot("gear_prompt", 10)
		await _key(_key_of(&"interact"), Tweak.interaction().item_pickup_s + 0.6)  # the real hold
		await get_tree().create_timer(1.0).timeout
		await _shot("gear_taken", 10)
		await _key(_key_of(&"mask_up"), 2.6)
		await get_tree().create_timer(1.0).timeout
		return
	print("AH ISSUE no enabled GearPickup")


func _operator() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		if String(n.get(&"role") if n.get(&"role") != null else "").contains("operator") and n is Node3D:
			await _place_facing((n as Node3D).global_position + Vector3(0, 1.2, 0))
			_report("operator %s" % n.name)
			await _shot("camera_operator", 10)
			return
	print("AH NOTE no camera operator this roll (sec_empty?)")


func _pager() -> void:
	var ps: Array[Node] = get_tree().root.find_children("*", "PagerSystem", true, false)
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		if n is NpcBase and String(n.get(&"role") if n.get(&"role") != null else "").contains("guard"):
			if not ps.is_empty():
				ps[0].call(&"start_pager", n)  # stated shortcut: a guard went down with his pager
			await _place_facing((n as Node3D).global_position + Vector3(0, 0.8, 0))
			_report("pager on %s" % n.name)
			await _shot("pager_prompt", 10)
			return
	print("AH NOTE no guard for the pager")


func _report(tag: String) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for n: Node in get_tree().root.find_children("*", "ObjectivesPanel", true, false):
		for l: Node in n.find_children("*", "Label", true, false):
			if (l as Label).is_visible_in_tree() and (l as Label).text != "":
				parts.append((l as Label).text)
	var prompt: PackedStringArray = PackedStringArray()
	for n: Node in get_tree().root.find_children("*", "InteractionPanel", true, false):
		for l: Node in n.find_children("*", "Label", true, false):
			if (l as Label).is_visible_in_tree() and (l as Label).text != "":
				prompt.append((l as Label).text)
	print("AH %s | objectives: %s | prompt: %s" % [tag, " / ".join(parts), " ".join(prompt)])
