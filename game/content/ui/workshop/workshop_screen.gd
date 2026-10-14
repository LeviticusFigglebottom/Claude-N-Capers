## The weapon workshop (B4-17, pd2_fidelity P6). Owner: ENV B.
## Left: every weapon (owned; for sale with its price; locked with its unlock level). Centre: the 3D
## WorkshopStage (assembled WeaponVisual on a turntable, orbit / zoom / pan, slot focus with a marker
## gizmo). Right: the weapon's mod slots, the parts of the selected slot (unowned parts dimmed with their
## price or source), live StatCalculator numbers with green / red deltas against the weapon equipped in
## the same slot, and the concealment total + detection risk the loadout would have (LoadoutResolver).
## Footer: Back, Buy (the selected weapon or part, spending cash, disabled when short) and Equip (writes
## the loadout's primary / secondary + mods and saves the profile).
## Finish picker (B7-04, WorkshopFinishPanel) under the parts: previews a finish live on the turntable model
## (WeaponVisual.apply_finish), shows locked finishes with how to earn them, and "Apply Finish" saves it to the
## profile (WeaponFinishes; PlayerProfile.weapon_finishes from save v7).
## Rules live in WorkshopModel; this script only shows them. Opened from the loadout screen's Workshop
## button (armory station in the safehouse, and the heist path); Back = back_requested.
class_name WorkshopScreen
extends UiScreen

## The loadout changed (equip) or something was bought; the profile is already saved.
signal profile_changed()

const STAT_ROWS: Array[Array] = [
	["damage", &"ui.stat.damage"], ["accuracy", &"ui.stat.accuracy"], ["stability", &"ui.stat.stability"],
	["concealment", &"ui.stat.concealment"], ["threat", &"ui.stat.threat"], ["mag", &"ui.stat.magazine"],
	["total_ammo", &"ui.stat.total_ammo"], ["rof", &"ui.stat.rate_of_fire"], ["reload", &"ui.stat.reload"],
]
const LIST_ROW_PX: int = 40

## Profile slot (SaveService) this screen edits.
@export var profile_slot: int = 0

var profile: PlayerProfile
var model: WorkshopModel
var stage: WorkshopStage
var weapon_list: ItemList
var parts_list: ItemList
## ModType (int) -> its slot Button.
var slot_buttons: Dictionary = {}
var overview_button: Button
var buy_button: Button
var equip_button: Button
var back_button: Button
## D-106: stats with skills (default) or base values; boosted values are marked (SkillBoost).
var stats_mode_button: Button
## "* boosted by your skills" legend, shown when a value is marked.
var boosted_legend: Label
var cash_label: Label
var weapon_name_label: Label
var weapon_status_label: Label
var part_status_label: Label
var part_desc_label: Label
var concealment_label: Label
var detection_risk_label: Label
var compare_label: Label
var message_label: Label
## Selected mod slot (ModType int, -1 = none / weapon without slots).
var selected_slot: int = -1
## Stat key -> value / delta Label.
var stat_value_labels: Dictionary = {}
var stat_delta_labels: Dictionary = {}
## Finish picker (B7-04).
var finish_panel: WorkshopFinishPanel

var _hud_tweak: HudTweak
var _slot_flow: HFlowContainer
## Row index -> weapon id (&"" for section headers).
var _weapon_rows: Array[StringName] = []


## Optional: inject a profile before the screen enters the tree (tests, LoadoutScreen).
func setup(p: PlayerProfile) -> void:
	profile = p


func build_ui() -> void:
	_hud_tweak = HudTweak.load_default()
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	model = WorkshopModel.new(profile)
	var bg: ColorRect = ColorRect.new()
	bg.color = UiAccent.app_bg()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root: VBoxContainer = UiBuild.vbox(16)
	UiBuild.screen_margin(self, root, 48)
	root.add_child(_build_header())
	var body: HBoxContainer = UiBuild.hbox(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_weapon_column())
	body.add_child(_build_stage_column())
	body.add_child(_build_mod_column())
	root.add_child(_build_footer())
	_fill_weapon_list()
	var start: StringName = profile.loadout.primary if profile.loadout.primary != &"" else profile.loadout.secondary
	select_weapon(start if start != &"" else WorkshopModel.weapon_ids()[0])
	focus_chain.append_array([weapon_list, parts_list, finish_panel.list, finish_panel.equip_button, equip_button, buy_button,
			stats_mode_button, back_button] as Array[Control])
	_wire_focus.call_deferred()


