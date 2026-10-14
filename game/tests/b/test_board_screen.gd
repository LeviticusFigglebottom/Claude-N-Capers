## B4-06: the Board screen instantiates with one pin per contract on the map, Take emits
## contract_chosen with the selected contract, and the broker charges the stash or refuses.
extends TestCase

const SCENE: String = "res://content/ui/board/board_screen.tscn"
const T0: float = 600.0 * 3000.0 + 1.0

var _time: Dictionary = {"now": T0}
var _chosen: Array = []


func before_each() -> void:
	_time["now"] = T0
	_chosen = []


func _screen(stash: int, level: int = 10) -> BoardScreen:
	var p: PlayerProfile = PlayerProfile.new()
	p.stash = stash
	p.level = level
	var s: BoardScreen = (load(SCENE) as PackedScene).instantiate() as BoardScreen
	s.save_on_buy = false
	s.clock = func() -> float: return float(_time["now"])
	s.build_gate = func(_d: int) -> bool: return true
	s.setup(p)
	s.contract_chosen.connect(func(h: StringName, d: int, pro: bool) -> void: _chosen.append([h, d, pro]))
	add_child(s)
	return s


func test_screen_instantiates_with_pins() -> void:
	var s: BoardScreen = _screen(0)
	await wait_frames(3)
	assert_eq(s.contracts.size(), s.tweak.slot_count)
	assert_eq(s.map_view.pins.size(), s.contracts.size())
	assert_eq(s.selected_slot, 0)
	assert_true(s.map_view.pins[0].has_focus(), "first pin focused for keyboard/gamepad")
	var r: Rect2 = s.map_view.map_rect()
	assert_true(r.size.x > 100.0, "map laid out: %s" % r)
	for pin: BoardPin in s.map_view.pins:
		assert_true(r.has_point(pin.position + pin.disc_center()), "pin inside the map")
	var c: Array[Vector2] = s.map_view.pin_centers
	for i: int in range(c.size()):
		for j: int in range(i + 1, c.size()):
			assert_true(c[i].distance_to(c[j]) >= s.map_view.pins[0].size.x * 0.95, "pins %d/%d do not overlap" % [i, j])
	assert_true(s.heist_label.text != "" and s.payout_label.text.contains("$"), s.payout_label.text)
	assert_true(s.time_label.text != "")
	assert_eq(s.pro_label.visible, bool(s.selected_contract()["is_pro"]))
	s.queue_free()
	await wait_frames(1)


func test_pin_focus_selects_and_take_emits() -> void:
	var s: BoardScreen = _screen(0)
	await wait_frames(2)
	s.map_view.pins[3].grab_focus()
	await wait_frames(1)
	assert_eq(s.selected_slot, 3, "focusing a pin selects it")
	var c: Dictionary = s.contracts[3]
	s.map_view.pins[3].pressed.emit()
	assert_true(s.take_button.has_focus(), "pressing a pin jumps to Take")
	s.take_button.pressed.emit()
	assert_eq(_chosen.size(), 1)
	assert_eq(_chosen[0], [StringName(c["heist_id"]), int(c["difficulty"]), bool(c["is_pro"])])
	# An expired contract is not taken; the board refreshes instead.
	_time["now"] = float(c["expires_at"]) + 1.0
	assert_false(s.take_selected())
	assert_eq(_chosen.size(), 1)
	assert_true(float(s.selected_contract()["expires_at"]) > float(_time["now"]), "refreshed")
	s.queue_free()
	await wait_frames(1)


func test_broker_charges_stash_and_emits() -> void:
	var s: BoardScreen = _screen(1000000, 10)
	await wait_frames(1)
	s.broker_select(&"glasshouse", Enums.Difficulty.HAZARDOUS)
	var cost: int = s.broker_cost()
	assert_true(cost > 0)
	assert_false(s.buy_button.disabled)
	assert_true(s.broker_cost_label.text.contains(UiText.group_digits(cost)), s.broker_cost_label.text)
	assert_eq(s.broker_buy(), BoardBroker.OK)
	assert_eq(s.profile.stash, 1000000 - cost)
	assert_eq(_chosen, [[&"glasshouse", Enums.Difficulty.HAZARDOUS, false]])
	s.profile.stash = cost - 1
	s.broker_select(&"glasshouse", Enums.Difficulty.HAZARDOUS)
	assert_true(s.buy_button.disabled, "not enough stash")
	assert_eq(s.broker_reason_label.text, UiText.t(&"ui.board.broker.reason.stash"))
	assert_eq(s.broker_buy(), BoardBroker.R_STASH)
	assert_eq(s.profile.stash, cost - 1)
	assert_eq(_chosen.size(), 1)
	var lethal: int = s.broker_difficulty.get_item_index(Enums.Difficulty.LETHAL)
	assert_true(s.broker_difficulty.is_item_disabled(lethal), "Lethal needs level 80")
	s.queue_free()
	await wait_frames(1)


func test_map_spread_keeps_distance() -> void:
	var pts: Array[Vector2] = [Vector2(100, 100), Vector2(100, 100), Vector2(101, 100), Vector2(99, 102)]
	var out: Array[Vector2] = BoardMapView.spread(pts, 50.0, Rect2(0, 0, 1000, 1000))
	assert_eq(out, BoardMapView.spread(pts, 50.0, Rect2(0, 0, 1000, 1000)), "deterministic")
	for i: int in range(out.size()):
		for j: int in range(i + 1, out.size()):
			assert_true(out[i].distance_to(out[j]) >= 49.0, "%s %s" % [out[i], out[j]])


## AU-5 (lane 2 audit): district names keep their centre when clear, else step off the pins.
func test_district_label_box_steps_off_pins() -> void:
	var size: Vector2 = Vector2(100, 20)
	var clear: Rect2 = BoardMapView.label_box(Vector2(200, 200), size, [] as Array[Rect2])
	assert_eq(clear.get_center(), Vector2(200, 200), "no pin: centred")
	var pin: Rect2 = Rect2(180, 185, 50, 50)
	var moved: Rect2 = BoardMapView.label_box(Vector2(200, 200), size, [pin] as Array[Rect2])
	assert_false(moved.intersects(pin), "off the pin: %s" % moved)
	assert_eq(moved.position.x, clear.position.x, "only moves up or down")


func test_board_district_names_clear_of_pins() -> void:
	var s: BoardScreen = _screen(0)
	await wait_frames(3)
	var labels: Dictionary = s.map_view.label_rects
	assert_true(labels.size() >= 5, "district names drawn")
	for id: Variant in labels:
		for pin: BoardPin in s.map_view.pins:
			if pin.visible:
				assert_false((labels[id] as Rect2).intersects(pin.get_rect()), "%s under a pin" % id)
	s.queue_free()
	await wait_frames(1)
