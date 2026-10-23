## Pre-planning board (B2-01, pd2_fidelity C3). Owner: ENV B.
## Left: the heist blueprint (BlueprintView) with a marker per pre-planning point; a "Crew assets"
## tab for assets with no location. Right: the selected point's assets (buy / remove / vote),
## favors and spending-cash budget, the plan so far and the plan votes. Bottom: Back / Confirm.
##
## Usage (MenuFlow wires it; this screen never changes scenes itself):
##   var s: PreplanningScreen = preload(".../preplanning_screen.tscn").instantiate()
##   s.setup(&"glasshouse", Enums.Difficulty.BRUTAL, profile)    # before or after add_child
##   s.confirmed.connect(func(plan: Dictionary) -> void: options["preplan"] = plan)
## `confirmed(plan)` carries the PreplanResult (PreplanPlan.apply(); contract docs/contracts/preplanning.md).
## On confirm the local player's share (own assets + their part of voted plans) is deducted from
## profile.cash and, with save_on_confirm, saved to profile_slot. Plan votes go through
## Net.lobby_send / Net.lobby_message (PlanVote.send_cast); solo, Net delivers them locally at once.
## Music (B5-03): solo and on the host the bottom bar carries a MusicPicker (writes profile.music_choice and
## saves; MenuFlow puts it into options["music_track"]); co-op clients get none (the lobby shows the host's pick).
## Keyboard / gamepad: arrows move between markers (by position) and lists; Enter / A picks; Esc / B
## leaves the asset list (back to its marker), or leaves the screen.
class_name PreplanningScreen
extends UiScreen

signal confirmed(plan: Dictionary)

## Plan lines listed in the side panel before "+n more".
const PLAN_LINES_MAX: int = 6

@export var profile_slot: int = 0
@export var save_on_confirm: bool = true
## Show the music pick (B5-03). MenuFlow clears it on co-op clients (the host's pick wins); standalone the
## screen also hides it when this peer is not the Net authority.
@export var music_enabled: bool = true

var heist_id: StringName = &""
var difficulty: int = Enums.Difficulty.ROUTINE
var profile: PlayerProfile
var board: PreplanBoard
var plan: PreplanPlan
var tweak: PreplanTweak
var local_slot: int = 0
## &"" = crew assets tab
var selected_point: StringName = &""

var blueprint_view: BlueprintView
var crew_button: Button
var floor_buttons: Array[Button] = []
var asset_buttons: Array[Button] = []
## Asset id per entry of asset_buttons.
var asset_button_ids: Array[StringName] = []
var favors_label: Label
var favors_bar: ProgressBar
var cash_label: Label
var point_title: Label
var point_meta: Label
var detail_label: Label
var reason_label: Label
var plan_label: Label
var vote_label: Label
var placeholder_label: Label
## Heist accent strip beside the title (UiAccent, B4-07).
var accent_strip: ColorRect
var back_button: Button
var confirm_button: Button
## Heist music pick (B5-03); null on a co-op client.
var music_picker: MusicPicker = null
var _list: VBoxContainer
var _built: bool = false


func setup(p_heist_id: StringName, p_difficulty: int, p: PlayerProfile = null) -> void:
	heist_id = p_heist_id
	difficulty = p_difficulty
	if p != null:
		profile = p
	if _built:
		_rebuild()


func build_ui() -> void:
	tweak = PreplanTweak.load_default()
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	if heist_id == &"":
		var ids: Array[StringName] = HeistCatalog.ids()
		heist_id = ids[0] if not ids.is_empty() else &""
	_init_plan()
	var root: VBoxContainer = UiBuild.vbox(14)
	UiBuild.screen_margin(self, root, 48)
	root.add_child(_build_top())
	var body: HBoxContainer = UiBuild.hbox(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_map_column())
	body.add_child(_build_panel())
	root.add_child(_build_bottom())
	_built = true
	_wire_static_focus()
	show_crew_assets()


func focus_default() -> void:
	if not is_visible_in_tree():
		return
	var first: Array[Control] = []
	for pid: StringName in blueprint_view.marker_ids() if blueprint_view != null else ([] as Array[StringName]):
		first.append(blueprint_view.markers[pid] as Control)
	first.append(crew_button)
	UiNav.focus_first(first)


