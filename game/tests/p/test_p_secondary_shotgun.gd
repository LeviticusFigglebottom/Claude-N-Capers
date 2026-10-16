## D-126 (PO 2026-10-16): shotguns go in the secondary slot. ENV P checks the first-person side for a secondary long
## gun: equip / swap both ways (holster + draw), reload, ADS on the shotgun's own set and AimPoint, and a downed
## player (CrewWeapons equips the secondary when DOWNED) holds and fires the shotgun. Real input (PInputDriver).
## Owner: ENV P.
extends TestCase

const SHOTGUN: StringName = &"weapon.mule_12"
const RIFLE: StringName = &"weapon.corsair_ar"

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = RIFLE
	l.primary_mods = [] as Array[StringName]
	l.resolved_primary = LoadoutResolver.resolve_weapon(RIFLE, l.primary_mods)
	l.secondary = SHOTGUN
	l.secondary_mods = [] as Array[StringName]
	l.resolved_secondary = LoadoutResolver.resolve_weapon(SHOTGUN, l.secondary_mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_physics_frames(60)
	return c


func _settled(vm: FpViewmodel) -> bool:
	return vm.action == FpViewmodel.Action.NONE


func test_secondary_shotgun_swap_reload_ads() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of_crew(c)
	assert_true(vm != null, "FP viewmodel")
	if vm == null:
		return
	var shotgun_set: StringName = ContentDB.weapon(SHOTGUN).anim_set
	var rifle_set: StringName = ContentDB.weapon(RIFLE).anim_set
	await _inp.tap(&"slot_secondary")
	assert_true(await wait_until(func() -> bool: return vm.anim_set == shotgun_set and _settled(vm), 6.0),
		"swap to the secondary shotgun (set %s, wanted %s)" % [vm.anim_set, shotgun_set])
	assert_eq(c.weapons.weapon_id(c.weapons.equipped_slot), SHOTGUN, "the shotgun is equipped")
	assert_true(FpViewmodel.has_aim_point(vm.weapon_visual), "the shotgun has an AimPoint")
	await _inp.tap(&"fire")
	await wait_physics_frames(40)
	await _inp.tap(&"reload")
	assert_true(await wait_until(func() -> bool: return vm.action == FpViewmodel.Action.RELOAD, 2.0), "reload plays")
	assert_true(await wait_until(func() -> bool: return not c.weapons.reloading and _settled(vm), 12.0), "reload ends")
	_inp.press(&"aim")
	assert_true(await wait_until(func() -> bool: return vm.ads_weight > 0.999, 3.0), "aimed")
	await wait_frames(5)
	var cam: Camera3D = CrewView.of(c).camera()
	var aim: Node3D = vm.weapon_visual.get_marker(WeaponVisual.AIM_POINT)
	var p: Vector3 = cam.global_transform.affine_inverse() * aim.global_position
	assert_true(Vector2(p.x, p.y).length() < 0.004, "shotgun sights on the camera axis (%s)" % p)
	_inp.release(&"aim")
	await wait_physics_frames(30)
	await _inp.tap(&"slot_primary")
	assert_true(await wait_until(func() -> bool: return vm.anim_set == rifle_set and _settled(vm), 6.0),
		"swap back to the primary (set %s)" % vm.anim_set)


func test_downed_player_holds_and_fires_the_secondary_shotgun() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch()
	var vm: FpViewmodel = FpViewmodel.of_crew(c)
	var shotgun_set: StringName = ContentDB.weapon(SHOTGUN).anim_set
	assert_eq(c.weapons.equipped_slot, Enums.WeaponSlot.PRIMARY, "the rifle out first")
	c.health.go_down()
	assert_true(await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.DOWNED, 2.0), "downed")
	assert_true(await wait_until(func() -> bool: return c.weapons.equipped_slot == Enums.WeaponSlot.SECONDARY
		and vm.anim_set == shotgun_set and _settled(vm), 6.0), "downed: the secondary shotgun comes out (set %s)" %
		vm.anim_set)
	var flashes: int = vm.fx.flashes
	var mag: int = c.weapons.mag(c.weapons.equipped_slot)
	await _inp.tap(&"fire")
	await wait_physics_frames(20)
	assert_eq(c.weapons.mag(c.weapons.equipped_slot), mag - 1, "a downed shot fired")
	assert_true(vm.fx.flashes > flashes, "the FP shotgun flashed")
	assert_true(vm.weapon_visual != null and vm.weapon_visual.is_visible_in_tree(), "the shotgun is on screen")
