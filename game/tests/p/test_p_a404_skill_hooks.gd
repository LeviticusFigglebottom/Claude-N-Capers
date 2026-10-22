## A4-04: the five skill hooks in P's files (spec from A, values in B's skill data). Real input (PInputDriver); the
## skills arrive as a Modifiers source on the crew slot, as ENV B's progression sets them.
##   weapon.ads_speed_mult (class / suppressed), movement.ads_speed_penalty_mult, movement.shoot_while_sprinting
##   (class), movement.reload_while_sprinting, movement.sprint_any_direction.
extends TestCase

const SRC: StringName = &"skills_test"

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 404, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()


func after_each() -> void:
	_inp.release_all()
	Modifiers.clear_source(0, SRC)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew(skills: Dictionary = {}) -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	Modifiers.set_source(c.slot, SRC, skills)
	return c


func _hspeed(c: CrewController) -> float:
	return Vector2(c.velocity.x, c.velocity.z).length()


## Walk forward for `ticks` with `extra` held too; the horizontal speed at the end.
func _walk_speed(c: CrewController, extra: StringName, ticks: int = 45) -> float:
	if extra != &"":
		_inp.press(extra)
	_inp.press(&"move_forward")
	await wait_physics_frames(ticks)
	var v: float = _hspeed(c)
	_inp.release_all()
	await wait_physics_frames(20)
	return v


func test_ads_rate_mult_by_class() -> void:
	var c: CrewController = _crew()
	await wait_physics_frames(5)
	var base: float = CrewView.ads_rate(c)
	Modifiers.set_source(c.slot, SRC, {&"weapon.ads_speed_mult.all": 2.0})
	assert_near(CrewView.ads_rate(c), base * 2.0, 0.001, "Snap Shot (.all) doubles the ADS rate")
	Modifiers.set_source(c.slot, SRC, {&"weapon.ads_speed_mult.shotgun": 2.25})
	var q: Array[StringName] = CrewView.weapon_qualifiers(c)
	assert_near(CrewView.ads_rate(c), base * (2.25 if q.has(&"shotgun") else 1.0), 0.001,
		"Pump Action (.shotgun) only for a shotgun (equipped %s)" % [q])
	Modifiers.set_source(c.slot, SRC, {&"weapon.ads_speed_mult.suppressed": 2.0})
	assert_near(CrewView.ads_rate(c), base * (2.0 if c.weapons.is_suppressed() else 1.0), 0.001,
		"Hushed Hands (.suppressed) follows the suppressor (suppressed %s)" % c.weapons.is_suppressed())


func test_ads_walk_penalty_and_snap_shot() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	await wait_physics_frames(5)
	var walk: float = await _walk_speed(c, &"")
	var ads: float = await _walk_speed(c, &"aim")
	assert_near(walk, tw.walk_speed, 0.15, "walk speed")
	assert_near(ads, tw.walk_speed * tw.ads_speed_mult, 0.15, "aiming caps the walk (PD2 steelsight 185 / 350)")
	Modifiers.set_source(c.slot, SRC, {&"movement.ads_speed_penalty_mult": 0.0})
	var snap: float = await _walk_speed(c, &"aim")
	assert_near(snap, tw.walk_speed, 0.15, "Snap Shot (penalty x 0): full walk speed while aiming")


func test_shoot_while_sprinting_flag() -> void:
	var c: CrewController = _crew()
	await wait_physics_frames(5)
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await wait_physics_frames(15)
	assert_true(c.sprinting, "sprinting")
	_inp.press(&"fire")
	await wait_physics_frames(3)
	assert_false(c.sprinting, "without the skill, fire ends the sprint (PO-4)")
	_inp.release_all()
	await wait_physics_frames(20)
	Modifiers.set_source(c.slot, SRC, {&"movement.shoot_while_sprinting.all": true})
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await wait_physics_frames(15)
	var mag0: int = c.weapons.mag(c.weapons.equipped_slot)
	_inp.press(&"fire")
	await wait_physics_frames(10)
	assert_true(c.sprinting, "Run and Gun (.all): the sprint goes on while firing")
	assert_true(c.weapons.mag(c.weapons.equipped_slot) < mag0, "and the shot is fired")


func test_reload_while_sprinting_flag() -> void:
	var c: CrewController = _crew()
	await wait_physics_frames(5)
	await _inp.tap(&"fire")  # one round out so a reload can start
	await wait_physics_frames(30)
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await wait_physics_frames(15)
	assert_true(c.sprinting, "sprinting")
	await _inp.tap(&"reload")
	await wait_physics_frames(3)
	assert_true(c.weapons.reloading, "reloading")
	assert_false(c.sprinting, "without Free Running aced, a reload ends the sprint")
	await wait_until(func() -> bool: return not c.weapons.reloading, 6.0)
	_inp.release_all()
	await wait_physics_frames(20)
	Modifiers.set_source(c.slot, SRC, {&"movement.reload_while_sprinting": true})
	await _inp.tap(&"fire")
	await wait_physics_frames(30)
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await wait_physics_frames(15)
	await _inp.tap(&"reload")
	await wait_physics_frames(3)
	assert_true(c.weapons.reloading, "reloading")
	assert_true(c.sprinting, "Free Running aced: reload and sprint together")


func test_sprint_any_direction_flag() -> void:
	var c: CrewController = _crew()
	await wait_physics_frames(5)
	_inp.press(&"move_right")
	_inp.press(&"sprint")
	await wait_physics_frames(15)
	assert_false(c.sprinting, "no sideways sprint by default")
	_inp.release_all()
	await wait_physics_frames(10)
	Modifiers.set_source(c.slot, SRC, {&"movement.sprint_any_direction": true})
	_inp.press(&"move_right")
	_inp.press(&"sprint")
	await wait_physics_frames(15)
	assert_true(c.sprinting, "Free Running aced: sideways sprint")
