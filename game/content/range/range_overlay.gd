## Firing range overlay (B1-05): loadout swap panel (left), live stat panel (left, below), readout
## and last shot (right), ammo/hints (bottom), crosshair. Owner: ENV B. Shared theme
## (UiBuild/caper_theme), every string from strings.csv, keyboard/mouse and gamepad focus chain.
## PO-4 Case File restyle (style.md): case-file panels, caption labels over values, 21-unit rows, a fixed
## footer (Leave ghost left, Reset right) and a key cap hint strip that follows the last device. Aim
## mode shows less: the loadout panel hides and the right panel shrinks to the readout and last shot.
##
## The overlay holds no game state: FiringRange pushes values in (show_*) and listens to the
## signals. Panel mode = interactive (mouse visible, focus chain active); aim mode = read-only.
## Panel mode keys: Tab / gamepad Start -> aim mode; Esc / gamepad B (ui_cancel) -> exit_requested.
class_name RangeOverlay
extends Control

signal weapon_selected(weapon_id: StringName)
signal mod_selected(mod_type: int, mod_id: StringName)
signal difficulty_selected(difficulty: int)
signal readout_lane_selected(lane: int)
signal reset_requested()
signal exit_requested()
signal aim_requested(on: bool)

const ROW_FONT_SIZE: int = UiTokens.FONT_SMALL
const PANEL_MARGIN: int = UiTokens.S4
## Space kept free under the side panels for the ammo line and the hint strip.
const BOTTOM_RESERVE: int = 150
const LEFT_WIDTH: int = 460
const RIGHT_WIDTH: int = 440
## [row id, label key]: StatCalculator.display keys first, then physical values.
const DISPLAY_ROWS: Array[Array] = [
	["damage", &"ui.stat.damage"], ["accuracy", &"ui.stat.accuracy"], ["stability", &"ui.stat.stability"],
	["concealment", &"ui.stat.concealment"], ["threat", &"ui.stat.threat"], ["mag", &"ui.stat.magazine"],
	["total_ammo", &"ui.stat.total_ammo"], ["rof", &"ui.stat.rate_of_fire"], ["reload", &"ui.stat.reload"],
]
const PHYSICAL_ROWS: Array[Array] = [
	["phys_damage", &"ui.range.phys.damage"], ["phys_pellets", &"ui.range.phys.pellets"],
	["phys_headshot", &"ui.range.phys.headshot_mult"], ["phys_rpm", &"ui.range.phys.fire_rate"],
	["phys_falloff_start", &"ui.range.phys.falloff_start"], ["phys_falloff_end", &"ui.range.phys.falloff_end"],
	["phys_falloff_min", &"ui.range.phys.falloff_min"], ["phys_spread_ads", &"ui.range.phys.spread_ads"],
	["phys_spread_hip", &"ui.range.phys.spread_hip"], ["phys_reload", &"ui.range.phys.reload"],
	["phys_reload_empty", &"ui.range.phys.reload_empty"],
]
const READOUT_ROWS: Array[Array] = [
	["ro_target", &"ui.range.ro.target"], ["ro_distance", &"ui.range.ro.distance"], ["ro_health", &"ui.range.ro.health"],
	["ro_armor", &"ui.range.ro.armor"], ["ro_falloff", &"ui.range.ro.falloff"], ["ro_body", &"ui.range.ro.body_damage"],
	["ro_head", &"ui.range.ro.head_damage"], ["ro_dps", &"ui.range.ro.dps"],
	["ro_sustained", &"ui.range.ro.sustained_dps"], ["ro_ttk_body", &"ui.range.ro.ttk_body"],
	["ro_ttk_head", &"ui.range.ro.ttk_head"],
]
## D-111 ("the range still feels experimental"): aim mode keeps a small target card, these rows only; the
## full readout, falloff graph and per-dummy table are in panel mode (Tab).
const AIM_ROWS: Array[String] = ["ro_target", "ro_distance", "ro_dps", "ro_ttk_body", "ro_ttk_head", "ls_damage",
	"ls_result"]
const LAST_SHOT_ROWS: Array[Array] = [
	["ls_distance", &"ui.range.ls.distance"], ["ls_damage", &"ui.range.ls.damage"],
	["ls_zone", &"ui.range.ls.zone"], ["ls_result", &"ui.range.ls.result"],
]

