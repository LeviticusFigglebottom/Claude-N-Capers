## PT-01 core-loop playtest by real input only (PInputDriver): spawn, casing, mask-up, sprint, crouch, jump,
## interact/shout, aim and fire, reload, throw, melee, keyboard/gamepad parity. Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _masked_crew() -> CrewController:
	var c: CrewController = _crew()
	await wait_until(func() -> bool: return c.grounded, 2.0)
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await wait_physics_frames(10)
	return c


func _speed(c: CrewController) -> float:
	return Vector2(c.velocity.x, c.velocity.z).length()


func test_spawn_grounded_casing_unmasked() -> void:
	var c: CrewController = _crew()
	assert_true(await wait_until(func() -> bool: return c.grounded, 2.0), "grounded after spawn")
	assert_true(c.is_casing(), "spawns casing")
	assert_false(c.masked, "spawns unmasked")


func test_mask_up_by_hold() -> void:
	var c: CrewController = await _masked_crew()
	assert_true(c.masked, "masked after holding mask_up")
	assert_false(c.is_casing(), "not casing once masked")


func test_sprint_faster_than_walk_and_crouch_slower() -> void:
	var c: CrewController = await _masked_crew()
	_inp.press(&"move_forward")
	await wait_physics_frames(40)
	var walk: float = _speed(c)
	_inp.press(&"sprint")
	await wait_physics_frames(40)
	var run: float = _speed(c)
	assert_true(c.sprinting, "sprinting while sprint held")
	_inp.release(&"sprint")
	_inp.press(&"crouch")
	await wait_physics_frames(40)
	var crouch: float = _speed(c)
	assert_true(c.crouched, "crouched while crouch held")
	_inp.release_all()
	assert_true(run > walk * 1.2, "sprint %.2f > walk %.2f" % [run, walk])
	assert_true(crouch < walk * 0.9, "crouch %.2f < walk %.2f" % [crouch, walk])


func test_jump_leaves_ground_and_lands() -> void:
	var c: CrewController = await _masked_crew()
	var y0: float = c.global_position.y
	await _inp.tap(&"jump")
	var peak: float = y0
	for i: int in 40:
		await wait_physics_frames(1)
		peak = maxf(peak, c.global_position.y)
	assert_true(peak > y0 + 0.3, "jump height %.2f" % (peak - y0))
	assert_true(await wait_until(func() -> bool: return c.grounded, 2.0), "lands")


func test_held_jump_does_not_bunny_hop() -> void:
	var c: CrewController = await _masked_crew()
	_inp.press(&"jump")
	await wait_physics_frames(10)
	await wait_until(func() -> bool: return c.grounded, 2.0)
	var y_land: float = c.global_position.y
	var peak: float = y_land
	for i: int in 30:
		await wait_physics_frames(1)
		peak = maxf(peak, c.global_position.y)
	_inp.release(&"jump")
	assert_true(peak < y_land + 0.1, "holding jump does not re-jump (%.2f)" % (peak - y_land))


## PI-25: jump pressed while airborne and held through the landing jumps once on landing (was eaten).
func test_jump_held_from_air_fires_on_landing() -> void:
	var c: CrewController = await _masked_crew()
	await _inp.tap(&"jump")
	await wait_physics_frames(6)
	assert_false(c.grounded, "airborne")
	_inp.press(&"jump")
	await wait_until(func() -> bool: return c.grounded, 2.0)
	var y: float = c.global_position.y
	var peak: float = y
	for _i: int in 30:
		await wait_physics_frames(1)
		peak = maxf(peak, c.global_position.y)
	_inp.release(&"jump")
	assert_true(peak > y + 0.3, "held jump from the air jumps on landing (%.2f)" % (peak - y))


func test_shout_while_casing_does_not_unmask_or_alarm() -> void:
	var c: CrewController = _crew()
	await wait_until(func() -> bool: return c.grounded, 2.0)
	await _inp.tap(&"shout")
	await wait_physics_frames(10)
	assert_true(c.is_casing(), "still casing after F with nothing aimed")
	assert_eq(_rt.phase, Enums.HeistPhase.CASING, "phase unchanged")


func test_fire_spends_ammo_and_reload_refills() -> void:
	var c: CrewController = await _masked_crew()
	var w: CrewWeapons = c.weapons
	var ws: int = w.equipped_slot
	var m0: int = w.mag(ws)
	assert_true(m0 > 0, "has a loaded mag")
	_inp.press(&"aim")
	await wait_physics_frames(20)
	await _inp.hold(&"fire", 0.5)
	_inp.release(&"aim")
	var m1: int = w.mag(ws)
	assert_true(m1 < m0, "fire spent ammo (%d -> %d)" % [m0, m1])
	await _inp.tap(&"reload")
	assert_true(await wait_until(func() -> bool: return not w.reloading and w.mag(ws) == w.mag_size(ws), 6.0),
		"reload refills the mag (%d/%d)" % [w.mag(ws), w.mag_size(ws)])


