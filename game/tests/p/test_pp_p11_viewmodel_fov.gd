## PP-P-11: the first-person arms/weapon render with a fixed viewmodel FOV, independent of the world FOV setting
## and ADS zoom; the world camera culls them. Real input for aiming. Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await wait_seconds(1.0)


func after_each() -> void:
	_inp.release_all()
	GameSettings.current().set_value(GameSettings.VIDEO, &"fov", 75.0)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_viewmodel_fov_fixed_and_layers_split() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var view: CrewView = CrewView.of(c)
	var cam: Camera3D = view.camera()
	var want: float = FpViewmodelTweak.data().viewmodel_fov_deg
	assert_near(view.viewmodel_fov(), want, 0.01, "viewmodel camera at the tweak FOV")
	assert_eq(cam.cull_mask & CrewView.VIEWMODEL_LAYER, 0, "world camera culls the viewmodel layer")
	var n: int = 0
	for g: Node in cam.find_children("*", "GeometryInstance3D", true, false):
		n += 1
		assert_eq((g as GeometryInstance3D).layers & CrewView.VIEWMODEL_LAYER, CrewView.VIEWMODEL_LAYER, "%s on the viewmodel layer" % g.name)
	assert_true(n > 0, "arms/weapon meshes under the camera (%d)" % n)
	GameSettings.current().set_value(GameSettings.VIDEO, &"fov", 100.0)
	await wait_frames(3)
	assert_near(cam.fov, 100.0, 0.01, "world FOV follows the setting")
	assert_near(view.viewmodel_fov(), want, 0.01, "viewmodel FOV does not")
	_inp.press(&"aim")
	await wait_seconds(1.0)
	assert_true(cam.fov < 100.0 - 1.0 or c.weapons.stats(c.weapons.equipped_slot).magnification <= 1.0,
		"ADS zooms the world (%.1f)" % cam.fov)
	assert_near(view.viewmodel_fov(), want, 0.01, "ADS does not change the viewmodel FOV")


## PO-4: the viewmodel gets its own key light, culled to the viewmodel layer (never lights the world).
func test_viewmodel_key_light_only_lights_the_viewmodel() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var view: CrewView = CrewView.of(c)
	var key: DirectionalLight3D = view.find_child("ViewmodelKeyLight", true, false) as DirectionalLight3D
	var vt: FpViewmodelTweak = FpViewmodelTweak.data()
	if vt.viewmodel_key_light_energy <= 0.0 or vt.viewmodel_fov_deg <= 0.0:
		assert_true(key == null, "no key light when disabled")
		return
	assert_true(key != null, "key light exists")
	assert_eq(key.light_cull_mask, CrewView.VIEWMODEL_LAYER, "culled to the viewmodel layer")
	assert_eq(key.layers, CrewView.VIEWMODEL_LAYER, "on the viewmodel layer, else the vm camera culls the light itself")
	assert_false(key.shadow_enabled, "no shadows")
	assert_near(key.light_energy, vt.viewmodel_key_light_energy, 1e-4, "energy from the tweak")


## PO6-10: the gun fill light lights only the first-person gun (VIEWMODEL_GUN_LAYER on the WeaponVisual's meshes,
## never on the arms).
func test_gun_fill_light_only_lights_the_gun() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var view: CrewView = CrewView.of(c)
	var vt: FpViewmodelTweak = FpViewmodelTweak.data()
	var fill: DirectionalLight3D = view.find_child("ViewmodelGunFill", true, false) as DirectionalLight3D
	if vt.viewmodel_gun_fill_energy <= 0.0 or vt.viewmodel_fov_deg <= 0.0:
		assert_true(fill == null, "no gun fill when disabled")
		return
	assert_true(fill != null, "gun fill exists")
	if fill == null:
		return
	assert_eq(fill.light_cull_mask, CrewView.VIEWMODEL_GUN_LAYER, "culled to the gun layer")
	assert_eq(fill.layers, CrewView.VIEWMODEL_LAYER, "inside the vm camera's cull mask")
	var gun: int = 0
	var arms: int = 0
	for g: Node in view.camera().find_children("*", "GeometryInstance3D", true, false):
		var on_gun: bool = (g as GeometryInstance3D).layers & CrewView.VIEWMODEL_GUN_LAYER != 0
		var in_wv: bool = CrewView.viewmodel_layers_for(g as GeometryInstance3D, view.camera()) != CrewView.VIEWMODEL_LAYER
		assert_eq(on_gun, in_wv, "%s: gun layer only inside the WeaponVisual" % g.name)
		if in_wv:
			gun += 1
		else:
			arms += 1
	assert_true(gun > 0 and arms > 0, "gun meshes (%d) and arms meshes (%d)" % [gun, arms])


## D-094 / PO-4: the viewmodel camera also sees lights tagged VIEWMODEL_LIT_LAYER; a shot (real input) lights the
## muzzle on the world layer + that layer for FpViewmodelTweak.muzzle_light_s, then goes dark.
func test_muzzle_light_flashes_on_lit_layer() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var view: CrewView = CrewView.of(c)
	var vcam: Camera3D = view.find_child("ViewmodelCamera", true, false) as Camera3D
	assert_true(vcam != null and (vcam.cull_mask & CrewView.VIEWMODEL_LIT_LAYER) != 0, "vm camera sees lit lights")
	assert_eq(CrewView.VIEWMODEL_LIT_LAYER & CrewView.FIRST_PERSON_HIDDEN_LAYER, 0, "lit layer is not the own-body layer")
	_inp.press(&"fire")
	var seen: bool = false
	var layers_ok: bool = false
	for _i: int in 20:
		await wait_physics_frames(1)
		var l: OmniLight3D = c.find_child("MuzzleLight", true, false) as OmniLight3D
		if l != null and l.visible:
			seen = true
			layers_ok = (l.layers & CrewView.VIEWMODEL_LIT_LAYER) != 0 and (l.layers & 1) != 0
	_inp.release(&"fire")
	assert_true(seen, "a shot lights the muzzle")
	assert_true(layers_ok, "muzzle light on world + viewmodel_lit layers")
	await wait_seconds(FpViewmodelTweak.data().muzzle_light_s + 0.5)
	var l2: OmniLight3D = c.find_child("MuzzleLight", true, false) as OmniLight3D
	assert_true(l2 == null or not l2.visible, "dark again after the flash")
