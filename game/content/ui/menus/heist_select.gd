## Heist select: heist list (HeistCatalog) + difficulty picker + contract pay preview. Owner: ENV B.
## Difficulties not in heist_list.tres `unlocked_difficulties` are visible but locked (C4; PO-5.9: Routine..Brutal open, in order).
## The preview uses PayoutCalculator (same multipliers as the payday screen). Next -> briefing (MenuFlow).
class_name HeistSelect
extends UiScreen

signal heist_chosen(heist_id: StringName, difficulty: int)

var heist_buttons: Array[Button] = []
var difficulty_buttons: Array[Button] = []
## D-130 line under the difficulty row ("Titan cameras  ·  3 pagers"); hidden when the heist has neither.
var stealth_label: Label
var payout_label: Label
## D-139: the local player's heist freshness for the selected heist ("Freshness -20 %  ·  Played 2× in ..."); hidden at 0.
var freshness_label: Label
var brief_label: Label
var mode_label: Label
## PO-4: the selected heist's name as the detail title.
var name_label: Label
var next_button: Button
var back_button: Button
## Gamepad pass: why the locked difficulties are locked, shown under the row (a tooltip alone never reaches a pad).
var locked_label: Label
var selected_heist: int = 0
var selected_difficulty: int = Enums.Difficulty.ROUTINE
## C4 Last Breath (PD2 One Down): one down before custody. A toggle beside the difficulties; MenuFlow reads it when a
## job is chosen (and the lobby host's contract carries it).
var last_breath: bool = false
var last_breath_button: Button
var _entries: Array[Dictionary] = []


func build_ui() -> void:
	_entries = HeistCatalog.entries()
	var root: VBoxContainer = UiBuild.vbox(18)
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.header(&"ui.heist_select.crumb", &"ui.heist_select.title"))
	var cols: HBoxContainer = UiBuild.hbox(40)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var list: VBoxContainer = UiBuild.vbox(10)
	list.custom_minimum_size = Vector2(440, 0)
	cols.add_child(list)
	list.add_child(UiBuild.caption(&"ui.heist_select.jobs"))
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in range(_entries.size()):
		var b: Button = UiBuild.button(StringName(_entries[i]["name_key"]))
		# PO-4: a job card with the heist's accent on its edge (UiAccent, style_guide §3).
		b.theme_type_variation = &"StationButton"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(440, 76)
		b.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
		var edge: StyleBoxFlat = (UiBuild.theme().get_stylebox(&"pressed", &"StationButton") as StyleBoxFlat).duplicate() as StyleBoxFlat
		edge.border_color = UiAccent.for_heist(StringName(_entries[i]["id"]))
		edge.border_width_left = 6
		b.add_theme_stylebox_override(&"pressed", edge)
		b.add_theme_stylebox_override(&"hover_pressed", edge)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(select_heist.bind(i))
		list.add_child(b)
		heist_buttons.append(b)
	var detail: VBoxContainer = UiBuild.vbox(12)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(detail)
	mode_label = UiBuild.caption()
	detail.add_child(mode_label)
	name_label = UiBuild.label(&"", UiBuild.HEADER)
	detail.add_child(name_label)
	brief_label = UiBuild.label()
	brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	detail.add_child(brief_label)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.S4)
	detail.add_child(gap)
	detail.add_child(UiBuild.caption(&"ui.heist_select.difficulty"))
	_build_difficulties(detail)
	var lb_row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	detail.add_child(lb_row)
	last_breath_button = UiBuild.tab(UiBuild.button(&"ui.heist_select.last_breath"))
	last_breath_button.name = "LastBreath"
	last_breath_button.custom_minimum_size = Vector2(0, 0)
	last_breath_button.toggled.connect(set_last_breath)
	lb_row.add_child(last_breath_button)
	var lb_note: Label = UiBuild.label(&"ui.heist_select.last_breath_desc", UiBuild.DIM)
	lb_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lb_row.add_child(lb_note)
	# D-130: what this difficulty changes in the heist's stealth (Titan cameras, the pager cap); hidden when nothing.
	stealth_label = UiBuild.label(&"", UiBuild.DIM)
	stealth_label.name = "StealthNote"
	detail.add_child(stealth_label)
	detail.add_child(UiBuild.caption(&"ui.heist_select.pay_caption"))
	payout_label = UiBuild.label(&"", UiBuild.MONEY)
	payout_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_H1)
	detail.add_child(payout_label)
	freshness_label = UiBuild.label(&"", UiBuild.DIM)
	freshness_label.name = "FreshnessNote"
	detail.add_child(freshness_label)
	var nav: HBoxContainer = UiBuild.hbox(16)
	root.add_child(nav)
	back_button = UiBuild.back(UiBuild.button(&"ui.menu.back"))
	next_button = UiBuild.primary(UiBuild.button(&"ui.heist_select.next"))
	back_button.pressed.connect(back_requested.emit)
	next_button.pressed.connect(_on_next)
	nav.add_child(back_button)
	var push: Control = Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(push)
	nav.add_child(next_button)
	for b: Button in heist_buttons:
		focus_chain.append(b)
	var open_difficulties: Array[Control] = []
	for b: Button in difficulty_buttons:
		if not b.disabled:
			open_difficulties.append(b)
			focus_chain.append(b)
	focus_chain.append(last_breath_button)
	focus_chain.append(next_button)
	focus_chain.append(back_button)
	UiNav.chain_horizontal(open_difficulties, false)
	UiNav.chain_horizontal([back_button, next_button] as Array[Control], false)
	if not _entries.is_empty():
		select_heist(0)
	select_difficulty(selected_difficulty)


