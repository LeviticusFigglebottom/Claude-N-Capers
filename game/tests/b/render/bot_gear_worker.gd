## Worker for bot_gear_capture.gd (real_input_run_worker's keyboard helpers; loaded at runtime for the autoloads).
extends "res://tests/b/render/real_input_run_worker.gd"

const LOUD_WAIT_S: float = 150.0
const LOUD_WALL_MS: int = 900000

var _mismatches: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = StringName(args[1]) if args.size() > 1 else &"ostrander_federal"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/bot_gear").path_join(String(_heist))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _profile() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 25
	for id: StringName in [&"weapon.corsair_ar", &"weapon.anvil_lmg", &"weapon.heron_308"]:
		if not p.owned_weapons.has(id):
			p.owned_weapons.append(id)
	for id: StringName in [&"mod.corsair_suppressor", &"mod.rail_prism_scope"]:
		p.owned_mods.append(id)
	var masks: Array[StringName] = MaskLocker.available_ids(p)
	CrewLoadouts.set_entry(p, 0, {"weapon": &"weapon.corsair_ar", "mods": [&"mod.corsair_suppressor",
		&"mod.rail_prism_scope"], "armor": &"armor.flak_rig", "mask": masks[0] if masks.size() > 0 else &"",
		"outfit": &"dutch"})
	CrewLoadouts.set_entry(p, 1, {"weapon": &"weapon.heron_308", "mask": masks[1] if masks.size() > 1 else &""})
	CrewLoadouts.set_entry(p, 2, {"weapon": &"weapon.anvil_lmg", "armor": &"armor.heavy_vest",
		"mask": masks[2] if masks.size() > 2 else &""})
	return p


func _run() -> void:
	SaveService.root_dir = "user://bot_gear_%d" % OS.get_process_id()
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	var p: PlayerProfile = _profile()
	SaveService.save_profile(p, 0)
	var want: Array[Dictionary] = []
	for i: int in range(CrewLoadouts.SLOTS):
		want.append(CrewLoadouts.validate(p, CrewLoadouts.entry(p, i)))
		print("BOT WANT %d %s" % [i, want[i]])
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
	await get_tree().create_timer(4.0).timeout
	var bots: Array[CrewController] = []
	for n: Node in get_tree().root.find_children("*", "CrewController", true, false):
		if (n as CrewController).is_ai:
			bots.append(n as CrewController)
	bots.sort_custom(func(a: CrewController, b: CrewController) -> bool: return a.slot < b.slot)
	if bots.size() != CrewLoadouts.SLOTS:
		_miss("expected %d bots, found %d" % [CrewLoadouts.SLOTS, bots.size()])
	for i: int in range(bots.size()):
		_check(i, bots[i], want[i] if i < want.size() else CrewLoadouts.empty_entry())
	await _spectate(bots, "bots_casing")
	await _key(_key_of(&"mask_up"), 2.6)
	await get_tree().create_timer(2.0).timeout
	for i: int in range(bots.size()):
		var v: CrewView = CrewView.of(bots[i])
		var mask: StringName = v._mask_id if v != null else &""
		print("BOT %d masked=%s mask_node=%s" % [bots[i].slot, bots[i].masked, mask])
		var wm: StringName = StringName(want[i]["mask"]) if i < want.size() else &""
		if bots[i].masked and wm != &"" and mask != wm:
			_miss("bot %d wears mask %s, assigned %s" % [bots[i].slot, mask, wm])
	await _spectate(bots, "bots_masked")
	await _loud(bots)
	print("BOT DONE %d" % _mismatches)
	SaveService.delete_profile(0)
	get_tree().quit(0)


