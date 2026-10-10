## B2-01: the pre-planning screen instantiates, draws the (placeholder) blueprint, buying deducts
## favors and cash, votes resolve, and Confirm emits the hand-off and charges the profile.
extends TestCase

const SCENE: String = "res://content/ui/preplanning/preplanning_screen.tscn"


func _screen(cash: int, difficulty: int = Enums.Difficulty.BRUTAL) -> PreplanningScreen:
	var p: PlayerProfile = PlayerProfile.new()
	p.cash = cash
	var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
	s.save_on_confirm = false
	s.setup(&"glasshouse", difficulty, p)
	add_child(s)
	return s


func test_scene_instantiates_with_markers_and_placeholder() -> void:
	var s: PreplanningScreen = _screen(50000)
	await wait_frames(2)
	assert_true(s.get_child_count() > 0)
	assert_eq(s.heist_id, &"glasshouse")
	assert_eq(s.blueprint_view.markers.size(), s.board.active_point_ids().size())
	assert_true(s.blueprint_view.markers.size() >= 5, "markers drawn")
	assert_eq(s.placeholder_label.visible, s.board.blueprint.placeholder)
	assert_eq(s.selected_point, &"", "starts on crew assets")
	assert_eq(s.asset_buttons.size(), s.board.crew_assets().size())
	var first: Button = s.blueprint_view.markers[s.blueprint_view.marker_ids()[0]] as Button
	assert_true(first.has_focus(), "first marker focused for keyboard/gamepad")
	var r: Rect2 = Rect2(Vector2.ZERO, s.blueprint_view.size)
	for pid: Variant in s.blueprint_view.markers:
		var b: Button = s.blueprint_view.markers[pid] as Button
		assert_true(r.has_point(b.position + b.size * 0.5), "marker %s inside the blueprint" % pid)
	s.queue_free()
	await wait_frames(1)


func test_buying_deducts_budget() -> void:
	var s: PreplanningScreen = _screen(50000)
	await wait_frames(1)
	var marker: Button = s.blueprint_view.markers[&"pp_alley_dumpsters"] as Button
	marker.pressed.emit()
	assert_eq(s.selected_point, &"pp_alley_dumpsters")
	assert_true(s.asset_buttons[0].has_focus(), "pressing a marker focuses its asset list")
	var cost: int = s.board.cost_of(&"asset.ammo_bag_drop")
	assert_eq(s.buy(&"asset.ammo_bag_drop"), PreplanPlan.OK)
	assert_eq(s.cash_left(), 50000 - cost)
	assert_eq(s.plan.favors_used(), 2)
	assert_true(s.favors_label.text.contains("2 / 10"), s.favors_label.text)
	assert_true(s.cash_label.text.contains(UiText.group_digits(50000 - cost)), s.cash_label.text)
	assert_true(s.is_selected(&"asset.ammo_bag_drop"))
	assert_eq(s.buy(&"asset.doctor_bag_drop"), PreplanPlan.R_POINT_TAKEN)
	assert_ne(s.reason_label.text, "", "reason shown")
	var i: int = s.asset_button_ids.find(&"asset.ammo_bag_drop")
	s.asset_buttons[i].pressed.emit()
	assert_eq(s.plan.favors_used(), 0, "pressing a bought asset refunds it")
	assert_eq(s.cash_left(), 50000)
	s.queue_free()
	await wait_frames(1)


func test_cash_limit_and_vote() -> void:
	var s: PreplanningScreen = _screen(0, Enums.Difficulty.ROUTINE)
	await wait_frames(1)
	s.show_crew_assets()
	assert_eq(s.buy(&"asset.extra_cable_ties"), PreplanPlan.R_CASH, "no spending cash")
	s.profile.cash = 100000
	s.show_point(&"pp_escape_side_street")
	var sent: Array[StringName] = []
	var listen: Callable = func(_peer: int, kind: StringName, _data: Dictionary) -> void: sent.append(kind)
	Net.lobby_message.connect(listen)
	assert_eq(s.buy(&"asset.escape_position"), PreplanPlan.OK)
	Net.lobby_message.disconnect(listen)
	assert_eq(sent, [PlanVote.MSG_CAST] as Array[StringName], "the vote went through Net.lobby_send (solo: local)")
	assert_true(s.is_selected(&"asset.escape_position"))
	assert_eq(s.plan.cash_cost(s.local_slot), s.board.cost_of(&"asset.escape_position"), "solo: the one human pays the plan")
	assert_true(s.vote_label.text.contains(UiText.t(&"ui.preplan.point.pp_escape_side_street")), s.vote_label.text)
	s.show_point(&"pp_escape_alley_west")
	assert_eq(s.buy(&"asset.escape_position"), PreplanPlan.OK, "re-vote moves the plan")
	assert_eq(s.plan.count_of(&"asset.escape_position"), 1)
	assert_eq(s.plan.index_at(&"pp_escape_side_street"), -1)
	s.remove(&"asset.escape_position")
	assert_eq(s.plan.count_of(&"asset.escape_position"), 0, "retract went through Net too")
	s.queue_free()
	await wait_frames(1)


func test_confirm_emits_handoff_and_charges() -> void:
	var s: PreplanningScreen = _screen(50000)
	await wait_frames(1)
	s.show_crew_assets()
	assert_eq(s.buy(&"asset.spare_body_bags"), PreplanPlan.OK)
	var cost: int = s.board.cost_of(&"asset.spare_body_bags")
	var got: Array[Dictionary] = []
	s.confirmed.connect(func(plan: Dictionary) -> void: got.append(plan))
	s.confirm_button.pressed.emit()
	assert_eq(got.size(), 1)
	assert_has(got[0]["modifier_sources"], &"asset.spare_body_bags")
	assert_eq(int((got[0]["plan"] as Dictionary)["difficulty"]), Enums.Difficulty.BRUTAL)
	assert_eq((got[0].keys() as Array).size(), PreplanPlan.RESULT_KEYS.size(), "exactly the PreplanResult v1 keys")
	assert_eq(int((got[0]["cash_spent"] as Dictionary)[s.local_slot]), cost)
	assert_eq(s.profile.cash, 50000 - cost, "spending cash paid on confirm")
	var backs: Array[int] = [0]
	s.back_requested.connect(func() -> void: backs[0] += 1)
	s.back_button.pressed.emit()
	assert_eq(backs[0], 1)
	s.queue_free()
	await wait_frames(1)


func test_setup_after_ready_rebuilds() -> void:
	var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
	s.save_on_confirm = false
	var p: PlayerProfile = PlayerProfile.new()
	p.cash = 1234
	s.setup(&"", Enums.Difficulty.ROUTINE, p)
	add_child(s)
	await wait_frames(1)
	s.setup(&"glasshouse", Enums.Difficulty.LETHAL, p)
	await wait_frames(1)
	assert_eq(s.board.difficulty, Enums.Difficulty.LETHAL)
	assert_eq(s.blueprint_view.markers.size(), s.board.active_point_ids().size())
	assert_true(s.cash_label.text.contains("1,234"), s.cash_label.text)
	s.queue_free()
	await wait_frames(1)
