## Heist loading screen (lead queue b): shown by MenuFlow.launch() while HeistLauncher.launch() runs,
## over the Case File backdrop. Heist name (in its accent) and difficulty, a "LOADING" caption with a
## running bar, and one PD2-style tip that changes every TIP_S (picked with GameRng stream &"ui_tips",
## never the same twice in a row). Owner: ENV B.
class_name LoadingScreen
extends Control

const TIP_S: float = 6.0
const TIP_COUNT: int = 14

var heist_id: StringName = &""
var difficulty: int = Enums.Difficulty.ROUTINE
var title: Label
var caption: Label
var subtitle: Label
var tip_label: Label
var bar: ProgressBar
var accent: ColorRect
## Index of the tip on screen (tests).
var tip_index: int = -1
var _tip_t: float = 0.0
var _bar_t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind is clickable while loading
	if theme == null:
		theme = UiBuild.theme()
	var back: ColorRect = ColorRect.new()
	back.color = UiTokens.INK_0
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var grid: Control = CaseBackdrop.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(grid)
	var col: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	col.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	col.offset_left = UiTokens.MARGIN + UiTokens.S5
	col.offset_right = col.offset_left + 1100.0
	col.offset_top = -420.0
	col.offset_bottom = -UiTokens.MARGIN - UiTokens.S5
	col.alignment = BoxContainer.ALIGNMENT_END
	add_child(col)
	caption = UiBuild.caption()
	caption.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	col.add_child(caption)
	title = UiBuild.label(&"", UiBuild.DISPLAY)
	title.add_theme_font_size_override(&"font_size", UiTokens.FONT_H1 + 16)
	col.add_child(title)
	subtitle = UiBuild.label(&"", UiBuild.DIM)
	subtitle.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	col.add_child(subtitle)
	accent = ColorRect.new()
	accent.custom_minimum_size = Vector2(96, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(accent)
	tip_label = UiBuild.label(&"", UiBuild.DIM)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	tip_label.custom_minimum_size = Vector2(900, 0)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.S4)
	col.add_child(gap)
	var tip_cap: Label = UiBuild.caption(&"ui.loading.tip_caption")
	tip_cap.add_theme_color_override(&"font_color", UiTokens.PAPER_DIM)
	col.add_child(tip_cap)
	col.add_child(tip_label)
	var loading: Label = UiBuild.caption(&"ui.loading.loading")
	loading.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	loading.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	loading.grow_vertical = Control.GROW_DIRECTION_BEGIN
	loading.offset_right = -UiTokens.MARGIN - UiTokens.S5
	loading.offset_bottom = -UiTokens.MARGIN - UiTokens.S5 - 14.0
	add_child(loading)
	bar = UiBuild.bar(UiTokens.BRASS, Vector2(240, 3))
	bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bar.offset_left = -UiTokens.MARGIN - UiTokens.S5 - 240.0
	bar.offset_right = -UiTokens.MARGIN - UiTokens.S5
	bar.offset_top = -UiTokens.MARGIN - UiTokens.S5
	bar.offset_bottom = bar.offset_top + 3.0
	add_child(bar)
	_fill()
	next_tip()


func setup(id: StringName, diff: int) -> void:
	heist_id = id
	difficulty = diff
	if is_node_ready():
		_fill()


func _fill() -> void:
	title.text = UiText.t(StringName("heist.%s.name" % heist_id)) if heist_id != &"" else ""
	var sub_key: StringName = StringName("heist.%s.subtitle" % heist_id)
	subtitle.text = UiText.t(sub_key) if heist_id != &"" else ""
	subtitle.visible = subtitle.text != "" and subtitle.text != String(sub_key)
	accent.color = UiAccent.for_heist(heist_id) if heist_id != &"" else UiTokens.BRASS
	caption.text = UiText.t(&"ui.loading.caption", {"difficulty": UiText.t(UiText.difficulty_key(difficulty))}).to_upper()


## Shows another tip (never the one on screen).
func next_tip() -> void:
	var rng: RandomNumberGenerator = GameRng.stream(&"ui_tips")
	var i: int = rng.randi_range(0, TIP_COUNT - 1)
	if i == tip_index:
		i = (i + 1) % TIP_COUNT
	tip_index = i
	tip_label.text = UiText.t(StringName("ui.loading.tip.%d" % (i + 1)))
	_tip_t = TIP_S


func _process(delta: float) -> void:
	_tip_t -= delta
	if _tip_t <= 0.0:
		next_tip()
	# An indeterminate bar: a sweep that loops (the launcher reports no progress).
	_bar_t = fmod(_bar_t + delta * 0.6, 1.0)
	bar.value = _bar_t if UiTokens.motion_ok() else 1.0