var weapon_option: OptionButton
var difficulty_option: OptionButton
var readout_option: OptionButton
var reset_button: Button
var exit_button: Button
## ModType (int) -> OptionButton for the current weapon.
var mod_options: Dictionary = {}
var focus_chain: Array[Control] = []
var interactive: bool = true
## B4-13 falloff graph (right panel).
var falloff_graph: RangeFalloffGraph
## Key cap hint strip (bottom): [key cap, caption] pairs for the current mode and device.
var hints: HBoxContainer
## D-111: the physical-values section folds behind this toggle (closed by default).
var details_toggle: Button
var _physical_section: VBoxContainer

var _values: Dictionary = {}   # row id -> Label
var _mods_box: VBoxContainer
var _ammo_label: Label
var _hints_pad: bool = false
var _crosshair: Label
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _right_box: VBoxContainer
## Right-panel parts hidden in aim mode (target picker, falloff graph, per-dummy table).
var _right_extras: Array[Control] = []
var _weapon_ids: Array[StringName] = []
var _lane_labels: PackedStringArray = PackedStringArray()
## B4-13: the per-dummy-type TTK table (dummy id -> value Label).
var _dummy_grid: GridContainer
var _dummy_values: Dictionary = {}
var _tweak: RangeTweak = null
var _difficulty: int = 0
var _readout_lane: int = 0
## True when the FALLBACK range camera is the shooter (no ENV A crew controller).
var _fallback_camera: bool = true


## Call before adding to the tree. `fallback_camera`: the shooter is the fallback RangeSpectator
## (other aim-mode controls, and a notice), not ENV A's crew member.
## `lane_labels`: one readout-target option per range target (lane order).
func setup(lane_labels: PackedStringArray, difficulty: int, readout_lane: int, fallback_camera: bool,
		range_tweak: RangeTweak = null) -> void:
	_lane_labels = lane_labels
	_tweak = range_tweak
	_difficulty = difficulty
	_readout_lane = readout_lane
	_fallback_camera = fallback_camera


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if theme == null:
		theme = UiBuild.theme()
	UiNav.ensure_pad_ui_actions()  # pad A / B work here even when the range is the first screen
	_build_left()
	_build_right()
	_build_bottom()
	_rechain()
	set_interactive(interactive)


## Fill the weapon list and the mod options for `def` (selected `mods`, ModType -> mod id).
func show_weapon(def: WeaponDef, mods: Dictionary) -> void:
	if _weapon_ids.is_empty():
		for w: WeaponDef in ContentDB.all_weapons():
			_weapon_ids.append(w.id)
			weapon_option.add_item(UiText.t(UiText.item_key(w.id)))
	weapon_option.select(_weapon_ids.find(def.id))
	for c: Node in _mods_box.get_children():
		_mods_box.remove_child(c)
		c.queue_free()
	mod_options.clear()
	var slots: Array = def.mod_slots.keys()
	slots.sort()
	for slot: Variant in slots:
		var mod_type: int = int(slot)
		var type_name: String = String(Enums.ModType.keys()[mod_type]).to_lower()
		var opt: OptionButton = UiBuild.option_button()
		var ids: Array[StringName] = []
		if not def.default_mods.has(slot):
			ids.append(&"")
			opt.add_item(UiText.t(&"ui.range.mod_none"))
		for mod_id: Variant in def.mod_slots[slot]:
			ids.append(StringName(mod_id))
			opt.add_item(UiText.t(UiText.item_key(StringName(mod_id))))
		opt.set_meta(&"ids", ids)
		opt.select(maxi(ids.find(StringName(mods.get(mod_type, &""))), 0))
		opt.item_selected.connect(_on_mod_selected.bind(mod_type, opt))
		_mods_box.add_child(_inline_field(StringName("ui.mod_type.%s" % type_name), opt))
		mod_options[mod_type] = opt
	_rechain()


