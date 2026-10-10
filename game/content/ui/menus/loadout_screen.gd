## Simple loadout screen (P1): secondary weapon + one mod per slot from the profile's owned mods,
## melee, armor, deployable, mask. Live StatCalculator numbers with green/red deltas against the
## stock weapon, concealment total and detection risk from LoadoutResolver (single source of truth).
## Owner: ENV B. Saves the loadout to the profile via SaveService on Back and Launch.
class_name LoadoutScreen
extends UiScreen

signal launch_requested(loadout: Loadout)

## [display key, strings key] in panel order (StatCalculator.display keys).
const STAT_ROWS: Array[Array] = [
	["damage", &"ui.stat.damage"], ["accuracy", &"ui.stat.accuracy"], ["stability", &"ui.stat.stability"],
	["concealment", &"ui.stat.concealment"], ["threat", &"ui.stat.threat"], ["mag", &"ui.stat.magazine"],
	["total_ammo", &"ui.stat.total_ammo"], ["rof", &"ui.stat.rate_of_fire"], ["reload", &"ui.stat.reload"],
]

## Profile slot (SaveService) this screen edits.
@export var profile_slot: int = 0

var profile: PlayerProfile
var weapon_option: OptionButton
var melee_option: OptionButton
var armor_option: OptionButton
var deployable_option: OptionButton
var mask_option: OptionButton
## ModType (int) -> OptionButton for the current weapon.
var mod_options: Dictionary = {}
var concealment_label: Label
var detection_risk_label: Label
var detection_risk: int = 0
var concealment_total: int = 0
var launch_button: Button
var back_button: Button
var _stat_value_labels: Dictionary = {}
var _stat_delta_labels: Dictionary = {}
var _mods_box: VBoxContainer
var _tweak: HudTweak


## Optional: inject a profile before the screen enters the tree (tests, MenuFlow).
func setup(p: PlayerProfile) -> void:
	profile = p


func build_ui() -> void:
	_tweak = HudTweak.load_default()
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	var root: VBoxContainer = UiBuild.vbox(16)
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.label(&"ui.loadout.title", UiBuild.HEADER))
	var cols: HBoxContainer = UiBuild.hbox(48)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	cols.add_child(scroll)
	var left: VBoxContainer = UiBuild.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(left)
	weapon_option = _row(left, &"ui.loadout.secondary")
	_mods_box = UiBuild.vbox(10)
	left.add_child(UiBuild.label(&"ui.loadout.mods", UiBuild.DIM))
	left.add_child(_mods_box)
	melee_option = _row(left, &"ui.loadout.melee")
	armor_option = _row(left, &"ui.loadout.armor")
	deployable_option = _row(left, &"ui.loadout.deployable")
	mask_option = _row(left, &"ui.loadout.mask")
	cols.add_child(_build_stats_panel())
	var nav: HBoxContainer = UiBuild.hbox(16)
	root.add_child(nav)
	back_button = UiBuild.button(&"ui.menu.back")
	launch_button = UiBuild.button(&"ui.heist_select.start")
	back_button.pressed.connect(_on_back)
	launch_button.pressed.connect(_on_launch)
	nav.add_child(back_button)
	nav.add_child(launch_button)
	_fill_options()
	_rebuild_mod_rows()
	_rebuild_focus()
	refresh()


func _build_stats_panel() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(8)
	v.custom_minimum_size = Vector2(520, 0)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 24)
	v.add_child(grid)
	for row: Array in STAT_ROWS:
		grid.add_child(UiBuild.label(StringName(row[1])))
		var val: Label = UiBuild.label()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var dl: Label = UiBuild.label()
		dl.custom_minimum_size = Vector2(90, 0)
		grid.add_child(val)
		grid.add_child(dl)
		_stat_value_labels[row[0]] = val
		_stat_delta_labels[row[0]] = dl
	concealment_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	v.add_child(concealment_label)
	var dr_row: HBoxContainer = UiBuild.hbox(12)
	dr_row.add_child(UiBuild.label(&"ui.stat.detection_risk", UiBuild.SUBHEADER))
	detection_risk_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	dr_row.add_child(detection_risk_label)
	v.add_child(dr_row)
	return UiBuild.panel(v)


