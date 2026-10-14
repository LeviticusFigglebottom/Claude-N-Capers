## Lead failure pass: every way a heist can fail ends on the payday's failure screen (why + what was lost)
## and Continue goes back home with the failure counted once. Leave Heist from the pause menu is the solo
## abort; all-custody and the stealth-only alarm are setup through HeistRuntime.end_heist (A's rules decide
## when they happen in play).
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")

var _flow: MenuFlow = null


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	if _flow != null and is_instance_valid(_flow):
		_flow.call(&"_leave_heist")
		await wait_frames(3)
		_flow.queue_free()
	_flow = null
	await wait_frames(3)


func _launch() -> bool:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(1)
	_flow.show_hub()
	await wait_frames(1)
	assert_true(_flow.direct_launch(LaunchArgs.parse(PackedStringArray(["--heist=glasshouse", "--seed=7",
			"--difficulty=0"]))))
	assert_true(await wait_until(func() -> bool: return _flow.runtime != null, 60.0), "live")
	await wait_frames(10)
	return _flow.runtime != null


## The payday shows the failure for `reason`; Continue returns home and counts one failed heist.
func _check_failure(reason: StringName) -> void:
	var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
	assert_true(await wait_until(func() -> bool: return pd != null and pd.visible, 10.0), "payday shown for %s" % reason)
	if pd == null:
		return
	assert_false(bool(pd.payout.get("success", true)), "a failure")
	assert_eq((pd.value_labels[&"fail_reason"] as Label).text, UiText.t(PaydayScreen.fail_reason_key(reason)))
	assert_true(pd.value_labels.has(&"lost_total"), "what was lost")
	assert_false(pd.has_card_pick(), "no card pick on a failure")
	pd.continue_button.pressed.emit()
	assert_true(await wait_until(func() -> bool: return _flow.visible and _flow.runtime == null, 10.0), "home again")
	var p: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(int(p.stats.get("heists_failed", 0)), 1, "counted once")
	assert_eq(p.cash, PlayerProfile.new_default().cash - maxi(-int(pd.payout.get("spending", 0)), 0), "no pay")


func test_leave_heist_is_a_solo_abort() -> void:
	if not await _launch():
		return
	var pm: PauseMenu = _flow.options_menu.open_pause()
	assert_true(pm != null, "pause opens in the heist")
	pm.leave_requested.emit()
	await _check_failure(&"abort")


func test_all_custody() -> void:
	if not await _launch():
		return
	_flow.runtime.call(&"end_heist", false, [] as Array[int], &"all_custody")
	await _check_failure(&"all_custody")


func test_stealth_only_alarm() -> void:
	if not await _launch():
		return
	_flow.runtime.call(&"end_heist", false, [] as Array[int], &"stealth_only_alarm")
	await _check_failure(&"stealth_only_alarm")
