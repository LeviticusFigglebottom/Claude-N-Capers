## Briefing screen (pd2_fidelity C2, roadmap B2-02). Owner: ENV B.
## Contact portrait slot + name/role, heist name, briefing text, objectives, loot with difficulty-scaled
## values, contract pay, approach (stealth/loud), escape options, difficulty, the heist's known security
## (D-115, BriefingIntel: the intel column's last section), a blueprint placeholder,
## and "Play Briefing" with in-screen subtitles. Data: BriefingModel.build().
##
## API (MenuFlow wires it): setup(heist_id, difficulty) before or after the screen enters the tree.
## Signals: continue_requested(heist_id, difficulty), back_requested() (UiScreen; Esc / gamepad B).
##
## Voice: "Play Briefing" emits EventBus.voice_line_requested(speaker, line_id, ctx) for the contact's
## briefing lines, one at a time, then the handler's. This is a LOCAL UI fact: it is emitted on this
## machine only, never replicated over Net (each player in a lobby plays their own briefing), and
## ctx carries "local": true and "source": &"briefing" so the voice player can tell it apart from
## in-heist lines. ctx = { "source", "local", "heist_id", "index", "count", "priority" }.
class_name BriefingScreen
extends UiScreen

signal continue_requested(heist_id: StringName, difficulty: int)

const SOURCE: StringName = &"briefing"

var heist_id: StringName = &""
var difficulty: int = Enums.Difficulty.ROUTINE
## Last BriefingModel.build() result (see its header for the shape).
var model: Dictionary = {}
var data: BriefingUiData = null
var playing: bool = false

var portrait: ContactPortrait
var blueprint: BlueprintPlaceholder
## r224 GN capture: the heist's real pre-planning blueprint (read-only, entry floor), over the placeholder sketch,
## which stays only for a heist without one (PreplanBlueprint.placeholder).
var blueprint_view: BlueprintView
var heist_label: Label
var difficulty_label: Label
var mode_label: Label
var pay_label: Label
var placeholder_label: Label
var contact_name_label: Label
var contact_role_label: Label
var briefing_label: Label
var objectives_box: VBoxContainer
## Under the timeline: the loud-branch line and the optional extras (D-109).
var extras_box: VBoxContainer
## D-115: "Known security" (the intel column's last section), one line per BriefingIntel line.
var security_box: VBoxContainer
var loot_box: VBoxContainer
var escape_label: Label
var subtitle_label: Label
## Holds subtitle_label: a long line scrolls here instead of growing the page.
var subtitle_scroll: ScrollContainer
## The intel column (the job, objectives, known security): scrolls when it is taller than the page (720p).
var intel_scroll: ScrollContainer
## LEAD r307 (720p: KNOWN SECURITY cut mid-line): a fade over the column's foot while more lies below, with the
## column's scroll bar shown; hidden at the end of the column or when it all fits.
var intel_fade: TextureRect
var play_button: Button
var continue_button: Button
var back_button: Button
## Heist accent strip beside the header (UiAccent, B4-07).
var accent_strip: ColorRect

var _line_index: int = -1
var _timer: Timer
var _speaker_names: Dictionary = {}


func setup(new_heist_id: StringName, new_difficulty: int) -> void:
	heist_id = new_heist_id
	difficulty = new_difficulty
	if is_node_ready():
		refresh()


