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
## D-073: a throwable picker (ThrowableGate.pickable(): perk-deck items such as the flask and the injector are
## never offered) and a heister picker ("Any free heister" + Heisters.ids(), each with its accent swatch and ENV
## D's 2D portrait when one exists). In co-op MenuFlow sets `taken_heisters` (LobbyState.heisters_taken_by_others):
## those are shown taken and cannot be picked (the lobby's first-come rule still settles races).
class_name LoadoutScreen
extends UiScreen

signal launch_requested(loadout: Loadout)
signal skills_requested()
signal perk_deck_requested()
signal masks_requested()

const WORKSHOP_SCENE_PATH: String = "res://content/ui/workshop/workshop_screen.tscn"

## [display key, strings key] in panel order (StatCalculator.display keys).
## PO-4 stat bar full scale per stat (display units; UI scale only, not balance). Missing = 100.
const STAT_BAR_MAX: Dictionary = {"damage": 200.0, "mag": 100.0, "total_ammo": 400.0, "rof": 1200.0, "reload": 6.0,
	"concealment": 30.0, "threat": 50.0}
## PO-4 Detection Risk colour bands (%): green up to DR_LOW, amber up to DR_HIGH, red above.
const DR_LOW: int = 20
const DR_HIGH: int = 45
## D-111 (style.md §11): six key stats; threat, total ammo and reload live in the Workshop's full sheet.
const STAT_ROWS: Array[Array] = [
	["damage", &"ui.stat.damage"], ["accuracy", &"ui.stat.accuracy"], ["stability", &"ui.stat.stability"],
	["concealment", &"ui.stat.concealment"], ["mag", &"ui.stat.magazine"], ["rof", &"ui.stat.rate_of_fire"],
]

## Profile slot (SaveService) this screen edits.
@export var profile_slot: int = 0
## Armory mode (B4-07, opened from the safehouse hub): no heist to launch, so no Launch button;
## Back saves and returns to the hub.
@export var hub_mode: bool = false
## The heist's HeistDef.start_mode (D-065). &"civilian" shows a notice: you start without gear and pick
## it up on site (S1.3). Set by MenuFlow before the screen enters the tree.
@export var start_mode: StringName = &"casing"
## Compact mode (B6-04 drop-in loadout pick): no Skills / Perk Deck / Workshop / Masks buttons; the owner
## relabels Launch.
@export var compact_mode: bool = false

