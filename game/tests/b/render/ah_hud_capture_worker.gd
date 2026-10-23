## Worker for ah_hud_capture.gd (real_input_run_worker's helpers; loaded at runtime for the autoloads).
extends "res://tests/b/render/real_input_run_worker.gd"

const STEALTH_ORDER: Array[StringName] = [&"casing", &"gear", &"keycard", &"office", &"safe_code", &"safe",
	&"safe_loot", &"secure"]

var _rt: HeistRuntime
## args[1]: a run seed (and Brutal) for the direct launch: one that staffs the security room (the camera operator).
var _seed: int = 0
var _crew: Node3D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = &"afterhours"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/ah_hud").path_join(String(_heist))
	DirAccess.make_dir_recursive_absolute(_out)
	_seed = int(args[1]) if args.size() > 1 else 0
	_run.call_deferred()


func _run() -> void:
	SaveService.root_dir = "user://ah_hud_%d" % OS.get_process_id()
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _frames(30)
	if _seed != 0:
		_flow.launch(_heist, Enums.Difficulty.BRUTAL, SaveService.load_profile().loadout, _seed)
	else:
		await _menu_launch()
	if not await _wait_runtime():
		return
	await _play()


func _menu_launch() -> void:
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


func _wait_runtime() -> bool:
	var t0: int = Time.get_ticks_msec()
	while _flow.runtime == null and Time.get_ticks_msec() - t0 < 120000:
		await _frames(5)
	if _flow.runtime == null:
		print("AH ISSUE the heist did not launch")
		get_tree().quit(1)
		return false
	_rt = _flow.runtime as HeistRuntime
	print("AH variants %s" % _rt.variants)
	return true


func _play() -> void:
	await get_tree().create_timer(4.0).timeout
	_crew = _rt.crew_controller(Net.local_slot()) as Node3D
	_crew.set(&"stealth_hidden", true)  # stated shortcut (as A's X4 stealth flow): NPCs / cameras never see the crew
	_report("civilian start")
	await _shot("civilian_start", 10)
	await _gear()
	await _shot("masked_after_gear", 10)
	await _operator()
	await _pager()
	for id: StringName in STEALTH_ORDER:
		if int(_rt.mission.call(&"objective_state", id)) == Enums.ObjectiveState.ACTIVE:
			_rt.mission.call(&"complete", id)
			await get_tree().create_timer(1.5).timeout
			_report("after %s" % id)
			await _shot("obj_%s_done" % id, 6)
	await _secure_bag()
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
		var target: Vector3 = g.global_position + Vector3(0, 0.3, 0)
		for i: int in 8:  # the side of the bag with a clear look at it (the booth bag sits against the deck)
			var d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
			_crew.global_position = Vector3(target.x, _crew.global_position.y, target.z) + d * 1.3
			await _place_facing(target)
			if _prompt_text() != "":
				break
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
		if _has_tag(n, &"camera_operator") and n is Node3D:
			var op: Node3D = n as Node3D
			# Over the shoulder: stand behind the seat (the desk is ahead of the operator) and look at the monitors.
			_crew.global_position = op.global_position + op.global_transform.basis.z * 1.6
			await _place_facing(op.global_position + Vector3(0, 1.1, 0))
			_report("operator %s" % n.name)
			await _shot("camera_operator", 10)
			return
	print("AH NOTE no camera operator this roll (sec_empty?)")


## A rover guard killed in stealth (stated shortcut: NpcBase.die from the crew); the real PagerSystem pages him and,
## after its delay, puts the answer prompt on the body. Shot facing the body, then mid-answer (the real hold).
func _pager() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var g: NpcBase = n as NpcBase
		if g == null or not g.alive or not _has_tag(g, &"guard_alley"):
			continue  # the alley smoker: alone outside, so nobody finds the body before the pager
		await _place_facing(g.global_position + Vector3(0, 1.0, 0))
		g.die({}, int(_crew.get(&"net_id")) if _crew.get(&"net_id") != null else 0)
		await get_tree().create_timer(Tweak.stealth().pager_delay_max_s + 1.0).timeout
		var comp: Node3D = g.find_child(PagerSystem.COMP_NAME, true, false) as Node3D
		print("AH pager comp %s" % (comp.global_position if comp != null else "none"))
		await _place_facing(comp.global_position if comp != null else g.global_position + Vector3(0, 0.3, 0))
		_report("pager on %s" % g.name)
		await _shot("pager_prompt", 10)
		var hold: float = Tweak.stealth().pager_answer_s + 1.0
		_hold_interact(hold)  # the real hold, to the end
		await get_tree().create_timer(2.0).timeout
		_report("pager answering")
		await _shot("pager_answering", 4)
		await get_tree().create_timer(hold).timeout
		_report("pager answered")
		return
	print("AH NOTE no guard for the pager")


func _has_tag(n: Node, tag: StringName) -> bool:
	var info: Variant = n.get(&"spawn_info")
	return info is Dictionary and (Array((info as Dictionary).get("tags", [])).has(tag) \
			or Array((info as Dictionary).get("tags", [])).has(String(tag)))


func _hold_interact(seconds: float) -> void:
	_key(_key_of(&"interact"), seconds)  # not awaited: the shot lands mid-hold


## One bag of the safe's cash secured (stated shortcut: spawned and dropped in the secure zone; the real
## LootManager rest timer secures it) so payday shows the Afterhours loot lines.
func _secure_bag() -> void:
	var lm: LootManager = _rt.find_children("*", "LootManager", true, false).front() as LootManager
	var zone: Area3D = null
	for z: Node in get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		if z is Area3D and _rt.is_ancestor_of(z):
			zone = z as Area3D
			break
	if lm == null or zone == null:
		print("AH NOTE no LootManager / secure zone")
		return
	var centre: Vector3 = zone.global_position
	for c: Node in zone.get_children():
		if c is CollisionShape3D:
			centre = (c as CollisionShape3D).global_position
			var box: BoxShape3D = (c as CollisionShape3D).shape as BoxShape3D
			if box != null:
				centre.y -= box.size.y * 0.5 - 0.5
			break
	print("AH secure zone %s at %s inside=%s" % [zone.name, centre, ZoneUtil.contains(zone, centre)])
	var bag: LootBag = lm.spawn_bag(&"loot.cash_bricks", Transform3D(Basis(), centre))
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(bag) and not bag.secured:
		print("AH NOTE the spawned bag did not rest-secure at %s; LootManager._secure (stated shortcut)" % bag.global_position)
		lm.call(&"_secure", bag)
		await get_tree().create_timer(0.5).timeout
	print("AH bag secured=%s" % (not is_instance_valid(bag) or bag.secured))


func _prompt_text() -> String:
	for n: Node in get_tree().root.find_children("*", "InteractionPanel", true, false):
		for l: Node in n.find_children("*", "Label", true, false):
			if (l as Label).is_visible_in_tree() and (l as Label).text != "":
				return (l as Label).text
	return ""


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