func _row(parent: Container, key: StringName) -> OptionButton:
	var h: HBoxContainer = UiBuild.hbox(16)
	var l: Label = UiBuild.label(key)
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	var o: OptionButton = UiBuild.option_button()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(o)
	parent.add_child(h)
	return o


## Builds the current Loadout input from the widgets (unresolved; resolve with LoadoutResolver).
func current_loadout() -> Loadout:
	var l: Loadout = profile.loadout.duplicate(true) as Loadout
	l.secondary = _selected_id(weapon_option)
	var mods: Array[StringName] = []
	var types: Array = mod_options.keys()
	types.sort()
	for t: Variant in types:
		var id: StringName = _selected_id(mod_options[t] as OptionButton)
		if id != &"":
			mods.append(id)
	l.secondary_mods = mods
	l.melee = _selected_id(melee_option)
	l.armor = _selected_id(armor_option)
	l.deployable = _selected_id(deployable_option)
	l.mask = _selected_id(mask_option)
	return l


## Select a mod (or &"" = stock) in a slot, as if picked in the UI. Returns false if unavailable.
func select_mod(mod_type: int, mod_id: StringName) -> bool:
	if not mod_options.has(mod_type):
		return false
	var ok: bool = _select_id(mod_options[mod_type] as OptionButton, mod_id)
	if ok:
		refresh()
	return ok


func select_armor(armor_id: StringName) -> bool:
	var ok: bool = _select_id(armor_option, armor_id)
	if ok:
		refresh()
	return ok


## Recompute every number from the widgets.
func refresh() -> void:
	var l: Loadout = current_loadout()
	var resolved: Loadout = LoadoutResolver.resolve(l)
	concealment_total = resolved.concealment_total
	detection_risk = resolved.detection_risk
	concealment_label.text = UiText.t(&"ui.loadout.concealment_total", {"value": concealment_total})
	detection_risk_label.text = UiText.t(&"ui.common.percent", {"value": detection_risk})
	var stock: WeaponStats = LoadoutResolver.resolve_weapon(l.secondary, [] as Array[StringName])
	var modded: WeaponStats = resolved.resolved_secondary
	if stock == null or modded == null:
		for k: Variant in _stat_value_labels:
			(_stat_value_labels[k] as Label).text = "-"
			(_stat_delta_labels[k] as Label).text = ""
		return
	var shown: Dictionary = StatCalculator.display(modded)
	var deltas: Dictionary = StatCalculator.delta(stock, modded)
	for k: Variant in _stat_value_labels:
		(_stat_value_labels[k] as Label).text = _fmt(shown.get(k, 0))
		var dl: Label = _stat_delta_labels[k] as Label
		dl.text = ""
		if deltas.has(k) and bool((deltas[k] as Dictionary)["changed"]):
			var d: Dictionary = deltas[k] as Dictionary
			var diff: float = float(d["diff"])
			var key: StringName = &"ui.loadout.stat_delta_up" if diff > 0.0 else &"ui.loadout.stat_delta_down"
			dl.text = UiText.t(key, {"value": _fmt(absf(diff))})
			dl.add_theme_color_override(&"font_color",
					_tweak.delta_better_color if bool(d["better"]) else _tweak.delta_worse_color)


## Persist the current loadout (input fields only) to the profile.
func save() -> Error:
	profile.loadout = current_loadout()
	return SaveService.save_profile(profile, profile_slot)