## Live weapon stats: StatCalculator display numbers and the physical values.
func show_stats(stats: WeaponStats) -> void:
	var disp: Dictionary = StatCalculator.display(stats)
	for row: Array in DISPLAY_ROWS:
		var key: String = String(row[0])
		var v: Variant = disp.get(key, 0)
		var text: String = _num(float(v), 2)
		if key == "rof":
			text = UiText.t(&"ui.range.fmt.rpm", {"value": _num(float(v), 0)})
		elif key == "reload":
			text = UiText.t(&"ui.range.fmt.s", {"value": _num(float(v), 2)})
		_set_value(key, text)
	_set_value("phys_damage", _num(stats.damage, 2))
	_set_value("phys_pellets", str(stats.pellets))
	_set_value("phys_headshot", UiText.t(&"ui.range.fmt.mult", {"value": _num(stats.headshot_mult, 2)}))
	_set_value("phys_rpm", UiText.t(&"ui.range.fmt.rpm", {"value": _num(stats.fire_rate_rpm, 0)}))
	_set_value("phys_falloff_start", UiText.t(&"ui.range.fmt.m", {"value": _num(stats.falloff_start_m, 1)}))
	_set_value("phys_falloff_end", UiText.t(&"ui.range.fmt.m", {"value": _num(stats.falloff_end_m, 1)}))
	_set_value("phys_falloff_min", UiText.t(&"ui.range.fmt.mult", {"value": _num(stats.falloff_min_mult, 2)}))
	_set_value("phys_spread_ads", UiText.t(&"ui.range.fmt.deg", {"value": _num(stats.spread_deg_ads, 2)}))
	_set_value("phys_spread_hip", UiText.t(&"ui.range.fmt.deg", {"value": _num(stats.spread_deg_hip, 2)}))
	_set_value("phys_reload", UiText.t(&"ui.range.fmt.s", {"value": _num(stats.reload_time_s, 2)}))
	_set_value("phys_reload_empty", UiText.t(&"ui.range.fmt.s", {"value": _num(stats.reload_empty_time_s, 2)}))


## RangeDamageModel.readout() (or RangeMath.readout()) for the selected dummy, plus its display
## name and armor description.
func show_readout(r: Dictionary, dummy_name: String, armor_text: String = "") -> void:
	_set_value("ro_target", dummy_name)
	_set_value("ro_armor", armor_text if armor_text != "" else UiText.t(&"ui.range.armor.none"))
	_set_value("ro_distance", UiText.t(&"ui.range.fmt.m", {"value": _num(float(r["distance_m"]), 1)}))
	_set_value("ro_health", UiText.t(&"ui.range.fmt.hp", {"value": _num(float(r["health"]), 0)}))
	_set_value("ro_falloff", UiText.t(&"ui.range.fmt.mult", {"value": _num(float(r["falloff_mult"]), 2)}))
	var body_blocked: bool = bool(r.get("body_blocked", false))
	var head_blocked: bool = bool(r.get("head_blocked", false))
	_set_value("ro_body", UiText.t(&"ui.range.blocked") if body_blocked else _num(float(r["body_damage"]), 1))
	if head_blocked:
		_set_value("ro_head", UiText.t(&"ui.range.blocked"))
	else:
		_set_value("ro_head", UiText.t(&"ui.range.fmt.head", {
			"value": _num(float(r["head_damage"]), 1), "mult": _num(float(r["headshot_mult"]), 2)}))
	_set_value("ro_dps", UiText.t(&"ui.range.fmt.dps", {"value": _num(float(r["dps"]), 1)}))
	_set_value("ro_sustained", UiText.t(&"ui.range.fmt.dps", {"value": _num(float(r["sustained_dps"]), 1)}))
	_set_value("ro_ttk_body", _ttk(int(r["shots_body"]), float(r["ttk_body_s"]), body_blocked))
	_set_value("ro_ttk_head", _ttk(int(r["shots_head"]), float(r["ttk_head_s"]), head_blocked))


## Falloff graph for the resolved weapon with a marker at the readout distance.
func show_falloff(stats: WeaponStats, distance_m: float) -> void:
	if falloff_graph != null:
		falloff_graph.show_falloff(stats, distance_m)


## Per-dummy-type TTK table: rows of {id, name, readout} (RangeDamageModel.readout at the readout
## distance). Rows are created on the first call and updated in place afterwards.
func show_dummy_table(rows: Array[Dictionary]) -> void:
	for row: Dictionary in rows:
		var id: StringName = StringName(row["id"])
		var value: Label = _dummy_values.get(id) as Label
		if value == null:
			var name_label: Label = _small(UiBuild.label(&"", UiBuild.DIM))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_dummy_grid.add_child(name_label)
			value = _small(UiBuild.label(&""))
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value.set_meta(&"name_label", name_label)
			_dummy_grid.add_child(value)
			_dummy_values[id] = value
		(value.get_meta(&"name_label") as Label).text = String(row["name"])
		value.text = dummy_row_text(row["readout"] as Dictionary)


