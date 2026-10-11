## Simple loadout screen (P1): secondary weapon + one mod per slot from the profile's owned mods,
## melee, armor, deployable, mask. Live StatCalculator numbers with green/red deltas against the
## stock weapon, concealment total and detection risk from LoadoutResolver (single source of truth).
## Owner: ENV B. Saves the loadout to the profile via SaveService on Back and Launch.
## B4-03: "Skills" / "Perk Deck" buttons ask MenuFlow to open the skill tree / perk deck screens on
## the same PlayerProfile (commit_to_profile() first); refresh() afterwards picks up their changes
## (skills and perk cards feed LoadoutResolver's concealment bonus, so DR updates).
## B2-01: the mask picker lists MaskLocker.available_ids() (owned presets + filled custom slots,
## names from MaskCatalog.display_name) so an equipped `mask.custom.<n>` survives a save; "Masks"
## (masks_requested) opens the mask screen; refresh_masks() re-reads the picker from the profile.
## B4-17: "Workshop" opens the 3D WorkshopScreen over this screen on the same profile (open_workshop();
## its Back calls close_workshop(), which re-reads the weapon and mods it may have equipped). Self-contained,
## so MenuFlow needs no change: the armory station and the heist path both reach it from here.
class_name LoadoutScreen
extends UiScreen

signal launch_requested(loadout: Loadout)
signal skills_requested()
signal perk_deck_requested()
signal masks_requested()

const WORKSHOP_SCENE_PATH: String = "res://content/ui/workshop/workshop_screen.tscn"

## [display key, strings key] in panel order (StatCalculator.display keys).
const STAT_ROWS: Array[Array] = [
	["damage", &"ui.stat.damage"], ["accuracy", &"ui.stat.accuracy"], ["stability", &"ui.stat.stability"],
	["concealment", &"ui.stat.concealment"], ["threat", &"ui.stat.threat"], ["mag", &"ui.stat.magazine"],
	["total_ammo", &"ui.stat.total_ammo"], ["rof", &"ui.stat.rate_of_fire"], ["reload", &"ui.stat.reload"],
]

## Profile slot (SaveService) this screen edits.
@export var profile_slot: int = 0
## Armory mode (B4-07, opened from the safehouse hub): no heist to launch, so no Launch button;
## Back saves and returns to the hub.
@export var hub_mode: bool = false

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
var skills_button: Button
var perks_button: Button
var masks_button: Button
var workshop_button: Button
## The workshop while it is open over this screen (B4-17), else null.
var workshop: WorkshopScreen = null
var skills_summary_label: Label
var perk_summary_label: Label
var _stat_value_labels: Dictionary = {}
var _stat_delta_labels: Dictionary = {}
var _mods_box: VBoxContainer
var _tweak: HudTweak
var _content: Control


## Optional: inject a profile before the screen enters the tree (tests, MenuFlow).
func setup(p: PlayerProfile) -> void:
	profile = p


func build_ui() -> void:
	_tweak = HudTweak.load_default()
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	var root: VBoxContainer = UiBuild.vbox(16)
	_content = UiBuild.screen_margin(self, root)
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
	masks_button = UiBuild.button(&"ui.masks.open")
	masks_button.custom_minimum_size = Vector2(180, 0)
	masks_button.pressed.connect(_on_progression.bind(masks_requested))
	mask_option.get_parent().add_child(masks_button)
	cols.add_child(_build_stats_panel())
	var nav: HBoxContainer = UiBuild.hbox(16)
	root.add_child(nav)
	back_button = UiBuild.button(&"ui.menu.back")
	launch_button = UiBuild.primary(UiBuild.button(&"ui.heist_select.start"))
	skills_button = UiBuild.button(&"ui.loadout.skills")
	perks_button = UiBuild.button(&"ui.loadout.perk_deck")
	workshop_button = UiBuild.button(&"ui.workshop.open")
	workshop_button.pressed.connect(open_workshop)
	for b: Button in [skills_button, perks_button, workshop_button]:
		b.custom_minimum_size = Vector2(240, 0)
	back_button.pressed.connect(_on_back)
	launch_button.pressed.connect(_on_launch)
	skills_button.pressed.connect(_on_progression.bind(skills_requested))
	perks_button.pressed.connect(_on_progression.bind(perk_deck_requested))
	nav.add_child(back_button)
	nav.add_child(skills_button)
	nav.add_child(perks_button)
	nav.add_child(workshop_button)
	nav.add_child(launch_button)
	launch_button.visible = not hub_mode
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
	skills_summary_label = UiBuild.label(&"", UiBuild.DIM)
	perk_summary_label = UiBuild.label(&"", UiBuild.DIM)
	v.add_child(skills_summary_label)
	v.add_child(perk_summary_label)
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
	l.mask_descriptor = LoadoutResolver.mask_descriptor_for(l, profile)  # D-043 QA-25: travels with launch
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
	if _gate_deployables(LoadoutResolver.resolve_modifiers(l)):
		l = current_loadout()
	var resolved: Loadout = LoadoutResolver.resolve(l)
	concealment_total = resolved.concealment_total
	detection_risk = resolved.detection_risk
	concealment_label.text = UiText.t(&"ui.loadout.concealment_total", {"value": concealment_total})
	detection_risk_label.text = UiText.t(&"ui.common.percent", {"value": detection_risk})
	_refresh_progression_summary(l)
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
	commit_to_profile()
	return SaveService.save_profile(profile, profile_slot)


