## Co-op lobby screen (B4-11; pd2_fidelity C2/C3 crew lobby). Owner: ENV B.
## Two modes on one screen:
## * Connect (no session): Host (port), Join (address + port, validated by LobbyAddress), a loopback
##   quick-join (LobbyTweak.loopback_address, dev/tests), Back.
## * Lobby (session live): the host's contract, 4 crew slots (name, host / you tags, level, ready state,
##   loadout summary: primary / secondary / armor / deployable / perk deck, mask name + colours, AI, and an
##   "illegal loadout" flag), Ready toggle, host-only Start (LobbyState.start_block() says why not), Leave.
##   Contract / Briefing / Loadout buttons ask MenuFlow to open those screens (signals below).
## All networking goes through `session` (LobbySession -> Net API). MenuFlow passes its session in with
## setup(); standalone the screen makes its own.
class_name LobbyScreen
extends UiScreen

## Host: open the Board (&"board") or the planning table (&"heist_select") to pick the contract.
signal contract_requested(target: StringName)
## Open the briefing -> pre-planning path for the lobby's contract.
signal briefing_requested()
## Open the loadout (armory) screen; its Back returns here and re-sends the profile summary.
signal loadout_requested()

const SLOT_CARD_MIN: Vector2 = Vector2(360, 380)

var session: LobbySession = null
var profile: PlayerProfile = null
var tweak: LobbyTweak
## Connect mode widgets.
var connect_box: VBoxContainer
var host_port_edit: LineEdit
var host_button: Button
var join_address_edit: LineEdit
var join_port_edit: LineEdit
var join_button: Button
var loopback_button: Button
var back_button: Button
var error_label: Label
## Lobby mode widgets.
var lobby_box: VBoxContainer
var status_label: Label
var contract_label: Label
var contract_detail_label: Label
var board_button: Button
var planning_button: Button
var briefing_button: Button
var loadout_button: Button
var ready_button: Button
var start_button: Button
var leave_button: Button
var block_label: Label
## Per slot: {"panel", "name", "tags", "level", "ready", "items": {field: Label}, "mask", "swatch_a",
## "swatch_b", "flag"}.
var slot_widgets: Array[Dictionary] = []


## MenuFlow: the shared session and the profile being advertised (before or after entering the tree).
func setup(p_session: LobbySession, p: PlayerProfile = null) -> void:
	if session != null and session != p_session and session.changed.is_connected(refresh):
		session.changed.disconnect(refresh)
	session = p_session
	if p != null:
		profile = p
		if session != null:
			session.profile = p
	if is_node_ready():
		_bind_session()
		refresh()


func build_ui() -> void:
	tweak = LobbyTweak.load_default()
	if session == null:
		session = LobbySession.new()
		session.name = "LobbySession"
		add_child(session)
	if profile != null:
		session.profile = profile
	var root: VBoxContainer = UiBuild.vbox(24)
	UiBuild.screen_margin(self, root)
	root.add_child(_build_header())
	connect_box = _build_connect()
	root.add_child(connect_box)
	lobby_box = _build_lobby()
	root.add_child(lobby_box)
	_bind_session()
	refresh()


func _bind_session() -> void:
	if not session.changed.is_connected(refresh):
		session.changed.connect(refresh)
	if not session.connection_failed.is_connected(_on_connection_failed):
		session.connection_failed.connect(_on_connection_failed)


func _build_header() -> HBoxContainer:
	var header: HBoxContainer = UiBuild.hbox(20)
	header.add_child(UiAccent.strip(UiAccent.table().fallback, 6.0))
	var titles: VBoxContainer = UiBuild.vbox(2)
	titles.add_child(UiBuild.label(&"ui.menu.title", UiBuild.DIM))
	titles.add_child(UiBuild.label(&"ui.lobby.title", UiBuild.HEADER))
	status_label = UiBuild.label(&"ui.lobby.status.offline", UiBuild.DIM)
	titles.add_child(status_label)
	header.add_child(titles)
	return header