func _build_difficulties(parent: Container) -> void:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 10)
	row.add_theme_constant_override(&"v_separation", 10)
	parent.add_child(row)
	var group: ButtonGroup = ButtonGroup.new()
	for d: int in range(Enums.Difficulty.size()):
		var b: Button = UiBuild.tab(UiBuild.button(UiText.difficulty_key(d)))
		b.custom_minimum_size = Vector2(0, 0)
		b.button_group = group
		if not HeistCatalog.is_difficulty_unlocked(d):
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = UiText.t(&"ui.loadout.locked")
			# PO-4: muted name (disabled tab) + tooltip; "(locked)" on six tabs wrapped the row at 720p.
			b.tooltip_text = UiText.t(&"ui.heist_select.difficulty_locked", {"name": UiText.t(UiText.difficulty_key(d))})
			if HeistCatalog.is_progression_difficulty(d) and d > 0:
				b.tooltip_text = UiText.t(&"ui.heist_select.difficulty_locked_progress",
						{"name": UiText.t(UiText.difficulty_key(d)), "prev": UiText.t(UiText.difficulty_key(d - 1))})
		b.pressed.connect(select_difficulty.bind(d))
		row.add_child(b)
		difficulty_buttons.append(b)
	var reasons: PackedStringArray = PackedStringArray()
	for b2: Button in difficulty_buttons:
		if b2.disabled and b2.tooltip_text != "" and not reasons.has(b2.tooltip_text):
			reasons.append(b2.tooltip_text)
	locked_label = UiBuild.caption()
	locked_label.uppercase = false
	locked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	locked_label.text = "  ".join(reasons)
	locked_label.visible = not reasons.is_empty()
	parent.add_child(locked_label)