func build_ui() -> void:
	data = BriefingModel.ui_data()
	if heist_id == &"":
		var ids: Array[StringName] = HeistCatalog.ids()
		heist_id = ids[0] if not ids.is_empty() else &""
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(next_line)
	add_child(_timer)
	var root: VBoxContainer = UiBuild.vbox(16)
	UiBuild.screen_margin(self, root, 48)
	_build_header(root)
	var body: HBoxContainer = UiBuild.hbox(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_build_contact_column(body)
	_build_intel_column(body)
	_build_side_column(body)
	var nav: HBoxContainer = UiBuild.hbox(16)
	root.add_child(nav)
	back_button = UiBuild.back(UiBuild.button(&"ui.menu.back"))
	continue_button = UiBuild.primary(UiBuild.button(&"ui.briefing.continue"))
	back_button.pressed.connect(_on_back)
	continue_button.pressed.connect(_on_continue)
	nav.add_child(back_button)
	var push: Control = Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(push)
	nav.add_child(continue_button)
	focus_chain.append(continue_button)
	focus_chain.append(play_button)
	focus_chain.append(back_button)
	UiNav.chain_horizontal([back_button, continue_button] as Array[Control], false)
	refresh()


func _build_header(root: VBoxContainer) -> void:
	var header: HBoxContainer = UiBuild.hbox(24)
	root.add_child(header)
	accent_strip = UiAccent.strip(UiAccent.for_heist(heist_id))
	header.add_child(accent_strip)
	var left: VBoxContainer = UiBuild.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(left)
	left.add_child(UiBuild.caption(&"ui.briefing.title"))
	heist_label = UiBuild.label(&"", UiBuild.HEADER)
	left.add_child(heist_label)
	placeholder_label = UiBuild.label(&"ui.briefing.placeholder", UiBuild.DIM)
	placeholder_label.add_theme_color_override(&"font_color", data.placeholder_color)
	left.add_child(placeholder_label)
	var right: VBoxContainer = UiBuild.vbox(4)
	header.add_child(right)
	difficulty_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	mode_label = UiBuild.label(&"", UiBuild.DIM)
	# D-109 pass: the Escape section sat below the fold of the job column (ND/SL); one line under Approach.
	escape_label = UiBuild.label(&"", UiBuild.DIM)
	pay_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	for l: Label in [difficulty_label, mode_label, escape_label, pay_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(l)


func _build_contact_column(body: HBoxContainer) -> void:
	var col: VBoxContainer = UiBuild.vbox(10)
	col.custom_minimum_size = Vector2(data.left_column_width, 0)
	body.add_child(col)
	portrait = ContactPortrait.new()
	portrait.custom_minimum_size = data.portrait_size
	portrait.bg_color = data.portrait_bg
	portrait.figure_color = data.silhouette_color
	col.add_child(portrait)
	contact_name_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	col.add_child(contact_name_label)
	contact_role_label = UiBuild.label(&"", UiBuild.DIM)
	col.add_child(contact_role_label)
	play_button = UiBuild.button(&"ui.briefing.play")
	play_button.custom_minimum_size = Vector2(data.left_column_width, 0)
	play_button.pressed.connect(toggle_briefing)
	col.add_child(play_button)
	subtitle_label = UiBuild.label(&"ui.briefing.subtitle_idle")
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# GN-B1 capture: a long line (Gallery Night's run to ~190 characters) grew the column and pushed Back /
	# Continue off the screen at 720p and 1080p. The line scrolls inside the panel instead.
	subtitle_scroll = ScrollContainer.new()
	subtitle_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	subtitle_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subtitle_scroll.add_child(subtitle_label)
	var sub_panel: PanelContainer = UiBuild.panel(subtitle_scroll)
	sub_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sub_panel)


func _build_intel_column(body: HBoxContainer) -> void:
	var wrap: Control = Control.new()  # the scroll plus the fade over its foot
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(wrap)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(scroll)
	intel_scroll = scroll
	intel_fade = TextureRect.new()
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(UiTokens.INK_0, 0.0))
	grad.set_color(1, Color(UiTokens.INK_0, 0.92))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	intel_fade.texture = tex
	intel_fade.stretch_mode = TextureRect.STRETCH_SCALE
	intel_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intel_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intel_fade.anchor_left = 0.0
	intel_fade.anchor_right = 1.0
	intel_fade.anchor_top = 1.0
	intel_fade.anchor_bottom = 1.0
	intel_fade.offset_top = -float(UiTokens.S7)
	intel_fade.offset_right = -float(UiTokens.S3)  # leave the scroll bar uncovered
	intel_fade.visible = false
	wrap.add_child(intel_fade)
	var more: Label = UiBuild.caption(&"ui.briefing.more_below")
	more.name = "MoreBelow"
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	more.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	more.offset_top = -float(UiTokens.S4)
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intel_fade.add_child(more)
	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	vbar.value_changed.connect(func(_v: float) -> void: _update_intel_fade())
	vbar.changed.connect(_update_intel_fade)
	scroll.resized.connect(_update_intel_fade)
	var col: VBoxContainer = UiBuild.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	col.add_child(_head(&"ui.briefing.intel"))
	briefing_label = UiBuild.label()
	briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(briefing_label)
	col.add_child(_spacer(8))
	col.add_child(_head(&"ui.briefing.objectives"))
	objectives_box = UiBuild.vbox(0)  # the timeline rail runs row to row
	col.add_child(objectives_box)
	extras_box = UiBuild.vbox(UiTokens.S1)  # D-109: "If it goes loud: ..." and the Optional list
	col.add_child(extras_box)
	security_box = UiBuild.vbox(UiTokens.S1)
	security_box.name = "KnownSecurity"
	col.add_child(security_box)


