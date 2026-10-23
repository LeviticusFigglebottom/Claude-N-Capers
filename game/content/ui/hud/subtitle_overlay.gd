## In-heist subtitles (B7-03; brief content/docs/radio.md). Owner: ENV B.
## Shows EventBus.voice_line_requested lines: every ContactRadio line (ctx.source == &"radio") and the lines of
## RadioTweak.subtitle_speakers from anyone else (ENV C's mission say(), A's abort / last-pager lines; they reach
## every peer as [R] voice_line_requested). Briefing playback (ctx.source == &"briefing") is never shown here.
## A row = the speaker's name in their accent (ContactDef.accent_color, a heister's roster accent, lifted to
## RadioTweak.min_contrast on the panel) + the line text (VoiceLineTable text_key, `{arg}`s from ctx, ctx values
## that are string keys translated, e.g. {escape} = ui.escape.heli). Text colour = the active HUD palette's
## interaction colour (HudPaletteSet). Each row stays RadioTweak.display_s(text) (length-scaled), fading over
## fade_s; at most max_lines rows, oldest dropped. Font size = font_sizes[accessibility/subtitle_size], live via
## GameSettings.changed. Placed bottom-centre, width_px wide: clear of the vitals / ammo corners up to hud_scale 1.5.
class_name SubtitleOverlay
extends Control

const SOURCE_BRIEFING: StringName = &"briefing"
const SPEAKER_KEY: StringName = &"ui.subtitle.speaker"
## A non-contact, non-heister speaker's display name (ui.subtitle.name.dj = "DJ"); absent = the capitalised id.
const NAME_KEY_FMT: String = "ui.subtitle.name.%s"

## Settings followed (null = GameSettings.current(); tests set their own before _ready).
## Group the overlay joins so the HUD can keep objective markers clear of its box (Hud._subtitle_rect).
const GROUP: StringName = &"subtitle_overlay"

var settings: GameSettings = null
var tweak: RadioTweak = null
var table: VoiceLineTable = null
var box: VBoxContainer
## Visible rows, oldest first: {panel, speaker, text, left, total, color}.
var rows: Array[Dictionary] = []
## Advanced by _process; tests set auto_process = false and call advance().
var auto_process: bool = true
var _text_color: Color = Color.WHITE
var _contacts: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	if tweak == null:
		tweak = RadioTweak.load_default()
	if table == null:
		table = load(ContactRadio.LINES_PATH) as VoiceLineTable
	if settings == null:
		settings = GameSettings.current()
	if theme == null:
		theme = UiBuild.theme()
	for c: ContactDef in ContactDef.all():
		_contacts[c.voice_speaker] = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -tweak.width_px * 0.5
	offset_right = tweak.width_px * 0.5
	offset_bottom = -tweak.bottom_margin_px
	offset_top = offset_bottom - 480.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override(&"separation", 6)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.changed.connect(_on_settings_changed)
	EventBus.voice_line_requested.connect(_on_voice_line_requested)
	EventBus.heist_ended.connect(_on_heist_ended)
	apply_settings()


func _exit_tree() -> void:
	if settings != null and settings.changed.is_connected(_on_settings_changed):
		settings.changed.disconnect(_on_settings_changed)


func _process(delta: float) -> void:
	if auto_process:
		advance(delta)
	fit_height()


## Drops the oldest rows while the shown rows are taller than RadioTweak.max_height_px (one row stays).
func fit_height() -> void:
	while rows.size() > 1:
		var h: float = 0.0
		for r: Dictionary in rows:
			h += (r["panel"] as Control).size.y + 6.0
		if h <= tweak.max_height_px:
			return
		_drop(0)


## Shows `line_id` said by `speaker` (ctx = voice_line_requested context). False when it is not shown (unknown
## speaker for subtitles, briefing playback, or no text).
func show_line(speaker: StringName, line_id: StringName, ctx: Dictionary = {}) -> bool:
	var src: StringName = StringName(ctx.get("source", &""))
	if src == SOURCE_BRIEFING or (src != ContactRadio.SOURCE and not _shows_speaker(speaker)):
		return false
	if settings != null and not settings.subtitles():
		return false  # Options parity: Accessibility > Subtitles off
	var key: StringName = StringName(table.line(line_id).get("text_key", StringName("voice.%s" % line_id)))
	if not StringTable.has(key):
		return false
	var text: String = StringTable.text(key, _args(ctx))
	while rows.size() >= maxi(tweak.max_lines, 1):
		_drop(0)
	var row: Dictionary = _build_row(speaker, text)
	rows.append(row)
	box.add_child(row["panel"] as Control)
	return true


