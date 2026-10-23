## PO report (2026-10-23): "I'm not able to move my cursor at all in Ostrander (so can't look around)".
## A heist launched from the 3D safehouse calls SafehouseHost.leave(heist_marker) (MenuFlow._spawn_in_heist_ui); it
## must not leave a MouseCapture release held, or the heist's PlayerInput never gets the mouse (D-087: CAPTURED only
## while no release is held) and mouse look is dead for the whole heist. Same for the range. Owner: ENV P (the
## capture contract); the host is ENV B's.
extends TestCase

const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const MOCK_SCENE: String = "res://tests/b/mock_safehouse/mock_safehouse.tscn"
const MOCK_CLASS: StringName = &"MockSafehouseMap"
const HUB_KEY: StringName = &"safehouse_hub"


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
	GameSettings.current().set_value(GameSettings.CONTROLS, HUB_KEY, "walk")
	MouseCapture.reset()


func before_each() -> void:
	MouseCapture.reset()
	SaveService.delete_profile(0)
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	GameSettings.current().set_value(GameSettings.CONTROLS, HUB_KEY, "walk")


func _flow() -> MenuFlow:
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	var t: SafehouseHubTweak = SafehouseHubTweak.load_default().duplicate() as SafehouseHubTweak
	t.scene_path = MOCK_SCENE
	t.map_class = MOCK_CLASS
	t.station_cam_blend_s = 0.0
	t.crew_class = &"NoSuchCrewClass"  # the mock walker stand-in (B's test_hub_3d pattern)
	f.safehouse.tweak = t
	return f


func _leave_for(marker_of: Callable) -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	f.main_menu.safehouse_button.pressed.emit()
	await wait_frames(2)
	assert_true(f.safehouse.is_active(), "in the 3D safehouse")
	assert_false(MouseCapture.is_released(&"station"), "walking: no station release")
	f.safehouse.leave(marker_of.call(f.safehouse.tweak))
	await wait_frames(2)
	assert_false(MouseCapture.is_released(&"station"), "after leave(): no station release left held")
	var owner: RefCounted = RefCounted.new()  # the heist's PlayerInput taking gameplay
	MouseCapture.set_gameplay_active(owner, true)
	assert_true(MouseCapture.wants_capture(), "the heist's gameplay owner gets the mouse (wants_capture)")
	MouseCapture.set_gameplay_active(owner, false)
	f.queue_free()
	await wait_frames(1)


func test_heist_launch_from_the_safehouse_releases_nothing() -> void:
	await _leave_for(func(t: SafehouseHubTweak) -> StringName: return t.heist_marker)


func test_range_from_the_safehouse_releases_nothing() -> void:
	await _leave_for(func(t: SafehouseHubTweak) -> StringName: return t.range_marker)