var profile: PlayerProfile
## S1.3 civilian-start notice (visible only for a civilian-start heist).
var civilian_notice: Label
var weapon_option: ItemSlot
var melee_option: ItemSlot
var armor_option: ItemSlot
var deployable_option: ItemSlot
var throwable_option: ItemSlot
var mask_option: ItemSlot
## D-073 heister picker: metadata = heister id (&"" = any free heister); accent strip + portrait beside it.
var heister_option: ItemSlot
var heister_swatch: ColorRect
var heister_portrait: TextureRect
## Heisters other crew members hold (co-op); shown taken and disabled in the picker.
var taken_heisters: Array[StringName] = []
## ModType (int) -> ItemSlot for the current weapon.
var mod_options: Dictionary = {}
var concealment_label: Label
## PO-4: the equipped primary (read-only here; equip / buy in the Workshop).
var primary_slot: ItemSlot
var detection_risk_label: Label
## D-106: stats with skills (default) or base values; boosted values are marked (SkillBoost).
var with_skills: bool = true
var stats_mode_button: Button
## "* boosted by your skills" legend, shown when a value is marked.
var boosted_legend: Label
var detection_risk: int = 0
var concealment_total: int = 0
## P5 melee roster: the focused melee's numbers and blurb, shown while the melee picker previews (PD2's melee card).
var melee_info: VBoxContainer
var melee_info_title: Label
var melee_info_stats: Label
var melee_info_desc: Label
var launch_button: Button
var back_button: Button
var skills_button: Button
var perks_button: Button
## The perk deck line above the nav row (PerkProgress.summary_text: deck, cards, D-164 Copycat picks) (tests).
var perk_summary_label: Label
var workshop_button: Button
## The workshop while it is open over this screen (B4-17), else null.
var workshop: WorkshopScreen = null
## D-111: names the weapon the stat panel describes (the secondary; the primary's sheet is in the Workshop).
var stats_weapon_label: Label
var _stat_value_labels: Dictionary = {}
var _stat_delta_labels: Dictionary = {}
var _stat_bars: Dictionary = {}
var _mods_box: GridContainer
## The picker item being previewed ({slot, index}; {} = none): current_loadout() swaps it in.
var _preview: Dictionary = {}
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
	root.add_child(UiBuild.header(&"ui.workshop.crumb" if hub_mode else &"ui.loadout.crumb", &"ui.loadout.title"))
	civilian_notice = UiBuild.label(&"ui.loadout.civilian_start", UiBuild.DIM)
	civilian_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	civilian_notice.visible = start_mode == &"civilian" and not hub_mode
	root.add_child(civilian_notice)
	var cols: HBoxContainer = UiBuild.hbox(48)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	cols.add_child(scroll)
	var left: VBoxContainer = UiBuild.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(left)
	# PO-4 (lead note 3): slot cards in two columns per section; each opens an item grid (ItemSlot /
	# ItemPicker). The primary card opens the Workshop, where primaries are bought and equipped.
	left.add_child(_section(&"ui.loadout.section.weapons"))
	var weapons: GridContainer = _card_grid(left)
	primary_slot = _row(weapons, &"ui.loadout.primary", &"armory")
	primary_slot.pressed.disconnect(primary_slot.open_picker)
	primary_slot.pressed.connect(open_workshop)
	weapon_option = _row(weapons, &"ui.loadout.secondary", &"pistol")
	_mods_box = _card_grid(left, 3)
	# D-111: mods are edited in the Workshop (primary and secondary); the slots stay as the loadout's picks.
	_mods_box.visible = false
	left.add_child(_section(&"ui.loadout.section.gear"))
	var gear: GridContainer = _card_grid(left)
	melee_option = _row(gear, &"ui.loadout.melee", &"knife")
	armor_option = _row(gear, &"ui.loadout.armor", &"vest")
	deployable_option = _row(gear, &"ui.loadout.deployable", &"bag")
	throwable_option = _row(gear, &"ui.loadout.throwable", &"grenade")
	left.add_child(_section(&"ui.loadout.section.crew"))
	var crew: GridContainer = _card_grid(left)
	mask_option = _row(crew, &"ui.loadout.mask", &"masks")
	if not compact_mode:  # D-111: the mask tile opens the bench (the separate Masks button is gone)
		mask_option.pressed.disconnect(mask_option.open_picker)
		mask_option.pressed.connect(_on_progression.bind(masks_requested))
	heister_option = _row(crew, &"ui.loadout.heister", &"crew")
	heister_swatch = ColorRect.new()
	heister_swatch.custom_minimum_size = Vector2(8, 0)
	heister_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heister_option.get_parent().add_child(heister_swatch)
	heister_portrait = TextureRect.new()
	heister_portrait.custom_minimum_size = Vector2(72, 72)
	heister_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heister_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heister_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heister_option.get_parent().add_child(heister_portrait)
	var stats_panel: PanelContainer = _build_stats_panel()
	stats_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # D-111: hugs its rows, no empty box below
	cols.add_child(stats_panel)
	perk_summary_label = UiBuild.label(&"", UiBuild.DIM)
	perk_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk_summary_label.visible = not compact_mode
	root.add_child(perk_summary_label)
	var nav: HBoxContainer = UiBuild.hbox(16)
	root.add_child(nav)
	back_button = UiBuild.ghost(UiBuild.button(&"ui.menu.back"))
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
	var push: Control = Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(push)
	nav.add_child(launch_button)
	launch_button.visible = not hub_mode
	for b: Button in [skills_button, perks_button, workshop_button]:
		b.visible = not compact_mode
	_fill_options()
	_rebuild_mod_rows()
	_rebuild_focus()
	refresh()