## The local player's spending cash minus their share of the plan.
func cash_left() -> int:
	return profile.cash - plan.cash_cost(local_slot)


func cash_by_slot() -> Dictionary:
	return {local_slot: profile.cash}


## Show the assets of one point.
func show_point(point_id: StringName) -> void:
	selected_point = point_id
	var p: Dictionary = board.blueprint.point(point_id)
	point_title.text = UiText.t(StringName(p.get("label", &"")))
	point_meta.text = UiText.t(StringName("ui.preplan.category.%s" % p.get("category", &"")))
	_fill_list(board.assets_for_point(point_id))
	refresh()


func show_crew_assets() -> void:
	selected_point = &""
	point_title.text = UiText.t(&"ui.preplan.crew_assets")
	point_meta.text = UiText.t(&"ui.preplan.crew_assets_meta")
	_fill_list(board.crew_assets())
	refresh()


## Buy (or vote for) `asset_id` at the selected point. Returns the PreplanPlan reason (&"" = done;
## for a vote: sent, applied when Net delivers it, which solo is immediate).
func buy(asset_id: StringName) -> StringName:
	var a: PreplanAssetDef = board.asset(asset_id)
	var r: StringName = PreplanPlan.OK
	if a != null and a.vote_group != &"":
		r = _can_take(asset_id)
		if r == PreplanPlan.OK:
			PlanVote.send_cast(PlanVote.option_key(asset_id, selected_point))
	else:
		r = plan.add(asset_id, selected_point, local_slot, cash_by_slot())
	reason_label.text = "" if r == PreplanPlan.OK else _reason_text(r, asset_id)
	refresh()
	return r


func remove(asset_id: StringName) -> bool:
	var a: PreplanAssetDef = board.asset(asset_id)
	var ok: bool = true
	if a != null and a.vote_group != &"":
		PlanVote.send_retract(a.vote_group)
	else:
		ok = plan.remove(asset_id, selected_point, local_slot)
	reason_label.text = ""
	refresh()
	return ok


## Net.lobby_message: apply plan votes from any peer (the local player's own votes come back here too).
func on_lobby_message(from_peer: int, kind: StringName, data: Dictionary) -> void:
	if plan == null or not PlanVote.is_vote_message(kind):
		return
	var slot: int = Net.slot_of_peer(from_peer)
	if slot < 0 and from_peer == Net.local_peer_id():
		slot = local_slot
	if slot < 0:
		return
	var r: StringName = plan.receive_vote(slot, kind, data)
	if r != PreplanPlan.OK:
		Log.warn(&"preplan", "vote from slot %d rejected: %s" % [slot, r])
	refresh()


## Is `asset_id` part of the plan at the selected point (for a vote option: is it the local vote)?
func is_selected(asset_id: StringName) -> bool:
	var a: PreplanAssetDef = board.asset(asset_id)
	if a != null and a.vote_group != &"":
		return plan.votes.vote_of(local_slot, a.vote_group) == PlanVote.option_key(asset_id, selected_point)
	return plan.has(asset_id, selected_point)


func toggle(asset_id: StringName) -> void:
	if is_selected(asset_id):
		remove(asset_id)
	else:
		buy(asset_id)


func confirm() -> bool:
	var errs: Array[String] = plan.validate(cash_by_slot())
	if not errs.is_empty():
		reason_label.text = UiText.t(&"ui.preplan.invalid")
		Log.warn(&"preplan", "plan invalid: %s" % ", ".join(errs))
		return false
	plan.charge_profile(profile, local_slot)
	if save_on_confirm:
		SaveService.save_profile(profile, profile_slot)
	confirmed.emit(plan.apply())
	return true


func refresh() -> void:
	if not _built:
		return
	favors_label.text = UiText.t(&"ui.preplan.favors", {"used": plan.favors_used(), "budget": board.favors_budget})
	favors_bar.value = float(plan.favors_used()) / float(maxi(board.favors_budget, 1))
	cash_label.text = UiText.t(&"ui.preplan.cash", {
		"cash": UiText.money(profile.cash), "cost": UiText.money(plan.cash_cost(local_slot)),
		"left": UiText.money(cash_left()),
	})
	for i: int in range(asset_buttons.size()):
		_refresh_row(asset_buttons[i], asset_button_ids[i])
	plan_label.text = _plan_text()
	vote_label.text = _vote_text()
	blueprint_view.refresh(plan, selected_point)
	crew_button.set_pressed_no_signal(selected_point == &"")
	_wire_exits()


