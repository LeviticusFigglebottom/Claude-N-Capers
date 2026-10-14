## Co-op windowed pass: a client whose host drops mid-heist (Net.host_lost; HeistNetSync leaves the
## result to the app flow) is taken out of the dead replica and lands on the lobby's connect view with
## the reason; leaving on purpose does not trip it.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const INFO: Dictionary = {"heist": &"glasshouse", "difficulty": 0, "is_pro": false}

var _flow: MenuFlow = null


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(1)
	_flow.show_hub()
	_flow.show_lobby()
	await wait_frames(1)


func after_each() -> void:
	if _flow != null and is_instance_valid(_flow):
		_flow.call(&"_leave_heist")
		_flow.queue_free()
	_flow = null
	await wait_frames(2)


func test_host_lost_mid_heist_returns_to_the_lobby_with_the_reason() -> void:
	_flow.call(&"_begin_client_heist", INFO)
	await wait_frames(1)
	assert_true(_flow.get(&"_in_heist") != null, "client heist UI up")
	assert_false(_flow.visible)
	Net.host_lost.emit()
	await wait_frames(2)
	assert_true(_flow.get(&"_in_heist") == null, "the dead replica's UI is gone")
	assert_true(_flow.visible and _flow.current == _flow.lobby_screen, "back on the lobby")
	assert_eq(_flow.lobby_screen.error_label.text, UiText.t(&"ui.dropin.failed.host_lost"), "says why")
	assert_false(Net.host_lost.is_connected(Callable(_flow, &"_on_client_host_lost")), "one-shot")


func test_leaving_on_purpose_is_not_a_host_loss() -> void:
	_flow.call(&"_begin_client_heist", INFO)
	await wait_frames(1)
	_flow.call(&"_leave_heist")
	await wait_frames(1)
	assert_false(Net.host_lost.is_connected(Callable(_flow, &"_on_client_host_lost")), "unhooked on leave")
	Net.host_lost.emit()
	await wait_frames(1)
	assert_eq(_flow.lobby_screen.error_label.text, "", "no host-lost message after our own leave")