## "body N shots, t s · head ..." for one per-dummy readout.
static func dummy_row_text(r: Dictionary) -> String:
	var body: String = _ttk_short(int(r["shots_body"]), float(r["ttk_body_s"]))
	var head: String = _ttk_short(int(r["shots_head"]), float(r["ttk_head_s"]))
	return UiText.t(&"ui.range.fmt.ttk_pair", {"body": body, "head": head})


## Current text of a per-dummy row (tests).
func dummy_value_text(dummy_id: StringName) -> String:
	var l: Label = _dummy_values.get(dummy_id) as Label
	return l.text if l != null else ""


## Last hit: {distance_m, amount, zone, killed, health_after} or empty for "no shot yet".
func show_last_shot(d: Dictionary) -> void:
	if d.is_empty():
		for row: Array in LAST_SHOT_ROWS:
			_set_value(String(row[0]), UiText.t(&"ui.range.none"))
		return
	_set_value("ls_distance", UiText.t(&"ui.range.fmt.m", {"value": _num(float(d.get("distance_m", 0.0)), 1)}))
	_set_value("ls_damage", _num(float(d.get("amount", 0.0)), 1))
	var zone_text: String = UiText.t(zone_key(int(d.get("zone", Enums.HitZone.BODY))))
	if bool(d.get("via_shield", false)):
		zone_text = UiText.t(&"ui.range.ls.via_shield", {"zone": zone_text})
	_set_value("ls_zone", zone_text)
	if bool(d.get("blocked", false)):
		_set_value("ls_result", UiText.t(&"ui.range.blocked"))
	elif int(d.get("plate_stage", -1)) >= 0:
		if bool(d.get("plate_broken", false)):
			_set_value("ls_result", UiText.t(&"ui.range.ls.plate_broken", {"n": int(d["plate_stage"]) + 1}))
		else:
			_set_value("ls_result", UiText.t(&"ui.range.ls.plate", {
				"n": int(d["plate_stage"]) + 1, "hp": _num(float(d.get("plate_health_after", 0.0)), 1)}))
	elif bool(d.get("killed", false)):
		_set_value("ls_result", UiText.t(&"ui.range.ls.killed"))
	else:
		_set_value("ls_result", UiText.t(&"ui.range.fmt.hp", {"value": _num(float(d.get("health_after", 0.0)), 1)}))


## Magazine `ammo` of `mag`; `reserve` < 0 = no reserve shown (the fallback gun has infinite ammo).
func show_ammo(ammo: int, mag: int, reloading: bool, reserve: int = -1) -> void:
	if reloading:
		_ammo_label.text = UiText.t(&"ui.range.reloading")
	elif reserve >= 0:
		_ammo_label.text = UiText.t(&"ui.range.ammo_reserve", {"ammo": ammo, "mag": mag, "reserve": reserve})
	else:
		_ammo_label.text = UiText.t(&"ui.range.ammo", {"ammo": ammo, "mag": mag})


## Current ammo line (tests).
func ammo_text() -> String:
	return _ammo_label.text if _ammo_label != null else ""


## Panel mode (true) or aim mode (false).
func set_interactive(on: bool) -> void:
	interactive = on
	if hints == null:
		return
	_crosshair.visible = not on
	_left_panel.visible = on
	for c: Control in _right_extras:
		c.visible = on
	_apply_row_filter()
	_fit_right.call_deferred()
	refresh_hints()
	for c: Control in focus_chain:
		c.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
		c.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if on:
		UiNav.focus_first(focus_chain)
	elif is_inside_tree():
		get_viewport().gui_release_focus()


