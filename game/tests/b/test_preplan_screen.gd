## B2-01: the pre-planning screen instantiates, draws the (placeholder) blueprint, buying deducts
## favors and cash, votes resolve, and Confirm emits the hand-off and charges the profile.
extends TestCase

const SCENE: String = "res://content/ui/preplanning/preplanning_screen.tscn"
const STAGED_FIXTURE: GDScript = preload("res://tests/b/staged_heist_fixture.gd")


func _screen(cash: int, difficulty: int = Enums.Difficulty.BRUTAL) -> PreplanningScreen:
	var p: PlayerProfile = PlayerProfile.new()
	p.cash = cash
	var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
	s.save_on_confirm = false
	s.setup(&"glasshouse", difficulty, p)
	add_child(s)
	return s


func _expected_favors(heist_id: StringName) -> int:
	var def: HeistDef = HeistRegistry.get_def(heist_id)
	var pre: Dictionary = def.preplanning if def != null else {}
	if pre.has("favors") and not PreplanBoard.is_legacy_format(pre):
		return int(pre["favors"])
	return PreplanTweak.load_default().default_favors


func test_scene_instantiates_with_markers_and_placeholder() -> void:
	var s: PreplanningScreen = _screen(50000)
	await wait_frames(2)
	assert_true(s.get_child_count() > 0)
	assert_eq(s.heist_id, &"glasshouse")
	assert_eq(s.blueprint_view.markers.size(), _points_on_floor(s, s.blueprint_view.floor_index))
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
	# D-046 QC-23: the budget is the HeistDef's preplanning.favors (else the tweak default), never 10.
	var budget: int = _expected_favors(&"glasshouse")
	assert_eq(s.board.favors_budget, budget)
	assert_true(s.favors_label.text.contains("2 / %d" % budget), s.favors_label.text)
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
	assert_eq(s.blueprint_view.markers.size(), _points_on_floor(s, s.blueprint_view.floor_index))
	assert_true(s.cash_label.text.contains("1,234"), s.cash_label.text)
	s.queue_free()
	await wait_frames(1)


## LEAD: the blueprint draws one floor at a time (Glasshouse has an upstairs insider point).
func _points_on_floor(s: PreplanningScreen, floor_index: int) -> int:
	var n: int = 0
	for pid: StringName in s.board.active_point_ids():
		if int(s.board.blueprint.point(pid).get("floor", 0)) == floor_index:
			n += 1
	return n


## GN-B1 capture: two points a couple of meters apart drew one marker over the other.
func test_close_points_do_not_stack_markers() -> void:
	var s: PreplanningScreen = _screen(50000)
	await wait_frames(2)
	var v: BlueprintView = s.blueprint_view
	var bp: PreplanBlueprint = s.board.blueprint.duplicate(true) as PreplanBlueprint
	s.board.blueprint = bp
	var ids: Array[StringName] = v.marker_ids()
	assert_true(ids.size() >= 3)
	var at: Vector2 = bp.point(ids[0]).get("pos", Vector2.ZERO) as Vector2
	bp.point(ids[1])["pos"] = at  # the same spot
	bp.point(ids[2])["pos"] = at + Vector2(0.5, 0.0)  # half a meter off
	v.set_floor(v.floor_index)
	await wait_frames(2)
	var r: Rect2 = Rect2(Vector2.ZERO, v.size)
	for i: int in range(3):
		var a: Button = v.markers[ids[i]] as Button
		assert_true(r.encloses(a.get_rect()), "marker %d inside the view" % i)
		for j: int in range(i):
			var b: Button = v.markers[ids[j]] as Button
			assert_false(a.get_rect().intersects(b.get_rect()), "markers %d and %d overlap" % [j, i])
	s.queue_free()
	await wait_frames(1)


func test_every_heist_fits_the_screen() -> void:
	# r229 menu walk: the floor-tab row (crew tab, divider, MAP caption, one tab per floor, hint) made a 4-floor heist's
	# screen wider than the 1920 canvas, so Confirm sat off screen. Every heist's screen fits the viewport.
	var vis: Rect2 = get_viewport().get_visible_rect()
	for id: StringName in HeistCatalog.ids():
		var p: PlayerProfile = PlayerProfile.new()
		p.cash = 50000
		var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
		s.save_on_confirm = false
		s.setup(id, Enums.Difficulty.ROUTINE, p)
		add_child(s)
		await wait_frames(3)
		for c: Control in [s.confirm_button, s.crew_button, s.blueprint_view] as Array[Control]:
			assert_true(vis.encloses(c.get_global_rect()), "%s: %s on screen (%s in %s)" % [id, c.name,
					c.get_global_rect(), vis])
		for fb: Button in s.floor_buttons:
			assert_true(vis.encloses(fb.get_global_rect()), "%s: floor tab %s on screen" % [id, fb.text])
		s.queue_free()
		await wait_frames(1)


