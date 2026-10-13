## Small control factories so every screen builds the same looking widgets from the shared theme
## (res://content/ui/theme/caper_theme.tres). Owner: ENV B. Text is always a strings.csv key.
class_name UiBuild
extends RefCounted

const THEME_PATH: String = "res://content/ui/theme/caper_theme.tres"
## Theme type variations defined in caper_theme.tres.
const HEADER: StringName = &"HeaderLabel"
const SUBHEADER: StringName = &"SubheaderLabel"
const DIM: StringName = &"DimLabel"
const HUD: StringName = &"HudLabel"
const HUD_BIG: StringName = &"HudBigLabel"
const HUD_PANEL: StringName = &"HudPanel"
const BANNER_PANEL: StringName = &"BannerPanel"
## The screen's main forward action (Launch, Continue, Confirm, Take): brass-edged button (B4-07).
const PRIMARY: StringName = &"PrimaryButton"
## PQ-B-23 floating HUD text style (see float_text).
const FLOAT_OUTLINE_SIZE: int = 8
const FLOAT_OUTLINE_COLOR: Color = Color(0, 0, 0, 1)
const FLOAT_SHADOW_COLOR: Color = Color(0, 0, 0, 0.55)
const FLOAT_SHADOW_OFFSET: Vector2i = Vector2i(2, 3)
const FLOAT_SHADOW_SOFTNESS: int = 6


static func theme() -> Theme:
	return load(THEME_PATH) as Theme


## PQ-B-23 (lead ruling): floating HUD text (world prompts, casing hint, domination prompt) gets an
## outline of 8 plus a soft dark drop shadow, no backing panel.
static func float_text(l: Label) -> Label:
	l.add_theme_constant_override(&"outline_size", FLOAT_OUTLINE_SIZE)
	l.add_theme_color_override(&"font_outline_color", FLOAT_OUTLINE_COLOR)
	l.add_theme_color_override(&"font_shadow_color", FLOAT_SHADOW_COLOR)
	l.add_theme_constant_override(&"shadow_offset_x", FLOAT_SHADOW_OFFSET.x)
	l.add_theme_constant_override(&"shadow_offset_y", FLOAT_SHADOW_OFFSET.y)
	l.add_theme_constant_override(&"shadow_outline_size", FLOAT_SHADOW_SOFTNESS)
	return l


static func label(key: StringName = &"", variation: StringName = &"", args: Dictionary = {}) -> Label:
	var l: Label = Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if key != &"":
		l.text = UiText.t(key, args)
	if variation != &"":
		l.theme_type_variation = variation
	return l


static func button(key: StringName, args: Dictionary = {}) -> Button:
	var b: Button = Button.new()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = UiText.t(key, args)
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(320, 0)
	return b


## Marks `b` as the screen's primary action (theme variation PrimaryButton). Returns `b`.
static func primary(b: Button) -> Button:
	b.theme_type_variation = PRIMARY
	return b


static func option_button() -> OptionButton:
	var o: OptionButton = OptionButton.new()
	o.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	o.focus_mode = Control.FOCUS_ALL
	o.custom_minimum_size = Vector2(360, 0)
	return o


static func vbox(separation: int = 12) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override(&"separation", separation)
	return v


static func hbox(separation: int = 12) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override(&"separation", separation)
	return h


## Full-rect margin container (safe area ~4% of the 1920x1080 base) holding `child`.
static func screen_margin(parent: Control, child: Control, margin: int = 64) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	parent.add_child(m)
	m.add_child(child)
	return m


static func panel(child: Control, variation: StringName = &"") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	if variation != &"":
		p.theme_type_variation = variation
	p.add_child(child)
	return p


static func bar(color: Color, min_size: Vector2 = Vector2(240, 14)) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	b.custom_minimum_size = min_size
	b.self_modulate = color
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b
