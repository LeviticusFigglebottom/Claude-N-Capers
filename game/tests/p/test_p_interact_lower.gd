## PO pass (PD2 PlayerStandard:_start_action_interact -> _play_unequip_animation): a timed interaction by this crew
## holsters the first-person weapon and holds it out of view; completing or cancelling it draws the weapon again.
## Instant interactions (ended within interact_lower_delay_s) never holster; other crews' interactions are ignored.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4404, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _vm() -> FpViewmodel:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_seconds(1.5)
	return FpViewmodel.of(CrewView.of(c).camera())


func test_timed_interaction_holsters_then_draws() -> void:
	var vm: FpViewmodel = await _vm()
	assert_true(vm != null and vm.anim_set != &"", "a weapon in the hands")
	if vm == null:
		return
	EventBus.interaction_started.emit(77, 0, &"lockpick")
	await wait_seconds(1.0)
	assert_eq(vm.action, FpViewmodel.Action.INTERACT, "lowered while interacting")
	assert_true(String(vm.clip).ends_with("holster"), "the holster clip (%s)" % vm.clip)
	await wait_seconds(1.0)
	assert_eq(vm.action, FpViewmodel.Action.INTERACT, "held out of view, not back to idle")
	EventBus.interaction_completed.emit(77, 0, &"lockpick")
	await wait_frames(2)
	assert_eq(vm.action, FpViewmodel.Action.SWAP, "drawn again on completion")
	assert_true(String(vm.clip).ends_with("draw"), "the draw clip (%s)" % vm.clip)
	await wait_seconds(2.0)
	assert_eq(vm.action, FpViewmodel.Action.NONE, "back to the hold")


func test_cancel_draws_and_instant_never_holsters() -> void:
	var vm: FpViewmodel = await _vm()
	if vm == null:
		return
	EventBus.interaction_started.emit(78, 0, &"bag")
	await wait_frames(2)
	EventBus.interaction_completed.emit(78, 0, &"bag")
	await wait_seconds(0.5)
	assert_ne(vm.action, FpViewmodel.Action.INTERACT, "an instant interaction never holsters")
	await wait_seconds(1.5)
	EventBus.interaction_started.emit(79, 0, &"lockpick")
	await wait_seconds(0.8)
	assert_eq(vm.action, FpViewmodel.Action.INTERACT)
	EventBus.interaction_cancelled.emit(79, 0)
	await wait_frames(2)
	assert_eq(vm.action, FpViewmodel.Action.SWAP, "a cancelled interaction draws the weapon too")
	await wait_seconds(2.0)
	EventBus.interaction_started.emit(80, 2, &"lockpick")  # another crew's
	await wait_seconds(0.8)
	assert_ne(vm.action, FpViewmodel.Action.INTERACT, "another crew's interaction is not ours")