## [key cap text, caption key] pairs of the hint strip for the current mode and last device.
func hint_pairs() -> Array[Array]:
	var panels_key: String = UiText.t(&"ui.key.start" if InteractionPanel.pad_active else &"ui.key.tab")
	if interactive:
		return [[panels_key, &"ui.range.key.aim"], [InteractionPanel.action_key_text(&"ui_accept"), &"ui.hint.select"],
			[InteractionPanel.action_key_text(&"ui_cancel"), &"ui.range.key.leave"]]
	if _fallback_camera:
		return []  # the fallback camera's own controls are spelled out (ui.range.hint_aim)
	var pairs: Array[Array] = []
	for a: Array in [[&"fire", &"ui.range.key.fire"], [&"aim", &"ui.range.key.ads"], [&"reload", &"ui.range.key.reload"]]:
		pairs.append([InteractionPanel.action_key_text(a[0] as StringName), a[1]])
	var swap: String = InteractionPanel.action_key_text(&"swap_weapon")
	if not InteractionPanel.pad_active:  # the keyboard swaps with the slot keys (swap_weapon is the wheel)
		swap = "%s/%s" % [InteractionPanel.action_key_text(&"slot_secondary"),
			InteractionPanel.action_key_text(&"slot_primary")]
	pairs.append([swap, &"ui.range.key.swap"])
	pairs.append([panels_key, &"ui.range.key.panels"])
	return pairs


## Rebuilds the hint strip (mode change or device switch).
func refresh_hints() -> void:
	if hints == null:
		return
	_hints_pad = InteractionPanel.pad_active
	for c: Node in hints.get_children():
		hints.remove_child(c)
		c.queue_free()
	if not interactive and _fallback_camera:
		var l: Label = UiBuild.caption(&"ui.range.hint_aim")
		l.uppercase = false
		hints.add_child(UiBuild.float_text(l))
		return
	for pair: Array in hint_pairs():
		var h: HBoxContainer = UiBuild.hbox(UiTokens.S2)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UiBuild.keycap(String(pair[0]), UiTokens.FONT_SMALL))
		h.add_child(UiBuild.float_text(UiBuild.caption(StringName(pair[1]))))
		hints.add_child(h)


## Current text of a value row (tests).
func value_text(row_id: String) -> String:
	var l: Label = _values.get(row_id) as Label
	return l.text if l != null else ""


static func zone_key(zone: int) -> StringName:
	var keys: Array = Enums.HitZone.keys()
	return StringName("ui.range.zone.%s" % String(keys[clampi(zone, 0, keys.size() - 1)]).to_lower())


func _input(event: InputEvent) -> void:
	InteractionPanel.note_input(event)
	if hints != null and InteractionPanel.pad_active != _hints_pad:
		refresh_hints()
	if not interactive or not is_visible_in_tree():
		return
	var key: InputEventKey = event as InputEventKey
	var jb: InputEventJoypadButton = event as InputEventJoypadButton
	var to_aim: bool = (key != null and key.pressed and not key.echo and key.physical_keycode == KEY_TAB) \
		or (jb != null and jb.pressed and jb.button_index == JOY_BUTTON_START)
	if to_aim:
		get_viewport().set_input_as_handled()
		aim_requested.emit(true)


func _unhandled_input(event: InputEvent) -> void:
	if interactive and is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()


func _build_left() -> void:
	var outer: VBoxContainer = _side_panel(true, LEFT_WIDTH)
	_left_panel = outer.get_parent() as PanelContainer
	var head: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	head.add_child(UiBuild.caption(&"ui.range.crumb"))
	head.add_child(UiBuild.label(&"ui.range.title", UiBuild.SUBHEADER))
	head.add_child(_small(UiBuild.label(&"ui.range.free_note", UiBuild.DIM)))
	outer.add_child(head)
	var box: VBoxContainer = _scroll(outer)
	weapon_option = UiBuild.option_button()
	weapon_option.item_selected.connect(_on_weapon_selected)
	box.add_child(_inline_field(&"ui.range.weapon", weapon_option))
	_mods_box = UiBuild.vbox(UiTokens.S2)
	box.add_child(_mods_box)
	difficulty_option = UiBuild.option_button()
	for d: int in range(Enums.Difficulty.size()):
		difficulty_option.add_item(UiText.t(UiText.difficulty_key(d)))
	difficulty_option.select(_difficulty)
	difficulty_option.item_selected.connect(func(i: int) -> void: difficulty_selected.emit(i))
	box.add_child(_inline_field(&"ui.range.difficulty", difficulty_option))
	box.add_child(_section(&"ui.range.stats", DISPLAY_ROWS))
	details_toggle = UiBuild.ghost(UiBuild.button(&"ui.range.details_show"))
	details_toggle.toggle_mode = true
	details_toggle.toggled.connect(set_details_open)
	box.add_child(details_toggle)
	_physical_section = _section(&"ui.range.physical", PHYSICAL_ROWS)
	_physical_section.visible = false
	box.add_child(_physical_section)
	# Footer outside the scroll, always in view: Leave (ghost, left), Reset (right).
	exit_button = UiBuild.button(&"ui.range.exit")
	reset_button = UiBuild.button(&"ui.range.reset_targets")
	var foot: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	foot.add_child(UiBuild.back(exit_button))
	foot.add_child(UiBuild.spacer())
	foot.add_child(reset_button)
	for b: Button in [reset_button, exit_button]:
		b.custom_minimum_size = Vector2(0, 0)
	outer.add_child(foot)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	exit_button.pressed.connect(func() -> void: exit_requested.emit())