func _fill_options() -> void:
	weapon_option.clear()
	for wid: StringName in profile.owned_weapons:
		var w: WeaponDef = ContentDB.weapon(wid)
		if w != null and w.slot == Enums.WeaponSlot.SECONDARY:
			_add_item(weapon_option, UiText.t(UiText.item_key(wid)), wid)
	_select_id(weapon_option, profile.loadout.secondary)
	weapon_option.item_selected.connect(_on_weapon_changed)
	_fill_from(melee_option, ContentDB.all_melees(), profile.loadout.melee, false)
	_fill_from(armor_option, ContentDB.all_armors(), profile.loadout.armor, false)
	_fill_from(deployable_option, ContentDB.all_deployables(), profile.loadout.deployable, true)
	var masks: Array = []
	for m: Resource in ContentDB.all_of(ContentDB.MASKS):
		var md: MaskDef = m as MaskDef
		if md != null and (md.unlock == &"" or profile.owned_masks.has(md.id)):
			masks.append(md)
	_fill_from(mask_option, masks, profile.loadout.mask, true)
	for o: OptionButton in [melee_option, armor_option, deployable_option, mask_option]:
		o.item_selected.connect(_on_item_changed)


func _fill_from(o: OptionButton, defs: Array, selected: StringName, allow_none: bool) -> void:
	o.clear()
	if allow_none:
		_add_item(o, UiText.t(&"ui.loadout.none"), &"")
	for r: Variant in defs:
		var id: StringName = StringName((r as Resource).get(&"id"))
		_add_item(o, UiText.t(UiText.item_key(id)), id)
	if not _select_id(o, selected) and o.item_count > 0:
		o.select(0)


func _rebuild_mod_rows() -> void:
	for c: Node in _mods_box.get_children():
		_mods_box.remove_child(c)
		c.queue_free()
	mod_options.clear()
	var w: WeaponDef = ContentDB.weapon(_selected_id(weapon_option)) if weapon_option.item_count > 0 else null
	if w == null:
		return
	var types: Array = w.mod_slots.keys()
	types.sort()
	for t: Variant in types:
		var mod_type: int = int(t)
		var stock_id: StringName = StringName(w.default_mods.get(mod_type, &""))
		var o: OptionButton = _row(_mods_box, _mod_type_key(mod_type))
		_add_item(o, UiText.t(&"ui.loadout.stock" if stock_id != &"" else &"ui.loadout.none"), &"")
		for mid: Variant in (w.mod_slots[t] as Array):
			var id: StringName = StringName(mid)
			if id != stock_id and profile.owned_mods.has(id):
				_add_item(o, UiText.t(UiText.item_key(id)), id)
		o.select(0)
		for equipped: StringName in profile.loadout.secondary_mods:
			_select_id(o, equipped)
		o.item_selected.connect(_on_item_changed)
		mod_options[mod_type] = o


func _rebuild_focus() -> void:
	focus_chain.clear()
	focus_chain.append(weapon_option)
	var types: Array = mod_options.keys()
	types.sort()
	for t: Variant in types:
		focus_chain.append(mod_options[t] as Control)
	for c: Control in [melee_option, armor_option, deployable_option, mask_option, launch_button, back_button]:
		focus_chain.append(c)
	if is_inside_tree():
		UiNav.chain_vertical(focus_chain)
		UiNav.chain_horizontal([back_button, launch_button] as Array[Control], false)


func _on_weapon_changed(_index: int) -> void:
	_rebuild_mod_rows()
	_rebuild_focus()
	refresh()


func _on_item_changed(_index: int) -> void:
	refresh()


func _on_back() -> void:
	save()
	back_requested.emit()


func _on_launch() -> void:
	save()
	launch_requested.emit(current_loadout())


static func _add_item(o: OptionButton, text: String, id: StringName) -> void:
	o.add_item(text)
	o.set_item_metadata(o.item_count - 1, id)


static func _selected_id(o: OptionButton) -> StringName:
	if o == null or o.selected < 0:
		return &""
	return StringName(o.get_item_metadata(o.selected))


static func _select_id(o: OptionButton, id: StringName) -> bool:
	for i: int in range(o.item_count):
		if StringName(o.get_item_metadata(i)) == id:
			o.select(i)
			return true
	return false


static func _mod_type_key(mod_type: int) -> StringName:
	return StringName("ui.mod_type.%s" % String(Enums.ModType.keys()[mod_type]).to_lower())


static func _fmt(v: Variant) -> String:
	if v is float:
		var f: float = v
		return str(roundi(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f
	return str(v)
