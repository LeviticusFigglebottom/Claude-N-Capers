## Lead D-082 queue item 3 (PP-B-6): after a completed and after a failed heist, quitting (MenuFlow
## freed, as on a game exit) and starting again restores exactly what the run saved: cash, XP, level,
## unlocks / owned items and the loadout. The payday is driven with the keyboard; the heist end is setup.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")

var _flow: MenuFlow = null


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	if _flow != null and is_instance_valid(_flow):
		_flow.call(&"_leave_heist")
		await wait_frames(3)
		_flow.queue_free()
	_flow = null
	await wait_frames(3)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func _start_profile() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = 12345
	p.xp = 100
	var mods: Array[StringName] = []
	var def: WeaponDef = ContentDB.weapon(p.loadout.secondary)
	if def != null:
		for slot: Variant in def.mod_slots:
			var opts: Array = def.mod_slots[slot] as Array
			if opts.size() > 1:
				mods.append(StringName(opts[1]))
				if not p.owned_mods.has(StringName(opts[1])):
					p.owned_mods.append(StringName(opts[1]))
				break
	p.loadout.secondary_mods = mods
	return p


## Runs one heist from the hub and returns the profile on disk once the flow is back home.
func _run(success: bool, run_seed: int) -> Dictionary:
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(1)
	_flow.show_hub()
	await wait_frames(1)
	assert_true(_flow.direct_launch(LaunchArgs.parse(PackedStringArray(["--heist=glasshouse", "--seed=%d" % run_seed,
			"--difficulty=0"]))))
	assert_true(await wait_until(func() -> bool: return _flow.runtime != null, 60.0), "live")
	if _flow.runtime == null:
		return {}
	await wait_frames(10)
	var escaped: Array[int] = []
	if success:
		escaped.append(Net.local_slot())
	_flow.runtime.call(&"end_heist", success, escaped)
	for _i: int in range(6):  # payday (Enter: Continue -> cards -> key 1 -> Continue), or straight home
		await wait_frames(20)
		if _flow.current == (_flow.hub as Control) and _flow.visible:
			break
		var pd: PaydayScreen = null
		for n: Node in get_tree().root.find_children("*", "PaydayScreen", true, false):
			if (n as PaydayScreen).is_visible_in_tree():
				pd = n as PaydayScreen
		if pd == null:
			continue
		if pd.cards_stage and pd.picked_index < 0:
			pd.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
			await _key(KEY_1)
		pd.continue_button.grab_focus()
		await wait_frames(1)
		await _key(KEY_ENTER)
	assert_true(await wait_until(func() -> bool: return _flow.current == (_flow.hub as Control) and _flow.visible, 10.0),
			"back home after the %s heist" % ("completed" if success else "failed"))
	return SaveService.load_profile(SLOT).to_dict()


## Quit (free the flow) and start again: the new flow's profile and loadout screen match `saved`.
func _quit_and_reload(saved: Dictionary, what: String) -> void:
	_flow.queue_free()
	_flow = null
	await wait_frames(3)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(2)
	_flow.show_hub()
	await wait_frames(2)
	var now: Dictionary = _flow.profile.to_dict()
	for k: String in ["cash", "stash", "xp", "level", "owned_weapons", "owned_mods", "owned_masks", "unlocks",
			"notoriety", "career"]:
		assert_eq(var_to_str(now.get(k)), var_to_str(saved.get(k)), "%s: %s restored" % [what, k])
	assert_eq(var_to_str(now.get("loadout")), var_to_str(saved.get("loadout")), "%s: loadout restored" % what)
	_flow.open_station(&"armory")
	await wait_frames(2)
	var l: Loadout = _flow.loadout_screen.current_loadout()
	var sl: Loadout = PlayerProfile.from_dict(saved).loadout
	assert_eq([l.primary, l.secondary, l.primary_mods, l.secondary_mods, l.melee, l.armor, l.deployable, l.throwable, l.mask],
			[sl.primary, sl.secondary, sl.primary_mods, sl.secondary_mods, sl.melee, sl.armor, sl.deployable, sl.throwable,
			sl.mask], "%s: the loadout screen shows the saved loadout" % what)


func test_completed_heist_save_quit_reload() -> void:
	if UiNav.global_class(&"HeistLauncher") == null:
		skip("no HeistLauncher")
		return
	var p: PlayerProfile = _start_profile()
	SaveService.save_profile(p, SLOT)
	var saved: Dictionary = await _run(true, 61)
	if saved.is_empty():
		return
	assert_true(int(saved["cash"]) > p.cash or int(saved["stash"]) > p.stash, "a completed heist pays")
	assert_true(int(saved["xp"]) > p.xp or int(saved["level"]) > p.level, "a completed heist gives XP")
	assert_eq(var_to_str(PlayerProfile.from_dict(saved).loadout.secondary_mods), var_to_str(p.loadout.secondary_mods),
			"the heist keeps the modded loadout")
	await _quit_and_reload(saved, "completed")


func test_failed_heist_save_quit_reload() -> void:
	if UiNav.global_class(&"HeistLauncher") == null:
		skip("no HeistLauncher")
		return
	var p: PlayerProfile = _start_profile()
	SaveService.save_profile(p, SLOT)
	var saved: Dictionary = await _run(false, 62)
	if saved.is_empty():
		return
	assert_true(int(saved["cash"]) <= p.cash, "a failed heist pays nothing")
	await _quit_and_reload(saved, "failed")