## The fade shows while the intel column has more below its visible part (see intel_fade).
func _update_intel_fade() -> void:
	if intel_scroll == null:
		return
	var bar: VScrollBar = intel_scroll.get_v_scroll_bar()
	intel_fade.visible = bar.max_value - bar.page > float(intel_scroll.scroll_vertical) + 2.0


## True when the intel column is taller than its view (it scrolls; the fade / scroll bar say so).
func intel_overflows() -> bool:
	var bar: VScrollBar = intel_scroll.get_v_scroll_bar()
	return bar.max_value - bar.page > 2.0


## PO-4 section head: a brass caption (style.md §4).
func _head(key: StringName) -> Label:
	var l: Label = UiBuild.caption(key)
	l.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	return l


func _build_side_column(body: HBoxContainer) -> void:
	var col: VBoxContainer = UiBuild.vbox(10)
	col.custom_minimum_size = Vector2(data.right_column_width, 0)
	body.add_child(col)
	col.add_child(_head(&"ui.briefing.blueprint"))
	blueprint = BlueprintPlaceholder.new()
	blueprint.custom_minimum_size = Vector2(0, data.blueprint_min_height)
	blueprint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blueprint.bg_color = data.blueprint_bg
	blueprint.grid_color = data.blueprint_grid
	blueprint.line_color = data.blueprint_line
	col.add_child(blueprint)
	blueprint_view = BlueprintView.new()
	blueprint_view.name = "BriefingBlueprint"
	blueprint_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blueprint_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint_view.visible = false
	blueprint.add_child(blueprint_view)
	col.add_child(_head(&"ui.briefing.loot"))
	loot_box = UiBuild.vbox(6)
	col.add_child(loot_box)


