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
## PO-4 "Case File" variations (docs/design/ui/style.md).
const CAPTION: StringName = &"CaptionLabel"
const DISPLAY: StringName = &"DisplayLabel"
const MONEY: StringName = &"MoneyLabel"
const GHOST: StringName = &"GhostButton"
const TAB: StringName = &"TabButton"
const CARD: StringName = &"CardPanel"
const KEYCAP: StringName = &"KeyCap"
const KEYCAP_ROUND: StringName = &"KeyCapRound"
## Pad face buttons drawn as discs (KEYCAP_ROUND) instead of keyboard keys.
const PAD_FACE: Array[String] = ["A", "B", "X", "Y"]
const SCRIM: StringName = &"ScrimPanel"
const MENU_ITEM: StringName = &"MenuItemButton"
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
	return sfx(b, UiSfx.KIND_CONFIRM) as Button


## D-090 UI sounds: wires `b` to play the focus cue on keyboard / pad navigation and the press cue of
## `kind` (UiSfx.KIND_*: confirm, primary, back, tab, none). Every button() is wired as confirm;
## primary() / ghost() / tab() switch the kind. Returns `b`.
static func sfx(b: BaseButton, kind: StringName) -> BaseButton:
	return UiSfx.wire(b, kind)


## Tracked-caps caption label (field names, breadcrumbs, column heads).
static func caption(key: StringName = &"", args: Dictionary = {}) -> Label:
	var l: Label = label(key, CAPTION, args)
	l.uppercase = true
	return l


## A key / pad button glyph ("F", "Space", "A") drawn as a key cap (prompts, hint strips).
static func keycap(text: String, font_size: int = UiTokens.FONT_HUD) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = keycap_variation(text)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l: Label = label(&"", HUD)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override(&"outline_size", 0)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_font_override(&"font", UiTokens.font_caps())
	l.custom_minimum_size = Vector2(font_size * 0.9, 0)
	p.add_child(l)
	return p


## KEYCAP_ROUND for a pad face button while the pad is the active device, else KEYCAP.
static func keycap_variation(text: String) -> StringName:
	return KEYCAP_ROUND if InteractionPanel.pad_active and PAD_FACE.has(text) else KEYCAP


## Marks `b` as a tertiary action (Back, Reset): no fill until hovered. Returns `b`.
static func ghost(b: Button) -> Button:
	b.theme_type_variation = GHOST
	sfx(b, UiSfx.KIND_BACK)
	return b


## Marks `b` as a tab (caps, cyan underline when pressed). Returns `b`.
static func tab(b: Button) -> Button:
	b.theme_type_variation = TAB
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 0)
	sfx(b, UiSfx.KIND_TAB)
	return b


## Marks `b` as the screen's primary action (theme variation PrimaryButton). Returns `b`.
static func primary(b: Button) -> Button:
	b.theme_type_variation = PRIMARY
	sfx(b, UiSfx.KIND_PRIMARY)
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