## Preview weapon `id` (its equipped mods when it is in the loadout, else stock).
func select_weapon(id: StringName) -> void:
	model.select_weapon(id)
	var row: int = _weapon_rows.find(id)
	if row >= 0 and (not weapon_list.is_selected(row)):
		weapon_list.select(row)
		weapon_list.ensure_current_is_visible()
	_rebuild_slots()
	var first: int = model.slots()[0] if not model.slots().is_empty() else -1
	selected_slot = -1
	_rebuild_visual()
	finish_panel.set_weapon(id, model.weapon_state(id) == WorkshopModel.ItemState.OWNED)
	stage.reset_view()
	if first >= 0:
		_show_slot(first, false)
	else:
		parts_list.clear()
	refresh()


## Select mod slot `mod_type`: the parts list shows its choices and the camera focuses its marker.
func select_slot(mod_type: int) -> void:
	_show_slot(mod_type, true)
	refresh()


## Pick `mod_id` (&"" = stock / none) in the selected slot; the model updates at once.
func select_part(mod_id: StringName) -> void:
	if selected_slot < 0:
		return
	model.pick(selected_slot, mod_id)
	_rebuild_visual()
	if stage.focused_slot != selected_slot:
		stage.focus_slot(selected_slot)
	_fill_parts()
	refresh()


## Buy the selected weapon when unowned, else the selected part. Saves on success.
func buy_selected() -> bool:
	var ok: bool = false
	var item: StringName = _purchase_item()
	if item == &"":
		return false
	if item == model.weapon_id:
		ok = model.buy_weapon(item)
	else:
		ok = model.buy_mod(item)
	if ok:
		_save(&"ui.workshop.bought")
		_fill_weapon_list()
		_fill_parts()
	refresh()
	return ok


## Equip the preview build in its loadout slot and save. False when blocked (unowned weapon / parts).
func equip_selected() -> bool:
	if not model.equip():
		refresh()
		return false
	_save(&"ui.workshop.saved")
	_fill_weapon_list()
	refresh()
	return true


## Preview finish `id` (&"" = stock) on the turntable model without equipping it.
func select_finish(id: StringName) -> bool:
	return finish_panel.preview(id)


## Apply the previewed finish to the previewed weapon and save. False when locked / the weapon is not owned.
func equip_finish() -> bool:
	return finish_panel.equip_preview()


## Recompute stats, detection risk, item statuses and the buttons from the model.
func refresh() -> void:
	cash_label.text = UiText.money(profile.cash)
	var w: WeaponDef = model.weapon()
	weapon_name_label.text = UiText.t(UiText.item_key(w.id)) if w != null else ""
	weapon_status_label.text = _weapon_status(model.weapon_id)
	_refresh_stats()
	_refresh_part_status()
	_refresh_buttons()
	var owned: bool = w != null and model.weapon_state(w.id) == WorkshopModel.ItemState.OWNED
	if finish_panel.weapon_owned != owned:
		finish_panel.weapon_owned = owned
		finish_panel.refresh()


func _build_header() -> HBoxContainer:
	var h: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	var titles: VBoxContainer = UiBuild.header(&"ui.workshop.crumb", &"ui.workshop.title")
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(titles)
	cash_label = UiBuild.label(&"", UiBuild.MONEY)
	var cash: VBoxContainer = UiBuild.field(&"ui.workshop.cash_caption", cash_label)
	cash.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(cash)
	return h


func _build_weapon_column() -> Control:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.custom_minimum_size = Vector2(400, 0)
	v.add_child(UiBuild.caption(&"ui.workshop.weapons"))
	weapon_list = _item_list()
	weapon_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_list.item_selected.connect(_on_weapon_row)
	v.add_child(weapon_list)
	return v