func _build_stats_panel() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(8)
	v.custom_minimum_size = Vector2(520, 0)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 6)
	stats_mode_button = UiBuild.ghost(UiBuild.button(&"ui.stats.with_skills"))
	stats_mode_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	stats_mode_button.pressed.connect(toggle_stats_mode)
	var top: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	v.add_child(top)
	stats_weapon_label = UiBuild.caption(&"")
	stats_weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_weapon_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(stats_weapon_label)
	top.add_child(stats_mode_button)
	v.add_child(grid)
	for row: Array in STAT_ROWS:
		grid.add_child(UiBuild.caption(StringName(row[1])))
		var bar: ProgressBar = UiBuild.bar(UiTokens.PAPER_DIM, Vector2(150, 6))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		_stat_bars[row[0]] = bar
		var val: Label = UiBuild.label()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var dl: Label = UiBuild.label()
		dl.custom_minimum_size = Vector2(90, 0)
		grid.add_child(val)
		grid.add_child(dl)
		_stat_value_labels[row[0]] = val
		_stat_delta_labels[row[0]] = dl
	boosted_legend = UiBuild.caption(&"ui.stats.boosted_legend")
	boosted_legend.uppercase = false
	v.add_child(boosted_legend)
	v.add_child(HSeparator.new())
	v.add_child(UiBuild.caption(&"ui.stat.detection_risk"))
	detection_risk_label = UiBuild.label(&"", UiBuild.DISPLAY)  # PO-4: the stealth number is the hero
	v.add_child(detection_risk_label)
	concealment_label = UiBuild.label(&"", UiBuild.DIM)
	v.add_child(concealment_label)
	melee_info = UiBuild.vbox(UiTokens.S1)
	melee_info.visible = false
	melee_info.add_child(HSeparator.new())
	melee_info_title = UiBuild.caption(&"")
	melee_info.add_child(melee_info_title)
	melee_info_stats = UiBuild.label()
	melee_info_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # wrap, never widen the panel under the picker
	melee_info.add_child(melee_info_stats)
	melee_info_desc = UiBuild.label(&"", UiBuild.DIM)
	melee_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	melee_info.add_child(melee_info_desc)
	v.add_child(melee_info)
	return UiBuild.panel(v)


## A section head: caption over a hairline.
func _section(key: StringName) -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.S1)
	v.add_child(gap)
	var c: Label = UiBuild.caption(key)
	c.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	v.add_child(c)
	v.add_child(HSeparator.new())
	return v


func _row(parent: Container, key: StringName, glyph: StringName = &"armory") -> ItemSlot:
	var cell: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var o: ItemSlot = ItemSlot.new()
	o.caption_key = key
	o.glyph = glyph
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.item_previewed.connect(_on_previewed.bind(o))
	cell.add_child(o)
	parent.add_child(cell)
	return o


func _card_grid(parent: Container, columns: int = 2) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = columns
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override(&"h_separation", UiTokens.S3)
	g.add_theme_constant_override(&"v_separation", UiTokens.S2)
	parent.add_child(g)
	return g


## PO-4: the picker's focused item previews its stat changes against what is equipped (weapon and mod
## slots; other slots show the concealment / Detection Risk change). -1 = picker closed, no preview.
func _on_previewed(index: int, o: ItemSlot) -> void:
	# LEAD r229 reach pass: a locked item previews too (PD2 shows a locked weapon's stats); it still can't be picked.
	if index < 0:
		_preview = {}
	else:
		_preview = {"slot": o, "index": index}
	refresh()


## P5: the melee card shows the melee the picker has focused (hidden for every other slot)
func _refresh_melee_info() -> void:
	var d: MeleeDef = null
	if not _preview.is_empty() and _preview["slot"] == melee_option:
		d = ContentDB.melee(_pick_id(melee_option, true))
	if melee_info == null:
		return
	melee_info.visible = d != null
	if d == null:
		return
	melee_info_title.text = UiText.t(&"ui.loadout.melee_card", {"name": UiText.t(UiText.item_key(d.id))})
	melee_info_stats.text = UiText.t(&"ui.loadout.melee_stats", {"damage": _fmt(d.damage),
			"charged": _fmt(d.charged_damage), "knockdown": roundi(d.knockdown * 100.0),
			"reach": "%.1f" % d.range_m, "concealment": d.concealment})
	var desc: StringName = StringName(String(UiText.item_key(d.id)).trim_suffix(".name") + ".desc")
	melee_info_desc.text = UiText.t(desc) if UiText.has(desc) else ""