## Copy the widgets' choices into profile.loadout (before another screen edits the same profile).
func commit_to_profile() -> void:
	profile.loadout = current_loadout()


func _refresh_progression_summary(l: Loadout) -> void:
	var total: int = SkillPoints.points_for_level(profile.level)
	skills_summary_label.text = UiText.t(&"ui.loadout.skills_summary",
			{"spent": SkillPoints.spent_total(l.skills), "total": total})
	if l.perk_deck == &"":
		perk_summary_label.text = UiText.t(&"ui.loadout.perk_none")
	else:
		perk_summary_label.text = UiText.t(&"ui.loadout.perk_summary",
				{"deck": UiText.t(StringName("%s.name" % l.perk_deck)), "cards": l.perk_deck_cards})


func _on_progression(request: Signal) -> void:
	save()
	request.emit()


func _fill_options() -> void:
	_fill_weapons()
	weapon_option.item_selected.connect(_on_weapon_changed)
	_fill_from(melee_option, ContentDB.all_melees(), profile.loadout.melee, false)
	_fill_from(armor_option, ContentDB.all_armors(), profile.loadout.armor, false)
	_fill_from(deployable_option, ContentDB.all_deployables(), profile.loadout.deployable, true)
	_fill_masks(profile.loadout.mask)
	for o: OptionButton in [melee_option, armor_option, deployable_option, mask_option]:
		o.item_selected.connect(_on_item_changed)


## Re-read the mask picker from the profile (after the mask screen edited / equipped masks).
func refresh_masks() -> void:
	_fill_masks(profile.loadout.mask)


## Mask ids offered by the picker ("" = none first), in picker order.
func mask_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in range(mask_option.item_count):
		out.append(StringName(mask_option.get_item_metadata(i)))
	return out


func _fill_masks(selected: StringName) -> void:
	mask_option.clear()
	_add_item(mask_option, UiText.t(&"ui.loadout.none"), &"")
	for id: StringName in MaskLocker.available_ids(profile):
		_add_item(mask_option, MaskCatalog.display_name(id), id)
	if not _select_id(mask_option, selected):
		mask_option.select(0)


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
	for c: Control in [melee_option, armor_option, deployable_option, mask_option, masks_button, launch_button,
			skills_button, perks_button, workshop_button, back_button]:
		if c != launch_button or not hub_mode:
			focus_chain.append(c)
	if is_inside_tree():
		UiNav.chain_vertical(focus_chain)
		UiNav.chain_horizontal([mask_option, masks_button] as Array[Control], false)
		var nav: Array[Control] = [back_button, skills_button, perks_button, workshop_button]
		if not hub_mode:
			nav.append(launch_button)
		UiNav.chain_horizontal(nav, false)


## Open the workshop over this screen (saves first; the workshop edits the same profile).
func open_workshop() -> WorkshopScreen:
	save()
	close_workshop(false)
	workshop = (load(WORKSHOP_SCENE_PATH) as PackedScene).instantiate() as WorkshopScreen
	workshop.profile_slot = profile_slot
	workshop.setup(profile)
	workshop.back_requested.connect(close_workshop, CONNECT_DEFERRED)
	_content.visible = false
	add_child(workshop)
	return workshop


## Close the workshop and re-read the weapon and mods from the profile.
func close_workshop(refocus: bool = true) -> void:
	if workshop == null:
		return
	remove_child(workshop)
	workshop.queue_free()
	workshop = null
	_content.visible = true
	_fill_weapons()
	_on_weapon_changed(weapon_option.selected)
	if refocus:
		workshop_button.grab_focus.call_deferred()


func _fill_weapons() -> void:
	weapon_option.clear()
	for wid: StringName in profile.owned_weapons:
		var w: WeaponDef = ContentDB.weapon(wid)
		if w != null and w.slot == Enums.WeaponSlot.SECONDARY:
			_add_item(weapon_option, UiText.t(UiText.item_key(wid)), wid)
	_select_id(weapon_option, profile.loadout.secondary)


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


## Lock the deployables whose DeployableGate flag `modifiers` lacks (disabled, with the perk card that
## unlocks them); a locked pick falls back to none. True when the selection changed.
func _gate_deployables(modifiers: Dictionary) -> bool:
	var changed: bool = false
	for i: int in range(deployable_option.item_count):
		var id: StringName = StringName(deployable_option.get_item_metadata(i))
		if DeployableGate.required_flag(id) == &"":
			continue
		var ok: bool = DeployableGate.allowed(id, modifiers)
		var text: String = UiText.t(UiText.item_key(id))
		if not ok:
			var card: Dictionary = DeployableGate.unlock_card(id)
			text = UiText.t(&"ui.loadout.deployable_locked", {"item": text, "card": int(card.get("card", 0)),
					"name": UiText.t(StringName(card.get("name", &"")))})
		deployable_option.set_item_text(i, text)
		deployable_option.set_item_disabled(i, not ok)
		if not ok and deployable_option.selected == i:
			_select_id(deployable_option, &"")
			changed = true
	return changed


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