func _build_stage_column() -> Control:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var names: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	weapon_name_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	weapon_status_label = UiBuild.caption()
	weapon_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weapon_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	names.add_child(weapon_name_label)
	names.add_child(weapon_status_label)
	v.add_child(names)
	var box: Control = Control.new()
	box.custom_minimum_size = Vector2(560, 360)
	stage = WorkshopStage.new()
	stage.name = "Stage"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(stage)
	var hint: Label = UiBuild.caption(&"ui.workshop.hint")
	hint.uppercase = false
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = UiTokens.S3
	hint.offset_right = -UiTokens.S3
	hint.offset_top = -UiTokens.S7
	hint.offset_bottom = -UiTokens.S2
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(hint)
	stage.view_changed.connect(func() -> void: hint.visible = stage.focused_slot < 0)
	var frame: PanelContainer = UiBuild.panel(box)
	var sb: StyleBoxFlat = UiThemeFactory.box(Color.TRANSPARENT, UiTokens.LINE, 1, UiTokens.CUT, Vector2(1, 1))
	sb.draw_center = false
	frame.add_theme_stylebox_override(&"panel", sb)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(frame)
	v.add_child(_build_stats_panel())
	return v


func _build_mod_column() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, 0)
	scroll.follow_focus = true
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	v.add_child(UiBuild.caption(&"ui.workshop.slots"))
	_slot_flow = HFlowContainer.new()
	_slot_flow.add_theme_constant_override(&"h_separation", UiTokens.S1)
	_slot_flow.add_theme_constant_override(&"v_separation", UiTokens.S2)
	v.add_child(_slot_flow)
	parts_list = _item_list()
	parts_list.custom_minimum_size = Vector2(0, LIST_ROW_PX * 3 + 12)
	parts_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts_list.item_selected.connect(_on_part_row)
	v.add_child(parts_list)
	part_status_label = UiBuild.label()
	part_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(part_status_label)
	part_desc_label = UiBuild.label(&"", UiBuild.DIM)
	part_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(part_desc_label)
	finish_panel = WorkshopFinishPanel.new()
	finish_panel.name = "FinishPanel"
	finish_panel.build(profile, _item_list())
	finish_panel.preview_changed.connect(_on_finish_preview)
	finish_panel.finish_equipped.connect(_on_finish_equipped)
	v.add_child(finish_panel)
	return scroll


## Stats against the equipped weapon (caption names, body values, green / red deltas) over the
## concealment and Detection Risk the loadout would have.
func _build_stats_panel() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	compare_label = UiBuild.caption()
	v.add_child(compare_label)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
	grid.add_theme_constant_override(&"v_separation", 0)
	v.add_child(grid)
	for row: Array in STAT_ROWS:
		var name_l: Label = UiBuild.caption(StringName(row[1]))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(name_l)
		var val: Label = UiBuild.label()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size = Vector2(70, 0)
		var dl: Label = UiBuild.label()
		dl.custom_minimum_size = Vector2(70, 0)
		grid.add_child(val)
		grid.add_child(dl)
		stat_value_labels[row[0]] = val
		stat_delta_labels[row[0]] = dl
	boosted_legend = UiBuild.caption(&"ui.stats.boosted_legend")
	boosted_legend.uppercase = false
	v.add_child(boosted_legend)
	v.add_child(HSeparator.new())
	var dr: HBoxContainer = UiBuild.hbox(UiTokens.S6)
	concealment_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	detection_risk_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	dr.add_child(UiBuild.field(&"ui.workshop.loadout_concealment", concealment_label))
	dr.add_child(UiBuild.field(&"ui.stat.detection_risk", detection_risk_label))
	v.add_child(dr)
	return UiBuild.panel(v)


## PO-4 footer: Back (ghost) left, the last message, then Buy and Equip (the one primary) on the right.
func _build_footer() -> HBoxContainer:
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.custom_minimum_size = Vector2(220, 0)
	back_button.pressed.connect(back_requested.emit)
	buy_button = UiBuild.button(&"ui.workshop.buy_none")
	buy_button.custom_minimum_size = Vector2(380, 0)
	buy_button.pressed.connect(func() -> void: UiSfx.check(buy_selected()))
	equip_button = UiBuild.button(&"ui.workshop.equip")
	equip_button.custom_minimum_size = Vector2(380, 0)
	equip_button.pressed.connect(equip_selected)
	message_label = UiBuild.label(&"", UiBuild.DIM)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stats_mode_button = UiBuild.ghost(UiBuild.button(&"ui.stats.with_skills"))
	stats_mode_button.pressed.connect(toggle_skills)
	return UiBuild.footer(back_button, equip_button, [stats_mode_button, message_label, buy_button] as Array[Control])


