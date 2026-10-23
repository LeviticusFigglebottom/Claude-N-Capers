## Options screen (roadmap B5-01). Owner: ENV B. Tabs: Controls (look / hold-toggle settings and the
## rebind list, OptionsControlsTab), Audio (one slider per bus), Video, Accessibility (palette with a
## swatch preview, HUD scale, subtitle size). Footer: Apply / Revert / Reset tab / Back (+ Leave Heist
## in a heist: `in_heist`, confirm dialog, then `leave_heist_requested`; B / Esc cancels the dialog).
##
## Edits go to `draft` (a copy of `settings`); Apply copies it into `settings` (GameSettings.current()
## unless set before _ready), saves it (`save_on_apply`) and pushes it into the engine (`apply()`);
## Revert reloads the draft; Back (button, Esc / pad B) discards unapplied edits. Opened by MenuFlow
## from the main menu, the hub's profile panel and, in a heist, the `pause` action (open_options()).
## Focus: tab row (left/right), the page's rows (up/down; sliders use left/right), footer.
class_name OptionsScreen
extends UiScreen

signal applied()
## In-heist only: the player confirmed Leave Heist (MenuOptions wires it to MenuFlow._leave_heist).
signal leave_heist_requested()

const TAB_CONTROLS: StringName = &"controls"
## D-111 (style.md §11): the rebind table has its own tab (it sat under twelve Controls rows and read as a
## stray header over the footer).
const TAB_KEYS: StringName = &"keys"
const TAB_AUDIO: StringName = &"audio"
const TAB_VIDEO: StringName = &"video"
const TAB_ACCESSIBILITY: StringName = &"accessibility"
const TABS: Array[StringName] = [TAB_CONTROLS, TAB_KEYS, TAB_AUDIO, TAB_VIDEO, TAB_ACCESSIBILITY]
## Settings sections each tab edits (Reset tab resets these).
const TAB_SECTIONS: Dictionary = {
	&"controls": [&"controls", &"gameplay"], &"keys": [&"bindings"], &"audio": [&"audio"], &"video": [&"video"],
	&"accessibility": [&"accessibility"],
}

## Write the file on Apply (tests turn it off).
@export var save_on_apply: bool = true

var settings: GameSettings = null
## Set before _ready by MenuOptions.open_in_heist: shows Leave Heist in the footer.
var in_heist: bool = false
var leave_button: Button = null
var leave_confirm: Control = null
var leave_confirm_button: Button = null
var leave_cancel_button: Button = null
## Lead r228: Controls tab "First-time tips: Show again" (confirm dialog, then OnboardingTips.reset()).
var tips_button: Button = null
var tips_done_label: Label = null
var tips_confirm: Control = null
var tips_confirm_button: Button = null
var tips_cancel_button: Button = null
var draft: GameSettings = null
var current_tab: StringName = TAB_CONTROLS
## tab id -> Button / page Control / Array[Control] (the page's vertical focus order).
var tab_buttons: Dictionary = {}
var pages: Dictionary = {}
var page_focus: Dictionary = {}
var controls_tab: OptionsControlsTab
var palette_preview: HBoxContainer
var apply_button: Button
var revert_button: Button
var reset_button: Button
var back_button: Button
var dirty_label: Label
var _page_host: ScrollContainer
## "section/key" -> its row control, so rows follow draft changes made elsewhere (video/quality_preset).
var _row_controls: Dictionary = {}


func build_ui() -> void:
	if settings == null:
		settings = GameSettings.current()
	draft = settings.duplicate_settings()
	draft.changed.connect(_on_draft_changed)
	var bg: ColorRect = ColorRect.new()
	bg.color = UiAccent.app_bg()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	fill_window(bg)  # r268: opened from the in-heist pause, the map showed at both sides on 21:9
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.header(&"ui.options.crumb", &"ui.options.title"))
	var tab_row: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	var group: ButtonGroup = ButtonGroup.new()
	for t: StringName in TABS:
		var b: Button = UiBuild.tab(UiBuild.button(StringName("ui.options.tab.%s" % t)))
		b.custom_minimum_size = Vector2(220, 0)
		b.button_group = group
		b.pressed.connect(show_tab.bind(t))
		tab_row.add_child(b)
		tab_buttons[t] = b
	root.add_child(tab_row)
	_page_host = ScrollContainer.new()
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_host.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_host.follow_focus = true
	root.add_child(_page_host)
	root.add_child(_build_footer())
	_build_pages()
	show_tab(current_tab, false)
	if in_heist:
		_build_leave_confirm()