func _check(i: int, c: CrewController, w: Dictionary) -> void:
	var prim: StringName = c.weapons.weapon_id(Enums.WeaponSlot.PRIMARY) if c.weapons != null else &""
	var mods: Array[StringName] = c.loadout.primary_mods if c.loadout != null else ([] as Array[StringName])
	var st: WeaponStats = c.weapons.stats(Enums.WeaponSlot.PRIMARY) if c.weapons != null else null
	var armor: StringName = c.loadout.armor if c.loadout != null else &""
	print("BOT %d slot=%d heister=%s primary=%s mods=%s equipped=%d mag=%d suppressed=%s armor=%s max_armor=%.1f mask=%s" % [
		i, c.slot, c.heister, prim, mods, c.weapons.equipped_slot, c.weapons.mag(Enums.WeaponSlot.PRIMARY),
		st.get(&"suppressed") if st != null else null, armor, c.health.max_armor if c.health != null else -1.0,
		c.loadout.mask if c.loadout != null else &""])
	if w["weapon"] != &"" and prim != w["weapon"]:
		_miss("bot %d primary %s, assigned %s" % [i, prim, w["weapon"]])
	for m: StringName in w["mods"] as Array[StringName]:
		if not mods.has(m):
			_miss("bot %d lacks mod %s" % [i, m])
	if w["armor"] != &"" and armor != w["armor"]:
		_miss("bot %d armor %s, assigned %s" % [i, armor, w["armor"]])
	if w["armor"] != &"" and c.health != null:
		var ad: ArmorDef = ContentDB.armor(w["armor"])
		print("BOT %d armor def %s" % [i, ad])
	if w["mask"] != &"" and c.loadout != null and c.loadout.mask != w["mask"]:
		_miss("bot %d loadout mask %s, assigned %s" % [i, c.loadout.mask, w["mask"]])
	if w["outfit"] != &"" and c.heister != w["outfit"]:
		_miss("bot %d heister %s, assigned outfit %s" % [i, c.heister, w["outfit"]])


func _miss(what: String) -> void:
	_mismatches += 1
	print("BOT MISMATCH ", what)


## A spectator camera 4 m in front of the bots' centre, looking at their chests.
func _spectate(bots: Array[CrewController], tag: String) -> void:
	if bots.is_empty():
		return
	var centre: Vector3 = Vector3.ZERO
	for b: CrewController in bots:
		centre += b.global_position
	centre /= float(bots.size())
	var fwd: Vector3 = -bots[0].global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var prev: Camera3D = get_viewport().get_camera_3d()
	var cam: Camera3D = Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = centre + fwd * 3.0 + Vector3.UP * 1.5
	cam.look_at(centre + Vector3.UP * 1.2, Vector3.UP)
	cam.current = true
	await _shot(tag, 10)
	cam.current = false
	cam.queue_free()
	if prev != null:
		prev.current = true


## Setup: the alarm goes off (StealthDirector.raise_alarm); then each bot must fire its assigned primary (its primary
## magazine + reserve drops below full) within LOUD_WAIT_S of the first assault.
func _loud(bots: Array[CrewController]) -> void:
	var sd: Array[Node] = get_tree().root.find_children("*", "StealthDirector", true, false)
	if sd.is_empty():
		_miss("no StealthDirector to raise the alarm")
		return
	var full: Dictionary = {}
	for b: CrewController in bots:
		full[b.slot] = _primary_ammo(b)
	sd[0].call(&"raise_alarm", &"setup")
	Engine.max_physics_steps_per_frame = 30  # xvfb renders slowly: let game time keep pace with the wall clock
	var game_s: float = 0.0
	var t0: int = Time.get_ticks_msec()
	var shot_taken: bool = false
	while game_s < LOUD_WAIT_S and Time.get_ticks_msec() - t0 < LOUD_WALL_MS:
		for _i: int in range(10):
			await get_tree().physics_frame
			game_s += 1.0 / float(Engine.physics_ticks_per_second)
		var all_fired: bool = true
		for b: CrewController in bots:
			if _primary_ammo(b) >= int(full[b.slot]):
				all_fired = false
		if not shot_taken and bots.any(func(b: CrewController) -> bool: return b.weapons.shots_fired > 0):
			shot_taken = true
			await _spectate(bots, "bots_loud")
		if all_fired:
			break
	print("BOT loud waited %.0f game s, %.0f wall s, %d enemies" % [game_s, (Time.get_ticks_msec() - t0) / 1000.0,
		get_tree().get_nodes_in_group(G.ENEMY).size()])
	for b: CrewController in bots:
		var used: int = int(full[b.slot]) - _primary_ammo(b)
		print("BOT %d loud: primary=%s rounds_used=%d shots_fired=%d equipped=%d" % [b.slot,
			b.weapons.weapon_id(Enums.WeaponSlot.PRIMARY), used, b.weapons.shots_fired, b.weapons.equipped_slot])
		if used <= 0:
			_miss("bot %d never fired its primary %s" % [b.slot, b.weapons.weapon_id(Enums.WeaponSlot.PRIMARY)])


func _primary_ammo(b: CrewController) -> int:
	return b.weapons.mag(Enums.WeaponSlot.PRIMARY) + b.weapons.reserve(Enums.WeaponSlot.PRIMARY)
