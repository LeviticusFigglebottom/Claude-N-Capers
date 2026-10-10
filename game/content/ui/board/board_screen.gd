## The Board (pd2_fidelity C1, roadmap B4-06). Owner: ENV B. A stylised city map in the safehouse
## with rotating contracts from the contacts (BoardContracts), a contract card for the selected pin,
## and the contract broker (BoardBroker). Design: res://content/docs/board.md.
##
## API (MenuFlow wires it): setup(profile) before or after the screen enters the tree (null = load
## profile_slot). Signals: contract_chosen(heist_id, difficulty, is_pro) (Take on a pin, or a broker
## purchase after the stash was charged and, with save_on_buy, saved); back_requested() (UiScreen;
## Esc / gamepad B). `clock` (Callable() -> float Unix seconds) replaces the system clock in tests.
##
## Navigation: pins move spatially (BoardMapView); right from the map's edge reaches Take; left from
## the side panel returns to the selected pin. Focusing a pin selects it; pressing it jumps to Take.
class_name BoardScreen
extends UiScreen

signal contract_chosen(heist_id: StringName, difficulty: int, is_pro: bool)

const TICK_S: float = 0.5

@export var profile_slot: int = 0
@export var save_on_buy: bool = true

var profile: PlayerProfile = null
var tweak: BoardTweak = null
var city: BoardCityMap = null
var heist_pool: Array[Dictionary] = []
var contracts: Array[Dictionary] = []
var selected_slot: int = -1
## Optional time source (tests): Callable() -> float Unix seconds.
var clock: Callable = Callable()
## Build-wide difficulty gate (Callable(int) -> bool); tests may replace it.
var build_gate: Callable = BoardContracts.build_gate()

var map_view: BoardMapView
var status_label: Label
var empty_label: Label
var card: VBoxContainer
var portrait: ContactPortrait
var contact_label: Label
var role_label: Label
var heist_label: Label
var subtitle_label: Label
var difficulty_label: Label
var payout_label: Label
var pro_label: Label
var pro_desc_label: Label
var time_label: Label
var take_button: Button
var broker_heist: OptionButton
var broker_difficulty: OptionButton
var broker_cost_label: Label
var broker_reason_label: Label
var buy_button: Button
var back_button: Button

var _timer: Timer


func setup(new_profile: PlayerProfile) -> void:
	profile = new_profile
	if is_node_ready():
		refresh_board()
		_refresh_broker()