func _build_leave_confirm() -> void:
	var d: Dictionary = _confirm_dialog(&"ui.menu.leave_heist", &"ui.menu.quit_confirm", &"AlertPanel",
			func() -> void:
				close_leave_confirm()
				leave_heist_requested.emit(),
			close_leave_confirm)  # leaving forfeits the job: a loud box
	leave_confirm = d["dim"] as Control
	leave_confirm_button = d["confirm"] as Button
	leave_cancel_button = d["cancel"] as Button


## A modal confirm over the screen: title, body, Cancel (left) and Confirm (right); hidden until opened.
func _confirm_dialog(title_key: StringName, body_key: StringName, panel_type: StringName, on_confirm: Callable,
		on_cancel: Callable) -> Dictionary:
	var dim: PanelContainer = PanelContainer.new()
	dim.theme_type_variation = UiBuild.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center: CenterContainer = CenterContainer.new()
	dim.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = panel_type
	center.add_child(panel)
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	panel.add_child(v)
	v.add_child(UiBuild.label(title_key, UiBuild.SUBHEADER))
	v.add_child(UiBuild.label(body_key))
	# Cancel (ghost) left, Confirm (primary) right, like every footer.
	var confirm: Button = UiBuild.button(&"ui.menu.confirm")
	var cancel: Button = UiBuild.button(&"ui.menu.cancel")
	for b: Button in [confirm, cancel]:
		b.custom_minimum_size = Vector2(240, 0)
		b.focus_neighbor_top = NodePath(".")  # the d-pad stays inside the dialog
		b.focus_neighbor_bottom = NodePath(".")
	var h: HBoxContainer = UiBuild.footer(cancel, confirm)
	UiNav.chain_horizontal([cancel, confirm] as Array[Control])
	confirm.pressed.connect(on_confirm)
	cancel.pressed.connect(on_cancel)
	v.add_child(h)
	dim.visible = false
	add_child(dim)
	return {"dim": dim, "confirm": confirm, "cancel": cancel}


