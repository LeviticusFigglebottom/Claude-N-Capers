## The Board (pd2_fidelity C1, roadmap B4-06). Owner: ENV B. A stylised city map in the safehouse
## with rotating contracts from the contacts (BoardContracts), a contract card for the selected pin,
## and the contract broker (BoardBroker). Design: res://content/docs/board.md.
##
## API (MenuFlow wires it): setup(profile) before or after the screen enters the tree (null = load
## profile_slot). Signals: contract_chosen(heist_id, difficulty, is_pro) (Take on a pin, or a broker
## purchase after the stash was charged and, with save_on_buy, saved); back_requested() (UiScreen;
## Esc / gamepad B). `clock` (Callable() -> float Unix seconds) replaces the system clock in tests.
##
## Pro jobs have no restart (QB-BRD1, D-049): `consumed` (BoardContracts.contract_key() -> true,
## shared with MenuFlow) marks failed pro contracts; their pin is dimmed and Take is locked until the
## slot rotates to a new contract.
##
## Navigation: pins move spatially (BoardMapView); right from the map's edge reaches the broker; left
## from the side panel returns to the selected pin. Focusing a pin selects it; pressing it jumps to Take
## (the footer's primary, bottom right).
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
## BoardContracts.contract_key() -> true for consumed (failed pro) contracts. MenuFlow shares its dict.
var consumed: Dictionary = {}
var contracts: Array[Dictionary] = []
var selected_slot: int = -1
## Optional time source (tests): Callable() -> float Unix seconds.
var clock: Callable = Callable()
## Build-wide difficulty gate (Callable(int) -> bool); tests may replace it.
var build_gate: Callable = BoardContracts.build_gate()

var map_view: BoardMapView
## PO-4 header: level and stash as caption + value pairs.
var level_label: Label
var stash_label: Label
var empty_label: Label
var card: VBoxContainer
## The contract card's panel; its edge takes the heist accent (UiAccent, B4-07).
var card_panel: PanelContainer
var portrait: ContactPortrait
var contact_label: Label
var role_label: Label
var heist_label: Label
var subtitle_label: Label
var difficulty_label: Label
var payout_label: Label
var pro_label: Label
var pro_desc_label: Label
var consumed_label: Label
var time_label: Label
var take_button: Button
var broker_heist: OptionButton
var broker_difficulty: OptionButton
var broker_cost_label: Label
var broker_reason_label: Label
var buy_button: Button
var back_button: Button

var _timer: Timer
var _card_fields: Array[VBoxContainer] = []


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
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	UiBuild.screen_margin(self, root, UiTokens.S6)
	_build_header(root)
	var body: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var map_col: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	map_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(map_col)
	map_view = BoardMapView.new()
	map_view.city = city
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.custom_minimum_size = Vector2(640, 400)
	map_view.pin_focused.connect(select_slot)
	map_view.pin_pressed.connect(_on_pin_pressed)
	map_col.add_child(map_view)
	_build_legend(map_col)
	var side: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	side.custom_minimum_size = Vector2(560, 0)
	body.add_child(side)
	_build_card(side)
	_build_broker(side)
	# PO-4 footer: Back (ghost) left, Take Contract (the screen's one primary) right.
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	take_button = UiBuild.button(&"ui.board.take")
	take_button.pressed.connect(take_selected)
	root.add_child(UiBuild.footer(back_button, take_button))
	map_view.exit_right = broker_heist
	for c: Control in [broker_heist, broker_difficulty, buy_button, take_button, back_button]:
		focus_chain.append(c)
	UiNav.chain_horizontal([back_button, take_button] as Array[Control], false)
	refresh_board()
	_refresh_broker()


func _build_header(root: VBoxContainer) -> void:
	var header: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	root.add_child(header)
	var left: VBoxContainer = UiBuild.header(&"ui.board.crumb", &"ui.board.title")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UiBuild.label(&"ui.board.subtitle", UiBuild.DIM, {"minutes": roundi(tweak.rotation_s / 60.0)}))
	header.add_child(left)
	level_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	stash_label = UiBuild.label(&"", UiBuild.MONEY)
	for pair: Array in [[&"ui.board.level_caption", level_label], [&"ui.board.stash_caption", stash_label]]:
		var f: VBoxContainer = UiBuild.field(StringName(pair[0]), pair[1] as Control)
		f.size_flags_vertical = Control.SIZE_SHRINK_END
		header.add_child(f)


func _build_legend(parent: VBoxContainer) -> void:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	parent.add_child(row)
	for c: ContactDef in ContactDef.all():
		if c.is_handler:
			continue
		var item: HBoxContainer = UiBuild.hbox(UiTokens.S2)
		var dot: ColorRect = ColorRect.new()
		dot.color = c.accent_color
		dot.custom_minimum_size = Vector2(UiTokens.S3, UiTokens.S3)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(dot)
		item.add_child(UiBuild.label(c.display_name_key, UiBuild.DIM))
		row.add_child(item)
	var pro: Label = UiBuild.label(&"ui.board.legend_pro", UiBuild.DIM)
	pro.add_theme_color_override(&"font_color", UiTokens.ALERT)
	row.add_child(pro)