func _build_right() -> void:
	var outer: VBoxContainer = _side_panel(false, RIGHT_WIDTH)
	_right_panel = outer.get_parent() as PanelContainer
	var box: VBoxContainer = _scroll(outer)
	_right_box = box
	readout_option = UiBuild.option_button()
	for label: String in _lane_labels:
		readout_option.add_item(label)
	if _lane_labels.size() > 0:
		readout_option.select(clampi(_readout_lane, 0, _lane_labels.size() - 1))
	readout_option.item_selected.connect(func(i: int) -> void: readout_lane_selected.emit(i))
	var lane_field: HBoxContainer = _inline_field(&"ui.range.readout_lane", readout_option)
	box.add_child(lane_field)
	# D-111: the falloff graph is the panel's picture; it sits under the target picker, above the numbers.
	var graph_box: VBoxContainer = _section_box(&"ui.range.falloff_graph")
	falloff_graph = RangeFalloffGraph.new()
	falloff_graph.name = "FalloffGraph"
	falloff_graph.setup(_tweak if _tweak != null else RangeTweak.new())
	graph_box.add_child(falloff_graph)
	box.add_child(graph_box)
	box.add_child(_section(&"ui.range.readout", READOUT_ROWS))
	box.add_child(_section(&"ui.range.last_shot", LAST_SHOT_ROWS))
	var dummies: VBoxContainer = _section_box(&"ui.range.per_dummy")
	dummies.add_child(_small(UiBuild.label(&"ui.range.per_dummy_hint", UiBuild.DIM)))
	_dummy_grid = GridContainer.new()
	_dummy_grid.columns = 2
	_dummy_grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
	_dummy_grid.add_theme_constant_override(&"v_separation", 2)
	dummies.add_child(_dummy_grid)
	box.add_child(dummies)
	_right_extras = [lane_field, graph_box, dummies]
	show_last_shot({})


func _build_bottom() -> void:
	var bottom: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -PANEL_MARGIN
	bottom.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom)
	_ammo_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD_BIG))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_ammo_label)
	hints = UiBuild.hbox(UiTokens.S5)
	hints.name = "Hints"
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(hints)
	if _fallback_camera:
		var temp: Label = UiBuild.float_text(UiBuild.caption(&"ui.range.temp_camera"))
		temp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bottom.add_child(temp)
	_crosshair = UiBuild.label(&"ui.range.crosshair", UiBuild.HUD_BIG)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)


## A full-height scrolling HUD panel on the left or right edge; returns its content box.
## A full-height HUD panel on the left or right edge; returns its outer box (fixed parts go here,
## the scrolling part comes from _scroll()).
func _side_panel(left: bool, width: int) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.0 if left else 1.0
	panel.anchor_right = panel.anchor_left
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = PANEL_MARGIN if left else -PANEL_MARGIN - width
	panel.offset_right = PANEL_MARGIN + width if left else -PANEL_MARGIN
	panel.offset_top = PANEL_MARGIN
	panel.offset_bottom = -BOTTOM_RESERVE
	panel.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var outer: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	panel.add_child(outer)
	return outer


