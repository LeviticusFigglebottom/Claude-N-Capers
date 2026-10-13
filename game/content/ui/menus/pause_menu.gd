## PO-4 in-heist pause menu (audit: "pause is the full Options screen"): Resume / Options / Leave Heist
## over the dimmed, still running game (PD2 has no real pause, and a note says so). Leave asks first
## (focus starts on Cancel so a stray A never leaves). ui_cancel (Esc / B) backs out of the confirm,
## else resumes. MenuOptions owns it (open_pause / close_pause) and does the input pause / cursor.
## Owner: ENV B.
class_name PauseMenu
extends Control

signal resume_requested()
signal options_requested()
signal leave_requested()

var resume_button: Button
var options_button: Button
var leave_button: Button
var confirm_box: VBoxContainer
var confirm_button: Button
var cancel_button: Button
## The job card on the right (lead queue a): heist, difficulty, current objective, loot secured.
var job_card: PanelContainer
var job_labels: Dictionary = {}
var _menu_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if theme == null:
		theme = UiBuild.theme()
	UiNav.ensure_pad_ui_actions()
	# A left-weighted scrim: near-opaque behind the menu column (the HUD's left widgets sit there),
	# lighter over the rest so the heist stays visible.
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiTokens.INK_0, 0.75)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 760
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var scrim: PanelContainer = PanelContainer.new()
	scrim.theme_type_variation = UiBuild.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var col: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UiBuild.screen_margin(self, col, UiTokens.MARGIN + UiTokens.S5)
	col.add_child(UiBuild.caption(&"ui.pause.title"))
	var title: Label = UiBuild.label(&"ui.pause.heading", UiBuild.HEADER)
	col.add_child(title)
	var note: Label = UiBuild.label(&"ui.pause.live_note", UiBuild.DIM)
	col.add_child(note)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.S5)
	col.add_child(gap)
	_menu_box = UiBuild.vbox(UiTokens.S1)
	col.add_child(_menu_box)
	resume_button = _item(_menu_box, &"ui.menu.resume")
	options_button = _item(_menu_box, &"ui.menu.options")
	leave_button = _item(_menu_box, &"ui.menu.leave_heist")
	UiNav.chain_vertical([resume_button, options_button, leave_button] as Array[Control])
	confirm_box = UiBuild.vbox(UiTokens.S3)
	confirm_box.visible = false
	col.add_child(confirm_box)
	confirm_box.add_child(UiBuild.caption(&"ui.menu.leave_heist"))
	confirm_box.add_child(UiBuild.label(&"ui.menu.quit_confirm"))
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	confirm_box.add_child(row)
	confirm_button = UiBuild.primary(UiBuild.button(&"ui.menu.confirm"))
	cancel_button = UiBuild.sfx(UiBuild.button(&"ui.menu.cancel"), UiSfx.KIND_BACK) as Button
	for b: Button in [confirm_button, cancel_button]:
		b.custom_minimum_size = Vector2(240, UiTokens.BUTTON_H)
		row.add_child(b)
	UiNav.chain_horizontal([confirm_button, cancel_button] as Array[Control])
	resume_button.pressed.connect(resume_requested.emit)
	options_button.pressed.connect(options_requested.emit)
	leave_button.pressed.connect(open_confirm)
	confirm_button.pressed.connect(leave_requested.emit)
	cancel_button.pressed.connect(close_confirm)
	_build_job_card()
	resume_button.grab_focus.call_deferred()


func _build_job_card() -> void:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	job_card = UiBuild.panel(v, UiBuild.CARD)
	job_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	job_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	job_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	job_card.offset_right = -(UiTokens.MARGIN + UiTokens.S5)
	job_card.custom_minimum_size = Vector2(520, 0)
	job_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(job_card)
	var cap: Label = UiBuild.caption(&"ui.pause.job_caption")
	cap.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	v.add_child(cap)
	for key: StringName in [&"heist", &"difficulty", &"objective_cap", &"objective", &"loot_cap", &"loot"]:
		var l: Label
		match key:
			&"heist":
				l = UiBuild.label(&"", UiBuild.HEADER)
			&"objective_cap", &"loot_cap":
				l = UiBuild.caption(&"ui.scoreboard.objectives" if key == &"objective_cap" else &"ui.scoreboard.loot")
			&"difficulty":
				l = UiBuild.label(&"", UiBuild.DIM)
			_:
				l = UiBuild.label()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		job_labels[key] = l
	job_card.visible = false


## Fills the job card: {heist_id, difficulty, objective (text), bags (int), loot_value (int)}.
## Missing keys hide their lines; an empty dict hides the card.
func set_job(info: Dictionary) -> void:
	if job_card == null:
		return
	job_card.visible = not info.is_empty()
	var id: StringName = StringName(info.get("heist_id", &""))
	(job_labels[&"heist"] as Label).text = UiText.t(StringName("heist.%s.name" % id)) if id != &"" else ""
	job_card.add_theme_stylebox_override(&"panel", _accent_box(UiAccent.for_heist(id) if id != &"" else UiTokens.BRASS))
	(job_labels[&"difficulty"] as Label).text = UiText.t(UiText.difficulty_key(int(info.get("difficulty", 0))))
	var obj: String = String(info.get("objective", ""))
	(job_labels[&"objective"] as Label).text = obj
	(job_labels[&"objective"] as Label).visible = obj != ""
	(job_labels[&"objective_cap"] as Label).visible = obj != ""
	var bags: int = int(info.get("bags", 0))
	var loot: Label = job_labels[&"loot"] as Label
	loot.text = UiText.t(&"ui.pause.loot_line", {"bags": bags, "value": UiText.money(int(info.get("loot_value", 0)))})
	loot.add_theme_color_override(&"font_color", UiTokens.BRASS_HI if bags > 0 else UiTokens.PAPER_DIM)


func _accent_box(edge: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = (UiBuild.theme().get_stylebox(&"panel", UiBuild.CARD) as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.border_color = edge
	sb.border_width_left = 3
	return sb


func _item(parent: Container, key: StringName) -> Button:
	var b: Button = UiBuild.button(key)  # D-090: focus + confirm cues come with UiBuild.button
	b.text = b.text.to_upper()
	b.theme_type_variation = UiBuild.MENU_ITEM
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(440, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(b)
	return b


func is_confirming() -> bool:
	return confirm_box.visible


func open_confirm() -> void:
	_menu_box.visible = false
	confirm_box.visible = true
	cancel_button.grab_focus.call_deferred()


func close_confirm() -> void:
	confirm_box.visible = false
	_menu_box.visible = true
	leave_button.grab_focus.call_deferred()


## Re-focuses Resume (shown again after Options closes).
func focus_default() -> void:
	if is_confirming():
		cancel_button.grab_focus.call_deferred()
	else:
		resume_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		UiSfx.play(UiSfx.BACK)
		if is_confirming():
			close_confirm()
		else:
			resume_requested.emit()