## D-106: switch the stat panel between skill-boosted (default) and base values.
func toggle_skills() -> void:
	model.with_skills = not model.with_skills
	stats_mode_button.text = UiText.t(&"ui.stats.with_skills" if model.with_skills else &"ui.stats.base")
	_refresh_stats()


func _item_list() -> ItemList:
	var l: ItemList = ItemList.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.focus_mode = Control.FOCUS_ALL
	l.select_mode = ItemList.SELECT_SINGLE
	l.allow_reselect = true
	l.max_columns = 1
	var panel: StyleBoxFlat = (UiBuild.theme().get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat).duplicate() as StyleBoxFlat
	panel.set_content_margin_all(6)
	l.add_theme_stylebox_override(&"panel", panel)
	var focus: StyleBoxFlat = panel.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = UiBuild.theme().get_color(&"highlight", &"Screen")
	focus.set_border_width_all(2)
	l.add_theme_stylebox_override(&"focus", focus)
	var sel: StyleBoxFlat = StyleBoxFlat.new()
	sel.bg_color = UiTokens.INK_3  # PO-4: selection is ink + an edge, never a brass flood
	sel.border_color = UiTokens.PAPER_DIM
	sel.border_width_left = 4
	l.add_theme_stylebox_override(&"selected", sel)
	var sel_focus: StyleBoxFlat = sel.duplicate() as StyleBoxFlat
	sel_focus.border_color = UiBuild.theme().get_color(&"highlight", &"Screen")
	l.add_theme_stylebox_override(&"selected_focus", sel_focus)
	l.add_theme_constant_override(&"v_separation", 10)
	l.add_theme_color_override(&"font_color", UiBuild.theme().get_color(&"font_color", &"Label"))
	return l


func _fill_weapon_list() -> void:
	weapon_list.clear()
	_weapon_rows.clear()
	var last_slot: int = -1
	for id: StringName in WorkshopModel.weapon_ids():
		var w: WeaponDef = ContentDB.weapon(id)
		if int(w.slot) != last_slot:
			last_slot = int(w.slot)
			var head: int = weapon_list.add_item(UiText.t(
					&"ui.workshop.primaries" if w.slot == Enums.WeaponSlot.PRIMARY else &"ui.workshop.secondaries"))
			weapon_list.set_item_selectable(head, false)
			weapon_list.set_item_custom_fg_color(head, _dim_color())
			_weapon_rows.append(&"")
		var text: String = UiText.t(&"ui.workshop.entry", {"name": UiText.t(UiText.item_key(id)), "status": _weapon_tag(id)})
		var row: int = weapon_list.add_item(text)
		weapon_list.set_item_tooltip(row, UiText.t(StringName("item.%s.desc" % id)))
		if model.weapon_state(id) != WorkshopModel.ItemState.OWNED:
			weapon_list.set_item_custom_fg_color(row, _dim_color())
		_weapon_rows.append(id)
	var cur: int = _weapon_rows.find(model.weapon_id)
	if cur >= 0:
		weapon_list.select(cur)


func _rebuild_slots() -> void:
	for c: Node in _slot_flow.get_children():
		_slot_flow.remove_child(c)
		c.queue_free()
	slot_buttons.clear()
	var group: ButtonGroup = ButtonGroup.new()
	for t: int in model.slots():
		var b: Button = UiBuild.tab(UiBuild.button(_mod_type_key(t)))
		b.button_group = group
		b.pressed.connect(select_slot.bind(t))
		b.focus_entered.connect(_on_slot_focus.bind(t))
		_slot_flow.add_child(b)
		slot_buttons[t] = b
	overview_button = UiBuild.tab(UiBuild.button(&"ui.workshop.overview"))
	overview_button.toggle_mode = false
	overview_button.pressed.connect(_on_overview)
	_slot_flow.add_child(overview_button)
	if is_inside_tree():
		_wire_focus.call_deferred()


func _show_slot(t: int, focus_camera: bool) -> void:
	if not slot_buttons.has(t):
		return
	selected_slot = t
	for k: int in slot_buttons:
		(slot_buttons[k] as Button).set_pressed_no_signal(k == t)
	_fill_parts()
	if focus_camera:
		stage.focus_slot(t)