## The heist's real blueprint (entry floor, markers read-only) when it has one; else the placeholder sketch.
func _show_blueprint() -> void:
	var board: PreplanBoard = PreplanBoard.build(heist_id, difficulty) if heist_id != &"" else null
	var real: bool = board != null and board.blueprint != null and not board.blueprint.placeholder
	blueprint_view.visible = real
	blueprint.note.visible = not real  # the "plans pending" note stays under a real blueprint otherwise (UI QA walk)
	if not real:
		return
	blueprint_view.setup(board)
	blueprint_view.set_floor(board.blueprint.entry_floor())  # OF-B1 dry run: OF opened on its basement, not the plaza
	for b: Variant in blueprint_view.markers.values():
		(b as Control).focus_mode = Control.FOCUS_NONE
		(b as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint_view.queue_redraw()


## Rebuilds every text from BriefingModel for the current heist and difficulty.
func refresh() -> void:
	stop_briefing()
	model = BriefingModel.build(heist_id, difficulty)
	heist_label.text = UiText.t(&"ui.briefing.heist", {
		"name": UiText.t(StringName(model["name_key"])), "subtitle": UiText.t(StringName(model["subtitle_key"])),
	})
	accent_strip.color = UiAccent.for_heist(heist_id)
	heist_label.add_theme_color_override(&"font_color", UiAccent.text_color(heist_id, UiAccent.app_bg()))
	placeholder_label.visible = bool(model["placeholder"])
	_show_blueprint()
	difficulty_label.text = UiText.t(&"ui.briefing.difficulty", {"name": UiText.t(UiText.difficulty_key(difficulty))})
	mode_label.text = UiText.t(&"ui.briefing.mode", {"mode": UiText.t(StringName(model["mode_key"]))})
	if bool(model.get("civilian_start", false)):  # B5-05 / S1.3: the job starts without gear
		mode_label.text += "   ·   " + UiText.t(&"ui.briefing.civilian_start")
	pay_label.text = UiText.t(&"ui.briefing.contract_pay", {"amount": UiText.money(int(model["contract_pay"]))})
	var contact: ContactDef = model["contact"] as ContactDef
	portrait.set_contact(contact)
	contact_name_label.text = UiText.t(contact.display_name_key) if contact != null else ""
	contact_role_label.text = UiText.t(contact.role_key) if contact != null else ""
	briefing_label.text = String(model["briefing_text"])
	_fill_objectives()
	_fill_security()
	_fill_loot()
	var escapes: PackedStringArray = PackedStringArray()
	for e: Dictionary in model["escape_options"] as Array:
		escapes.append(String(e["text"]))
	escape_label.text = UiText.t(&"ui.briefing.escape_line", {"options": ", ".join(escapes)}) if not escapes.is_empty() \
			else UiText.t(&"ui.briefing.escape_unknown")
	_speaker_names.clear()
	for c: ContactDef in ContactDef.all():
		_speaker_names[c.voice_speaker] = UiText.t(c.display_name_key)
	subtitle_label.text = UiText.t(&"ui.briefing.subtitle_idle")


func _fill_objectives() -> void:
	for c: Node in objectives_box.get_children():
		c.queue_free()
	var objectives: Array = model["objectives"] as Array
	if objectives.is_empty():
		objectives_box.add_child(UiBuild.label(&"ui.briefing.objectives_none", UiBuild.DIM))
	# PO-4: a timeline: a rail with a node per step (the first, where you start, filled brass).
	var more: int = int(model.get("objectives_more", 0))
	for i: int in range(objectives.size()):
		if more > 0 and i == objectives.size() - 1:
			# D-117 §5: the steps left out sit between the lead steps and the final one.
			# On the timeline: a rail-only node (dashed gap) and the text column, like the step rows.
			var mrow: HBoxContainer = UiBuild.hbox(UiTokens.S3)
			mrow.name = "ObjectivesMoreRow"
			var gap: TimelineNode = TimelineNode.new()
			gap.gap = true
			mrow.add_child(gap)
			var m: Label = UiBuild.label(&"ui.briefing.objectives_more_one" if more == 1 else &"ui.briefing.objectives_more",
					UiBuild.DIM, {"count": more})
			m.name = "ObjectivesMore"
			mrow.add_child(m)
			objectives_box.add_child(mrow)
		var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
		var node: TimelineNode = TimelineNode.new()
		node.first = i == 0
		node.last = i == objectives.size() - 1
		row.add_child(node)
		var l: Label = UiBuild.label(&"ui.briefing.objective_line", &"", {
			"index": int((objectives[i] as Dictionary).get("index", i + 1)), "text": String((objectives[i] as Dictionary)["text"]),
		})
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			l.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
		row.add_child(l)
		objectives_box.add_child(row)
	for c: Node in extras_box.get_children():
		c.queue_free()
	var loud: String = String(model.get("loud_text", ""))
	if loud != "":
		var ll: Label = UiBuild.label(&"ui.briefing.if_loud", UiBuild.DIM, {"text": loud})
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		extras_box.add_child(_spacer(4))
		extras_box.add_child(ll)
	var optional: Array = model.get("optional", []) as Array
	if not optional.is_empty():
		extras_box.add_child(_spacer(4))
		extras_box.add_child(UiBuild.caption(&"ui.briefing.optional"))
		for o: Dictionary in optional:
			var ol: Label = UiBuild.label(&"ui.briefing.optional_line", UiBuild.DIM, {"text": String(o["text"])})
			ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			extras_box.add_child(ol)


## D-115: the heading and one dim line per security item (all text from strings.csv via BriefingIntel).
func _fill_security() -> void:
	for c: Node in security_box.get_children():
		security_box.remove_child(c)  # the new grid takes the name "SecurityGrid" at once
		c.queue_free()
	var lines: Array = model.get("security", []) as Array
	security_box.visible = not lines.is_empty()
	if lines.is_empty():
		return
	security_box.add_child(_spacer(8))
	security_box.add_child(_head(&"ui.briefing.sec.title"))
	# Two columns keep the section short (GN lists 14 items) in the scrolling intel column.
	var grid: GridContainer = GridContainer.new()
	grid.name = "SecurityGrid"
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
	grid.add_theme_constant_override(&"v_separation", UiTokens.S1)
	security_box.add_child(grid)
	for line: Dictionary in lines:
		var l: Label = UiBuild.label(&"ui.briefing.optional_line", UiBuild.DIM, {"text": String(line["text"])})
		l.name = "Sec_%s" % line["id"]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)