## RT walk (r276): on a floor whose markers all sit low (RT's underpass) the markers, the asset list and the bottom
## row formed a closed arrow-key loop with no way back up to the tabs. The asset list's first row and the
## northernmost marker always lead Up to the active tab (the crew tab, else the floor shown).
func _wire_exits() -> void:
	var tab: Control = crew_button
	if selected_point != &"" and blueprint_view.floor_index < floor_buttons.size():
		tab = floor_buttons[blueprint_view.floor_index]
	if not asset_buttons.is_empty():
		asset_buttons[0].set_focus_neighbor(SIDE_TOP, asset_buttons[0].get_path_to(tab))
	# RT walk: a floor switch rebuilds the markers, so Left from the list pointed at a freed marker (an invalid
	# neighbour path: Left did nothing). Re-aim it at the anchor that exists now (the marker, else the crew tab).
	var anchor: Control = _anchor_control()
	for b: Button in asset_buttons:
		b.set_focus_neighbor(SIDE_LEFT, b.get_path_to(anchor))
	var top: Control = null
	var top_z: float = INF
	for pid: StringName in blueprint_view.marker_ids():
		var z: float = (board.blueprint.point(pid).get("pos", Vector2.ZERO) as Vector2).y
		if z < top_z:
			top_z = z
			top = blueprint_view.markers[pid] as Control
	if top != null:
		top.set_focus_neighbor(SIDE_TOP, top.get_path_to(tab))


func _enter_tree() -> void:
	if not Net.lobby_message.is_connected(on_lobby_message):
		Net.lobby_message.connect(on_lobby_message)


func _exit_tree() -> void:
	if Net.lobby_message.is_connected(on_lobby_message):
		Net.lobby_message.disconnect(on_lobby_message)


func _init_plan() -> void:
	board = PreplanBoard.build(heist_id, difficulty, null, tweak)
	local_slot = maxi(Net.local_slot(), 0)
	var voters: Array[int] = Net.human_slots()
	if voters.is_empty():
		voters = [local_slot]
	var host: int = Net.slot_of_peer(1)
	plan = PreplanPlan.new(board, host if host >= 0 else local_slot, voters)


func _rebuild() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	floor_buttons.clear()
	asset_buttons.clear()
	asset_button_ids.clear()
	focus_chain.clear()
	_built = false
	build_ui()
	focus_default()


func _build_top() -> HBoxContainer:
	# PO-4 Case File header: the heist and difficulty as the breadcrumb (heist accent) over the H1.
	var top: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	accent_strip = UiAccent.strip(UiAccent.for_heist(heist_id), 3.0)
	top.add_child(accent_strip)
	var head: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	var sub: Label = UiBuild.caption()
	sub.add_theme_color_override(&"font_color", UiAccent.text_color(heist_id, UiAccent.app_bg()))
	sub.text = "%s  ·  %s" % [UiText.t(StringName("heist.%s.name" % heist_id)), UiText.t(UiText.difficulty_key(difficulty))]
	head.add_child(sub)
	head.add_child(UiBuild.label(&"ui.preplan.title", UiBuild.HEADER))
	top.add_child(head)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	placeholder_label = UiBuild.caption(&"ui.preplan.placeholder")
	placeholder_label.add_theme_color_override(&"font_color", tweak.placeholder_color)
	placeholder_label.size_flags_vertical = Control.SIZE_SHRINK_END
	placeholder_label.visible = board.blueprint.placeholder
	top.add_child(placeholder_label)
	return top


## True when `l`'s whole text fits its width on one line.
static func hint_fits(l: Label) -> bool:
	var font: Font = l.get_theme_font(&"font")
	var fs: int = l.get_theme_font_size(&"font_size")
	return font == null or font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= l.size.x + 0.5