## Builds the current Loadout input from the widgets (unresolved; resolve with LoadoutResolver).
func current_loadout(with_preview: bool = false) -> Loadout:
	var l: Loadout = profile.loadout.duplicate(true) as Loadout
	var pick: Callable = _pick_id.bind(with_preview)
	l.secondary = pick.call(weapon_option)
	var mods: Array[StringName] = []
	var types: Array = mod_options.keys()
	types.sort()
	for t: Variant in types:
		var id: StringName = pick.call(mod_options[t] as ItemSlot)
		if id != &"":
			mods.append(id)
	l.secondary_mods = mods
	l.melee = pick.call(melee_option)
	l.armor = pick.call(armor_option)
	l.deployable = pick.call(deployable_option)
	l.throwable = pick.call(throwable_option)
	l.mask = pick.call(mask_option)
	l.heister = pick.call(heister_option)
	l.mask_descriptor = LoadoutResolver.mask_descriptor_for(l, profile)  # D-043 QA-25: travels with launch
	return l


func _pick_id(o: ItemSlot, with_preview: bool) -> StringName:
	if with_preview and not _preview.is_empty() and _preview["slot"] == o:
		return StringName(o.get_item_metadata(int(_preview["index"])))
	return _selected_id(o)


## Select a mod (or &"" = stock) in a slot, as if picked in the UI. Returns false if unavailable.
func select_mod(mod_type: int, mod_id: StringName) -> bool:
	if not mod_options.has(mod_type):
		return false
	var ok: bool = _select_id(mod_options[mod_type] as ItemSlot, mod_id)
	if ok:
		refresh()
	return ok


## Pick a heister (&"" = any free one) as if chosen in the UI. False when unknown or taken.
func select_heister(heister_id: StringName) -> bool:
	for i: int in range(heister_option.item_count):
		if StringName(heister_option.get_item_metadata(i)) == heister_id and not heister_option.is_item_disabled(i):
			heister_option.select(i)
			_on_heister_changed(i)
			return true
	return false


## Mark `ids` taken (co-op: other crew members hold them) and re-list the heister picker.
func set_taken_heisters(ids: Array[StringName]) -> void:
	taken_heisters = ids.duplicate()
	if heister_option != null:
		_fill_heisters(_selected_id(heister_option) if heister_option.item_count > 0 else profile.loadout.heister)