## The scrolling content box of a side panel (fills the panel's free height).
func _scroll(outer: VBoxContainer) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var box: VBoxContainer = UiBuild.vbox(UiTokens.S4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


## Aim mode: the right panel shrinks to its visible content (readout + last shot); panel mode: full height.
func _fit_right() -> void:
	if _right_panel == null:
		return
	if interactive:
		_right_panel.anchor_bottom = 1.0
		_right_panel.offset_bottom = -BOTTOM_RESERVE
		return
	var pad: float = _right_panel.get_theme_stylebox(&"panel").get_minimum_size().y
	_right_panel.anchor_bottom = 0.0
	_right_panel.offset_bottom = PANEL_MARGIN + _right_box.get_combined_minimum_size().y + pad


## D-111: caption left, control right on one row (the stacked caption-over-dropdown form doubled the panel).
func _inline_field(caption_key: StringName, value: Control) -> HBoxContainer:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	var cap: Label = UiBuild.caption(caption_key)
	cap.custom_minimum_size = Vector2(150, 0)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(cap)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return row


## A section: caption title over a hairline rule; returns the box to add the body to.
func _section_box(title_key: StringName) -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	v.add_child(UiBuild.caption(title_key))
	v.add_child(HSeparator.new())
	return v


func _section(title_key: StringName, rows: Array[Array]) -> VBoxContainer:
	var v: VBoxContainer = _section_box(title_key)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
	grid.add_theme_constant_override(&"v_separation", 2)
	v.add_child(grid)
	for row: Array in rows:
		var name_label: Label = _small(UiBuild.label(StringName(row[1]), UiBuild.DIM))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var value: Label = _small(UiBuild.label(&"ui.range.none"))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
		value.set_meta(&"name_label", name_label)
		_values[String(row[0])] = value
	return v


## Opens / folds the physical-values section (D-111).
func set_details_open(on: bool) -> void:
	_physical_section.visible = on
	details_toggle.set_pressed_no_signal(on)
	details_toggle.text = UiText.t(&"ui.range.details_hide" if on else &"ui.range.details_show")
	_rechain()


## Aim mode shows only AIM_ROWS of the readout and last shot; panel mode shows every row.
func _apply_row_filter() -> void:
	for row: Array in READOUT_ROWS + LAST_SHOT_ROWS:
		var id: String = String(row[0])
		var value: Label = _values.get(id) as Label
		if value == null:
			continue
		var show: bool = interactive or AIM_ROWS.has(id)
		value.visible = show
		(value.get_meta(&"name_label") as Label).visible = show


func _rechain() -> void:
	if weapon_option == null:
		return
	focus_chain.clear()
	focus_chain.append(weapon_option)
	var slots: Array = mod_options.keys()
	slots.sort()
	for s: Variant in slots:
		focus_chain.append(mod_options[s] as Control)
	focus_chain.append(difficulty_option)
	if details_toggle != null:
		focus_chain.append(details_toggle)
	focus_chain.append(readout_option)
	focus_chain.append(reset_button)
	focus_chain.append(exit_button)
	UiNav.chain_vertical(focus_chain)
	exit_button.focus_neighbor_right = exit_button.get_path_to(reset_button)  # footer row: Leave <-> Reset
	reset_button.focus_neighbor_left = reset_button.get_path_to(exit_button)
	if is_inside_tree():
		set_interactive(interactive)


func _set_value(row_id: String, text: String) -> void:
	var l: Label = _values.get(row_id) as Label
	if l != null:
		l.text = text


func _ttk(shots: int, seconds: float, blocked: bool = false) -> String:
	if blocked:
		return UiText.t(&"ui.range.blocked")
	if shots <= 0 or is_inf(seconds):
		return UiText.t(&"ui.range.none")
	return UiText.t(&"ui.range.fmt.ttk_one" if shots == 1 else &"ui.range.fmt.ttk", {"shots": shots, "time": _num(seconds, 3)})


static func _ttk_short(shots: int, seconds: float) -> String:
	if shots <= 0 or is_inf(seconds):
		return UiText.t(&"ui.range.blocked")
	return UiText.t(&"ui.range.fmt.ttk_short", {"shots": shots, "time": _num(seconds, 2)})


func _on_weapon_selected(index: int) -> void:
	if index >= 0 and index < _weapon_ids.size():
		weapon_selected.emit(_weapon_ids[index])


func _on_mod_selected(index: int, mod_type: int, opt: OptionButton) -> void:
	var ids: Array[StringName] = opt.get_meta(&"ids")
	if index >= 0 and index < ids.size():
		mod_selected.emit(mod_type, ids[index])


static func _small(l: Label) -> Label:
	l.add_theme_font_size_override(&"font_size", ROW_FONT_SIZE)
	return l


## Up to `decimals` decimals, trailing zeros trimmed: 0.125 -> "0.125", 2.0 -> "2".
static func _num(v: float, decimals: int) -> String:
	if is_inf(v) or is_nan(v):
		return "-"
	var s: String = String.num(v, decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s