## Security lines currently shown (tests), bullet included.
func security_texts() -> Array[String]:
	var out: Array[String] = []
	var grid: Node = security_box.get_node_or_null(^"SecurityGrid")
	if grid == null:
		return out
	for c: Node in grid.get_children():
		if not c.is_queued_for_deletion() and String(c.name).begins_with("Sec_"):
			out.append((c as Label).text)
	return out


func _fill_loot() -> void:
	for c: Node in loot_box.get_children():
		c.queue_free()
	var loot: Array = model["loot"] as Array
	if loot.is_empty():
		loot_box.add_child(UiBuild.label(&"ui.briefing.loot_none", UiBuild.DIM))
	for entry: Dictionary in loot:
		if bool(entry.get("small", false)):  # def-less small loot (loot.small_valuables): no bag value
			loot_box.add_child(UiBuild.label(&"ui.briefing.loot_line_small", &"", {"loot": String(entry["text"])}))
			continue
		loot_box.add_child(UiBuild.label(&"ui.briefing.loot_line", &"", {
			"loot": String(entry["text"]), "value": UiText.money(int(entry["value"])),
		}))


## Objective lines currently shown (tests).
func objective_texts() -> Array[String]:
	var out: Array[String] = []
	for c: Node in objectives_box.get_children():
		if c.is_queued_for_deletion() or c.name == &"ObjectivesMoreRow":
			continue  # D-117 §5: the "+N more" row is not a step
		var l: Label = c as Label if c is Label else c.get_child(1) as Label if c.get_child_count() > 1 else null
		if l != null:
			out.append(l.text)
	return out


func toggle_briefing() -> void:
	if playing:
		stop_briefing()
		subtitle_label.text = UiText.t(&"ui.briefing.subtitle_idle")
	else:
		play_briefing()


## Starts the briefing from its first line. Returns false when the heist has no briefing lines.
func play_briefing() -> bool:
	stop_briefing()
	var lines: Array = model.get("voice_lines", []) as Array
	if lines.is_empty():
		subtitle_label.text = UiText.t(&"ui.briefing.no_lines")
		return false
	playing = true
	play_button.text = UiText.t(&"ui.briefing.stop")
	_line_index = 0
	_play_current()
	return true


## Advances to the next line (the timer calls this; tests and a skip input may too).
func next_line() -> void:
	if not playing:
		return
	_line_index += 1
	if _line_index >= (model["voice_lines"] as Array).size():
		stop_briefing()
		return
	_play_current()


func stop_briefing() -> void:
	playing = false
	_line_index = -1
	if _timer != null:
		_timer.stop()
	if play_button != null:
		play_button.text = UiText.t(&"ui.briefing.play")


func _play_current() -> void:
	var lines: Array = model["voice_lines"] as Array
	var line: Dictionary = lines[_line_index] as Dictionary
	var speaker: StringName = StringName(line.get("speaker", &""))
	var text: String = UiText.t(StringName(line.get("text_key", &"")))
	subtitle_label.text = UiText.t(&"ui.briefing.subtitle", {
		"speaker": String(_speaker_names.get(speaker, String(speaker))), "text": text,
	})
	subtitle_scroll.scroll_vertical = 0
	var ctx: Dictionary = {
		"source": SOURCE, "local": true, "heist_id": heist_id, "index": _line_index,
		"count": lines.size(), "priority": int(line.get("priority", 0)),
	}
	EventBus.voice_line_requested.emit(speaker, StringName(line.get("id", &"")), ctx)
	_timer.start(data.line_gap_s + maxf(data.subtitle_min_s, data.subtitle_s_per_char * text.length()))


func _on_continue() -> void:
	stop_briefing()
	continue_requested.emit(heist_id, difficulty)


func _on_back() -> void:
	stop_briefing()
	back_requested.emit()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		stop_briefing()
	super._on_visibility_changed()


static func _spacer(height: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
