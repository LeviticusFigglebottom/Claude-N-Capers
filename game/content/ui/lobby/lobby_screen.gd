## Co-op lobby screen (B4-11; pd2_fidelity C2/C3 crew lobby). Owner: ENV B.
## Two modes on one screen:
## * Connect (no session): Host (port), Join (address + port, validated by LobbyAddress), a loopback
##   quick-join (LobbyTweak.loopback_address, dev/tests), Back.
## * Lobby (session live): the host's contract, 4 crew slots (name, host / you tags, level, ready state,
##   loadout summary: primary / secondary / armor / deployable / perk deck, mask name + colours, AI, and an
##   "illegal loadout" flag), Ready toggle, host-only Start (LobbyState.start_block() says why not), Leave.
##   Contract / Briefing / Loadout buttons ask MenuFlow to open those screens (signals below).
##   Music (B5-03): the host picks the heist music (MusicPicker: profile.music_choice, saved, re-sent in
##   the host's profile summary); clients see the host's pick read-only (LobbyState.host_music()).
## Lobby codes (B6-05, LobbyCode): the host sees its code (LAN IPv4 from IP.get_local_addresses() + the hosted
## port) in the header with Copy (DisplayServer.clipboard_set) and a hint that internet play needs the public
## address and a forwarded port; the Join panel has a code field (join_by_code() decodes it into the address /
## port fields and runs the normal join()). LAN host list (B6-05, ENV A's LanDiscovery): while the connect panel shows,
## the Join panel lists the lobbies hosting on this network (name, job, players); pressing one fills the address /
## port and joins. The host side (the beacon) is LobbySession's.
## Drop-in (B6-04): "Drop in to a running heist" next to Join (drop_in(): the address / port fields, or the code
## field when the address is empty) emits dropin_requested(address, port); MenuFlow opens DropInJoinScreen
## through DropInFlow (compact loadout pick -> connect -> HeistDropIn.request_join -> progress / cancel).
## Kick (B6-04, D-072): the host sees Kick on every other human's slot card; KickConfirmDialog asks first, then
## LobbySession.kick(slot) -> Net.kick. A kicked client lands back on the connect view with
## `ui.lobby.error.kicked` (LobbySession FAIL_KICKED, from Net.last_disconnect_reason); the crew's chat shows the
## notice. Drop-in policy (B6-04, PD2): the host picks Ask / Allowed / Not allowed (LobbySession.set_drop_in_policy,
## LobbyState.dropin_policy); clients see it read-only.
## Chat (B6-03): a ChatPanel (Mode.LOBBY) next to the contract panel; the chat key focuses its input.
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
## Drop in to the heist running at `address`:`port` (B6-04; MenuFlow opens DropInJoinScreen).
signal dropin_requested(address: String, port: int)

const SLOT_CARD_MIN: Vector2 = Vector2(360, 380)