## Ids the given picker lists, in order (&"" = none / any first): throwable_option, heister_option, ...
func option_ids(o: ItemSlot) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in range(o.item_count):
		out.append(StringName(o.get_item_metadata(i)))
	return out


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
	if perk_summary_label != null:
		perk_summary_label.text = PerkProgress.summary_text(l)
	concealment_total = resolved.concealment_total
	detection_risk = resolved.detection_risk
	concealment_label.text = UiText.t(&"ui.loadout.concealment_total", {"value": concealment_total})
	var pid: StringName = profile.loadout.primary
	primary_slot.clear()
	primary_slot.add_item(UiText.t(UiText.item_key(pid)) if pid != &"" else UiText.t(&"ui.loadout.primary_none"))
	detection_risk_label.text = UiText.t(&"ui.common.percent", {"value": detection_risk})
	detection_risk_label.add_theme_color_override(&"font_color", UiTokens.OK if detection_risk <= DR_LOW
			else (UiTokens.WARN if detection_risk <= DR_HIGH else UiTokens.ALERT))
	_refresh_progression_summary(l)
	var sdef: WeaponDef = ContentDB.weapon(l.secondary)
	var stock: WeaponStats = LoadoutResolver.resolve_weapon(l.secondary, [] as Array[StringName])
	# D-118: a loaded shotgun AMMO mod (Mule 12) shows as it fires (AmmoStats).
	var modded: WeaponStats = AmmoStats.apply(resolved.resolved_secondary, sdef, l.secondary_mods)
	if not _preview.is_empty():
		# PO-4: picker preview: the focused item's numbers, diffs against what is equipped now.
		var pl: Loadout = current_loadout(true)
		var pv: Loadout = LoadoutResolver.resolve(pl)
		stock = modded
		modded = AmmoStats.apply(pv.resolved_secondary, ContentDB.weapon(pl.secondary), pl.secondary_mods)
		detection_risk_label.text = UiText.t(&"ui.common.percent", {"value": pv.detection_risk})
		concealment_label.text = UiText.t(&"ui.loadout.concealment_total", {"value": pv.concealment_total})
		_refresh_progression_summary(pl)  # LEAD r229: the stat panel names the previewed weapon, not the equipped one
	_refresh_melee_info()
	if stock == null or modded == null:
		for k: Variant in _stat_value_labels:
			(_stat_value_labels[k] as Label).text = "-"
			(_stat_delta_labels[k] as Label).text = ""
		return
	var boosted: Array[String] = []
	if with_skills:  # D-106: the numbers as they play (skills + perk deck), boosted ones marked
		var mods: Dictionary = LoadoutResolver.resolve_modifiers(l)
		var def: WeaponDef = ContentDB.weapon(current_loadout(true).secondary if not _preview.is_empty() else l.secondary)
		var mb: WeaponStats = SkillBoost.apply(modded, def, mods)
		boosted = SkillBoost.boosted_keys(StatCalculator.display(modded), StatCalculator.display(mb))
		modded = mb
		stock = SkillBoost.apply(stock, ContentDB.weapon(l.secondary), mods)
	boosted_legend.visible = not boosted.is_empty()
	var shown: Dictionary = StatCalculator.display(modded)
	var deltas: Dictionary = StatCalculator.delta(stock, modded)
	for k: Variant in _stat_value_labels:
		(_stat_value_labels[k] as Label).text = _fmt(shown.get(k, 0))
		if boosted.has(String(k)):
			(_stat_value_labels[k] as Label).text = UiText.t(&"ui.stats.boosted_value", {"value": _fmt(shown.get(k, 0))})
		if _stat_bars.has(k):
			(_stat_bars[k] as ProgressBar).value = clampf(float(shown.get(k, 0)) / _bar_max(String(k)), 0.0, 1.0)
		var dl: Label = _stat_delta_labels[k] as Label
		dl.text = ""
		if deltas.has(k) and bool((deltas[k] as Dictionary)["changed"]):
			var d: Dictionary = deltas[k] as Dictionary
			var diff: float = float(d["diff"])
			var key: StringName = &"ui.loadout.stat_delta_up" if diff > 0.0 else &"ui.loadout.stat_delta_down"
			dl.text = UiText.t(key, {"value": _fmt(absf(diff))})
			dl.add_theme_color_override(&"font_color",
					_tweak.delta_better_color if bool(d["better"]) else _tweak.delta_worse_color)


## D-106: switch the stat panel between skill-boosted (default) and base values.
func toggle_stats_mode() -> void:
	with_skills = not with_skills
	stats_mode_button.text = UiText.t(&"ui.stats.with_skills" if with_skills else &"ui.stats.base")
	refresh()


## Persist the current loadout (input fields only) to the profile.
func save() -> Error:
	commit_to_profile()
	return SaveService.save_profile(profile, profile_slot)


## Copy the widgets' choices into profile.loadout (before another screen edits the same profile).
func commit_to_profile() -> void:
	profile.loadout = current_loadout()


func _refresh_progression_summary(l: Loadout) -> void:
	stats_weapon_label.text = UiText.t(UiText.item_key(l.secondary)) if l.secondary != &"" else ""


func _on_progression(request: Signal) -> void:
	save()
	request.emit()


func _fill_options() -> void:
	_fill_weapons()
	weapon_option.item_selected.connect(_on_weapon_changed)
	_fill_melees()
	_fill_from(armor_option, ContentDB.all_armors(), profile.loadout.armor, false)
	_fill_from(deployable_option, ContentDB.all_deployables(), profile.loadout.deployable, true)
	_fill_from(throwable_option, ThrowableGate.pickable(), profile.loadout.throwable, true)
	_fill_masks(profile.loadout.mask)
	_fill_heisters(profile.loadout.heister)
	for o: ItemSlot in [melee_option, armor_option, deployable_option, throwable_option, mask_option]:
		o.item_selected.connect(_on_item_changed)
	heister_option.item_selected.connect(_on_heister_changed)