func test_opens_on_the_entry_floor() -> void:
	# RT-B1 capture: the board opened on floor 0 (OF's basement, RT's underpass); it opens where the crew starts, with
	# that floor's tab pressed, as the briefing's blueprint does.
	var multi: int = 0
	for id: StringName in HeistCatalog.ids():
		var p: PlayerProfile = PlayerProfile.new()
		var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
		s.save_on_confirm = false
		s.setup(id, Enums.Difficulty.ROUTINE, p)
		add_child(s)
		await wait_frames(2)
		var entry: int = s.board.blueprint.entry_floor()
		assert_eq(s.blueprint_view.floor_index, entry, "%s opens on its entry floor" % id)
		for i: int in range(s.floor_buttons.size()):
			assert_eq(s.floor_buttons[i].button_pressed, i == entry, "%s floor tab %d pressed only at the entry" % [id, i])
		if s.floor_buttons.size() > 1 and entry > 0:
			multi += 1
		s.queue_free()
		await wait_frames(1)
	assert_true(multi > 0, "some heist starts above floor 0 (OF: the ground floor over the basement)")


func test_arrow_keys_never_trap_focus() -> void:
	# RT walk (r276): on RT's underpass floor (markers all low on the map) the markers, the asset list and the bottom
	# row formed a closed arrow-key loop; a keyboard / pad player could not get back to the tabs. For every heist
	# (RT through the staged fixture) and every list shown, each focusable control leads back to the crew tab.
	var fx: RefCounted = STAGED_FIXTURE.new()
	fx.call(&"stage")
	var states: int = 0
	for id: StringName in HeistCatalog.ids():
		var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
		s.save_on_confirm = false
		s.setup(id, Enums.Difficulty.ROUTINE, PlayerProfile.new())
		add_child(s)
		await wait_frames(3)
		s.show_crew_assets()
		await wait_frames(2)
		_assert_no_focus_trap(s, "%s crew" % id)
		states += 1
		for f: int in range(maxi(s.floor_buttons.size(), 1)):
			if f < s.floor_buttons.size():
				s.floor_buttons[f].pressed.emit()
			for pid: StringName in s.blueprint_view.marker_ids():
				s.show_point(pid)
				await wait_frames(2)
				_assert_no_focus_trap(s, "%s floor %d %s" % [id, f, pid])
				states += 1
		s.queue_free()
		await wait_frames(1)
	fx.call(&"unstage")
	assert_true(states > 20, "walked %d lists" % states)


func _assert_no_focus_trap(s: PreplanningScreen, where: String) -> void:
	var all: Array[Control] = []
	for n: Node in s.find_children("*", "Control", true, false):
		if (n as Control).focus_mode == Control.FOCUS_ALL and (n as Control).is_visible_in_tree():
			all.append(n as Control)
	var back: Dictionary = {s.crew_button: true}  # controls that reach the crew tab, grown to a fixed point
	var grew: bool = true
	while grew:
		grew = false
		for c: Control in all:
			if back.has(c):
				continue
			for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				if back.has(c.find_valid_focus_neighbor(side)):
					back[c] = true
					grew = true
					break
	for c: Control in all:
		assert_true(back.has(c), "%s: focus on %s cannot get back to the crew tab by arrow keys" % [where, c.name])


func test_list_left_neighbour_survives_a_floor_switch() -> void:
	# RT walk: with a point's assets listed, switching floors freed the markers, and the list's Left neighbour kept a
	# path to the freed marker ("Neighbor focus node path is invalid"; Left did nothing). It now aims at a live control.
	var fx: RefCounted = STAGED_FIXTURE.new()
	fx.call(&"stage")
	var checked: int = 0
	for id: StringName in HeistCatalog.ids():
		var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
		s.save_on_confirm = false
		s.setup(id, Enums.Difficulty.ROUTINE, PlayerProfile.new())
		add_child(s)
		await wait_frames(3)
		if s.floor_buttons.size() < 2 or s.blueprint_view.marker_ids().is_empty():
			s.queue_free()
			continue
		s.show_point(s.blueprint_view.marker_ids()[0])
		var other: int = (s.blueprint_view.floor_index + 1) % s.floor_buttons.size()
		s.floor_buttons[other].pressed.emit()
		await wait_frames(3)
		for b: Button in s.asset_buttons:
			var nb: NodePath = b.get_focus_neighbor(SIDE_LEFT)
			var target: Node = b.get_node_or_null(nb) if not nb.is_empty() else null
			assert_true(target != null and is_instance_valid(target) and not target.is_queued_for_deletion(),
					"%s: Left from '%s' after a floor switch points at a live control (%s)" % [id, b.text, nb])
		checked += 1
		s.queue_free()
		await wait_frames(1)
	fx.call(&"unstage")
	assert_true(checked >= 3, "multi-floor heists checked: %d" % checked)