func _fill_parts() -> void:
	parts_list.clear()
	if selected_slot < 0:
		return
	var w: WeaponDef = model.weapon()
	var picked: StringName = model.picks.get(selected_slot, &"")
	for id: StringName in model.slot_options(selected_slot):
		var text: String
		if id == &"":
			var has_stock: bool = w.default_mods.has(selected_slot) or stage.visual.stock_part(selected_slot) != null
			text = UiText.t(&"ui.loadout.stock" if has_stock else &"ui.loadout.none")
		else:
			text = UiText.t(&"ui.workshop.entry", {"name": UiText.t(UiText.item_key(id)), "status": _mod_tag(id)})
		var row: int = parts_list.add_item(text)
		parts_list.set_item_metadata(row, id)
		if model.mod_state(id) != WorkshopModel.ItemState.OWNED:
			parts_list.set_item_custom_fg_color(row, _dim_color())
		if id == picked:
			parts_list.select(row)
	parts_list.ensure_current_is_visible()


func _rebuild_visual() -> void:
	stage.show_build(model.weapon(), model.applied_mods())


func _refresh_stats() -> void:
	var rows: Dictionary = model.stat_rows()
	var w: WeaponDef = model.weapon()
	var is_primary: bool = w != null and w.slot == Enums.WeaponSlot.PRIMARY
	var slot_key: StringName = &"ui.loadout.primary" if is_primary else &"ui.loadout.secondary"
	var equipped: StringName = profile.loadout.primary if is_primary else profile.loadout.secondary
	if equipped != &"":
		compare_label.text = UiText.t(&"ui.workshop.vs_equipped", {"slot": UiText.t(slot_key)})
	else:
		compare_label.text = UiText.t(&"ui.workshop.vs_stock")
	for k: Variant in stat_value_labels:
		var val: Label = stat_value_labels[k]
		var dl: Label = stat_delta_labels[k]
		dl.text = ""
		if rows.is_empty():
			val.text = "-"
			continue
		val.text = _fmt((rows["shown"] as Dictionary).get(k, 0))
		if (rows.get("boosted", []) as Array).has(String(k)):
			val.text = UiText.t(&"ui.stats.boosted_value", {"value": val.text})
		var deltas: Dictionary = rows["delta"]
		if deltas.has(k) and bool((deltas[k] as Dictionary)["changed"]):
			var d: Dictionary = deltas[k]
			var diff: float = float(d["diff"])
			dl.text = UiText.t(&"ui.loadout.stat_delta_up" if diff > 0.0 else &"ui.loadout.stat_delta_down",
					{"value": _fmt(absf(diff))})
			dl.add_theme_color_override(&"font_color", delta_color(bool(d["better"])))
	boosted_legend.visible = not rows.is_empty() and not (rows.get("boosted", []) as Array).is_empty()
	var dr: Dictionary = model.dr_preview()
	var c_diff: int = int(dr["concealment"]) - int(dr["current_concealment"])
	concealment_label.text = UiText.t(&"ui.workshop.concealment", {"value": dr["concealment"], "current": dr["current_concealment"]})
	detection_risk_label.text = UiText.t(&"ui.workshop.dr_preview", {"value": dr["detection_risk"], "current": dr["current_detection_risk"]})
	var dr_diff: int = int(dr["detection_risk"]) - int(dr["current_detection_risk"])
	for pair: Array in [[concealment_label, c_diff, c_diff > 0], [detection_risk_label, dr_diff, dr_diff < 0]]:
		var l: Label = pair[0]
		if int(pair[1]) == 0:
			l.remove_theme_color_override(&"font_color")
		else:
			l.add_theme_color_override(&"font_color", delta_color(bool(pair[2])))


## Green for better, red for worse (HudTweak.delta_better_color / delta_worse_color).
func delta_color(better: bool) -> Color:
	return _hud_tweak.delta_better_color if better else _hud_tweak.delta_worse_color


func _refresh_part_status() -> void:
	if selected_slot < 0:
		part_status_label.text = ""
		part_desc_label.text = ""
		return
	var id: StringName = model.picks.get(selected_slot, &"")
	if id == &"":
		var has_stock: bool = model.weapon().default_mods.has(selected_slot) or stage.visual.stock_part(selected_slot) != null
		part_status_label.text = UiText.t(&"ui.workshop.status.stock" if has_stock else &"ui.workshop.status.none")
		var stock: StringName = StringName(model.weapon().default_mods.get(selected_slot, &""))
		part_desc_label.text = UiText.t(StringName("item.%s.desc" % stock)) if stock != &"" else ""
		return
	part_desc_label.text = UiText.t(StringName("item.%s.desc" % id))
	var m: WeaponModDef = ContentDB.mod(id)
	match model.mod_state(id):
		WorkshopModel.ItemState.OWNED:
			part_status_label.text = UiText.t(&"ui.workshop.status.owned")
		WorkshopModel.ItemState.FOR_SALE:
			part_status_label.text = UiText.t(&"ui.workshop.status.mod_source", {"price": UiText.money(m.price)})
		_:
			part_status_label.text = UiText.t(&"ui.workshop.status.mod_unlock", {"source": String(m.unlock)})