## Profile slot the music pick saves to (MenuFlow.profile_slot).
var profile_slot: int = 0
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
## "Drop in to a running heist" (B6-04).
var dropin_button: Button
var loopback_button: Button
## Join by lobby code (B6-05).
var code_edit: LineEdit
var code_join_button: Button
## B6-05 LAN list: one button per host row (LanDiscovery.hosts()), and the note shown when there is none.
var lan_list: VBoxContainer
var lan_note: Label
var lan_buttons: Array[Button] = []
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
## Host: heist music pick; clients: the host's pick, read-only (B5-03).
var music_picker: MusicPicker
## Drop-in policy (B6-04): host option (LobbyState.POLICIES order); clients: the value as text.
var dropin_option: OptionButton
var dropin_value_label: Label
## Host's lobby code (B6-05): box (hosting only), "Lobby code: XXXX-XXXX", Copy, hint line.
var code_box: VBoxContainer
var code_label: Label
var copy_button: Button
var code_hint_label: Label
## Port this screen hosted on (-1 = not hosting from here) and the last text put on the clipboard.
var hosted_port: int = -1
var last_copied: String = ""
## Lobby text chat (B6-03).
var chat_panel: ChatPanel
## Host kick confirmation over the screen (B6-04).
var kick_dialog: KickConfirmDialog
var ready_button: Button
var start_button: Button
var leave_button: Button
var block_label: Label
## Per slot: {"panel", "name", "tags", "level", "heister" (D-073: assigned heister in its accent), "ready",
## "items": {field: Label}, "mask", "swatch_a",
## "swatch_b", "flag", "kick"}.
var slot_widgets: Array[Dictionary] = []
## True while the default focus had to fall back to Leave (nothing else enabled yet).
var _focus_parked: bool = false
var _lan: LanDiscovery = null
var _lan_listening: bool = false


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
	kick_dialog = KickConfirmDialog.new()
	kick_dialog.name = "KickDialog"
	add_child(kick_dialog)
	kick_dialog.confirmed.connect(_on_kick_closed.unbind(2))
	kick_dialog.cancelled.connect(_on_kick_closed)
	_bind_session()
	refresh()


func _bind_session() -> void:
	if not session.changed.is_connected(refresh):
		session.changed.connect(refresh)
	if not session.connection_failed.is_connected(_on_connection_failed):
		session.connection_failed.connect(_on_connection_failed)
	if chat_panel != null and chat_panel.session != session:
		chat_panel.setup(session, ChatPanel.Mode.LOBBY)


func _build_header() -> HBoxContainer:
	var header: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	var titles: VBoxContainer = UiBuild.header(&"ui.lobby.crumb", &"ui.lobby.title")
	status_label = UiBuild.label(&"ui.lobby.status.offline", UiBuild.DIM)
	titles.add_child(status_label)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	# Host: the lobby code as a caption over the value, Copy beside it, the LAN / internet note under.
	code_box = UiBuild.vbox(UiTokens.S1)
	code_box.size_flags_vertical = Control.SIZE_SHRINK_END
	code_box.add_child(UiBuild.caption(&"ui.lobby.code.title"))
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	code_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	row.add_child(code_label)
	copy_button = UiBuild.button(&"ui.lobby.code.copy")
	copy_button.custom_minimum_size = Vector2(160, 0)
	copy_button.pressed.connect(copy_code)
	row.add_child(copy_button)
	code_box.add_child(row)
	code_hint_label = UiBuild.label(&"ui.lobby.code.wan_hint", UiBuild.DIM)
	code_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_hint_label.custom_minimum_size = Vector2(620, 0)
	code_box.add_child(code_hint_label)
	code_box.visible = false
	header.add_child(code_box)
	return header


