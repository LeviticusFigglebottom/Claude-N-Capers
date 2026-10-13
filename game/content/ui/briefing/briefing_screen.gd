## Briefing screen (pd2_fidelity C2, roadmap B2-02). Owner: ENV B.
## Contact portrait slot + name/role, heist name, briefing text, objectives, loot with difficulty-scaled
## values, contract pay, approach (stealth/loud), escape options, difficulty, a blueprint placeholder,
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
var heist_label: Label
var difficulty_label: Label
var mode_label: Label
var pay_label: Label
var placeholder_label: Label
var contact_name_label: Label
var contact_role_label: Label
var briefing_label: Label
var objectives_box: VBoxContainer
var loot_box: VBoxContainer
var escape_label: Label
var subtitle_label: Label
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
	back_button = UiBuild.ghost(UiBuild.button(&"ui.menu.back"))
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
	pay_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	for l: Label in [difficulty_label, mode_label, pay_label]:
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
	subtitle_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sub_panel: PanelContainer = UiBuild.panel(subtitle_label)
	sub_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sub_panel)


func _build_intel_column(body: HBoxContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
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
	col.add_child(_spacer(8))
	col.add_child(_head(&"ui.briefing.escape"))
	escape_label = UiBuild.label()
	escape_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(escape_label)


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
	col.add_child(_head(&"ui.briefing.loot"))
	loot_box = UiBuild.vbox(6)
	col.add_child(loot_box)


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
	difficulty_label.text = UiText.t(&"ui.briefing.difficulty", {"name": UiText.t(UiText.difficulty_key(difficulty))})
	mode_label.text = UiText.t(&"ui.briefing.mode", {"mode": UiText.t(StringName(model["mode_key"]))})
	pay_label.text = UiText.t(&"ui.briefing.contract_pay", {"amount": UiText.money(int(model["contract_pay"]))})
	var contact: ContactDef = model["contact"] as ContactDef
	portrait.set_contact(contact)
	contact_name_label.text = UiText.t(contact.display_name_key) if contact != null else ""
	contact_role_label.text = UiText.t(contact.role_key) if contact != null else ""
	briefing_label.text = String(model["briefing_text"])
	_fill_objectives()
	_fill_loot()
	var escapes: PackedStringArray = PackedStringArray()
	for e: Dictionary in model["escape_options"] as Array:
		escapes.append(String(e["text"]))
	escape_label.text = ", ".join(escapes) if not escapes.is_empty() else UiText.t(&"ui.briefing.escape_unknown")
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
	for i: int in range(objectives.size()):
		var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
		var node: TimelineNode = TimelineNode.new()
		node.first = i == 0
		node.last = i == objectives.size() - 1
		row.add_child(node)
		var l: Label = UiBuild.label(&"ui.briefing.objective_line", &"", {
			"index": i + 1, "text": String((objectives[i] as Dictionary)["text"]),
		})
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			l.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
		row.add_child(l)
		objectives_box.add_child(row)


func _fill_loot() -> void:
	for c: Node in loot_box.get_children():
		c.queue_free()
	var loot: Array = model["loot"] as Array
	if loot.is_empty():
		loot_box.add_child(UiBuild.label(&"ui.briefing.loot_none", UiBuild.DIM))
	for entry: Dictionary in loot:
		loot_box.add_child(UiBuild.label(&"ui.briefing.loot_line", &"", {
			"loot": String(entry["text"]), "value": UiText.money(int(entry["value"])),
		}))


## Objective lines currently shown (tests).
func objective_texts() -> Array[String]:
	var out: Array[String] = []
	for c: Node in objectives_box.get_children():
		if c.is_queued_for_deletion():
			continue
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