func _refresh_buttons() -> void:
	var w: WeaponDef = model.weapon()
	var block: StringName = model.equip_block()
	if model.is_equipped():
		equip_button.text = UiText.t(&"ui.workshop.equipped")
		equip_button.disabled = true
	else:
		equip_button.text = UiText.t(&"ui.workshop.equip_as", {"slot": UiText.t(
				&"ui.loadout.primary" if w != null and w.slot == Enums.WeaponSlot.PRIMARY else &"ui.loadout.secondary")})
		equip_button.disabled = block != &""
	var item: StringName = _purchase_item()
	var price: int = _price_of(item)
	if item == &"":
		buy_button.text = UiText.t(&"ui.workshop.buy_none")
		buy_button.disabled = true
	else:
		buy_button.text = UiText.t(&"ui.workshop.buy", {"name": UiText.t(UiText.item_key(item)), "price": UiText.money(price)})
		buy_button.disabled = not model.can_afford(price)
	if item != &"" and not model.can_afford(price):
		message_label.text = UiText.t(&"ui.workshop.short_cash", {"amount": UiText.money(price - profile.cash)})
	elif w != null and model.weapon_state(w.id) == WorkshopModel.ItemState.LOCKED:
		message_label.text = UiText.t(&"ui.workshop.status.locked_level", {"level": w.unlock_level})
	elif block != &"" and not model.is_equipped():
		message_label.text = UiText.t(block)


## What Buy would buy: the previewed weapon when it is for sale, else (weapon owned) the selected part,
## then any other fitted part, that is for sale; &"" when nothing is buyable (owned, or locked weapon).
func _purchase_item() -> StringName:
	var wid: StringName = model.weapon_id
	if wid == &"" or model.weapon_state(wid) == WorkshopModel.ItemState.LOCKED:
		return &""
	if model.weapon_state(wid) == WorkshopModel.ItemState.FOR_SALE:
		return wid
	# The selected slot's part first, then any other fitted part that is for sale.
	var order: Array[int] = model.slots()
	if selected_slot >= 0:
		order.push_front(selected_slot)
	for t: int in order:
		var id: StringName = model.picks.get(t, &"")
		if id != &"" and model.mod_state(id) == WorkshopModel.ItemState.FOR_SALE:
			return id
	return &""


static func _price_of(item: StringName) -> int:
	if item == &"":
		return 0
	var w: WeaponDef = ContentDB.weapon(item) if String(item).begins_with("weapon.") else null
	if w != null:
		return w.price
	var m: WeaponModDef = ContentDB.mod(item)
	return m.price if m != null else 0


func _weapon_status(id: StringName) -> String:
	var w: WeaponDef = ContentDB.weapon(id)
	if w == null:
		return ""
	var slot: int = model.equipped_slot_of(id)
	if slot == Enums.WeaponSlot.PRIMARY:
		return UiText.t(&"ui.workshop.status.equipped_primary")
	if slot == Enums.WeaponSlot.SECONDARY:
		return UiText.t(&"ui.workshop.status.equipped_secondary")
	match model.weapon_state(id):
		WorkshopModel.ItemState.OWNED:
			return UiText.t(&"ui.workshop.status.owned")
		WorkshopModel.ItemState.FOR_SALE:
			return UiText.t(&"ui.workshop.status.for_sale", {"price": UiText.money(w.price)})
	return UiText.t(&"ui.workshop.status.locked_level", {"level": w.unlock_level})


## Short tag after a weapon's name in the list.
func _weapon_tag(id: StringName) -> String:
	if model.equipped_slot_of(id) >= 0:
		return UiText.t(&"ui.workshop.tag.equipped")
	var w: WeaponDef = ContentDB.weapon(id)
	match model.weapon_state(id):
		WorkshopModel.ItemState.OWNED:
			return UiText.t(&"ui.workshop.tag.owned")
		WorkshopModel.ItemState.FOR_SALE:
			return UiText.money(w.price)
	return UiText.t(&"ui.workshop.tag.level", {"level": w.unlock_level})