func _build_connect() -> VBoxContainer:
	var box: VBoxContainer = UiBuild.vbox(UiTokens.S4)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var host_v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	host_v.add_child(UiBuild.label(&"ui.lobby.host.title", UiBuild.SUBHEADER))
	host_v.add_child(UiBuild.label(&"ui.lobby.host.desc", UiBuild.DIM))
	var host_row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	host_row.add_child(_field_caption(&"ui.lobby.port"))
	host_port_edit = _edit(str(tweak.default_port), &"ui.lobby.port", 160)
	host_row.add_child(host_port_edit)
	host_button = UiBuild.button(&"ui.lobby.host")
	host_button.pressed.connect(_on_host)
	host_row.add_child(host_button)
	host_v.add_child(host_row)
	box.add_child(UiBuild.panel(host_v))
	var join_v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	join_v.add_child(UiBuild.label(&"ui.lobby.join.title", UiBuild.SUBHEADER))
	join_v.add_child(UiBuild.label(&"ui.lobby.join.desc", UiBuild.DIM))
	var join_row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	join_row.add_child(_field_caption(&"ui.lobby.address"))
	join_address_edit = _edit("", &"ui.lobby.address_hint", 360)
	join_row.add_child(join_address_edit)
	join_row.add_child(_field_caption(&"ui.lobby.port"))
	join_port_edit = _edit(str(tweak.default_port), &"ui.lobby.port", 160)
	join_row.add_child(join_port_edit)
	join_button = UiBuild.button(&"ui.lobby.join")
	join_button.pressed.connect(_on_join)
	join_row.add_child(join_button)
	dropin_button = UiBuild.button(&"ui.lobby.dropin_join")
	dropin_button.tooltip_text = UiText.t(&"ui.lobby.dropin_join.hint")
	dropin_button.pressed.connect(_on_drop_in)
	join_row.add_child(dropin_button)
	join_v.add_child(join_row)
	# Gamepad pass: the drop-in hint was a tooltip only; a dim line under the row reaches every input.
	var dropin_hint: Label = UiBuild.label(&"ui.lobby.dropin_join.hint", UiBuild.DIM)
	dropin_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	join_v.add_child(dropin_hint)
	join_v.add_child(UiBuild.caption(&"ui.lobby.lan.title"))
	lan_list = UiBuild.vbox(UiTokens.S1)
	lan_list.name = "LanList"
	join_v.add_child(lan_list)
	lan_note = UiBuild.label(&"ui.lobby.lan.empty", UiBuild.DIM)
	join_v.add_child(lan_note)
	loopback_button = UiBuild.button(&"ui.lobby.loopback", {"address": tweak.loopback_address})
	loopback_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	loopback_button.pressed.connect(join_loopback)
	join_v.add_child(loopback_button)
	var code_row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	code_row.add_child(_field_caption(&"ui.lobby.code.title"))
	code_edit = _edit("", &"ui.lobby.code.hint", 360)
	code_edit.max_length = 24
	code_edit.text_submitted.connect(_on_code_submitted)
	code_row.add_child(code_edit)
	code_join_button = UiBuild.button(&"ui.lobby.code.join")
	code_join_button.pressed.connect(join_by_code)
	code_row.add_child(code_join_button)
	join_v.add_child(code_row)
	box.add_child(UiBuild.panel(join_v))
	error_label = UiBuild.label(&"", UiBuild.DIM)
	error_label.add_theme_color_override(&"font_color", tweak.illegal_color)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(error_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	# PO-4 footer: Back (ghost) bottom left. Host and Join are peer choices, so neither is the brass primary.
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	box.add_child(UiBuild.footer(back_button))
	return box


## A caption naming the field to its right ("PORT", "ADDRESS").
func _field_caption(key: StringName) -> Label:
	var l: Label = UiBuild.caption(key)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


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
	var box: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cv: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	cv.add_child(UiBuild.caption(&"ui.lobby.contract.title"))
	contract_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	contract_detail_label = UiBuild.label(&"", UiBuild.DIM)
	# PO-B-C6: the crew cards were cut under the fold at 720p. The contract, its difficulty, music and drop-in
	# share rows now (two rows shorter).
	var name_row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	contract_detail_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(contract_label)
	name_row.add_child(contract_detail_label)
	cv.add_child(name_row)
	var crow: HBoxContainer = UiBuild.hbox(UiTokens.S3)
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
	music_picker = MusicPicker.new()
	music_picker.name = "MusicPicker"
	music_picker.music_changed.connect(_on_music_changed)
	var opt_row: HBoxContainer = UiBuild.hbox(UiTokens.S5)
	opt_row.add_child(music_picker)
	opt_row.add_child(_build_dropin_row())
	cv.add_child(opt_row)
	var top: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	var contract_panel: PanelContainer = UiBuild.panel(cv)
	contract_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(contract_panel)
	chat_panel = ChatPanel.new()
	chat_panel.name = "ChatPanel"
	chat_panel.setup(session, ChatPanel.Mode.LOBBY)
	top.add_child(chat_panel)
	# PQ-B-11b: contract + crew cards outgrow the 1080-unit canvas (1280x720) and pushed the
	# Leave / Ready / Start footer off-screen. They scroll now; the footer stays pinned.
	var body_scroll: ScrollContainer = ScrollContainer.new()
	body_scroll.name = "LobbyBodyScroll"
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.follow_focus = true
	var body: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body)
	box.add_child(body_scroll)
	body.add_child(top)
	var slots: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	for _i: int in range(LobbyState.MAX_CREW):
		slots.add_child(_slot_card())
	body.add_child(slots)
	# PO-4 footer: Leave (ghost, the screen's Back) left, why Start is blocked, Ready, Start (primary) right.
	leave_button = UiBuild.button(&"ui.lobby.leave")
	ready_button = UiBuild.button(&"ui.lobby.ready")
	ready_button.toggle_mode = true
	start_button = UiBuild.button(&"ui.lobby.start")
	for b: Button in [leave_button, ready_button, start_button]:
		b.custom_minimum_size = Vector2(260, 0)
	block_label = UiBuild.label(&"", UiBuild.DIM)
	block_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	block_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var footer: HBoxContainer = UiBuild.footer(leave_button, start_button, [block_label, ready_button] as Array[Control])
	footer.get_child(footer.get_child_count() - 2).size_flags_horizontal = Control.SIZE_FILL  # spacer yields to block_label
	leave_button.pressed.connect(leave)
	ready_button.toggled.connect(_on_ready_toggled)
	start_button.pressed.connect(start)
	box.add_child(footer)
	return box