func _build_connect() -> VBoxContainer:
	var box: VBoxContainer = UiBuild.vbox(18)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var host_v: VBoxContainer = UiBuild.vbox(10)
	host_v.add_child(UiBuild.label(&"ui.lobby.host.title", UiBuild.SUBHEADER))
	host_v.add_child(UiBuild.label(&"ui.lobby.host.desc", UiBuild.DIM))
	var host_row: HBoxContainer = UiBuild.hbox(16)
	host_row.add_child(UiBuild.label(&"ui.lobby.port"))
	host_port_edit = _edit(str(tweak.default_port), &"ui.lobby.port", 160)
	host_row.add_child(host_port_edit)
	host_button = UiBuild.primary(UiBuild.button(&"ui.lobby.host"))
	host_button.pressed.connect(_on_host)
	host_row.add_child(host_button)
	host_v.add_child(host_row)
	box.add_child(UiBuild.panel(host_v))
	var join_v: VBoxContainer = UiBuild.vbox(10)
	join_v.add_child(UiBuild.label(&"ui.lobby.join.title", UiBuild.SUBHEADER))
	join_v.add_child(UiBuild.label(&"ui.lobby.join.desc", UiBuild.DIM))
	var join_row: HBoxContainer = UiBuild.hbox(16)
	join_row.add_child(UiBuild.label(&"ui.lobby.address"))
	join_address_edit = _edit("", &"ui.lobby.address_hint", 360)
	join_row.add_child(join_address_edit)
	join_row.add_child(UiBuild.label(&"ui.lobby.port"))
	join_port_edit = _edit(str(tweak.default_port), &"ui.lobby.port", 160)
	join_row.add_child(join_port_edit)
	join_button = UiBuild.button(&"ui.lobby.join")
	join_button.pressed.connect(_on_join)
	join_row.add_child(join_button)
	join_v.add_child(join_row)
	loopback_button = UiBuild.button(&"ui.lobby.loopback", {"address": tweak.loopback_address})
	loopback_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	loopback_button.pressed.connect(join_loopback)
	join_v.add_child(loopback_button)
	box.add_child(UiBuild.panel(join_v))
	error_label = UiBuild.label(&"", UiBuild.DIM)
	error_label.add_theme_color_override(&"font_color", tweak.illegal_color)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(error_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(back_requested.emit)
	box.add_child(back_button)
	return box


func _edit(text: String, hint: StringName, width: float) -> LineEdit:
	var e: LineEdit = LineEdit.new()
	e.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	e.text = text
	e.placeholder_text = UiText.t(hint)
	e.custom_minimum_size = Vector2(width, 0)
	e.focus_mode = Control.FOCUS_ALL
	e.select_all_on_focus = true
	return e


func _build_lobby() -> VBoxContainer:
	var box: VBoxContainer = UiBuild.vbox(20)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cv: VBoxContainer = UiBuild.vbox(6)
	cv.add_child(UiBuild.label(&"ui.lobby.contract.title", UiBuild.DIM))
	contract_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	contract_detail_label = UiBuild.label(&"", UiBuild.DIM)
	cv.add_child(contract_label)
	cv.add_child(contract_detail_label)
	var crow: HBoxContainer = UiBuild.hbox(14)
	board_button = UiBuild.button(&"ui.lobby.contract.board")
	planning_button = UiBuild.button(&"ui.lobby.contract.planning")
	briefing_button = UiBuild.button(&"ui.lobby.briefing")
	loadout_button = UiBuild.button(&"ui.lobby.loadout")
	for b: Button in [board_button, planning_button, briefing_button, loadout_button]:
		b.custom_minimum_size = Vector2(260, 0)
		crow.add_child(b)
	board_button.pressed.connect(contract_requested.emit.bind(&"board"))
	planning_button.pressed.connect(contract_requested.emit.bind(&"heist_select"))
	briefing_button.pressed.connect(briefing_requested.emit)
	loadout_button.pressed.connect(loadout_requested.emit)
	cv.add_child(crow)
	box.add_child(UiBuild.panel(cv))
	var slots: HBoxContainer = UiBuild.hbox(16)
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for _i: int in range(LobbyState.MAX_CREW):
		slots.add_child(_slot_card())
	box.add_child(slots)
	var footer: HBoxContainer = UiBuild.hbox(16)
	leave_button = UiBuild.button(&"ui.lobby.leave")
	ready_button = UiBuild.button(&"ui.lobby.ready")
	ready_button.toggle_mode = true
	start_button = UiBuild.primary(UiBuild.button(&"ui.lobby.start"))
	for b: Button in [leave_button, ready_button, start_button]:
		b.custom_minimum_size = Vector2(260, 0)
		footer.add_child(b)
	block_label = UiBuild.label(&"", UiBuild.DIM)
	block_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(block_label)
	leave_button.pressed.connect(leave)
	ready_button.toggled.connect(_on_ready_toggled)
	start_button.pressed.connect(start)
	box.add_child(footer)
	return box


func _slot_card() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(6)
	var w: Dictionary = {}
	w["name"] = UiBuild.label(&"", UiBuild.SUBHEADER)
	w["tags"] = UiBuild.label(&"", UiBuild.DIM)
	w["level"] = UiBuild.label(&"")
	w["ready"] = UiBuild.label(&"")
	for k: String in ["name", "tags", "level", "ready"]:
		var l: Label = w[k] as Label
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
	v.add_child(HSeparator.new())
	var items: Dictionary = {}
	for f: String in ["primary", "secondary", "armor", "deployable", "perk_deck"]:
		var l: Label = UiBuild.label(&"", UiBuild.DIM)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
		items[f] = l
	w["items"] = items
	var mrow: HBoxContainer = UiBuild.hbox(8)
	w["swatch_a"] = _swatch()
	w["swatch_b"] = _swatch()
	mrow.add_child(w["swatch_a"] as Control)
	mrow.add_child(w["swatch_b"] as Control)
	var mask: Label = UiBuild.label(&"", UiBuild.DIM)
	mask.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(mask)
	w["mask"] = mask
	v.add_child(mrow)
	var flag: Label = UiBuild.label(&"ui.lobby.slot.illegal")
	flag.add_theme_color_override(&"font_color", tweak.illegal_color)
	flag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(flag)
	w["flag"] = flag
	var p: PanelContainer = UiBuild.panel(v)
	p.custom_minimum_size = SLOT_CARD_MIN
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w["panel"] = p
	slot_widgets.append(w)
	return p


func _swatch() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.custom_minimum_size = Vector2(22, 22)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Host on the port field's value. Returns OK or the error (shown on the screen).
func host() -> Error:
	var port: int = LobbyAddress.parse_port(host_port_edit.text, tweak)
	if port < 0:
		_show_error(&"ui.lobby.error.port", {"min": tweak.min_port, "max": tweak.max_port})
		return ERR_INVALID_PARAMETER
	var err: Error = session.host(port)
	if err != OK:
		_show_error(&"ui.lobby.error.host", {"port": port})
	return err


## Join the address / port fields. Returns OK or the error (shown on the screen).
func join() -> Error:
	var address: String = LobbyAddress.parse_address(join_address_edit.text)
	if address == "":
		_show_error(&"ui.lobby.error.address")
		return ERR_INVALID_PARAMETER
	var port: int = LobbyAddress.parse_port(join_port_edit.text, tweak)
	if port < 0:
		_show_error(&"ui.lobby.error.port", {"min": tweak.min_port, "max": tweak.max_port})
		return ERR_INVALID_PARAMETER
	var err: Error = session.join(address, port)
	if err != OK:
		_show_error(&"ui.lobby.error.join", {"address": address, "port": port})
	return err


## Quick-join the loopback address on the join port field's value (dev / tests).
func join_loopback() -> Error:
	join_address_edit.text = tweak.loopback_address
	return join()


func leave() -> void:
	session.leave()


func set_ready(on: bool) -> void:
	session.set_ready(on)


## Host: send the launch order (MenuFlow launches on session.started). Returns LobbyState.OK or why not.
func start() -> StringName:
	var r: StringName = session.start(int(Time.get_unix_time_from_system()))
	refresh()
	return r


func _on_host() -> void:
	host()


func _on_join() -> void:
	join()


func _on_ready_toggled(on: bool) -> void:
	set_ready(on)


func _on_connection_failed(reason: StringName) -> void:
	_show_error(StringName("ui.lobby.error.%s" % reason))


func _show_error(key: StringName, args: Dictionary = {}) -> void:
	error_label.text = UiText.t(key, args)


func refresh() -> void:
	if connect_box == null:
		return
	var active: bool = session.is_active()
	var st: LobbyState = session.state
	var was_lobby: bool = lobby_box.visible
	connect_box.visible = not active
	lobby_box.visible = active
	if active:
		error_label.text = ""
	status_label.text = _status_text()
	_refresh_contract(st)
	for i: int in range(slot_widgets.size()):
		_refresh_slot(slot_widgets[i], st.slot_view(i))
	var in_slot: bool = st.local_slot >= 0
	ready_button.set_pressed_no_signal(st.is_ready(st.local_slot))
	ready_button.text = UiText.t(&"ui.lobby.unready" if ready_button.button_pressed else &"ui.lobby.ready")
	ready_button.disabled = not in_slot or st.contract.is_empty()
	board_button.visible = st.is_host
	planning_button.visible = st.is_host
	briefing_button.disabled = st.contract.is_empty()
	loadout_button.disabled = not in_slot
	start_button.visible = st.is_host
	var block: StringName = st.start_block()
	start_button.disabled = block != LobbyState.OK
	block_label.text = "" if block == LobbyState.OK or not st.is_host else UiText.t(StringName("ui.lobby.block.%s" % block))
	if not st.is_host and in_slot:
		block_label.text = UiText.t(&"ui.lobby.wait_host")
	_rebuild_focus()
	if was_lobby != active:
		focus_default()


func _status_text() -> String:
	var st: LobbyState = session.state
	if not session.is_active():
		return UiText.t(&"ui.lobby.status.offline")
	if session.is_joining() or st.local_slot < 0:
		return UiText.t(&"ui.lobby.status.joining")
	var key: StringName = &"ui.lobby.status.hosting" if st.is_host else &"ui.lobby.status.joined"
	return UiText.t(key, {"crew": st.human_slots().size(), "max": LobbyState.MAX_CREW})


func _refresh_contract(st: LobbyState) -> void:
	if st.contract.is_empty():
		contract_label.text = UiText.t(&"ui.lobby.contract.none")
		contract_detail_label.text = UiText.t(&"ui.lobby.contract.none_host" if st.is_host else &"ui.lobby.contract.none_client")
		return
	var heist: StringName = st.contract["heist"]
	contract_label.text = UiText.t(StringName("heist.%s.name" % heist))
	var detail: String = UiText.t(&"ui.board.difficulty", {"name": UiText.t(UiText.difficulty_key(int(st.contract["difficulty"])))})
	if bool(st.contract["is_pro"]):
		detail += "   " + UiText.t(&"ui.board.pro")
	contract_detail_label.text = detail
	contract_label.add_theme_color_override(&"font_color", UiAccent.text_color(heist, UiAccent.panel_bg()))


func _refresh_slot(w: Dictionary, view: Dictionary) -> void:
	var occupied: bool = bool(view["occupied"])
	var is_ai: bool = bool(view["is_ai"])
	var name_l: Label = w["name"] as Label
	var tags: Label = w["tags"] as Label
	var level: Label = w["level"] as Label
	var rd: Label = w["ready"] as Label
	var items: Dictionary = w["items"] as Dictionary
	var mask: Label = w["mask"] as Label
	var flag: Label = w["flag"] as Label
	var sa: ColorRect = w["swatch_a"] as ColorRect
	var sb: ColorRect = w["swatch_b"] as ColorRect
	var human: bool = occupied and not is_ai
	var has_sum: bool = human and bool(view["has_summary"])
	if not occupied:
		name_l.text = UiText.t(&"ui.lobby.slot.open")
	elif is_ai:
		name_l.text = UiText.t(&"ui.lobby.slot.ai")
	else:
		name_l.text = String(view["name"])
	var tag_parts: PackedStringArray = []
	if bool(view["is_host"]) and human:
		tag_parts.append(UiText.t(&"ui.lobby.slot.host"))
	if bool(view["is_local"]):
		tag_parts.append(UiText.t(&"ui.lobby.slot.you"))
	if not occupied or is_ai:
		tag_parts.append(UiText.t(&"ui.lobby.slot.ai_fill"))
	tags.text = "  ".join(tag_parts)
	level.text = NotorietyScreen.level_text(int(view["level"]), int(view.get("notoriety", 0))) if has_sum else ""
	if human:
		var is_ready: bool = bool(view["ready"])
		rd.text = UiText.t(&"ui.lobby.slot.ready" if is_ready else &"ui.lobby.slot.not_ready")
		rd.add_theme_color_override(&"font_color", tweak.ready_color if is_ready else tweak.not_ready_color)
	else:
		rd.text = ""
	var names: Dictionary = LobbyState.item_names(view["loadout"] as Dictionary) if has_sum else {}
	for f: Variant in items:
		var l: Label = items[f] as Label
		if not has_sum:
			l.text = ""
			continue
		var n: String = String(names.get(f, ""))
		l.text = UiText.t(StringName("ui.lobby.slot.%s" % f), {"name": n if n != "" else UiText.t(&"ui.lobby.slot.none")})
	var mdef: MaskDef = LobbyState.mask_def(view["loadout"] as Dictionary) if has_sum else null
	var mask_n: String = String(names.get("mask", ""))
	mask.text = UiText.t(&"ui.lobby.slot.mask", {"name": mask_n}) if mask_n != "" else ""
	sa.visible = mdef != null
	sb.visible = mdef != null
	if mdef != null:
		sa.color = mdef.color_a
		sb.color = mdef.color_b
	flag.visible = has_sum and not bool(view["legal"])
	if human and not has_sum:
		level.text = UiText.t(&"ui.lobby.slot.waiting")
	var panel: PanelContainer = w["panel"] as PanelContainer
	if bool(view["is_local"]):
		UiAccent.accent_panel(panel, UiBuild.theme().get_color(&"accent", &"Screen"))
	else:
		panel.remove_theme_stylebox_override(&"panel")
	panel.modulate.a = 1.0 if human else 0.7


func _rebuild_focus() -> void:
	focus_chain.clear()
	var cands: Array[Control] = []
	if connect_box.visible:
		cands = [host_port_edit, host_button, join_address_edit, join_port_edit, join_button, loopback_button, back_button]
	else:
		cands = [board_button, planning_button, briefing_button, loadout_button, ready_button, start_button, leave_button]
	for c: Control in cands:
		if c.visible:
			focus_chain.append(c)
	UiNav.chain_vertical(focus_chain)
	if connect_box.visible:
		# The join row reads left to right: left/right walk it too (up/down follow the chain).
		UiNav.chain_horizontal([join_address_edit, join_port_edit, join_button] as Array[Control], false)