## Lead r228: the Controls tab row that forgets every seen first-time card (OnboardingTips), after a confirm.
func _build_tips_row(page: VBoxContainer) -> Button:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	row.name = "Row_tips"
	var l: Label = UiBuild.caption(&"ui.options.tips.label")
	l.custom_minimum_size = Vector2(OptionsRows.LABEL_WIDTH, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	tips_button = UiBuild.button(&"ui.options.tips.reset")
	tips_button.name = "ShowTipsAgain"
	tips_button.custom_minimum_size = Vector2(OptionsRows.CONTROL_WIDTH, 0)
	tips_button.pressed.connect(open_tips_confirm)
	row.add_child(tips_button)
	tips_done_label = UiBuild.label(&"ui.options.tips.done", UiBuild.DIM)
	tips_done_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tips_done_label.visible = false
	row.add_child(tips_done_label)
	page.add_child(row)
	var d: Dictionary = _confirm_dialog(&"ui.options.tips.confirm_title", &"ui.options.tips.confirm_body", UiBuild.CARD,
			confirm_tips_reset, close_tips_confirm)
	tips_confirm = d["dim"] as Control
	tips_confirm_button = d["confirm"] as Button
	tips_cancel_button = d["cancel"] as Button
	return tips_button


func is_tips_confirming() -> bool:
	return tips_confirm != null and tips_confirm.visible


## Opens the confirm; focus starts on Cancel so a stray A does not reset.
func open_tips_confirm() -> void:
	if tips_confirm == null:
		return
	tips_confirm.visible = true
	tips_cancel_button.grab_focus.call_deferred()


func close_tips_confirm() -> void:
	if not is_tips_confirming():
		return
	tips_confirm.visible = false
	tips_button.grab_focus.call_deferred()


## Confirmed: every first-time card (situations and heists) shows again; takes effect at once (not on Apply).
func confirm_tips_reset() -> void:
	OnboardingTips.reset()
	close_tips_confirm()
	tips_done_label.visible = true


func is_leave_confirming() -> bool:
	return leave_confirm != null and leave_confirm.visible


## Opens the Leave Heist confirm; focus starts on Cancel so a stray A does not leave.
func open_leave_confirm() -> void:
	if leave_confirm == null:
		return
	leave_confirm.visible = true
	leave_cancel_button.grab_focus.call_deferred()


func close_leave_confirm() -> void:
	if not is_leave_confirming():
		return
	leave_confirm.visible = false
	if leave_button != null:
		leave_button.grab_focus.call_deferred()


## PO-4 footer: Back (ghost) and, in a heist, Leave Heist on the left; Revert and Reset tab (ghost);
## the unapplied note; Apply (the screen's primary) bottom right.
func _build_footer() -> HBoxContainer:
	apply_button = UiBuild.button(&"ui.options.apply")
	revert_button = UiBuild.ghost(UiBuild.button(&"ui.options.revert"))
	reset_button = UiBuild.ghost(UiBuild.button(&"ui.options.reset_tab"))
	back_button = UiBuild.button(&"ui.menu.back")
	var chain: Array[Control] = [back_button]
	if in_heist:
		leave_button = UiBuild.button(&"ui.menu.leave_heist")
		leave_button.pressed.connect(open_leave_confirm)
		chain.append(leave_button)
	chain.append_array([revert_button, reset_button, apply_button] as Array[Control])
	for b: Control in chain:
		b.custom_minimum_size = Vector2(220, 0)
	apply_button.pressed.connect(apply_changes)
	revert_button.pressed.connect(revert)
	reset_button.pressed.connect(reset_tab)
	back_button.pressed.connect(back_requested.emit)
	dirty_label = UiBuild.label(&"ui.options.unapplied", UiBuild.DIM)
	dirty_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dirty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dirty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var middle: Array[Control] = chain.slice(1, chain.size() - 1)
	middle.append(dirty_label)
	var footer: HBoxContainer = UiBuild.footer(back_button, apply_button, middle)
	UiNav.chain_horizontal(chain)
	_update_dirty()
	return footer


## Shows tab `t` and rebuilds the focus chain (focus moves to the tab's first row when `focus` is set).
func show_tab(t: StringName, focus: bool = true) -> void:
	if not pages.has(t):
		return
	if controls_tab != null:
		controls_tab.cancel_capture()
		controls_tab.cancel_conflict()
	current_tab = t
	for id: Variant in pages:
		(pages[id] as Control).visible = id == t
		(tab_buttons[id] as Button).set_pressed_no_signal(id == t)
	_rechain()
	if focus and is_visible_in_tree():
		for c: Control in page_focus[t] as Array[Control]:
			if c.is_visible_in_tree() and not (c is BaseButton and (c as BaseButton).disabled):
				OptionsRows.focus_later(c)
				break


## True when the draft differs from the applied settings.
func is_dirty() -> bool:
	return not draft.equals(settings)


## Copies the draft into `settings`, saves it (save_on_apply) and applies it to the engine.
func apply_changes() -> void:
	settings.copy_from(draft)
	if save_on_apply:
		settings.save()
	settings.apply(get_viewport())
	_update_dirty()
	applied.emit()


## Drops unapplied edits (the pages are rebuilt from `settings`).
func revert() -> void:
	draft.copy_from(settings)
	_build_pages()
	show_tab(current_tab)


## The current tab's settings back to their defaults (in the draft; Apply to keep them).
func reset_tab() -> void:
	for section: Variant in TAB_SECTIONS[current_tab]:
		draft.reset_section(StringName(section))
	_build_pages()
	show_tab(current_tab)


func _build_pages() -> void:
	for c: Node in _page_host.get_children():
		_page_host.remove_child(c)
		c.queue_free()
	var host: VBoxContainer = UiBuild.vbox(0)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_host.add_child(host)
	pages.clear()
	page_focus.clear()
	_row_controls.clear()
	for t: StringName in TABS:
		var page: VBoxContainer = UiBuild.vbox(10)
		page.name = "Page_%s" % t
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.add_child(page)
		pages[t] = page
		page_focus[t] = _fill_page(t, page)


func _fill_page(t: StringName, page: VBoxContainer) -> Array[Control]:
	var out: Array[Control] = []
	match t:
		TAB_CONTROLS:
			out = _rows(page, GameSettings.CONTROLS)
			out.append_array(_rows(page, GameSettings.GAMEPLAY))
			out.append(_build_tips_row(page))
		TAB_KEYS:
			controls_tab = OptionsControlsTab.new()
			page.add_child(controls_tab)
			controls_tab.setup(draft)
			controls_tab.bindings_changed.connect(_update_dirty)
			out.append_array(controls_tab.focus_controls())
		TAB_ACCESSIBILITY:
			out = _rows(page, GameSettings.ACCESSIBILITY)
			palette_preview = UiBuild.hbox(UiTokens.S2)
			palette_preview.name = "PalettePreview"
			page.add_child(palette_preview)
			_refresh_palette_preview()
		_:
			out = _rows(page, StringName(t))
	return out


## One row per key of `section` (slider / toggle / dropdown by spec type).
func _rows(page: VBoxContainer, section: StringName) -> Array[Control]:
	var out: Array[Control] = []
	for key: StringName in draft.defaults.keys(section):
		var sp: Dictionary = draft.defaults.spec(section, key)
		var c: Control = null
		match String(sp.get("type", "")):
			SettingsDefaults.T_FLOAT:
				c = OptionsRows.slider(page, draft, section, key)
			SettingsDefaults.T_BOOL:
				c = OptionsRows.toggle(page, draft, section, key)
			_:
				c = OptionsRows.choice(page, draft, section, key)
		_row_controls["%s/%s" % [section, key]] = c
		out.append(c)
	return out


func _rechain() -> void:
	var tabs: Array[Control] = []
	for t: StringName in TABS:
		tabs.append(tab_buttons[t] as Control)
	UiNav.chain_horizontal(tabs)
	var vertical: Array[Control] = [tab_buttons[current_tab] as Control]
	vertical.append_array(page_focus.get(current_tab, []) as Array[Control])
	vertical.append(apply_button)
	focus_chain = vertical
	UiNav.chain_vertical(focus_chain)
	var last: Control = vertical[vertical.size() - 2]
	for b: Control in [revert_button, reset_button, back_button, leave_button]:
		if b == null:
			continue
		b.focus_neighbor_top = b.get_path_to(last)
		b.focus_neighbor_bottom = b.get_path_to(tab_buttons[current_tab] as Control)
	for t: StringName in TABS:
		var tb: Control = tab_buttons[t] as Control
		tb.focus_neighbor_top = tb.get_path_to(apply_button)
		var first: Control = vertical[1] if vertical.size() > 2 else apply_button
		tb.focus_neighbor_bottom = tb.get_path_to(first)


func _refresh_palette_preview() -> void:
	if palette_preview == null or not is_instance_valid(palette_preview):
		return
	for c: Node in palette_preview.get_children():
		palette_preview.remove_child(c)
		c.queue_free()
	var p: HudPalette = HudPaletteSet.active(draft)
	for f: StringName in HudPalette.FIELDS:
		var sw: ColorRect = ColorRect.new()
		sw.color = p.color(f)
		sw.custom_minimum_size = Vector2(UiTokens.S6, UiTokens.S5)
		sw.tooltip_text = UiText.t(StringName("ui.options.palette.field.%s" % f))
		palette_preview.add_child(sw)


func _on_draft_changed(section: StringName, key: StringName) -> void:
	var c: Control = _row_controls.get("%s/%s" % [section, key]) as Control
	if c != null and is_instance_valid(c):
		OptionsRows.sync(c, draft, section, key)
	if section == GameSettings.ACCESSIBILITY:
		_refresh_palette_preview()
	_update_dirty()


func _update_dirty() -> void:
	if apply_button == null:
		return
	var d: bool = is_dirty()
	apply_button.disabled = not d
	revert_button.disabled = not d
	dirty_label.visible = d


func _unhandled_input(event: InputEvent) -> void:
	if is_leave_confirming() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_leave_confirm()
		return
	if is_tips_confirming() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_tips_confirm()
		return
	if controls_tab != null and (controls_tab.is_capturing() or not controls_tab.pending_conflict.is_empty()) \
			and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		controls_tab.resolve_conflict(OptionsControlsTab.CANCEL)
		return
	super._unhandled_input(event)