func _build_card(side: VBoxContainer) -> void:
	card = UiBuild.vbox(UiTokens.S3)
	card_panel = UiBuild.panel(card)
	side.add_child(card_panel)
	var top: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	card.add_child(top)
	portrait = ContactPortrait.new()
	portrait.custom_minimum_size = Vector2(128, 128)
	top.add_child(portrait)
	var who: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	pro_label = UiBuild.caption(&"ui.board.pro")
	pro_label.add_theme_color_override(&"font_color", UiTokens.ALERT)
	heist_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	subtitle_label = UiBuild.label(&"", UiBuild.CAPTION)
	subtitle_label.uppercase = true
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var contact_row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	contact_label = UiBuild.label()
	role_label = UiBuild.label(&"", UiBuild.DIM)
	role_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contact_row.add_child(contact_label)
	contact_row.add_child(role_label)
	for l: Control in [pro_label, heist_label, subtitle_label, contact_row]:
		if l is Label and l != subtitle_label:
			(l as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.add_child(l)
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S5)
	card.add_child(row)
	difficulty_label = UiBuild.label()
	difficulty_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	time_label = UiBuild.label()
	time_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	payout_label = UiBuild.label(&"", UiBuild.MONEY)
	_card_fields.clear()
	for pair: Array in [[&"ui.board.pay_caption", payout_label], [&"ui.board.difficulty_caption", difficulty_label],
			[&"ui.board.expires_caption", time_label]]:
		var f: VBoxContainer = UiBuild.field(StringName(pair[0]), pair[1] as Control)
		f.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(f)
		_card_fields.append(f)
	pro_desc_label = UiBuild.label(&"", UiBuild.DIM)
	pro_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label = UiBuild.label(&"ui.board.empty", UiBuild.DIM)
	consumed_label = UiBuild.label(&"ui.board.consumed")
	consumed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consumed_label.add_theme_color_override(&"font_color", UiTokens.ALERT)
	for l: Label in [pro_desc_label, consumed_label, empty_label]:
		card.add_child(l)


func _build_broker(side: VBoxContainer) -> void:
	var box: VBoxContainer = UiBuild.vbox(UiTokens.S2)
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
	broker_cost_label = UiBuild.label(&"", UiBuild.MONEY)
	broker_cost_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	for pair: Array in [[&"ui.board.broker.heist", broker_heist], [&"ui.board.broker.difficulty", broker_difficulty],
			[&"ui.board.broker.price", broker_cost_label]]:
		var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
		var l: Label = UiBuild.caption(StringName(pair[0]))
		l.custom_minimum_size = Vector2(150, 0)
		row.add_child(l)
		(pair[1] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pair[1] as Control)
		box.add_child(row)
	broker_reason_label = UiBuild.label(&"", UiBuild.DIM)
	broker_reason_label.add_theme_color_override(&"font_color", UiTokens.ALERT)
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
	for c: Dictionary in contracts:
		c["consumed"] = consumed.has(BoardContracts.contract_key(c))
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
	for n: Control in [portrait, heist_label, subtitle_label, contact_label, role_label]:
		n.visible = has
	for f: VBoxContainer in _card_fields:
		f.visible = has
	take_button.disabled = not has
	empty_label.visible = not has
	pro_label.visible = has and bool(c["is_pro"])
	pro_desc_label.visible = pro_label.visible
	consumed_label.visible = has and bool(c.get("consumed", false))
	take_button.disabled = take_button.disabled or consumed_label.visible
	if has:
		_fill_card(c)
		var pin_path: NodePath = take_button.get_path_to(map_view.pins[selected_slot])
		for n: Control in [broker_heist, broker_difficulty, buy_button, back_button]:
			n.focus_neighbor_left = pin_path


func selected_contract() -> Dictionary:
	return contracts[selected_slot] if selected_slot >= 0 and selected_slot < contracts.size() else {}


## Take the selected contract: emits contract_chosen unless it expired meanwhile (then the board
## refreshes and nothing is emitted) or it is a consumed pro job. Returns whether it emitted.
func take_selected() -> bool:
	var c: Dictionary = selected_contract()
	if c.is_empty() or bool(c.get("consumed", false)):
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
	UiAccent.accent_panel(card_panel, UiAccent.for_heist(heist_id))
	heist_label.text = UiText.t(StringName("heist.%s.name" % heist_id))
	subtitle_label.text = "%s  |  %s" % [UiText.t(StringName("heist.%s.subtitle" % heist_id)),
			UiText.t(_mode_key(int(c["mode"])))]
	contact_label.text = UiText.t(&"ui.board.contact", {"name": UiText.t(contact.display_name_key) if contact != null else "?"})
	role_label.text = UiText.t(contact.role_key) if contact != null else ""
	difficulty_label.text = UiText.t(UiText.difficulty_key(int(c["difficulty"])))
	payout_label.text = UiText.money(int(c["payout"]))
	var pay: PayoutTweak = ContentDB.tweak(&"payout") as PayoutTweak
	var pct: int = roundi(((pay.pro_job_xp_mult if pay != null else 1.0) - 1.0) * 100.0)
	pro_desc_label.text = UiText.t(&"ui.board.pro_desc", {"pct": pct})
	_update_time_label()


func _update_time_label() -> void:
	var c: Dictionary = selected_contract()
	if c.is_empty():
		return
	time_label.text = UiText.clock(BoardContracts.time_left(c, now()))


func _refresh_status() -> void:
	if level_label != null and profile != null:
		level_label.text = str(profile.level)
		stash_label.text = UiText.money(profile.stash)


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
	broker_cost_label.text = UiText.money(broker_cost())
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
	if not take_button.disabled:
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