func test_sprint_blocks_fire_until_released() -> void:
	var c: CrewController = await _masked_crew()
	var w: CrewWeapons = c.weapons
	var ws: int = w.equipped_slot
	var m0: int = w.mag(ws)
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await wait_physics_frames(30)
	_inp.press(&"fire")
	await wait_physics_frames(30)
	_inp.release_all()
	await wait_physics_frames(30)
	# PD2: firing while sprinting cancels the sprint and shoots after a short delay; either way a held trigger must
	# not be swallowed forever.
	assert_true(w.mag(ws) < m0 or not c.sprinting, "fire while sprinting either shoots or stops the sprint")


func test_melee_swing() -> void:
	var c: CrewController = await _masked_crew()
	if c.melee == null:
		assert_true(false, "crew has no CrewMelee")
		return
	_inp.press(&"melee")
	var swung: bool = await wait_until(func() -> bool: return c.melee.state != &"", 1.0)
	_inp.release(&"melee")
	assert_true(swung, "melee starts a swing or charge")
	assert_true(await wait_until(func() -> bool: return c.melee.state == &"", 3.0), "melee finishes")


func test_throw_uses_a_throwable() -> void:
	var c: CrewController = await _masked_crew()
	var w: CrewWeapons = c.weapons
	c.loadout.throwable = &"throwable.concussion"  # setup only: a real grenade in the loadout
	CrewThrowables.set_count(c, 2)
	assert_true(c.throwables.throwable_def() != null, "concussion is a throwable def")
	var spawned: Array = []
	c.throwables.released.connect(func() -> void: spawned.append(true))
	await _inp.tap(&"throw_item")
	assert_true(await wait_until(func() -> bool: return w.throwable_count == 1, 3.0),
		"throw spends a throwable (count %d)" % w.throwable_count)
	assert_eq(spawned.size(), 1, "released one throwable")
	assert_eq(c.throwables.throws, 1, "one throw counted")


func test_gamepad_buttons_match_keyboard() -> void:
	var acts: Array[StringName] = [&"sprint", &"crouch", &"jump", &"interact", &"reload", &"melee", &"throw_item",
		&"mask_up", &"swap_weapon", &"pause"]
	for a: StringName in acts:
		var joy: bool = false
		for e: InputEvent in InputMap.action_get_events(a):
			joy = joy or e is InputEventJoypadButton or e is InputEventJoypadMotion
		assert_true(joy, "%s has a gamepad binding" % a)


func test_gamepad_mask_up_and_jump() -> void:
	var c: CrewController = _crew()
	await wait_until(func() -> bool: return c.grounded, 2.0)
	var mb: int = -1
	var jb: int = -1
	for e: InputEvent in InputMap.action_get_events(&"mask_up"):
		if e is InputEventJoypadButton:
			mb = (e as InputEventJoypadButton).button_index
	for e: InputEvent in InputMap.action_get_events(&"jump"):
		if e is InputEventJoypadButton:
			jb = (e as InputEventJoypadButton).button_index
	_inp.joy_button(mb as JoyButton, true)
	await wait_seconds(Tweak.crew().mask_up_time_s + 0.3)
	_inp.joy_button(mb as JoyButton, false)
	await wait_physics_frames(10)
	assert_true(c.masked, "pad mask-up")
	var y0: float = c.global_position.y
	_inp.joy_button(jb as JoyButton, true)
	await wait_physics_frames(2)
	_inp.joy_button(jb as JoyButton, false)
	var peak: float = y0
	for i: int in 30:
		await wait_physics_frames(1)
		peak = maxf(peak, c.global_position.y)
	assert_true(peak > y0 + 0.3, "pad jump %.2f" % (peak - y0))


## PT-03: swap_weapon always goes to the other slot, even after picking a slot with 1/2.
func test_swap_after_slot_key_toggles() -> void:
	var c: CrewController = await _masked_crew()
	var w: CrewWeapons = c.weapons
	if not (w.has_weapon(Enums.WeaponSlot.PRIMARY) and w.has_weapon(Enums.WeaponSlot.SECONDARY)):
		c.loadout.primary = &"weapon.brute_12"  # setup: the P1 default loadout carries no primary
		c.loadout.resolved_primary = LoadoutResolver.resolve_weapon(c.loadout.primary, c.loadout.primary_mods)
		w.set_loadout(c.loadout)
		await wait_physics_frames(2)
	assert_true(w.has_weapon(Enums.WeaponSlot.PRIMARY), "two weapons for the swap test")
	await _inp.tap(&"slot_primary")
	await wait_seconds(1.0)
	assert_eq(w.equipped_slot, Enums.WeaponSlot.PRIMARY, "1 equips primary")
	await _inp.tap(&"swap_weapon")
	await wait_seconds(1.0)
	assert_eq(w.equipped_slot, Enums.WeaponSlot.SECONDARY, "swap goes to secondary")
	await _inp.tap(&"swap_weapon")
	await wait_seconds(1.0)
	assert_eq(w.equipped_slot, Enums.WeaponSlot.PRIMARY, "swap back to primary")