func build_ui() -> void:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	tweak = BoardTweak.load_default()
	city = BoardCityMap.load_default()
	heist_pool = BoardContracts.pool(city)
	_timer = Timer.new()
	_timer.wait_time = TICK_S
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_timer.start()
	var root: VBoxContainer = UiBuild.vbox(14)
	UiBuild.screen_margin(self, root, 40)
	_build_header(root)
	var body: HBoxContainer = UiBuild.hbox(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	map_view = BoardMapView.new()
	map_view.city = city
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.custom_minimum_size = Vector2(640, 400)
	map_view.pin_focused.connect(select_slot)
	map_view.pin_pressed.connect(_on_pin_pressed)
	body.add_child(map_view)
	var side: VBoxContainer = UiBuild.vbox(14)
	side.custom_minimum_size = Vector2(560, 0)
	body.add_child(side)
	_build_card(side)
	_build_broker(side)
	var footer: HBoxContainer = UiBuild.hbox(16)
	root.add_child(footer)
	_build_legend(footer)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	footer.add_child(back_button)
	map_view.exit_right = take_button
	focus_chain.append(take_button)
	focus_chain.append(broker_heist)
	focus_chain.append(broker_difficulty)
	focus_chain.append(buy_button)
	focus_chain.append(back_button)
	refresh_board()
	_refresh_broker()


func _build_header(root: VBoxContainer) -> void:
	var header: HBoxContainer = UiBuild.hbox(24)
	root.add_child(header)
	var left: VBoxContainer = UiBuild.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(left)
	left.add_child(UiBuild.label(&"ui.board.title", UiBuild.HEADER))
	left.add_child(UiBuild.label(&"ui.board.subtitle", UiBuild.DIM, {"minutes": roundi(tweak.rotation_s / 60.0)}))
	status_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(status_label)


func _build_legend(parent: HBoxContainer) -> void:
	var row: HBoxContainer = UiBuild.hbox(22)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	for c: ContactDef in ContactDef.all():
		if c.is_handler:
			continue
		var item: HBoxContainer = UiBuild.hbox(8)
		var dot: ColorRect = ColorRect.new()
		dot.color = c.accent_color
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(dot)
		item.add_child(UiBuild.label(c.display_name_key, UiBuild.DIM))
		row.add_child(item)
	var pro: Label = UiBuild.label(&"ui.board.legend_pro", UiBuild.DIM)
	pro.add_theme_color_override(&"font_color", city.pro_color.lightened(0.35))
	row.add_child(pro)


func _build_card(side: VBoxContainer) -> void:
	card = UiBuild.vbox(6)
	var panel: PanelContainer = UiBuild.panel(card)
	side.add_child(panel)
	var top: HBoxContainer = UiBuild.hbox(16)
	card.add_child(top)
	portrait = ContactPortrait.new()
	portrait.custom_minimum_size = Vector2(128, 128)
	top.add_child(portrait)
	var who: VBoxContainer = UiBuild.vbox(2)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	heist_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	subtitle_label = UiBuild.label(&"", UiBuild.DIM)
	var contact_row: HBoxContainer = UiBuild.hbox(10)
	contact_label = UiBuild.label()
	role_label = UiBuild.label(&"", UiBuild.DIM)
	role_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contact_row.add_child(contact_label)
	contact_row.add_child(role_label)
	pro_label = UiBuild.label(&"ui.board.pro")
	pro_label.add_theme_color_override(&"font_color", city.pro_color.lightened(0.45))
	for l: Control in [heist_label, subtitle_label, contact_row, pro_label]:
		if l is Label:
			(l as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.add_child(l)
	var row: HBoxContainer = UiBuild.hbox(12)
	card.add_child(row)
	difficulty_label = UiBuild.label()
	difficulty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label = UiBuild.label(&"", UiBuild.DIM)
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(difficulty_label)
	row.add_child(time_label)
	payout_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	pro_desc_label = UiBuild.label(&"", UiBuild.DIM)
	pro_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label = UiBuild.label(&"ui.board.empty", UiBuild.DIM)
	for l: Label in [payout_label, pro_desc_label, empty_label]:
		card.add_child(l)
	take_button = UiBuild.button(&"ui.board.take")
	take_button.pressed.connect(take_selected)
	card.add_child(take_button)


func _build_broker(side: VBoxContainer) -> void:
	var box: VBoxContainer = UiBuild.vbox(6)
	side.add_child(UiBuild.panel(box))
	box.add_child(UiBuild.label(&"ui.board.broker.title", UiBuild.SUBHEADER))
	var desc: Label = UiBuild.label(&"ui.board.broker.desc", UiBuild.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	broker_heist = UiBuild.option_button()
	for h: Dictionary in heist_pool:
		broker_heist.add_item(UiText.t(StringName("heist.%s.name" % h["id"])))
	broker_heist.item_selected.connect(func(_i: int) -> void: _refresh_broker())
	broker_difficulty = UiBuild.option_button()
	for d: int in range(Enums.Difficulty.size()):
		broker_difficulty.add_item(UiText.t(UiText.difficulty_key(d)), d)
	broker_difficulty.item_selected.connect(func(_i: int) -> void: _refresh_broker())
	for pair: Array in [[&"ui.board.broker.heist", broker_heist], [&"ui.board.broker.difficulty", broker_difficulty]]:
		var row: HBoxContainer = UiBuild.hbox(12)
		var l: Label = UiBuild.label(StringName(pair[0]), UiBuild.DIM)
		l.custom_minimum_size = Vector2(150, 0)
		row.add_child(l)
		(pair[1] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pair[1] as Control)
		box.add_child(row)
	broker_cost_label = UiBuild.label()
	broker_reason_label = UiBuild.label(&"", UiBuild.DIM)
	broker_reason_label.add_theme_color_override(&"font_color", city.pro_color.lightened(0.45))
	box.add_child(broker_cost_label)
	box.add_child(broker_reason_label)
	buy_button = UiBuild.button(&"ui.board.broker.buy")
	buy_button.pressed.connect(broker_buy)
	box.add_child(buy_button)


## Unix seconds from `clock`, else the system clock.
func now() -> float:
	return float(clock.call()) if clock.is_valid() else Time.get_unix_time_from_system()


## Regenerate every slot's contract for the current time, keeping the selected slot.
func refresh_board() -> void:
	contracts = BoardContracts.generate(now(), _level(), heist_pool, tweak, city, build_gate)
	if map_view == null:
		return
	map_view.set_contracts(contracts)
	map_view.update_times(now())
	if selected_slot < 0 or selected_slot >= contracts.size():
		selected_slot = 0 if not contracts.is_empty() else -1
	select_slot(selected_slot)
	_refresh_status()


func focus_default() -> void:
	if not is_visible_in_tree():
		return
	if selected_slot >= 0 and selected_slot < map_view.pins.size():
		map_view.pins[selected_slot].grab_focus.call_deferred()
	else:
		UiNav.focus_first(focus_chain)


## Select slot `slot` (the card shows its contract). -1 clears the card.
func select_slot(slot: int) -> void:
	selected_slot = slot if slot >= 0 and slot < contracts.size() else -1
	map_view.set_selected(selected_slot)
	var c: Dictionary = selected_contract()
	var has: bool = not c.is_empty()
	for n: Control in [portrait, heist_label, subtitle_label, contact_label, role_label, difficulty_label,
			payout_label, time_label, take_button]:
		n.visible = has
	empty_label.visible = not has
	pro_label.visible = has and bool(c["is_pro"])
	pro_desc_label.visible = pro_label.visible
	if has:
		_fill_card(c)
		var pin_path: NodePath = take_button.get_path_to(map_view.pins[selected_slot])
		for n: Control in [take_button, broker_heist, broker_difficulty, buy_button, back_button]:
			n.focus_neighbor_left = pin_path


func selected_contract() -> Dictionary:
	return contracts[selected_slot] if selected_slot >= 0 and selected_slot < contracts.size() else {}


## Take the selected contract: emits contract_chosen unless it expired meanwhile (then the board
## refreshes and nothing is emitted). Returns whether it emitted.
func take_selected() -> bool:
	var c: Dictionary = selected_contract()
	if c.is_empty():
		return false
	if BoardContracts.time_left(c, now()) <= 0.0:
		refresh_board()
		return false
	contract_chosen.emit(StringName(c["heist_id"]), int(c["difficulty"]), bool(c["is_pro"]))
	return true


func broker_selection() -> Dictionary:
	var i: int = broker_heist.selected
	var heist_id: StringName = StringName(heist_pool[i]["id"]) if i >= 0 and i < heist_pool.size() else &""
	var d: int = broker_difficulty.get_item_id(broker_difficulty.selected) if broker_difficulty.selected >= 0 else 0
	return {"heist_id": heist_id, "difficulty": d}


## Select a broker heist and difficulty (UI or tests).
func broker_select(heist_id: StringName, difficulty: int) -> void:
	for i: int in range(heist_pool.size()):
		if StringName(heist_pool[i]["id"]) == heist_id:
			broker_heist.select(i)
	broker_difficulty.select(broker_difficulty.get_item_index(difficulty))
	_refresh_broker()


func broker_cost() -> int:
	var sel: Dictionary = broker_selection()
	var h: Dictionary = BoardBroker.find_heist(heist_pool, StringName(sel["heist_id"]))
	return BoardBroker.cost(int(h.get("base_payout", 0)), int(sel["difficulty"]), tweak) if not h.is_empty() else 0


## Buy the broker selection: charges the stash, saves (save_on_buy), emits contract_chosen (never
## pro). Returns BoardBroker.OK or the refusal reason (nothing charged).
func broker_buy() -> StringName:
	var sel: Dictionary = broker_selection()
	var reason: StringName = BoardBroker.buy(profile, StringName(sel["heist_id"]), int(sel["difficulty"]), heist_pool,
			tweak, build_gate)
	if reason != BoardBroker.OK:
		_refresh_broker()
		return reason
	if save_on_buy:
		SaveService.save_profile(profile, profile_slot)
	_refresh_status()
	_refresh_broker()
	contract_chosen.emit(StringName(sel["heist_id"]), int(sel["difficulty"]), false)
	return reason


func _fill_card(c: Dictionary) -> void:
	var heist_id: StringName = StringName(c["heist_id"])
	var cid: StringName = StringName(c["contact_id"])
	var contact: ContactDef = ContactDef.find(cid) if cid != &"" else null
	portrait.set_contact(contact)
	heist_label.text = UiText.t(StringName("heist.%s.name" % heist_id))
	subtitle_label.text = "%s  |  %s" % [UiText.t(StringName("heist.%s.subtitle" % heist_id)),
			UiText.t(_mode_key(int(c["mode"])))]
	contact_label.text = UiText.t(&"ui.board.contact", {"name": UiText.t(contact.display_name_key) if contact != null else "?"})
	role_label.text = UiText.t(contact.role_key) if contact != null else ""
	difficulty_label.text = UiText.t(&"ui.board.difficulty", {"name": UiText.t(UiText.difficulty_key(int(c["difficulty"])))})
	payout_label.text = UiText.t(&"ui.board.payout", {"amount": UiText.money(int(c["payout"]))})
	var pay: PayoutTweak = ContentDB.tweak(&"payout") as PayoutTweak
	var pct: int = roundi(((pay.pro_job_xp_mult if pay != null else 1.0) - 1.0) * 100.0)
	pro_desc_label.text = UiText.t(&"ui.board.pro_desc", {"pct": pct})
	_update_time_label()


func _update_time_label() -> void:
	var c: Dictionary = selected_contract()
	if c.is_empty():
		return
	time_label.text = UiText.t(&"ui.board.expires", {"time": UiText.clock(BoardContracts.time_left(c, now()))})


func _refresh_status() -> void:
	if status_label != null and profile != null:
		status_label.text = UiText.t(&"ui.board.level_stash", {"level": profile.level, "amount": UiText.money(profile.stash)})


func _refresh_broker() -> void:
	if broker_difficulty == null:
		return
	var allowed: Array[int] = BoardContracts.allowed_difficulties(_level(), tweak, build_gate)
	for d: int in range(Enums.Difficulty.size()):
		var i: int = broker_difficulty.get_item_index(d)
		var name_text: String = UiText.t(UiText.difficulty_key(d))
		var locked: bool = not allowed.has(d)
		broker_difficulty.set_item_disabled(i, locked)
		if not locked:
			broker_difficulty.set_item_text(i, name_text)
		elif _level() < tweak.min_level_of(d):
			broker_difficulty.set_item_text(i, UiText.t(&"ui.board.broker.locked_level", {"name": name_text, "level": tweak.min_level_of(d)}))
		else:
			broker_difficulty.set_item_text(i, UiText.t(&"ui.heist_select.difficulty_locked", {"name": name_text}))
	if broker_difficulty.selected < 0 or broker_difficulty.is_item_disabled(broker_difficulty.selected):
		broker_difficulty.select(broker_difficulty.get_item_index(allowed[0] if not allowed.is_empty() else 0))
	if broker_heist.selected < 0 and broker_heist.item_count > 0:
		broker_heist.select(0)
	broker_cost_label.text = UiText.t(&"ui.board.broker.cost", {"amount": UiText.money(broker_cost())})
	var sel: Dictionary = broker_selection()
	var reason: StringName = BoardBroker.check(profile, StringName(sel["heist_id"]), int(sel["difficulty"]), heist_pool,
			tweak, build_gate)
	broker_reason_label.text = UiText.t(BoardBroker.reason_key(reason)) if reason != BoardBroker.OK else ""
	broker_reason_label.visible = reason != BoardBroker.OK
	buy_button.disabled = reason != BoardBroker.OK


func _level() -> int:
	return profile.level if profile != null else 0


func _on_pin_pressed(slot: int) -> void:
	select_slot(slot)
	if take_button.visible:
		take_button.grab_focus()


func _on_tick() -> void:
	if not is_visible_in_tree():
		return
	if now() >= BoardContracts.next_expiry(contracts):
		refresh_board()
	map_view.update_times(now())
	_update_time_label()


static func _mode_key(mode: int) -> StringName:
	match mode:
		Enums.HeistMode.STEALTH_ONLY:
			return &"ui.heist_select.modes_stealth_only"
		Enums.HeistMode.LOUD_ONLY:
			return &"ui.heist_select.modes_loud_only"
	return &"ui.heist_select.modes_stealth_loud"
