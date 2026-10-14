## Lead: Continue / Quick Play relaunches the last regular job (heist + difficulty) with the current loadout.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)


func test_last_job_round_trip_and_validation() -> void:
	assert_eq(QuickPlay.last(SaveService.load_profile(SLOT)), {}, "a new profile has no last job")
	QuickPlay.remember(SLOT, &"glasshouse", Enums.Difficulty.ROUTINE)
	var job: Dictionary = QuickPlay.last(SaveService.load_profile(SLOT))
	assert_eq(job, {"heist_id": &"glasshouse", "difficulty": Enums.Difficulty.ROUTINE})
	assert_true(QuickPlay.label(job).contains(UiText.t(&"heist.glasshouse.name")))
	QuickPlay.remember(SLOT, &"no_such_heist", 0)
	assert_eq(QuickPlay.last(SaveService.load_profile(SLOT)), {}, "a job no longer offered is not offered")


func test_menus_offer_continue_and_it_launches() -> void:
	var flow: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(flow)
	await wait_frames(1)
	flow.show_home()
	await wait_frames(1)
	assert_false(flow.main_menu.continue_button.visible, "nothing to continue yet")
	QuickPlay.remember(SLOT, &"glasshouse", Enums.Difficulty.ROUTINE)
	flow.main_menu.refresh_profile()
	assert_true(flow.main_menu.continue_button.visible)
	flow.hub.refresh_profile(SaveService.load_profile(SLOT))
	assert_true(flow.hub.continue_button.visible, "the hub offers it too")
	if UiNav.global_class(&"HeistLauncher") != null:
		flow.main_menu.continue_button.pressed.emit()
		assert_true(await wait_until(func() -> bool: return flow.runtime != null, 60.0), "Continue launched the heist")
		assert_eq(flow.get(&"_heist_id"), &"glasshouse")
		flow.call(&"_leave_heist")
		await wait_frames(3)
	flow.queue_free()
	await wait_frames(3)