## Heister picker: "Any free heister" first, then the roster with accent swatches; taken ones disabled.
func _fill_heisters(selected: StringName) -> void:
	heister_option.clear()
	_add_item(heister_option, UiText.t(Heisters.name_key(&"")), &"")
	heister_option.set_item_icon(0, heister_icon(&""))
	heister_option.set_item_accent(0, Heisters.accent(&""))
	for id: StringName in Heisters.ids():
		var taken: bool = taken_heisters.has(id)
		var locked: bool = not Heisters.is_unlocked(profile, id)  # D-111: earned heisters (Marten)
		var text: String = Heisters.display_name(id)
		if locked:
			text = UiText.t(&"ui.loadout.heister_locked", {"name": text})
		elif taken:
			text = UiText.t(&"ui.loadout.heister_taken", {"name": text})
		_add_item(heister_option, text, id)
		var i: int = heister_option.item_count - 1
		heister_option.set_item_icon(i, heister_icon(id))
		heister_option.set_item_accent(i, Heisters.accent(id))
		heister_option.set_item_disabled(i, taken or locked)
	if not _select_id(heister_option, selected):
		heister_option.select(0)
	_show_heister(_selected_id(heister_option))


func _on_heister_changed(_index: int) -> void:
	_show_heister(_selected_id(heister_option))
	refresh()


func _show_heister(id: StringName) -> void:
	heister_swatch.color = Heisters.accent(id)
	heister_swatch.visible = id != &""  # LEAD r229 run: "Any Free Heister" has no accent; a bare grey strip read as a scrollbar
	var tex: Texture2D = Heisters.portrait(id)
	heister_portrait.texture = tex
	heister_portrait.visible = tex != null


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


func _fill_from(o: ItemSlot, defs: Array, selected: StringName, allow_none: bool) -> void:
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
		var o: ItemSlot = _row(_mods_box, _mod_type_key(mod_type), &"range")
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
		if _mods_box.visible:
			focus_chain.append(mod_options[t] as Control)
	for c: Control in [melee_option, armor_option, deployable_option, throwable_option, mask_option,
			heister_option, stats_mode_button, launch_button,
			skills_button, perks_button, workshop_button, back_button]:
		if (c != launch_button or not hub_mode) and (c.visible or not compact_mode):
			focus_chain.append(c)
	if is_inside_tree():
		UiNav.chain_vertical(focus_chain)
		# PO-4 card grid: left / right pair the two cards of a row (the chain stays the down / up order).
		UiNav.chain_horizontal([primary_slot, weapon_option] as Array[Control], false)
		primary_slot.focus_neighbor_bottom = primary_slot.get_path_to(weapon_option)
		UiNav.chain_horizontal([melee_option, armor_option] as Array[Control], false)
		UiNav.chain_horizontal([deployable_option, throwable_option] as Array[Control], false)
		UiNav.chain_horizontal([mask_option, heister_option] as Array[Control], false)
		var mods: Array[Control] = []
		var mod_types: Array = mod_options.keys()
		mod_types.sort()
		for t: Variant in mod_types:
			mods.append(mod_options[t] as Control)
		UiNav.chain_horizontal(mods, false)
		var nav: Array[Control] = [back_button]
		if not compact_mode:
			nav.append_array([skills_button, perks_button, workshop_button] as Array[Control])
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


## D-155: every melee is listed; one the player's level has not reached is disabled with the level that unlocks it.
## A saved pick that is locked shows the starter knife instead (MeleeGate.usable).
func _fill_melees() -> void:
	melee_option.clear()
	for r: Variant in ContentDB.all_melees():
		var d: MeleeDef = r as MeleeDef
		var text: String = UiText.t(UiText.item_key(d.id))
		var locked: bool = not MeleeGate.is_unlocked(profile, d)
		if locked:
			text = UiText.t(&"ui.loadout.melee_locked", {"name": text, "level": d.unlock_level})
		_add_item(melee_option, text, d.id)
		melee_option.set_item_disabled(melee_option.item_count - 1, locked)
	if not _select_id(melee_option, MeleeGate.usable(profile, profile.loadout.melee)) and melee_option.item_count > 0:
		melee_option.select(0)