## Ticks every row's timer, fading the last fade_s and removing expired rows.
func advance(dt: float) -> void:
	for i: int in range(rows.size() - 1, -1, -1):
		var r: Dictionary = rows[i]
		r["left"] = float(r["left"]) - dt
		if float(r["left"]) <= 0.0:
			_drop(i)
			continue
		(r["panel"] as Control).modulate.a = clampf(float(r["left"]) / maxf(tweak.fade_s, 0.001), 0.0, 1.0)


func clear() -> void:
	while not rows.is_empty():
		_drop(0)


## Contact / handler lines always; everyone else (guard barks, crew acks, heister barks) with
## accessibility/subtitles_all_speakers (Options, default ON since LEAD r226: barks are dialogue).
func _shows_speaker(speaker: StringName) -> bool:
	return tweak.subtitle_speakers.has(speaker) \
			or bool(settings.get_value(GameSettings.ACCESSIBILITY, &"subtitles_all_speakers"))


## Font size for the current accessibility/subtitle_size.
func font_size() -> int:
	return tweak.font_size_for(String(settings.get_value(GameSettings.ACCESSIBILITY, &"subtitle_size")))


## Re-reads subtitle size and palette; existing rows follow.
func apply_settings() -> void:
	_text_color = HudPaletteSet.active_tweak(settings).interaction_color
	var fs: int = font_size()
	for r: Dictionary in rows:
		for l: Label in [r["speaker"] as Label, r["text"] as Label]:
			l.add_theme_font_size_override(&"font_size", fs)
		(r["text"] as Label).add_theme_color_override(&"font_color", _text_color)


## Display name and accent colour of `speaker` (contacts, then heisters, then ui.subtitle.name.<id> (Afterhours'
## "DJ"), then a capitalised id).
func speaker_style(speaker: StringName) -> Array:
	var c: ContactDef = _contacts.get(speaker) as ContactDef
	if c != null:
		return [StringTable.text(c.display_name_key), c.accent_color]
	if Heisters.is_known(speaker):
		return [Heisters.display_name(speaker), Heisters.accent(speaker)]
	var key: StringName = StringName(NAME_KEY_FMT % speaker)
	if StringTable.has(key):
		return [StringTable.text(key), _text_color]
	return [String(speaker).capitalize(), _text_color]


func _build_row(speaker: StringName, text: String) -> Dictionary:
	var style: Array = speaker_style(speaker)
	var bg: Color = UiAccent.over(tweak.panel_color, Color.BLACK)
	var accent: Color = UiAccent.readable(style[1] as Color, bg, tweak.min_contrast)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = tweak.panel_color
	sb.set_content_margin_all(8.0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	panel.add_theme_stylebox_override(&"panel", sb)
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override(&"separation", 10)
	panel.add_child(hb)
	var who: Label = Label.new()
	who.text = StringTable.text(SPEAKER_KEY, {"name": String(style[0])})
	who.add_theme_color_override(&"font_color", accent)
	who.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(who)
	var what: Label = Label.new()
	what.text = text
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.add_theme_color_override(&"font_color", _text_color)
	hb.add_child(what)
	var fs: int = font_size()
	who.add_theme_font_size_override(&"font_size", fs)
	what.add_theme_font_size_override(&"font_size", fs)
	var t: float = tweak.display_s(text)
	return {"panel": panel, "speaker": who, "text": what, "left": t, "total": t, "color": accent}


func _drop(i: int) -> void:
	var r: Dictionary = rows[i]
	rows.remove_at(i)
	var p: Control = r["panel"] as Control
	if is_instance_valid(p):
		p.queue_free()
		if p.get_parent() != null:
			p.get_parent().remove_child(p)


## ctx -> format args: string values that are string keys (e.g. ui.escape.heli) are translated.
static func _args(ctx: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in ctx:
		var v: Variant = ctx[k]
		if (v is String or v is StringName) and String(v).contains(".") and StringTable.has(StringName(v)):
			out[k] = StringTable.text(StringName(v))
		elif v is float:
			out[k] = roundi(v)  # HUD readability pass: "Van's 240.0 seconds out" -> "240 seconds"
		else:
			out[k] = v
	return out


func _on_voice_line_requested(speaker: StringName, line_id: StringName, ctx: Dictionary) -> void:
	show_line(speaker, line_id, ctx)


func _on_heist_ended(_result: Dictionary) -> void:
	clear()
	visible = false


func _on_settings_changed(section: StringName, _key: StringName) -> void:
	if section == GameSettings.ACCESSIBILITY:
		apply_settings()