func _build_dropin_row() -> HBoxContainer:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	row.add_child(_field_caption(&"ui.lobby.dropin.title"))
	dropin_option = UiBuild.option_button()
	dropin_option.name = "DropInPolicy"
	for policy: StringName in LobbyState.POLICIES:
		dropin_option.add_item(UiText.t(policy_key(policy)))
	dropin_option.custom_minimum_size = Vector2(260, 0)
	dropin_option.item_selected.connect(_on_dropin_selected)
	row.add_child(dropin_option)
	dropin_value_label = UiBuild.label(&"", UiBuild.DIM)
	row.add_child(dropin_value_label)
	return row


func _slot_card() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	var w: Dictionary = {}
	w["tags"] = UiBuild.caption()
	w["name"] = UiBuild.label(&"", UiBuild.SUBHEADER)
	w["level"] = UiBuild.label(&"")
	w["ready"] = UiBuild.caption()
	for k: String in ["tags", "name", "level", "ready"]:
		(w[k] as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# PO-B-C6: Kick sits beside the name and the level shares a row with the ready state (the mask row was
	# under the fold at 720p).
	v.add_child(w["tags"] as Label)
	var name_row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	(w["name"] as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(w["name"] as Label)
	v.add_child(name_row)
	var state_row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	# A trimming label in a box shrinks to nothing (the sweep caught "Level 4 / NOT READY" blank): these
	# short texts keep their width.
	for k: String in ["level", "ready"]:
		(w[k] as Label).text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	(w["ready"] as Label).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state_row.add_child(w["level"] as Label)
	state_row.add_child(w["ready"] as Label)
	v.add_child(state_row)
	v.add_child(HSeparator.new())
	# PO-4: loadout as caption / value rows ("PRIMARY  Corsair"), heister first.
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
	grid.add_theme_constant_override(&"v_separation", UiTokens.S1)
	v.add_child(grid)
	var captions: Dictionary = {}
	w["heister"] = _slot_row(grid, &"ui.loadout.heister", captions, "heister")
	var items: Dictionary = {}
	for f: String in ["primary", "secondary", "armor", "deployable", "perk_deck"]:
		items[f] = _slot_row(grid, StringName("ui.loadout.%s" % f), captions, f)
	w["items"] = items
	captions["mask"] = UiBuild.caption(&"ui.loadout.mask")
	captions["mask"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(captions["mask"] as Control)
	var mrow: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	w["swatch_a"] = _swatch()
	w["swatch_b"] = _swatch()
	mrow.add_child(w["swatch_a"] as Control)
	mrow.add_child(w["swatch_b"] as Control)
	var mask: Label = UiBuild.label()
	mask.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(mask)
	mrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w["mask"] = mask
	grid.add_child(mrow)
	w["captions"] = captions
	var flag: Label = UiBuild.label(&"ui.lobby.slot.illegal")
	flag.add_theme_color_override(&"font_color", tweak.illegal_color)
	flag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(flag)
	w["flag"] = flag
	var kick: Button = UiBuild.button(&"ui.kick.button")
	kick.custom_minimum_size = Vector2(140, 0)
	kick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kick.pressed.connect(ask_kick.bind(slot_widgets.size()))
	name_row.add_child(kick)
	w["kick"] = kick
	var p: PanelContainer = UiBuild.panel(v)
	p.custom_minimum_size = SLOT_CARD_MIN
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w["panel"] = p
	slot_widgets.append(w)
	return p


## One caption / value row of a slot card's loadout grid; returns the value label.
func _slot_row(grid: GridContainer, caption_key: StringName, captions: Dictionary, field: String) -> Label:
	var c: Label = UiBuild.caption(caption_key)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(c)
	captions[field] = c
	var l: Label = UiBuild.label()
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	grid.add_child(l)
	return l


func _swatch() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.custom_minimum_size = Vector2(UiTokens.S4, UiTokens.S4)
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
	hosted_port = port if err == OK else -1
	if err != OK:
		_show_error(&"ui.lobby.error.host", {"port": port})
	return err


## Join the address / port fields. Returns OK or the error (shown on the screen).
func join() -> Error:
	var target: Dictionary = _join_target()
	if target.is_empty():
		return ERR_INVALID_PARAMETER
	var address: String = target["address"]
	var port: int = target["port"]
	var err: Error = session.join(address, port)
	if err != OK:
		_show_error(&"ui.lobby.error.join", {"address": address, "port": port})
	return err


## B6-05: join the LAN host row `host` (LanDiscovery.hosts()): its address / port into the fields, then join().
func join_lan(host: Dictionary) -> Error:
	join_address_edit.text = String(host.get("address", ""))
	join_port_edit.text = str(int(host.get("port", 0)))
	return join()


## Listen for LAN hosts while the connect panel shows; stop in the lobby and when the screen leaves the tree.
func _set_lan_listening(on: bool) -> void:
	if on == _lan_listening:
		return
	if _lan == null:
		_lan = LanDiscovery.ensure(get_tree())
		_lan.hosts_changed.connect(_refresh_lan)
	_lan_listening = on
	if on:
		if not _lan.start_listening():
			lan_note.text = UiText.t(&"ui.lobby.lan.busy")  # another browser on this machine holds the port
			lan_note.visible = true
			return
		_refresh_lan(_lan.hosts())
	else:
		_lan.stop_listening()


func _refresh_lan(hosts: Array) -> void:
	if lan_list == null:
		return
	for b: Button in lan_buttons:
		lan_list.remove_child(b)
		b.queue_free()
	lan_buttons.clear()
	for h: Variant in hosts:
		var row: Dictionary = h as Dictionary
		var heist: StringName = StringName(row.get("heist", &""))
		var b: Button = UiBuild.ghost(Button.new())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = UiText.t(&"ui.lobby.lan.row", {"name": String(row.get("name", "")),
				"job": UiText.t(StringName("heist.%s.name" % heist)) if heist != &"" else UiText.t(&"ui.lobby.lan.no_job"),
				"players": int(row.get("players", 0)), "max": int(row.get("max_players", LobbyState.MAX_CREW))})
		b.pressed.connect(join_lan.bind(row))
		lan_list.add_child(b)
		lan_buttons.append(b)
	lan_note.text = UiText.t(&"ui.lobby.lan.empty")
	lan_note.visible = hosts.is_empty()
	if connect_box != null and connect_box.visible:
		_rebuild_focus()


func _exit_tree() -> void:
	if _lan != null and is_instance_valid(_lan) and _lan_listening:
		_lan.stop_listening()
	_lan_listening = false


## Join by the code field (LobbyCode): fills the address / port fields and runs join(). A bad code shows
## `ui.lobby.code.error.<reason>` and returns ERR_INVALID_DATA.
func join_by_code() -> Error:
	var d: Dictionary = LobbyCode.decode(code_edit.text, tweak.default_port)
	if d.has("error"):
		_show_error(StringName("ui.lobby.code.error.%s" % d["error"]))
		return ERR_INVALID_DATA
	join_address_edit.text = String(d["address"])
	join_port_edit.text = str(int(d["port"]))
	return join()


## The host's lobby code (no dashes) for this machine's LAN IPv4 and the hosted port, "" when unknown.
func lobby_code() -> String:
	if hosted_port < 0:
		return ""
	return LobbyCode.encode(LobbyCode.pick_lan_ipv4(IP.get_local_addresses()), hosted_port, tweak.default_port)


## Copy the code (display form) to the clipboard.
func copy_code() -> void:
	var code: String = lobby_code()
	if code == "":
		return
	last_copied = LobbyCode.display(code)
	DisplayServer.clipboard_set(last_copied)
	code_hint_label.text = UiText.t(&"ui.lobby.code.copied")


func _on_code_submitted(_text: String) -> void:
	join_by_code()


## Drop in to a running heist (B6-04): the address / port fields (an empty address with a code typed in uses
## the code) -> dropin_requested(address, port). Returns OK or the error (shown on the screen); nothing connects
## here (DropInFlow does after the loadout pick).
func drop_in() -> Error:
	if LobbyAddress.parse_address(join_address_edit.text) == "" and code_edit.text.strip_edges() != "":
		var d: Dictionary = LobbyCode.decode(code_edit.text, tweak.default_port)
		if d.has("error"):
			_show_error(StringName("ui.lobby.code.error.%s" % d["error"]))
			return ERR_INVALID_DATA
		join_address_edit.text = String(d["address"])
		join_port_edit.text = str(int(d["port"]))
	var target: Dictionary = _join_target()
	if target.is_empty():
		return ERR_INVALID_PARAMETER
	error_label.text = ""
	dropin_requested.emit(String(target["address"]), int(target["port"]))
	return OK


## {"address", "port"} from the join fields, or {} after showing why not.
func _join_target() -> Dictionary:
	var address: String = LobbyAddress.parse_address(join_address_edit.text)
	if address == "":
		_show_error(&"ui.lobby.error.address")
		return {}
	var port: int = LobbyAddress.parse_port(join_port_edit.text, tweak)
	if port < 0:
		_show_error(&"ui.lobby.error.port", {"min": tweak.min_port, "max": tweak.max_port})
		return {}
	return {"address": address, "port": port}


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


## Host: ask to kick the human in `slot` (confirm dialog). False when that slot cannot be kicked.
func ask_kick(slot: int) -> bool:
	var st: LobbyState = session.state
	if not st.is_host or slot == st.local_slot or not st.is_human(slot):
		return false
	kick_dialog.target = session
	kick_dialog.ask(slot, String(st.slot_view(slot)["name"]))
	return true


## Host: change the lobby's drop-in policy (LobbyState.POLICY_*). False for a client or a bad value.
func set_drop_in_policy(policy: StringName) -> bool:
	return session.set_drop_in_policy(policy)


## UI text key of a drop-in policy.
static func policy_key(policy: StringName) -> StringName:
	return StringName("ui.lobby.dropin.%s" % policy)


func _on_dropin_selected(index: int) -> void:
	if index >= 0 and index < LobbyState.POLICIES.size():
		set_drop_in_policy(LobbyState.POLICIES[index])


func _refresh_dropin(st: LobbyState) -> void:
	dropin_option.visible = st.is_host
	dropin_value_label.visible = not st.is_host
	dropin_option.select(maxi(LobbyState.POLICIES.find(st.dropin_policy), 0))
	dropin_value_label.text = UiText.t(policy_key(st.dropin_policy))


func _on_kick_closed() -> void:
	refresh()
	focus_default()


func _on_host() -> void:
	host()


func _on_join() -> void:
	join()


func _on_drop_in() -> void:
	drop_in()


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
	_set_lan_listening(not active and is_inside_tree())
	if active:
		error_label.text = ""
	status_label.text = _status_text()
	_refresh_contract(st)
	_refresh_code(active and st.is_host)
	_refresh_music(st)
	_refresh_dropin(st)
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
	# A client lands here before its slot and the host's contract arrive: everything but Leave is still
	# disabled, so the default focus parks on Leave (one stray Enter / A left the lobby: co-op pass).
	# Re-place it once something else is enabled, unless the player moved it.
	var parked: bool = _focus_parked and is_inside_tree() and get_viewport().gui_get_focus_owner() == leave_button
	if was_lobby != active or parked:
		var target: Control = UiNav.focus_first(focus_chain) if is_visible_in_tree() else null  # grabs deferred
		_focus_parked = active and target == leave_button


func _refresh_code(hosting: bool) -> void:
	if not hosting:
		hosted_port = -1 if not session.is_active() else hosted_port
		code_hint_label.text = UiText.t(&"ui.lobby.code.wan_hint")
	code_box.visible = hosting and hosted_port >= 0
	if not code_box.visible:
		return
	var code: String = lobby_code()
	code_label.text = UiText.t(&"ui.lobby.code.value", {"code": LobbyCode.display(code)}) if code != "" \
			else UiText.t(&"ui.lobby.code.unavailable")
	copy_button.visible = code != ""


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
	if bool(st.contract.get("last_breath", false)):
		detail += "   " + UiText.t(&"ui.heist_select.last_breath")  # C4 One Down: the host decides
	contract_detail_label.text = detail


func _refresh_music(st: LobbyState) -> void:
	var heist: StringName = st.contract.get("heist", &"")
	music_picker.profile_slot = profile_slot
	if st.is_host:
		music_picker.editable = true
		music_picker.setup(profile if profile != null else session.profile, heist)
	else:
		music_picker.heist_id = heist
		music_picker.set_read_only(st.host_music())


## Host picked a track: re-send the summary so every client shows it.
func _on_music_changed(_track_id: StringName) -> void:
	session.send_profile()


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
	# PO-19: an AI seat shows the host's crew bot loadout (primary, armor, mask; the outfit is the heister row).
	var bot: Dictionary = view.get("bot", {}) as Dictionary if is_ai or not occupied else {}
	var bot_shown: bool = not bot.is_empty()
	var bot_names: Dictionary = CrewLoadouts.names(bot) if bot_shown else {}
	for f: Variant in items:
		var l: Label = items[f] as Label
		if bot_shown and (f == "primary" or f == "armor"):
			l.text = UiText.t(StringName("ui.lobby.slot.%s" % f), {"name": String(bot_names["weapon" if f == "primary" else "armor"])})
			continue
		if not has_sum:
			l.text = ""
			continue
		var n: String = String(names.get(f, ""))
		l.text = UiText.t(StringName("ui.lobby.slot.%s" % f), {"name": n if n != "" else UiText.t(&"ui.lobby.slot.none")})
	var mdef: MaskDef = LobbyState.mask_def(view["loadout"] as Dictionary) if has_sum else null
	var mask_n: String = String(names.get("mask", ""))
	if bot_shown and String(bot.get("mask", "")) != "":
		mask_n = String(bot_names["mask"])
		mdef = LobbyState.mask_def({"mask": bot["mask"]})  # a preset's colours; a custom bot mask shows no swatch
	mask.text = UiText.t(&"ui.lobby.slot.mask", {"name": mask_n}) if mask_n != "" else ""
	var captions: Dictionary = w["captions"] as Dictionary
	for f: Variant in captions:
		(captions[f] as Label).visible = has_sum or (bot_shown and f in ["primary", "armor"]) \
			or (bot_shown and f == "mask" and mask_n != "")
	# A hidden row hides its value cell too, so the caption / value grid stays in step (PO-19 AI cards).
	for f: Variant in items:
		(items[f] as Label).visible = (captions[f] as Label).visible
	(mask.get_parent() as Control).visible = (captions["mask"] as Label).visible
	(captions["heister"] as Label).visible = occupied and (is_ai or has_sum) and StringName(view.get("heister", &"")) != &""
	sa.visible = mdef != null
	sb.visible = mdef != null
	if mdef != null:
		sa.color = mdef.color_a
		sb.color = mdef.color_b
	_refresh_heister(w["heister"] as Label, view, occupied and (is_ai or has_sum))
	flag.visible = has_sum and not bool(view["legal"])
	if human and not has_sum:
		level.text = UiText.t(&"ui.lobby.slot.waiting")
	var panel: PanelContainer = w["panel"] as PanelContainer
	if bool(view["is_local"]):
		UiAccent.accent_panel(panel, UiTokens.PAPER_DIM, 3)  # PO-4: your seat, a paper edge (brass is money / primary)
	else:
		panel.remove_theme_stylebox_override(&"panel")
	panel.modulate.a = 1.0 if human else 0.7
	var kick: Button = w["kick"] as Button
	kick.visible = session.state.is_host and human and not bool(view["is_local"])
	# r223 720p co-op capture: Kick made the name row 9 px taller on kickable cards only, so their rows sat
	# below the other cards'; every card's name row keeps the Kick height (themed by now, so it measures).
	(kick.get_parent() as Control).custom_minimum_size.y = kick.get_combined_minimum_size().y


## D-073: the slot's heister in its accent; a pick lost to an earlier claim shows what was wanted.
func _refresh_heister(l: Label, view: Dictionary, shown: bool) -> void:
	var id: StringName = StringName(view.get("heister", &""))
	l.visible = shown and id != &""
	if not l.visible:
		return
	var pick: StringName = StringName(view.get("heister_pick", &""))
	var args: Dictionary = {"name": CrewLoadouts.outfit_name(id), "pick": Heisters.display_name(pick)}  # PO-19: suits
	var lost: bool = not bool(view["is_ai"]) and pick != &"" and pick != id
	l.text = UiText.t(&"ui.lobby.slot.heister_fallback" if lost else &"ui.lobby.slot.heister", args)
	l.add_theme_color_override(&"font_color", Heisters.accent(id).lerp(Color.WHITE, 0.35))


func _rebuild_focus() -> void:
	focus_chain.clear()
	var cands: Array[Control] = []
	if connect_box.visible:
		cands = [host_port_edit, host_button, join_address_edit, join_port_edit, join_button, dropin_button]
		cands.append_array(lan_buttons)
		cands.append_array([loopback_button, code_edit, code_join_button, back_button] as Array[Control])
	else:
		cands = [board_button, planning_button, briefing_button, loadout_button, music_picker.option, dropin_option, ready_button,
				start_button, leave_button]
		for w: Dictionary in slot_widgets:
			cands.append(w["kick"] as Control)
		if code_box.visible:
			cands.append(copy_button)
		if chat_panel.input != null:
			cands.append(chat_panel.input)
	for c: Control in cands:
		if c.visible:
			focus_chain.append(c)
	UiNav.chain_vertical(focus_chain)
	if connect_box.visible:
		# The join row reads left to right: left/right walk it too (up/down follow the chain).
		UiNav.chain_horizontal([join_address_edit, join_port_edit, join_button, dropin_button] as Array[Control], false)