## D-126: every secondary (pistols, SMGs, shotguns, then the rest; WorkshopModel order). Owned ones can be picked; the
## others are listed disabled with what they take (a level, or buying in the Workshop), so the slot's range shows from
## a fresh profile (the PO saw only the Kestrel and read the slot as pistols only).
func _fill_weapons() -> void:
	weapon_option.clear()
	for wid: StringName in WorkshopModel.weapon_ids():
		var w: WeaponDef = ContentDB.weapon(wid)
		if w == null or w.slot != Enums.WeaponSlot.SECONDARY:
			continue
		var text: String = UiText.t(UiText.item_key(wid))
		var owned: bool = profile.owned_weapons.has(wid)
		if not owned:
			text = UiText.t(&"ui.loadout.weapon_locked", {"name": text, "level": w.unlock_level}) \
					if profile.level < w.unlock_level else UiText.t(&"ui.loadout.weapon_for_sale", {"name": text})
		_add_item(weapon_option, text, wid)
		weapon_option.set_item_disabled(weapon_option.item_count - 1, not owned)
		weapon_option.set_item_glyph(weapon_option.item_count - 1, class_glyph(int(w.weapon_class)))
	_select_id(weapon_option, profile.loadout.secondary)


## HubStationIcon kind for a weapon class (D-126 picker tiles).
static func class_glyph(weapon_class: int) -> StringName:
	match weapon_class:
		Enums.WeaponClass.SMG:
			return &"smg"
		Enums.WeaponClass.SHOTGUN:
			return &"shotgun"
		Enums.WeaponClass.SPECIAL:
			return &"saw"
		Enums.WeaponClass.PISTOL:
			return &"pistol"
	return &"armory"


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
			var skill: Dictionary = DeployableGate.unlock_skill(id) if card.is_empty() else {}
			if not skill.is_empty():  # lead ruling: ECM / trip mine / FAK need their skill
				text = UiText.t(&"ui.loadout.deployable_locked_skill", {"item": text,
						"name": UiText.t(StringName(skill["name"]))})
			else:
				text = UiText.t(&"ui.loadout.deployable_locked", {"item": text, "card": int(card.get("card", 0)),
						"name": UiText.t(StringName(card.get("name", &"")))})
		deployable_option.set_item_text(i, text)
		deployable_option.set_item_disabled(i, not ok)
		if not ok and deployable_option.selected == i:
			_select_id(deployable_option, &"")
			changed = true
	return changed


## Lead queue: a heister's picker picture: ENV D's portrait, else an accent-tinted head-and-shoulders silhouette.
static func heister_icon(id: StringName) -> Texture2D:
	var tex: Texture2D = Heisters.portrait(id)
	return tex if tex != null else silhouette_icon(Heisters.accent(id))


static func silhouette_icon(c: Color) -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(UiTokens.INK_0)
	var fill: Color = c.lerp(UiTokens.PAPER_DIM, 0.35)
	for y: int in range(n):
		for x: int in range(n):
			var head: bool = Vector2(x - 32, y - 24).length() <= 11.0
			var body: bool = y >= 40 and Vector2((x - 32) / 1.6, y - 64).length() <= 22.0
			if head or body:
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


static func _bar_max(stat: String) -> float:
	return float(STAT_BAR_MAX.get(stat, 100.0))


static func _add_item(o: ItemSlot, text: String, id: StringName) -> void:
	o.add_item(text)
	o.set_item_metadata(o.item_count - 1, id)


static func _selected_id(o: ItemSlot) -> StringName:
	if o == null or o.selected < 0:
		return &""
	return StringName(o.get_item_metadata(o.selected))


static func _select_id(o: ItemSlot, id: StringName) -> bool:
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
