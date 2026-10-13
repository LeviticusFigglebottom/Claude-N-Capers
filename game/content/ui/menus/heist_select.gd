## Heist select: heist list (HeistCatalog) + difficulty picker + contract pay preview. Owner: ENV B.
## Difficulties not in heist_list.tres `unlocked_difficulties` are visible but locked (C4, P1 = 2).
## The preview uses PayoutCalculator (same multipliers as the payday screen). Next -> briefing (MenuFlow).
class_name HeistSelect
extends UiScreen

signal heist_chosen(heist_id: StringName, difficulty: int)

var heist_buttons: Array[Button] = []
var difficulty_buttons: Array[Button] = []
var payout_label: Label
var brief_label: Label
var mode_label: Label
## PO-4: the selected heist's name as the detail title.
var name_label: Label
var next_button: Button
var back_button: Button
var selected_heist: int = 0
var selected_difficulty: int = Enums.Difficulty.ROUTINE
var _entries: Array[Dictionary] = []


func build_ui() -> void:
	_entries = HeistCatalog.entries()
	var root: VBoxContainer = UiBuild.vbox(18)
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.label(&"ui.heist_select.title", UiBuild.HEADER))
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
	detail.add_child(UiBuild.caption(&"ui.heist_select.pay_caption"))
	payout_label = UiBuild.label(&"", UiBuild.MONEY)
	payout_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_H1)
	detail.add_child(payout_label)
	var nav: HBoxContainer = UiBuild.hbox(16)
	root.add_child(nav)
	back_button = UiBuild.ghost(UiBuild.button(&"ui.menu.back"))
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
		b.pressed.connect(select_difficulty.bind(d))
		row.add_child(b)
		difficulty_buttons.append(b)


func select_heist(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	selected_heist = index
	heist_buttons[index].set_pressed_no_signal(true)
	var e: Dictionary = _entries[index]
	brief_label.text = UiText.t(StringName(e["brief_key"]))
	name_label.text = UiText.t(StringName(e["name_key"]))
	mode_label.text = "%s  |  %s" % [UiText.t(StringName(e["subtitle_key"])), UiText.t(_mode_key(int(e["mode"])))]
	_update_preview()


## Select the heist with `heist_id` (as if its button were pressed). False when it is not offered.
func select_heist_id(heist_id: StringName) -> bool:
	for i: int in range(_entries.size()):
		if StringName(_entries[i]["id"]) == heist_id:
			select_heist(i)
			return true
	return false


func select_difficulty(d: int) -> void:
	if not HeistCatalog.is_difficulty_unlocked(d):
		return
	selected_difficulty = d
	difficulty_buttons[d].set_pressed_no_signal(true)
	_update_preview()


func selected_heist_id() -> StringName:
	return StringName(_entries[selected_heist]["id"]) if selected_heist < _entries.size() else &""


## Contract pay for the current heist + difficulty (what the preview label shows).
func preview_amount() -> int:
	if selected_heist >= _entries.size():
		return 0
	return HeistCatalog.contract_preview(int(_entries[selected_heist]["base_payout"]), selected_difficulty)


func _update_preview() -> void:
	if payout_label == null:
		return
	payout_label.text = UiText.money(preview_amount())  # PO-4: the caption above says what it is


func _on_next() -> void:
	if selected_heist_id() != &"":
		heist_chosen.emit(selected_heist_id(), selected_difficulty)


static func _mode_key(mode: int) -> StringName:
	match mode:
		Enums.HeistMode.STEALTH_ONLY:
			return &"ui.heist_select.modes_stealth_only"
		Enums.HeistMode.LOUD_ONLY:
			return &"ui.heist_select.modes_loud_only"
	return &"ui.heist_select.modes_stealth_loud"