func _mod_tag(id: StringName) -> String:
	var m: WeaponModDef = ContentDB.mod(id)
	match model.mod_state(id):
		WorkshopModel.ItemState.OWNED:
			return UiText.t(&"ui.workshop.tag.owned")
		WorkshopModel.ItemState.FOR_SALE:
			return UiText.money(m.price)
	return UiText.t(&"ui.workshop.tag.locked")


static func _mod_type_key(mod_type: int) -> StringName:
	return StringName("ui.mod_type.%s" % String(Enums.ModType.keys()[mod_type]).to_lower())


static func _fmt(v: Variant) -> String:
	if v is float:
		var f: float = v
		return str(roundi(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f
	return str(v)


func _dim_color() -> Color:
	return UiBuild.theme().get_color(&"font_color", &"DimLabel")


func _save(message_key: StringName) -> void:
	var err: Error = SaveService.save_profile(profile, profile_slot)
	message_label.text = UiText.t(message_key if err == OK else &"ui.workshop.save_failed")
	profile_changed.emit()


## Gamepad / keyboard: weapon list <-> slot buttons / parts list (right column) <-> footer.
func _wire_focus() -> void:
	if not is_inside_tree():
		return
	var slots: Array[Control] = []
	for t: int in model.slots():
		slots.append(slot_buttons[t] as Control)
	slots.append(overview_button)
	UiNav.chain_horizontal(slots, false)
	var first_slot: Control = slots[0]
	slots[0].focus_neighbor_left = slots[0].get_path_to(weapon_list)
	for b: Control in slots:
		b.focus_neighbor_bottom = b.get_path_to(parts_list)
		b.focus_neighbor_top = b.get_path_to(b)
	weapon_list.focus_neighbor_right = weapon_list.get_path_to(first_slot)
	weapon_list.focus_neighbor_bottom = weapon_list.get_path_to(equip_button)
	weapon_list.focus_neighbor_top = weapon_list.get_path_to(weapon_list)
	parts_list.focus_neighbor_top = parts_list.get_path_to(first_slot)
	parts_list.focus_neighbor_left = parts_list.get_path_to(weapon_list)
	parts_list.focus_neighbor_bottom = parts_list.get_path_to(finish_panel.list)
	var fl: ItemList = finish_panel.list
	var fb: Button = finish_panel.equip_button
	fl.focus_neighbor_top = fl.get_path_to(parts_list)
	fl.focus_neighbor_left = fl.get_path_to(weapon_list)
	fl.focus_neighbor_bottom = fl.get_path_to(fb)
	fb.focus_neighbor_top = fb.get_path_to(fl)
	fb.focus_neighbor_left = fb.get_path_to(weapon_list)
	fb.focus_neighbor_bottom = fb.get_path_to(equip_button)
	UiNav.chain_horizontal([back_button, stats_mode_button, buy_button, equip_button] as Array[Control], false)
	for b: Control in [back_button, stats_mode_button, buy_button, equip_button]:
		b.focus_neighbor_top = b.get_path_to(fb)
		b.focus_neighbor_bottom = b.get_path_to(b)
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)


func _on_weapon_row(row: int) -> void:
	var id: StringName = _weapon_rows[row] if row >= 0 and row < _weapon_rows.size() else &""
	if id != &"" and id != model.weapon_id:
		message_label.text = ""
		select_weapon(id)


func _on_part_row(row: int) -> void:
	var id: StringName = StringName(parts_list.get_item_metadata(row))
	message_label.text = ""
	if id != model.picks.get(selected_slot, &""):
		select_part(id)


func _on_slot_focus(t: int) -> void:
	if t != selected_slot or stage.focused_slot != t:
		select_slot(t)


func _on_overview() -> void:
	stage.reset_view()


func _on_finish_preview(id: StringName) -> void:
	stage.visual.apply_finish(id)


func _on_finish_equipped(_id: StringName) -> void:
	if WeaponFinishes.persists(profile):
		_save(&"ui.workshop.finish.saved")
	else:
		message_label.text = UiText.t(&"ui.workshop.finish.not_saved")
		profile_changed.emit()