func select_heist(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	selected_heist = index
	_press_only(heist_buttons, index)
	var e: Dictionary = _entries[index]
	brief_label.text = UiText.t(StringName(e["brief_key"]))
	name_label.text = UiText.t(StringName(e["name_key"]))
	var mode: String = UiText.t(HeistCatalog.mode_key(StringName(e["id"]), int(e["mode"])))
	mode_label.text = "%s  |  %s" % [UiText.t(StringName(e["subtitle_key"])), mode]
	_update_preview()


## Select the heist with `heist_id` (as if its button were pressed). False when it is not offered.
## set_pressed_no_signal leaves the rest of a ButtonGroup pressed: a programmatic pick (saved difficulty, a flow)
## showed two tabs selected (D-130 capture). Only `index` stays pressed.
static func _press_only(buttons: Array[Button], index: int) -> void:
	for i: int in range(buttons.size()):
		buttons[i].set_pressed_no_signal(i == index)


func select_heist_id(heist_id: StringName) -> bool:
	for i: int in range(_entries.size()):
		if StringName(_entries[i]["id"]) == heist_id:
			select_heist(i)
			if is_inside_tree() and heist_buttons[i].is_visible_in_tree():
				heist_buttons[i].grab_focus()  # flow capture: the focus ring follows the chosen job
			return true
	return false


func select_difficulty(d: int) -> void:
	if not HeistCatalog.is_difficulty_unlocked(d):
		return
	selected_difficulty = d
	_press_only(difficulty_buttons, d)
	_update_preview()


## C4: Last Breath on / off (the toggle shows it pressed).
func set_last_breath(on: bool) -> void:
	last_breath = on
	if last_breath_button != null and last_breath_button.button_pressed != on:
		last_breath_button.set_pressed_no_signal(on)


func selected_heist_id() -> StringName:
	return StringName(_entries[selected_heist]["id"]) if selected_heist < _entries.size() else &""


## Contract pay for the current heist + difficulty (what the preview label shows).
func preview_amount() -> int:
	if selected_heist >= _entries.size():
		return 0
	return HeistCatalog.contract_preview(int(_entries[selected_heist]["base_payout"]), selected_difficulty)


## Re-reads the preview for the current selection (pay, stealth note, D-139 freshness note of
## HeistCatalog.progress_profile).
func refresh_preview() -> void:
	_update_preview()


func _update_preview() -> void:
	if payout_label == null:
		return
	payout_label.text = UiText.money(preview_amount())  # PO-4: the caption above says what it is
	if stealth_label != null and selected_heist < _entries.size():
		stealth_label.text = stealth_note(selected_heist_id(), selected_difficulty, int(_entries[selected_heist]["mode"]))
		stealth_label.visible = stealth_label.text != ""
	if freshness_label != null and selected_heist < _entries.size():
		freshness_label.text = freshness_note(selected_heist_id(), HeistCatalog.progress_profile)
		freshness_label.visible = freshness_label.text != ""


## D-139: "Freshness +5 %  ·  Not played in 17 heists" for `p` on `heist_id` (HeistFreshness), "" at 0 % or no profile.
static func freshness_note(heist_id: StringName, p: PlayerProfile) -> String:
	var ev: Dictionary = HeistFreshness.evaluate(p, heist_id)
	var badge: String = HeistFreshness.badge_text(float(ev["mult"]))
	if badge == "":
		return ""
	return UiText.t(&"ui.heist_select.freshness", {"pct": badge}) + UiText.t(&"ui.heist_select.stealth_note_sep") \
			+ HeistFreshness.reason_text(ev)


## D-130: "Titan cameras" from the heist's effective camera_titan_min_difficulty, and "N pagers" when its def's
## per-difficulty pager cap is below StealthTweak's (D-140: the usual 4 goes unsaid), or, on a heist with no pager row
## (a D-140 GUARDS map), "More guards: N" (the minimum over seeds) when the difficulty fields more than Routine; not on a
## loud-only heist; joined, "" when none applies.
static func stealth_note(heist_id: StringName, difficulty: int, mode: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if mode != Enums.HeistMode.LOUD_ONLY:
		if difficulty >= BriefingIntel.titan_min_difficulty(heist_id):
			parts.append(UiText.t(&"ui.heist_select.titan_cameras"))
		var cap: int = BriefingIntel.pager_cap(heist_id, difficulty)
		if cap >= 0 and cap < Tweak.stealth().pager_max_answers:
			parts.append(UiText.t(&"ui.heist_select.pager_one" if cap == 1 else &"ui.heist_select.pagers", {"n": cap}))
		elif cap < 0 and difficulty > Enums.Difficulty.ROUTINE:
			# D-140 GUARDS maps (no pager row, cap 4): the guaranteed guard count when this difficulty adds guards.
			var n: int = BriefingIntel.guard_range(heist_id, difficulty).x
			if n > BriefingIntel.guard_range(heist_id, Enums.Difficulty.ROUTINE).x:
				parts.append(UiText.t(&"ui.heist_select.more_guards", {"n": n}))
	return UiText.t(&"ui.heist_select.stealth_note_sep").join(parts)


func _on_next() -> void:
	if selected_heist_id() != &"":
		heist_chosen.emit(selected_heist_id(), selected_difficulty)