func _build_map_column() -> VBoxContainer:
	var col: VBoxContainer = UiBuild.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# r229 menu walk: with the MAP caption a 4-floor heist's tab row was 20 units wider than the 1920 canvas and pushed
	# Confirm off screen. The row wraps instead of widening the screen.
	var bar: HFlowContainer = HFlowContainer.new()
	bar.add_theme_constant_override(&"h_separation", 10)
	bar.add_theme_constant_override(&"v_separation", 6)
	crew_button = UiBuild.tab(_small_button(&"ui.preplan.crew_assets"))
	crew_button.name = "CrewButton"
	crew_button.pressed.connect(_on_crew_pressed)
	bar.add_child(crew_button)
	# RT-B1 capture: the board opened on floor 0 (OF's basement, RT's underpass); it opens where the crew starts, as the
	# briefing's blueprint does (entry_floor).
	var entry: int = board.blueprint.entry_floor()
	if board.blueprint.floor_count() > 1:
		# LEAD r229 real-input run: the crew tab and the floor tabs are separate choices (no map point picked / the
		# floor shown) and both showed "selected"; a divider and a MAP caption make the floors their own group.
		var sep: VSeparator = VSeparator.new()
		sep.custom_minimum_size = Vector2(UiTokens.S3, 0)
		bar.add_child(sep)
		var cap: Label = UiBuild.caption(&"ui.preplan.floor_caption")
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(cap)
		for i: int in range(board.blueprint.floor_count()):
			var fb: Button = UiBuild.tab(_small_button(board.blueprint.floor_names[i]))
			fb.name = "FloorTab%d" % i
			fb.set_pressed_no_signal(i == entry)
			fb.pressed.connect(_on_floor.bind(i))
			bar.add_child(fb)
			floor_buttons.append(fb)
	var hint: Label = UiBuild.label(&"ui.preplan.map_hint", UiBuild.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# GN-B1 capture: with four floor tabs the hint was cut to "Pick" at 720p and 1080p. It shows whole or not
	# at all (alpha, so the row's layout does not change).
	hint.resized.connect(func() -> void: hint.self_modulate.a = 1.0 if hint_fits(hint) else 0.0)
	bar.add_child(hint)
	col.add_child(bar)
	blueprint_view = BlueprintView.new()
	blueprint_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blueprint_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blueprint_view.custom_minimum_size = Vector2(720, 480)
	col.add_child(blueprint_view)
	blueprint_view.setup(board)
	blueprint_view.set_floor(entry)
	blueprint_view.point_pressed.connect(_on_point_pressed)
	return col


func _build_panel() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(8)
	v.custom_minimum_size = Vector2(620, 0)
	favors_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	v.add_child(favors_label)
	favors_bar = UiBuild.bar(tweak.point_owned_color, Vector2(240, 12))
	v.add_child(favors_bar)
	cash_label = UiBuild.label(&"", UiBuild.DIM)
	v.add_child(cash_label)
	v.add_child(HSeparator.new())
	point_title = UiBuild.label(&"", UiBuild.SUBHEADER)
	point_meta = UiBuild.label(&"", UiBuild.DIM)
	v.add_child(point_title)
	v.add_child(point_meta)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_list = UiBuild.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	v.add_child(scroll)
	detail_label = _wrap_label(UiBuild.DIM)
	detail_label.custom_minimum_size = Vector2(0, 52)
	v.add_child(detail_label)
	reason_label = _wrap_label(&"")
	reason_label.add_theme_color_override(&"font_color", tweak.reason_color)
	v.add_child(reason_label)
	v.add_child(HSeparator.new())
	v.add_child(UiBuild.label(&"ui.preplan.your_plan", UiBuild.DIM))
	plan_label = _wrap_label(&"")
	plan_label.add_theme_font_size_override(&"font_size", 21)
	v.add_child(plan_label)
	vote_label = _wrap_label(UiBuild.DIM)
	v.add_child(vote_label)
	return UiBuild.panel(v)


func _build_bottom() -> HBoxContainer:
	var bottom: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	back_button = UiBuild.back(UiBuild.button(&"ui.menu.back"))
	back_button.name = "BackButton"
	confirm_button = UiBuild.primary(UiBuild.button(&"ui.preplan.confirm"))
	confirm_button.name = "ConfirmButton"
	back_button.pressed.connect(back_requested.emit)
	confirm_button.pressed.connect(confirm)
	bottom.add_child(back_button)
	music_picker = null
	if music_enabled and Net.is_authority():
		music_picker = MusicPicker.new()
		music_picker.name = "MusicPicker"
		music_picker.profile_slot = profile_slot
		music_picker.save_on_change = save_on_confirm
		music_picker.setup(profile, heist_id)
		bottom.add_child(music_picker)
	var hint: Label = UiBuild.label(&"ui.preplan.hint", UiBuild.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override(&"font_size", UiTokens.FONT_SMALL)
	bottom.add_child(hint)
	bottom.add_child(confirm_button)  # the one commit action, bottom right
	return bottom


func _fill_list(ids: Array[StringName]) -> void:
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	asset_buttons.clear()
	asset_button_ids.clear()
	for id: StringName in ids:
		var b: Button = _small_button(&"")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(toggle.bind(id))
		b.focus_entered.connect(_show_detail.bind(id))
		b.mouse_entered.connect(_show_detail.bind(id))
		_list.add_child(b)
		asset_buttons.append(b)
		asset_button_ids.append(id)
	if ids.is_empty():
		var l: Label = UiBuild.label(&"ui.preplan.nothing_here", UiBuild.DIM)
		_list.add_child(l)
	var rows: Array[Control] = []
	rows.assign(asset_buttons)
	UiNav.chain_vertical(rows, false)
	var anchor: Control = _anchor_control()
	for b2: Button in asset_buttons:
		b2.set_focus_neighbor(SIDE_LEFT, b2.get_path_to(anchor))
	if not asset_buttons.is_empty():
		asset_buttons[asset_buttons.size() - 1].set_focus_neighbor(SIDE_BOTTOM,
				asset_buttons[asset_buttons.size() - 1].get_path_to(confirm_button))
		_show_detail(asset_button_ids[0])
	else:
		detail_label.text = ""
	reason_label.text = ""


func _refresh_row(b: Button, id: StringName) -> void:
	var a: PreplanAssetDef = board.asset(id)
	var args: Dictionary = {
		"name": UiText.t(UiText.item_key(id)), "cost": UiText.money(board.cost_of(id)), "favors": favor_text(a.favors),
	}
	var key: StringName = &"ui.preplan.row"
	if is_selected(id):
		key = &"ui.preplan.row_vote_cast" if a.vote_group != &"" else &"ui.preplan.row_owned"
	elif a.vote_group != &"":
		key = &"ui.preplan.row_vote"
	b.text = UiText.t(key, args)
	var ok: bool = is_selected(id) or _can_take(id) == PreplanPlan.OK
	b.modulate = Color(1, 1, 1) if ok else Color(1, 1, 1, 0.5)


## "1 favor" / "3 favors".
static func favor_text(n: int) -> String:
	return UiText.t(&"ui.preplan.favor_count.one") if n == 1 else UiText.t(&"ui.preplan.favor_count.many", {"n": n})


func _can_take(id: StringName) -> StringName:
	var a: PreplanAssetDef = board.asset(id)
	if a != null and a.vote_group != &"":
		var probe: PreplanPlan = PreplanPlan.from_dict(board, plan.to_dict())
		return probe.vote(local_slot, id, selected_point, cash_by_slot())
	return plan.can_add(id, selected_point, local_slot, cash_by_slot())


func _show_detail(id: StringName) -> void:
	var a: PreplanAssetDef = board.asset(id)
	if a == null:
		return
	var tags: Array[String] = []
	for t: StringName in a.tags:
		tags.append(UiText.t(StringName("ui.preplan.tag.%s" % t)))
	var desc: String = UiText.t(StringName("item.%s.desc" % id))
	detail_label.text = desc if tags.is_empty() else "%s\n%s" % [desc, UiText.t(&"ui.preplan.tags", {"tags": ", ".join(tags)})]
	var r: StringName = PreplanPlan.OK if is_selected(id) else _can_take(id)
	reason_label.text = "" if r == PreplanPlan.OK else _reason_text(r, id)


func _reason_text(r: StringName, id: StringName) -> String:
	return UiText.t(StringName("ui.preplan.reason.%s" % r), {
		"cost": UiText.money(board.cost_of(id)), "favors": favor_text(board.favors_of(id)),
		"left": plan.favors_left(), "cash": UiText.money(cash_left()),
	})


func _plan_text() -> String:
	if plan.selections.is_empty():
		return UiText.t(&"ui.preplan.plan_empty")
	var lines: Array[String] = []
	var sel: Array = plan.to_dict()["selections"] as Array
	for s: Dictionary in sel.slice(0, PLAN_LINES_MAX):
		var id: StringName = StringName(s["asset"])
		var pid: StringName = StringName(s["point"])
		var where: String = UiText.t(StringName(board.blueprint.point(pid).get("label", &""))) if pid != &"" \
				else UiText.t(&"ui.preplan.crew_short")
		var num: Variant = blueprint_view.marker_numbers.get(pid)
		if num != null:
			where = "%s %s" % [num, where]
		lines.append(UiText.t(&"ui.preplan.plan_line", {
			"name": UiText.t(UiText.item_key(id)), "where": where, "cost": UiText.money(board.cost_of(id)),
		}))
	if sel.size() > PLAN_LINES_MAX:
		lines.append(UiText.t(&"ui.preplan.plan_more", {"n": sel.size() - PLAN_LINES_MAX}))
	return "\n".join(lines)


func _vote_text() -> String:
	var groups: Array[StringName] = []
	for id: StringName in board.asset_ids():
		var g: StringName = board.asset(id).vote_group
		if g != &"" and not groups.has(g):
			groups.append(g)
	var lines: Array[String] = []
	for g: StringName in groups:
		var w: StringName = plan.votes.winner(g)
		var choice: String = UiText.t(&"ui.preplan.vote_none")
		if w != &"":
			var o: Dictionary = PlanVote.parse_option(w)
			choice = UiText.t(StringName(board.blueprint.point(StringName(o["point"])).get("label", &"")))
		var pr: Vector2i = plan.votes.progress(g)
		lines.append(UiText.t(&"ui.preplan.vote_line", {
			"group": UiText.t(StringName("ui.preplan.vote_group.%s" % g)), "choice": choice,
			"cast": pr.x, "voters": maxi(pr.y, plan.votes.voters.size()),
		}))
	if plan.votes.voters.size() <= 1:
		lines.append(UiText.t(&"ui.preplan.vote_solo"))
	else:
		lines.append(UiText.t(&"ui.preplan.vote_host_ties"))
	return "\n".join(lines)


func _wire_static_focus() -> void:
	# Left to right as laid out: Back, Music, Confirm (bottom right).
	var bottom_row: Array[Control] = [back_button]
	if music_picker != null:
		bottom_row.append(music_picker.option)
	bottom_row.append(confirm_button)
	UiNav.chain_horizontal(bottom_row, false)
	var row: Array[Control] = [crew_button]
	row.append_array(floor_buttons)
	UiNav.chain_horizontal(row, false)


## Where focus returns when leaving the asset list: the selected marker, or the crew tab.
func _anchor_control() -> Control:
	if selected_point != &"" and blueprint_view.markers.has(selected_point):
		return blueprint_view.markers[selected_point] as Control
	return crew_button


func _on_point_pressed(point_id: StringName) -> void:
	show_point(point_id)
	if not asset_buttons.is_empty():
		asset_buttons[0].grab_focus()


func _on_crew_pressed() -> void:
	show_crew_assets()
	if not asset_buttons.is_empty():
		asset_buttons[0].grab_focus()


func _on_floor(i: int) -> void:
	for j: int in range(floor_buttons.size()):
		floor_buttons[j].set_pressed_no_signal(j == i)
	blueprint_view.set_floor(i)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		var f: Control = get_viewport().gui_get_focus_owner()
		if f != null and asset_buttons.has(f):
			get_viewport().set_input_as_handled()
			_anchor_control().grab_focus()
			return
	super(event)


func _small_button(key: StringName) -> Button:
	var b: Button = UiBuild.button(key)
	b.custom_minimum_size = Vector2(0, 0)
	return b


func _wrap_label(variation: StringName) -> Label:
	var l: Label = UiBuild.label(&"", variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	return l
