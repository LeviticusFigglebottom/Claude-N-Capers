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
		assert_eq((g as GeometryInstance3D).layers, CrewView.VIEWMODEL_LAYER, "%s on the viewmodel layer" % g.name)
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
