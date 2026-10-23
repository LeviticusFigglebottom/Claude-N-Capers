## Small control factories so every screen builds the same looking widgets from the shared theme
## (res://content/ui/theme/caper_theme.tres). Owner: ENV B. Text is always a strings.csv key.
class_name UiBuild
extends RefCounted

## header()'s breadcrumb label name, and the crumb roots set_crumb_root() swaps.
const CRUMB_NAME: String = "Crumb"
const CRUMB_SAFEHOUSE: StringName = &"ui.crumb.safehouse"
const CRUMB_MAIN_MENU: StringName = &"ui.crumb.main_menu"
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
## r249 contrast ruling (style.md "fill vs local background >= 3:1"): the small HUD labels that failed it on the OF
## facade (world-marker labels, teammate names) sit on a subtle rounded scrim (~45% black: white over near-white
## stone measures ~3.4:1); the objective block stays frameless (PO-4).
const LABEL_SCRIM_COLOR: Color = Color(0, 0, 0, 0.45)
const LABEL_SCRIM_RADIUS: int = 4
const LABEL_SCRIM_PAD: Vector2 = Vector2(6, 2)
## r266: the status scrim (vitals captions, a teammate's Downed / In custody line): text that must read on a bright
## scene (white galleries, limestone, dawn) needs more than the 45% name scrim to keep a 3:1 fill.
const LABEL_SCRIM_STRONG_ALPHA: float = 0.75


## The r249 label scrim as a StyleBoxFlat (Label "normal" style, or ObjectiveMarkers.draw_style_box).
static func label_scrim(alpha: float = LABEL_SCRIM_COLOR.a) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(LABEL_SCRIM_COLOR, alpha)
	sb.set_corner_radius_all(LABEL_SCRIM_RADIUS)
	sb.content_margin_left = LABEL_SCRIM_PAD.x
	sb.content_margin_right = LABEL_SCRIM_PAD.x
	sb.content_margin_top = LABEL_SCRIM_PAD.y
	sb.content_margin_bottom = LABEL_SCRIM_PAD.y
	return sb


## `l` on the r249 label scrim (its text keeps the float outline / shadow).
static func scrim_label(l: Label, alpha: float = LABEL_SCRIM_COLOR.a) -> Label:
	l.add_theme_stylebox_override(&"normal", label_scrim(alpha))
	return l


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
## Marks `b` as a Back / Cancel / Leave button: the standard panelled Button (LEAD r299 / r304: a ghost reads faint
## over the 3D safehouse and the briefing backdrops) with the back click. Returns `b`.
static func back(b: Button) -> Button:
	sfx(b, UiSfx.KIND_BACK)
	return b


static func ghost(b: Button) -> Button:
	b.theme_type_variation = GHOST
	sfx(b, UiSfx.KIND_BACK)
	return b


## Marks `b` as a tab (caps, cyan underline when pressed). Returns `b`. Its current text is uppercased
## (style.md §5); set later text through tab_text().
static func tab(b: Button) -> Button:
	b.theme_type_variation = TAB
	b.text = b.text.to_upper()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 0)
	sfx(b, UiSfx.KIND_TAB)
	return b


## Sets a tab's text (uppercased like tab()).
static func tab_text(b: Button, text: String) -> void:
	b.text = text.to_upper()


## Marks `b` as the screen's primary action (theme variation PrimaryButton). Returns `b`.
static func primary(b: Button) -> Button:
	b.theme_type_variation = PRIMARY
	sfx(b, UiSfx.KIND_PRIMARY)
	return b


## PO-4 screen header (style.md §2): a caption breadcrumb ("SAFEHOUSE / CONTRACTS") over an H1 title.
## The title label is the box's last child (`header_title()`).
static func header(crumb_key: StringName, title_key: StringName, args: Dictionary = {}) -> VBoxContainer:
	var v: VBoxContainer = vbox(UiTokens.S1)
	var crumb: Label = caption(crumb_key)
	crumb.name = CRUMB_NAME
	crumb.set_meta(&"crumb_key", crumb_key)
	v.add_child(crumb)
	v.add_child(label(title_key, HEADER, args))
	return v


## LEAD r307: the breadcrumb follows the path taken. Every header() crumb of `screen` that starts "Safehouse / …"
## reads "Main menu / …" when `from_main_menu` (MenuFlow's direct entries), else its own text.
static func set_crumb_root(screen: Node, from_main_menu: bool) -> void:
	var safe: String = UiText.t(CRUMB_SAFEHOUSE)
	for n: Node in screen.find_children(CRUMB_NAME, "Label", true, false):
		var l: Label = n as Label
		if not l.has_meta(&"crumb_key"):
			continue
		var full: String = UiText.t(StringName(l.get_meta(&"crumb_key")))
		if from_main_menu and full.begins_with(safe + " /"):
			full = UiText.t(CRUMB_MAIN_MENU) + full.substr(safe.length())
		l.text = full


## The H1 of a box made by header().
static func header_title(h: VBoxContainer) -> Label:
	return h.get_child(h.get_child_count() - 1) as Label


## PO-4 field: a caption ("STASH") over its value control. Returns the box; the value is child 1.
static func field(caption_key: StringName, value: Control, separation: int = 0) -> VBoxContainer:
	var v: VBoxContainer = vbox(separation)
	v.add_child(caption(caption_key))
	v.add_child(value)
	return v


## An empty control that takes the free width of an HBox (pushes what follows to the right).
static func spacer() -> Control:
	var c: Control = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## PO-4 footer band (style.md §2): `back_button` (made back(): panelled, LEAD r304) on the left, `middle` controls
## after it, then `primary_button` (made primary) pushed to the right. Either may be null.
static func footer(back_button: Button, primary_button: Button = null, middle: Array[Control] = []) -> HBoxContainer:
	var h: HBoxContainer = hbox(UiTokens.S3)
	if back_button != null:
		h.add_child(back(back_button))
	for c: Control in middle:
		h.add_child(c)
	h.add_child(spacer())
	if primary_button != null:
		h.add_child(primary(primary_button))
	return h


## Makes a read-only panel focusable (keyboard / pad scroll a list through it) with a visible focus:
## its edge turns cyan while it has focus (style.md §5, focus is always visible). Returns `p`.
static func focus_panel(p: PanelContainer) -> PanelContainer:
	p.focus_mode = Control.FOCUS_ALL
	p.focus_entered.connect(func() -> void:
		var base: StyleBox = p.get_theme_stylebox(&"panel")
		var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate() as StyleBoxFlat if base is StyleBoxFlat else StyleBoxFlat.new()
		sb.border_color = UiTokens.CYAN
		sb.set_border_width_all(maxi(sb.border_width_left, 2))
		p.set_meta(&"_unfocused_panel", base)
		p.add_theme_stylebox_override(&"panel", sb))
	p.focus_exited.connect(func() -> void:
		p.remove_theme_stylebox_override(&"panel")
		if p.has_meta(&"_unfocused_panel") and p.get_meta(&"_unfocused_panel") != p.get_theme_stylebox(&"panel"):
			p.add_theme_stylebox_override(&"panel", p.get_meta(&"_unfocused_panel") as StyleBox))
	return p


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
